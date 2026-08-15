import { NextRequest, NextResponse } from 'next/server'
import Anthropic from '@anthropic-ai/sdk'
import { b2bSocket } from '@/lib/sockets/b2b'
import { parcelSocket } from '@/lib/sockets/parcels'
import { amenitySocket } from '@/lib/sockets/amenities'
import { pirSocket } from '@/lib/sockets/pir'
import { summarisePirReport, pirConceptCount } from '@/lib/pir-summary'
import { PostgrestError } from '@/lib/sockets/postgrest'
import { landUseLabel, labelToDorCode } from '@/lib/dor-use-codes'
import { checkRateLimit, pruneRateLimitStore } from '@/lib/rateLimit'
import type { B2BAccount } from '@/types/b2b'

const MODEL = 'claude-opus-4-8' // per claude-api skill: default Opus 4.8

// ── Opus 4.8 per-token rates (USD), as of 2026-07-23 ──────────────────────────
// cost_usd is computed here at request time and stored as a literal in the log;
// if these rates change, update them here — historical rows are NOT recomputed.
// Input $5 / output $25 / cache-read $0.50 / cache-write(5m) $6.25 per 1M tokens.
const RATE_INPUT = 5.0 / 1_000_000
const RATE_OUTPUT = 25.0 / 1_000_000
const RATE_CACHE_READ = 0.5 / 1_000_000
const RATE_CACHE_WRITE = 6.25 / 1_000_000 // default 5-min ephemeral cache

// ── Cost guardrails (env-overridable) ──
// OBSERVE-ONLY defaults on purpose. The $100/mo "ceiling" is an unverified guess
// (possibly a retail benchmark, not COGS) — enforcing on it would 402 a paying
// customer over a placeholder. So: hard cap is a catastrophe-only backstop, and
// the warn/alert thresholds sit LOW so we SEE the distribution form rather than
// block. Set real numbers from assistant_cost_report() once traffic exists.
const MONTHLY_HARD_CAP_USD = Number(process.env.ASSISTANT_MONTHLY_HARD_CAP_USD ?? 1000) // catastrophe backstop, not a business limit
const MONTHLY_SOFT_WARN_USD = Number(process.env.ASSISTANT_MONTHLY_SOFT_WARN_USD ?? 25) // low = observe the distribution
const ALERT_24H_USD = Number(process.env.ASSISTANT_24H_ALERT_USD ?? 10) // observation, not enforcement
const PER_QUERY_TOKEN_CAP = Number(process.env.ASSISTANT_PER_QUERY_TOKEN_CAP ?? 200_000) // runaway-query guard, not a business threshold — safe to keep

const M_TO_FT = 3.28084
const usd = (n: number) => (n >= 1_000_000 ? `$${(n / 1_000_000).toFixed(2)}M` : `$${Math.round(n).toLocaleString('en-US')}`)

const PROVENANCE =
  'Source: parcels_staging + get_site_intelligence() — assessor values are as recorded by the county property appraiser; GIS lot size is computed live from parcel geometry. Flood: fema_flood_zones. Elevation: parcel_elevations. Amenities: county GIS + HIFLD.'

// ── Tool definitions (built per tier) ─────────────────────────────────────────
const SINGLE_PROPERTY_TOOLS: Anthropic.Tool[] = [
  {
    name: 'find_parcel',
    description:
      "Look up a property by street address to get its parcel_id. Call this FIRST whenever the user names or describes a single address, before any report. Returns candidate parcels (parcel_id, address, city, just value).",
    input_schema: {
      type: 'object',
      properties: {
        address: { type: 'string', description: "Street address or fragment, e.g. '1778 Earhart Ct'" },
        county: { type: 'string', description: "County name, e.g. 'Volusia'. Optional; defaults to the account's county." },
      },
      required: ['address'],
    },
  },
  {
    name: 'get_property_report',
    description:
      "Get the full intelligence report for ONE parcel — the SAME document the Property Intelligence Report renders (get_pir_report). Covers owner and ownership, land use, year built and areas, assessed values and tax, flood zones with percentage of parcel, ground elevation, water adjacency (bay/canal/creek, named), wetland, historic designations, sinkhole susceptibility, aquifer vulnerability, mining, surface geology, zoning, permits, recorded conveyances, tax-deed status, land restrictions, contamination and pollution notices, census/demographics, schools and amenities. Call after find_parcel. Needs parcel_id. Fields carry their own coverage state — 'not_recorded' and 'not_available' are real answers and must be reported as such, never as zero or absent.",
    input_schema: {
      type: 'object',
      properties: {
        parcel_id: { type: 'string', description: 'Exact parcel_id from find_parcel' },
        county: { type: 'string', description: "County name. Optional; defaults to the account's county." },
      },
      required: ['parcel_id'],
    },
  },
  {
    name: 'get_nearby_amenities',
    description:
      "List the nearest civic/safety amenities for a parcel (hospital, fire station, school, police; plus hydrants/bus/SunRail/library where mapped) with distance and compass bearing. Coverage-aware — only returns types that have data for that county.",
    input_schema: {
      type: 'object',
      properties: {
        parcel_id: { type: 'string', description: 'Exact parcel_id from find_parcel' },
        county: { type: 'string', description: "County name. Optional; defaults to the account's county." },
      },
      required: ['parcel_id'],
    },
  },
]

const PRO_TOOLS: Anthropic.Tool[] = [
  {
    name: 'search_properties',
    description:
      "PRO ONLY. Search MANY properties in a county by fixed filters (value range, land use, city) and return matching parcels. Use for cross-property / portfolio questions, NOT single addresses. Filters are fixed fields only — no free-form SQL.",
    input_schema: {
      type: 'object',
      properties: {
        county: { type: 'string', description: "County name, e.g. 'Volusia'." },
        min_value: { type: 'number', description: 'Minimum just value in USD' },
        max_value: { type: 'number', description: 'Maximum just value in USD' },
        land_use: { type: 'string', description: "Land-use label ('Single Family') or DOR code ('001')" },
        city: { type: 'string', description: 'City name filter' },
        limit: { type: 'number', description: 'Max rows (default 25)' },
      },
      required: [],
    },
  },
  {
    name: 'search_properties_stats',
    description:
      "PRO ONLY. Aggregate statistics (count, average, min, max just value) across properties matching fixed filters. Use for 'how many…', 'average value of…' style questions.",
    input_schema: {
      type: 'object',
      properties: {
        county: { type: 'string', description: 'County name' },
        min_value: { type: 'number' },
        max_value: { type: 'number' },
        land_use: { type: 'string', description: "Land-use label or DOR code" },
        city: { type: 'string' },
      },
      required: [],
    },
  },
]

const CROSS_PROPERTY = new Set(['search_properties', 'search_properties_stats'])

interface ToolOutcome { text: string; isError: boolean; allowed: boolean; denialReason: string | null; countyNo: number | null; resultSummary: string; rows: number | null; dbMs: number | null; parcelId: string | null }

// ── Tool execution with tier + county enforcement ─────────────────────────────
async function runTool(
  name: string,
  input: Record<string, any>,
  account: B2BAccount,
  allowedCountyName: string,
): Promise<ToolOutcome> {
  // Tier gate: cross-property is Pro-only (defense in depth — Basic isn't even offered these tools).
  if (CROSS_PROPERTY.has(name) && account.tier !== 'pro') {
    const reason = 'Cross-property search requires the Pro plan.'
    return { text: reason + ' This account is on Basic (single-property lookups only). Suggest upgrading to Pro.', isError: true, allowed: false, denialReason: reason, countyNo: null, resultSummary: 'denied: tier', rows: null, dbMs: null, parcelId: null }
  }

  // Resolve the target county (name → co_no), else default to the account's county.
  let coNo: number
  let countyName: string
  if (input.county) {
    const resolved = await b2bSocket.resolveCountyNo(String(input.county))
    if (!resolved) {
      return { text: `Unknown county "${input.county}".`, isError: true, allowed: false, denialReason: 'unknown county', countyNo: null, resultSummary: 'denied: unknown county', rows: null, dbMs: null, parcelId: null }
    }
    coNo = resolved.coNo
    countyName = resolved.countyName
  } else {
    coNo = account.allowedCoNo ?? 74
    countyName = allowedCountyName
  }

  // County lock: Basic accounts may only touch their assigned county.
  //
  // RULING 197: ROUTE ON COVERAGE FIRST, ENTITLEMENT SECOND. Saying "upgrade to Pro
  // to unlock X County" implies the data exists behind a paywall. If we hold no
  // records for that county, Pro would not unlock it either, and the upgrade prompt
  // is a small dishonesty of exactly the class this codebase exists to eliminate.
  // Coverage is MEASURED here, never asserted from a hardcoded county list.
  if (account.tier === 'basic' && account.allowedCoNo != null && coNo !== account.allowedCoNo) {
    // null = the probe itself failed; do NOT claim either coverage or a gap from it.
    let held: boolean | null = null
    try { held = await b2bSocket.hasParcelCoverage(coNo) } catch { held = null }

    if (held === false) {
      const reason = `No parcel records held for ${countyName} County.`
      return { text: `${reason} This is a COVERAGE gap, not a plan limit — we do not hold ${countyName} County parcel records on any tier, so upgrading would not unlock it. Do not suggest an upgrade for this county.`, isError: true, allowed: false, denialReason: reason, countyNo: coNo, resultSummary: 'denied: no coverage', rows: 0, dbMs: null, parcelId: null }
    }
    const reason = `Basic plan is limited to ${allowedCountyName} County.`
    const heldNote = held === true
      ? ` We do hold parcel records for ${countyName} County, so Pro would cover it.`
      : ` Coverage for ${countyName} County could not be checked, so do not promise that an upgrade would unlock it.`
    return { text: `${reason} This account cannot access ${countyName} County.${heldNote} Cross-county access requires the Pro plan.`, isError: true, allowed: false, denialReason: reason, countyNo: coNo, resultSummary: 'denied: county lock', rows: null, dbMs: null, parcelId: null }
  }

  // ── Execute ── (measure DB time + row count for telemetry)
  const parcelIdIn = input.parcel_id != null ? String(input.parcel_id) : null
  const t0 = Date.now()
  try {
    if (name === 'find_parcel') {
      const rows = await b2bSocket.findParcels(coNo, String(input.address ?? ''))
      const dbMs = Date.now() - t0
      if (!rows.length) return ok(`No parcels found matching "${input.address}" in ${countyName} County.`, coNo, '0 matches', 0, dbMs, null)
      const list = rows.map(r => `- ${r.situsAddress}, ${r.city} — parcel_id ${r.parcelId}, just value ${usd(r.justValue)}, land use ${landUseLabel(r.dorUc)}`).join('\n')
      return ok(`${rows.length} candidate parcel(s) in ${countyName}:\n${list}`, coNo, `${rows.length} matches`, rows.length, dbMs, null)
    }

    if (name === 'get_property_report') {
      // RULING 197: ONE SOURCE OF TRUTH. This used to call get_site_intelligence and
      // assemble its own ~10-field payload, so the twelve concepts wired into
      // get_pir_report never reached the assistant. It now reads the same document
      // the PIR renders, summarised by lib/pir-summary (which walks every block
      // generically, so a new concept needs no change here).
      // SCRUBBED variant: the assistant is a render surface, so ruling 169 applies.
      // The raw report still carries deed party names; this one has them removed
      // server-side with the manifest at meta.scrubManifest.
      const report = await pirSocket.forParcelScrubbed(coNo, String(input.parcel_id ?? ''))
      const dbMs = Date.now() - t0
      if (!report) return ok(`No parcel ${input.parcel_id} found in ${countyName} County.`, coNo, 'not found', 0, dbMs, parcelIdIn)
      const text = summarisePirReport(report, countyName)
      return ok(text, coNo, `report ok (${pirConceptCount(report)} concepts)`, 1, dbMs, parcelIdIn)
    }

    if (name === 'get_nearby_amenities') {
      const a = await amenitySocket.forParcel(coNo, String(input.parcel_id ?? ''))
      const dbMs = Date.now() - t0
      if (!a.length) return ok(`No amenity data available for parcel ${input.parcel_id} in ${countyName} County.`, coNo, '0 amenities', 0, dbMs, parcelIdIn)
      const list = a.map(x => {
        const ft = x.distanceM * M_TO_FT
        const dist = ft < 1000 ? `${Math.round(ft / 10) * 10} ft` : `${(x.distanceM / 1609.344).toFixed(1)} mi`
        return `- ${x.displayName}: ${dist} at ${Math.round(x.bearingDegrees)}° (compass)`
      }).join('\n')
      return ok(`Nearby amenities for parcel ${input.parcel_id} (${countyName}):\n${list}`, coNo, `${a.length} amenities`, a.length, dbMs, parcelIdIn)
    }

    if (name === 'search_properties') {
      const dorUc = resolveDorCode(input.land_use)
      const rows = await b2bSocket.searchProperties({
        coNo, minValue: numOrNull(input.min_value), maxValue: numOrNull(input.max_value), dorUc, city: input.city ? String(input.city) : null, limit: numOrNull(input.limit) ?? 25,
      })
      const dbMs = Date.now() - t0
      if (!rows.length) return ok(`No properties matched those filters in ${countyName} County.`, coNo, '0 results', 0, dbMs, null)
      const list = rows.slice(0, 25).map(r => `- ${r.situsAddress}, ${r.city} — ${usd(r.justValue)}, ${landUseLabel(r.dorUc)} (parcel ${r.parcelId})`).join('\n')
      return ok(`${rows.length} matching properties in ${countyName} (showing up to 25), highest value first:\n${list}`, coNo, `${rows.length} results`, rows.length, dbMs, null)
    }

    if (name === 'search_properties_stats') {
      const dorUc = resolveDorCode(input.land_use)
      const st = await b2bSocket.searchPropertiesStats({
        coNo, minValue: numOrNull(input.min_value), maxValue: numOrNull(input.max_value), dorUc, city: input.city ? String(input.city) : null,
      })
      const dbMs = Date.now() - t0
      const text = `Statistics for ${countyName} County matching those filters:\n- Count: ${st.matchCount.toLocaleString()}\n- Average just value: ${st.avgValue != null ? usd(st.avgValue) : 'n/a'}\n- Range: ${st.minValue != null ? usd(st.minValue) : 'n/a'} to ${st.maxValue != null ? usd(st.maxValue) : 'n/a'}`
      return ok(text, coNo, `${st.matchCount} matched`, st.matchCount, dbMs, null)
    }

    return { text: `Unknown tool ${name}.`, isError: true, allowed: false, denialReason: 'unknown tool', countyNo: coNo, resultSummary: 'unknown tool', rows: null, dbMs: null, parcelId: null }
  } catch (err) {
    console.error('[assistant runTool]', name, err)
    // RULING 197: an infrastructure failure must NEVER be narrated as a data answer.
    // The 3 August outage read as "Invalid or inactive account key" for twelve days
    // because a 42501 resolved to [] and looked like "no rows". Name the class.
    if (err instanceof PostgrestError && err.isPermissionDenied) {
      return { text: `Tool ${name} could not run: the backend was denied access to the data (${err.code ?? err.status}: ${err.message}). This is a SYSTEM FAULT, not an answer about the property — do not tell the user the data does not exist. Report that the lookup failed and needs an operator.`, isError: true, allowed: true, denialReason: null, countyNo: coNo, resultSummary: 'error: permission denied', rows: null, dbMs: Date.now() - t0, parcelId: parcelIdIn }
    }
    const detail = err instanceof PostgrestError ? ` (${err.status}${err.code ? ' ' + err.code : ''}: ${err.message})` : ''
    return { text: `Tool ${name} failed to run${detail}. This is a system fault, not a statement about the property.`, isError: true, allowed: true, denialReason: null, countyNo: coNo, resultSummary: 'error', rows: null, dbMs: Date.now() - t0, parcelId: parcelIdIn }
  }
}

function ok(text: string, coNo: number, summary: string, rows: number | null, dbMs: number | null, parcelId: string | null): ToolOutcome {
  return { text: `${text}\n\n${PROVENANCE} Retrieved ${new Date().toISOString().slice(0, 10)}.`, isError: false, allowed: true, denialReason: null, countyNo: coNo, resultSummary: summary, rows, dbMs, parcelId }
}
function numOrNull(v: any): number | null { const n = Number(v); return Number.isFinite(n) ? n : null }
function resolveDorCode(v: any): string | null {
  if (v == null) return null
  const s = String(v).trim()
  if (/^\d{1,3}$/.test(s)) return s.padStart(3, '0')
  return labelToDorCode(s)
}

function systemPrompt(account: B2BAccount, county: string): string {
  const scope = account.tier === 'pro'
    ? 'This account is on the PRO plan: statewide access and cross-property/statistical search are enabled.'
    : `This account is on the BASIC plan: it is limited to ${county} County and single-property lookups. Cross-property search and other counties are Pro-only — if the user asks for those, explain the limitation and suggest upgrading to Pro. Do not attempt to work around it.`
  return [
    'You are the Department of Property (DoP) B2B intelligence assistant, serving licensed Florida real-estate and analytics professionals.',
    scope,
    'Use the tools to answer — never invent parcel data. To answer about a single address, call find_parcel first to get the parcel_id, then get_property_report and/or get_nearby_amenities.',
    'Data provenance matters: when you state a fact, make its source clear, and always distinguish the assessor-recorded lot size from the GIS-calculated site size (they can differ; if the assessor value is missing, say so rather than reporting 0).',
    'Be direct and lead with the answer. For read-only lookups, do not ask the user for confirmation — just retrieve and report. Keep responses concise and cite the county and figures.',
  ].join('\n\n')
}

// ── Route ─────────────────────────────────────────────────────────────────────
function getIp(req: NextRequest): string {
  return req.headers.get('cf-connecting-ip') ?? req.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ?? 'unknown'
}
// inet column can't take 'unknown' or a malformed value — coerce to null so a bad
// header never fails the (best-effort) telemetry insert.
function ipOrNull(ip: string): string | null {
  return ip && ip !== 'unknown' && /^[0-9a-fA-F:.]+$/.test(ip) ? ip : null
}

export async function POST(req: NextRequest) {
  if (!process.env.ANTHROPIC_API_KEY) {
    return NextResponse.json(
      { error: 'Assistant not configured. Set ANTHROPIC_API_KEY in the environment to enable the assistant.' },
      { status: 503 }
    )
  }

  pruneRateLimitStore()
  const { allowed } = checkRateLimit(getIp(req))
  if (!allowed) return NextResponse.json({ error: 'Rate limit exceeded.' }, { status: 429 })

  const body = await req.json().catch(() => ({} as any))
  const apiKey = String(body.apiKey ?? req.headers.get('x-api-key') ?? '')
  const incoming: { role: string; content: string }[] = Array.isArray(body.messages) ? body.messages : []
  if (!apiKey) return NextResponse.json({ error: 'Missing account API key.' }, { status: 401 })
  if (!incoming.length) return NextResponse.json({ error: 'No messages provided.' }, { status: 400 })

  // Session context for observe-only anomaly detection (disclosed in privacy + fair use).
  const sessionIp = ipOrNull(getIp(req))
  const userAgent = req.headers.get('user-agent')
  const sessionId = typeof body.sessionId === 'string' && body.sessionId ? body.sessionId.slice(0, 200) : null

  const account = await b2bSocket.getAccountByKey(apiKey)
  if (!account) return NextResponse.json({ error: 'Invalid or inactive account key.' }, { status: 401 })

  const allowedCountyName = account.allowedCoNo != null ? await b2bSocket.countyName(account.allowedCoNo) : 'your assigned'
  const tools = account.tier === 'pro' ? [...SINGLE_PROPERTY_TOOLS, ...PRO_TOOLS] : SINGLE_PROPERTY_TOOLS
  const lastUserQuery = [...incoming].reverse().find(m => m.role === 'user')?.content ?? null

  // ── Guardrail: per-user monthly HARD cap, checked BEFORE spending any tokens ──
  // (Calendar month, UTC. Operational cap — not billing-exact; the report buckets
  //  by America/New_York, a deliberate small inconsistency.)
  const t0now = new Date()
  const monthStart = new Date(Date.UTC(t0now.getUTCFullYear(), t0now.getUTCMonth(), 1))
  const monthCostBefore = await b2bSocket.costSince(account.id, monthStart)
  if (monthCostBefore >= MONTHLY_HARD_CAP_USD) {
    await b2bSocket.logCostAlert({ accountId: account.id, kind: 'monthly_hard_cap', windowHours: null, costUsd: monthCostBefore, thresholdUsd: MONTHLY_HARD_CAP_USD })
    return NextResponse.json({
      error: 'Monthly usage cap reached',
      detail: `This account has reached its monthly assistant cost cap ($${MONTHLY_HARD_CAP_USD.toFixed(2)}). It resets at the start of next month.`,
    }, { status: 402 })
  }

  const anthropic = new Anthropic()
  const messages: Anthropic.MessageParam[] = incoming.map(m => ({
    role: m.role === 'assistant' ? 'assistant' : 'user',
    content: m.content,
  }))

  const trace: { tool: string; county: number | null; allowed: boolean; denialReason: string | null }[] = []
  let reply = ''

  // ── Telemetry accumulators — summed across EVERY model call in the loop ──
  const startedAt = Date.now()
  let inTok = 0, outTok = 0, cacheRead = 0, cacheCreate = 0, modelCalls = 0
  let rowsTotal = 0, dbMsTotal = 0, dbHit = false
  let usedCross = false, usedAnyTool = false
  let targetParcel: string | null = null
  let targetCountyNo: number | null = null
  let success = true
  let errorMsg: string | null = null

  // Compute cost from current rates and write one row per assistant call, then run
  // rolling-window guardrails. Called on BOTH the success and error paths — a failed
  // call still costs tokens, so it is never dropped from the log.
  async function persist() {
    const costUsd = Number((inTok * RATE_INPUT + outTok * RATE_OUTPUT + cacheRead * RATE_CACHE_READ + cacheCreate * RATE_CACHE_WRITE).toFixed(6))
    const county = targetCountyNo != null
      ? await b2bSocket.countyName(targetCountyNo)
      : (account.allowedCoNo != null ? allowedCountyName : null)
    await b2bSocket.logAssistantQuery({
      accountId: account.id,
      tier: account.tier,
      model: MODEL,
      inputTokens: inTok, outputTokens: outTok, cacheReadTokens: cacheRead, cacheCreationTokens: cacheCreate,
      modelCalls,
      costUsd,
      queryType: usedCross ? 'cross_property' : usedAnyTool ? 'structured' : 'natural_language',
      parcelId: targetParcel,
      county,
      latencyMs: Date.now() - startedAt,
      success,
      error: errorMsg,
      rowsReturned: dbHit ? rowsTotal : null,
      dbQueryMs: dbHit ? dbMsTotal : null,
      ipAddress: sessionIp,
      userAgent,
      sessionId,
    })
    // Rolling-window guardrails (dedup-aware; include the row just written).
    const nowEnd = new Date()
    const cost24 = await b2bSocket.costSince(account.id, new Date(nowEnd.getTime() - 24 * 3600 * 1000))
    if (cost24 >= ALERT_24H_USD) {
      await b2bSocket.logCostAlert({ accountId: account.id, kind: '24h_threshold', windowHours: 24, costUsd: cost24, thresholdUsd: ALERT_24H_USD })
    }
    const monthCost = await b2bSocket.costSince(account.id, new Date(Date.UTC(nowEnd.getUTCFullYear(), nowEnd.getUTCMonth(), 1)))
    if (monthCost >= MONTHLY_SOFT_WARN_USD && monthCost < MONTHLY_HARD_CAP_USD) {
      await b2bSocket.logCostAlert({ accountId: account.id, kind: 'monthly_soft_warn', windowHours: null, costUsd: monthCost, thresholdUsd: MONTHLY_SOFT_WARN_USD })
    }
  }

  try {
    for (let guard = 0; guard < 8; guard++) {
      const resp = await anthropic.messages.create({
        model: MODEL,
        max_tokens: 8192,
        thinking: { type: 'adaptive' },
        system: systemPrompt(account, allowedCountyName),
        tools,
        messages,
      })

      modelCalls++
      const u = resp.usage
      inTok += u?.input_tokens ?? 0
      outTok += u?.output_tokens ?? 0
      cacheRead += u?.cache_read_input_tokens ?? 0
      cacheCreate += u?.cache_creation_input_tokens ?? 0

      if (resp.stop_reason === 'refusal') {
        reply = 'I can’t help with that request.'
        break
      }

      messages.push({ role: 'assistant', content: resp.content })
      const toolUses = resp.content.filter((b): b is Anthropic.ToolUseBlock => b.type === 'tool_use')

      if (resp.stop_reason === 'end_turn' || toolUses.length === 0) {
        reply = resp.content.filter((b): b is Anthropic.TextBlock => b.type === 'text').map(b => b.text).join('\n').trim()
        break
      }

      // ── Guardrail: per-query token cap. Each model call is already capped at
      //    max_tokens=8192; this stops a runaway multi-iteration agentic loop.
      if (inTok + outTok + cacheRead + cacheCreate >= PER_QUERY_TOKEN_CAP) {
        reply = reply || 'This request hit its processing limit. Please narrow it and try again.'
        success = false
        errorMsg = 'per_query_token_cap'
        break
      }

      const results: Anthropic.ToolResultBlockParam[] = []
      for (const tu of toolUses) {
        const input = (tu.input ?? {}) as Record<string, any>
        const outcome = await runTool(tu.name, input, account, allowedCountyName)
        // Telemetry: query-type + demand signal + DB metrics.
        usedAnyTool = true
        if (CROSS_PROPERTY.has(tu.name)) usedCross = true
        if (outcome.parcelId) targetParcel = outcome.parcelId
        if (outcome.countyNo != null) targetCountyNo = outcome.countyNo
        if (outcome.dbMs != null) { dbHit = true; dbMsTotal += outcome.dbMs; rowsTotal += outcome.rows ?? 0 }
        trace.push({ tool: tu.name, county: outcome.countyNo, allowed: outcome.allowed, denialReason: outcome.denialReason })
        results.push({ type: 'tool_result', tool_use_id: tu.id, content: outcome.text, is_error: outcome.isError })
        await b2bSocket.logQuery({
          accountId: account.id,
          userQuery: lastUserQuery,
          toolName: tu.name,
          toolArgs: input,
          countyNo: outcome.countyNo,
          allowed: outcome.allowed,
          denialReason: outcome.denialReason,
          resultSummary: outcome.resultSummary,
        })
      }
      messages.push({ role: 'user', content: results })
    }
  } catch (err) {
    const detail = err instanceof Error ? err.message : String(err)
    console.error('[/api/assistant]', detail)
    success = false
    errorMsg = detail.slice(0, 500)
    await persist() // a failed call still cost tokens — log it
    return NextResponse.json({ error: 'Assistant error', detail }, { status: 500 })
  }

  await persist()
  return NextResponse.json({ reply: reply || '(no response)', tier: account.tier, trace })
}
