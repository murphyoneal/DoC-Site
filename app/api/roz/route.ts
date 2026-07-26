import { NextRequest, NextResponse } from 'next/server'
import Anthropic from '@anthropic-ai/sdk'
import { createHash } from 'crypto'
import { getSupabaseAdmin } from '@/lib/supabase/server'
import { getSessionUser } from '@/lib/supabase/ssr-server'

const MODEL = 'claude-sonnet-5'
const ROZ_VERSION = '0.1.0-alpha' // roz_version_register current; stamped per exchange

// Sonnet 5 rates (USD/token) — cost computed at request time, stored as a literal.
// This task reads a precomputed payload and reports it; Opus reasoning isn't needed.
// Prompt caching bills cache WRITES at 1.25x input and cache READS at 0.1x.
const RATE_IN = 3.0 / 1e6, RATE_OUT = 15.0 / 1e6
const CACHE_WRITE_MULT = 1.25, CACHE_READ_MULT = 0.1

// DOR county code map. Reads of county_registry are denied to the app role, so the
// name→co_no crosswalk is static (DOR is stable). Roz defaults to Volusia.
const DOR: Record<string, number> = {
  alachua: 11, baker: 12, bay: 13, bradford: 14, brevard: 15, broward: 16, calhoun: 17, charlotte: 18,
  citrus: 19, clay: 20, collier: 21, columbia: 22, 'miami-dade': 23, miamidade: 23, dade: 23, desoto: 24,
  dixie: 25, duval: 26, escambia: 27, flagler: 28, franklin: 29, gadsden: 30, gilchrist: 31, glades: 32,
  gulf: 33, hamilton: 34, hardee: 35, hendry: 36, hernando: 37, highlands: 38, hillsborough: 39, holmes: 40,
  'indian river': 41, indianriver: 41, jackson: 42, jefferson: 43, lafayette: 44, lake: 45, lee: 46, leon: 47,
  levy: 48, liberty: 49, madison: 50, manatee: 51, marion: 52, martin: 53, monroe: 54, nassau: 55, okaloosa: 56,
  okeechobee: 57, orange: 58, osceola: 59, 'palm beach': 60, palmbeach: 61, pasco: 61, pinellas: 62, polk: 63,
  putnam: 64, 'st. johns': 65, 'st johns': 65, stjohns: 65, 'st. lucie': 66, 'st lucie': 66, stlucie: 66,
  'santa rosa': 67, santarosa: 67, sarasota: 68, seminole: 69, sumter: 70, suwannee: 71, taylor: 72, union: 73,
  volusia: 74, wakulla: 75, walton: 76, washington: 77,
}
function coNo(name?: string): number {
  if (!name) return 74
  return DOR[name.trim().toLowerCase().replace(/ county$/i, '')] ?? 74
}
const VOLUSIA_CITIES = new Set(['port orange', 'daytona beach', 'daytona', 'deland', 'de land', 'deltona', 'new smyrna beach',
  'new smyrna', 'ormond beach', 'ormond', 'edgewater', 'debary', 'de bary', 'orange city', 'lake helen', 'pierson',
  'oak hill', 'ponce inlet', 'holly hill', 'south daytona', 'osteen', 'seville', 'glenwood', 'cassadaga', 'samsula'])

// Address → progressively shorter query forms. Strip city/state/ZIP and commas; a single failed
// exact match must fall back before reporting "not found" (a false negative dressed as honesty).
function addressForms(raw: string): { forms: string[]; number: string | null; city: string | null } {
  const parts = raw.split(',').map(s => s.trim()).filter(Boolean)
  const city = parts.length >= 3 ? parts[1] : (parts.length === 2 && !/^(fl|florida)\b/i.test(parts[1]) ? parts[1] : null)
  let street = parts.length > 1 ? parts[0] : raw.replace(/\s+(FL|FLORIDA)\b.*$/i, '').replace(/\s+\d{5}(-\d{4})?\s*$/, '')
  street = street.replace(/,/g, ' ').replace(/\s+/g, ' ').trim()
  const num = (street.match(/^\d+/) || [null])[0]
  const nameOnly = num ? street.replace(/^\d+\s*/, '').trim() : street
  const forms = [street, num && nameOnly ? `${num} ${nameOnly.split(' ')[0]}` : null, nameOnly || null]
    .filter((v, i, a): v is string => !!v && a.indexOf(v) === i)
  return { forms, number: num, city }
}

const TOOLS: Anthropic.Tool[] = [
  { name: 'find_parcel', description: 'Look up a property by street address to get its parcel_id and county. Call FIRST for any address.',
    input_schema: { type: 'object', properties: { address: { type: 'string' }, county: { type: 'string', description: "County name; defaults to Volusia" } }, required: ['address'] } },
  { name: 'get_property_record', description: 'The full precomputed record for ONE parcel: property, values, tax, permits, transactions, environmental findings, and planned_works (development / environmental / stormwater government projects, each with relation — contains/intersects means the project footprint is ON the parcel, adjacent/within_distance is area context). Every field carries field_status / as_of / source / resolution_level / relation. Needs parcel_id.',
    input_schema: { type: 'object', properties: { parcel_id: { type: 'string' }, county: { type: 'string' } }, required: ['parcel_id'] } },
  { name: 'get_nearby_amenities', description: 'Nearest civic/safety amenities (hospital, fire, school, police) with distance and bearing for a parcel.',
    input_schema: { type: 'object', properties: { parcel_id: { type: 'string' }, county: { type: 'string' } }, required: ['parcel_id'] } },
  { name: 'search_properties', description: 'Cross-parcel search by fixed filters (value range, land use, city) in any county. For portfolio/cohort questions.',
    input_schema: { type: 'object', properties: { county: { type: 'string' }, min_value: { type: 'number' }, max_value: { type: 'number' }, land_use: { type: 'string' }, city: { type: 'string' }, limit: { type: 'number' } }, required: [] } },
  { name: 'search_properties_stats', description: 'Aggregate stats (count, avg, min, max value) across properties matching filters in a county.',
    input_schema: { type: 'object', properties: { county: { type: 'string' }, min_value: { type: 'number' }, max_value: { type: 'number' }, land_use: { type: 'string' }, city: { type: 'string' } }, required: [] } },
  { name: 'search_encumbered_parcels', description: 'Distressed-property search (Volusia): parcels with a corroborated recorded lis pendens or lien — matched by owner name AND legal description. doc_class: "lis_pendens" | "lien" | omit for both. NOT a title search (covers ~9% of filings); every result is "recorded against a party matching this owner", satisfaction not shown.',
    input_schema: { type: 'object', properties: { doc_class: { type: 'string' }, limit: { type: 'number' } }, required: [] } },
  { name: 'find_contractors', description: 'Find licensed Florida contractors by trade and county (Volusia default). trade e.g. "electrical", "plumbing", "roofing". Returns DBPR licence status/expiry, complaint_count, bond/insurance. City is a soft preference only — the DBPR city is the business address, not service area, so search by county.',
    input_schema: { type: 'object', properties: { trade: { type: 'string' }, city: { type: 'string' }, county: { type: 'string' } }, required: [] },
    // Cache breakpoint on the last tool → the whole (system + tools) prefix is cached and reused every call.
    cache_control: { type: 'ephemeral' } },
]

const SYSTEM = [
  'You are Roz (Rosalind O\'Neal), a Florida property intelligence assistant for a licensed real-estate professional.',
  'You know buildings and you know people. Absorb the complexity of the record and present clarity — do not narrate your own difficulty or hand over a pile of caveats. Tell the user what they need to hear, including when it is unwelcome, and including "I don\'t know, and here is who does."',
  'SCOPE (alpha): full function. All 67 counties, every layer, cross-parcel and cohort queries allowed. No caps.',
  'You answer ONLY from the record returned by the tools. Never invent parcel data; if the record does not contain something, say so and point to who would.',
  'ADDRESS LOOKUP: find_parcel already normalises the address and falls back to shorter forms. If it returns a match_note (the match was loosened, or the county was defaulted), tell the user plainly. If it returns NO results even after fallback, say the address was not found in that county\'s records and offer to try another county or spelling — NEVER "this property may not exist". A single failed exact match is a lookup miss, not evidence the property is not real; that false negative is as wrong as a fabricated clear.',
  'COVERAGE: this alpha\'s parcel records are VOLUSIA COUNTY (co_no 74) ONLY. If an address resolves to another county (e.g. Sanford is in Seminole), say explicitly that that county is not yet loaded and you cannot speak to it — do not return an empty answer as if the property had no data. Absence of loaded data for a county is a coverage statement, and you must make it out loud.',
  'GWCA / groundwater restriction: the Ch. 62-524 restriction applies to NEW potable wells, so a property on municipal/public water is unaffected in practice — always carry that caveat with the finding; a bare "this parcel is in a contamination area" overstates it. But if the parcel relies on a private well, the contamination is material.',
  'HONESTY CONTRACT — every field in the record carries field_status, as_of, source, resolution_level, and (for spatial layers) relation:',
  '- field_status: "present" → state the value WITH its as_of date. "not_computed" / "null_at_source" / "layer_not_loaded" / "county_not_covered" → WITHHELD. Never render an absence as a clear, a "none", a green checkmark, or false. A checked negative and an uncomputed field are different facts.',
  '- field_status: "assumed" → the value came from a rule with NO cited authority (distinct from a measured or computed value). State it EXPLICITLY as an assumption, naming that it has no documented basis — or omit it. Never present it as a flat fact. (e.g. a flight-path flag with no FAA Part 77 surface computed is an assumption, not a measurement.)',
  '- resolution_level: a county or tract statistic is NOT a fact about this house — present it as area context. A zone polygon that contains the parcel IS a fact about the parcel (statutory force).',
  'CODES CARRY THEIR CONSEQUENCE. Never leave a code, zone, or designation bare — state what it MEANS for the buyer, from the glossary. Flood Zone A/AE/VE (an SFHA) means flood insurance is required with a federally-backed mortgage; Zone X means it is not. Homestead brings the Save Our Homes assessment cap. "Zone X" alone is not an answer; "Zone X — outside the special flood hazard area, so no federal flood-insurance mandate" is.',
  'LIEN CLASSIFICATION: an encumbrance finding\'s lien_classification carries runs_with. Municipal, tax, and HOA liens, and PACE assessments, run WITH THE LAND — a buyer inherits them at closing. A medical lien runs with the PERSON (the debtor) and generally does not attach to a later owner. Say which, because it is the whole answer to "should I care about this." A PACE assessment transfers with the property AND can block some conforming (Fannie/Freddie) mortgages — flag it prominently.',
  '- relation: "contains" means it is on/over the parcel; "within_distance"/"adjacent" means nearby — always state the distance, never a bare radius count.',
  '- planned_works are proposed/active GOVERNMENT projects (a county project record IS a record). relation "contains"/"intersects" = the project footprint is ON this parcel (directly affects it — a taking; parcel-level); "adjacent"/"within_distance" = a nearby project (area context, NOT a fact about this parcel). These fill a real gap: works planned for the next two years are not on a property record until a recorded easement, and nobody — seller or agent — has assembled them. Surface a parcel-level project prominently; frame nearby ones as area context with the distance.',
  'COMPS: a transaction whose saleQualification is anything other than "Qualified" — unqualified, multi-parcel, non-arms-length / in-family, not exposed to the open market — is NOT a valid comparable; flag it and do not present its price as a market value. A "vacant" saleType is not a comp for an improved property. Prices that look wrong are usually unqualified sales — say why.',
  'ROOF LIFESPAN cites, it does not conclude: state the recorded roof material and permit date against the NAHB/NRCA standard ("roof cover recorded as concrete tile; NAHB estimates tile at 50+ years"), never "the roof is overdue". Where the roof material is unrecorded the field is not_evaluated — give the range (~20yr asphalt to 50+ tile/slate), never the shortest-lived default.',
  'GRAMMAR: every environmental or encumbrance statement takes an AGENCY as its subject, never the property. Say "FDEP\'s Institutional Controls Registry records a restriction against this parcel (retrieved [date])", not "this parcel is restricted". The first is a verifiable claim about a record; the second is an unsupportable claim about the world.',
  'Never assert past the record. Date every assertion. Where two sources disagree, name the conflict and both sources and do not pick a winner.',
  'NO OWN DETERMINATIONS ABOUT THIS PROPERTY. A CLAIM ABOUT THIS PARCEL must trace to a payload field. You may report that two records exist and note whether they are consistent or in tension — you may NOT draw your own conclusion from them. No "almost certainly", no "the practical exposure is real regardless", no inferring a property fact the record does not carry. If an assumed field (e.g. in_flight_path) is present, you may not reason past it to a determination in the same breath. When an obvious connection matters, name the two records and let the reader draw it; a conclusion you add has no field_status and is indistinguishable from invention.',
  'DEFINITIONS ARE DIFFERENT FROM CLAIMS. Explaining what a term, code, or agency MEANS is general knowledge and needs no field — use the glossary below, and prefer its wording. You may explain what something means, then state SEPARATELY what the record says about it: "A lis pendens is a recorded notice of pending litigation — not itself a foreclosure (definition). The record shows one recorded against this parcel on [date] (finding)." If a buyer asks why you said "not evaluated" or "assumed" or why a county figure is not a property fact, explain it plainly — being unable to explain your own honesty vocabulary reads as evasion, not rigor. The one line you never cross: a definition must not smuggle in a determination about THIS property that the record does not carry.',
  'A legally binding restriction (LA_Restriction) with no recorded source must be withheld — an unsourced restriction is an assertion, not a record.',
  'RECORDED ENCUMBRANCES (lis pendens, liens) are the highest-stakes findings and the easiest to overstate. A match is by owner-name + legal description, NOT a title search — coverage is ~6% of filings, so field_status "not_evaluated" means exactly that, never a clearance and never "no liens found". When one IS matched: NEVER say "there is a lien on this property." Say "a [lien / lis pendens] is recorded against a party matching this owner on [date], instrument [X]", and that the record does NOT show whether it has been satisfied (only 1.83% of liens carry a release, so satisfaction cannot be confirmed here). A lis pendens is pending litigation, not a foreclosure (see glossary). Follow each finding\'s reporting_rule verbatim; tell her to verify at the Clerk with the instrument number.',
  'LINKS & DOCUMENTS. Collect every external link into ONE "Sources & documents" section at the END of the answer — never scatter them inline; she reads first, then works the links. Label each with WHAT it is and WHO publishes it (a link with no attribution goes unclicked): recorded plat (Volusia Clerk), permit file (ConnectLive), county parcel viewer (Property Appraiser), FDEP layer, Clerk official records. A plat-scan link is a TIFF that downloads to an image viewer, not a web page — say so. Include the authoritative county parcel viewer on every property answer: Volusia County Property Appraiser (https://vcpa.vcgov.org/search/real-property) — tell her to search the AltKey, since a direct per-parcel deep-link is not yet confirmed. Do not surface a link you were not given in the record.',
].join('\n')

async function runTool(name: string, input: any, admin: ReturnType<typeof getSupabaseAdmin>) {
  const county = coNo(input.county)
  const pid = input.parcel_id != null ? String(input.parcel_id) : null
  if (name === 'find_parcel') {
    const raw = String(input.address ?? '')
    const { forms, number, city } = addressForms(raw)
    // county: explicit > inferred from a recognised Volusia city > default 74 (said out loud)
    let cnty = county, countyNote = ''
    if (!input.county) {
      if (city && VOLUSIA_CITIES.has(city.toLowerCase())) cnty = 74
      else { cnty = 74; countyNote = 'county not inferable from the address — defaulted to Volusia (74) for the alpha' }
    }
    let rows: any[] = [], usedForm = forms[0] ?? raw, loosened = false
    for (let i = 0; i < forms.length; i++) {
      const r = await admin.rpc('find_parcels', { p_co_no: cnty, p_query: forms[i], p_limit: 8 })
      let got = (r.data ?? []) as any[]
      if (i >= 2 && number) got = got.filter(x => JSON.stringify(x).includes(number)) // street-name-only: keep the right number
      if (got.length) { rows = got; usedForm = forms[i]; loosened = i > 0; break }
    }
    const coverageNote = (rows.length === 0 && cnty !== 74) ? `county ${cnty} is not loaded in this alpha (Volusia / co_no 74 only) — say so, do not imply the property has no data` : ''
    const note = [loosened ? `match loosened to "${usedForm}" (exact address not found)` : '', countyNote, coverageNote].filter(Boolean).join('; ')
    return { text: JSON.stringify({ results: rows, match_note: note || null }), county: cnty, pid: null }
  }
  if (name === 'get_property_record') {
    const [pir, env, pw] = await Promise.all([
      admin.rpc('get_pir_report', { p_co_no: county, p_parcel_id: pid }),
      admin.rpc('get_parcel_env_findings', { p_co_no: county, p_parcel_id: pid }),
      admin.rpc('get_parcel_planned_works', { p_co_no: county, p_parcel_id: pid }),
    ])
    return { text: JSON.stringify({ report: pir.data ?? pir.error?.message, environmental: env.data ?? env.error?.message, planned_works: pw.data ?? pw.error?.message }), county, pid }
  }
  if (name === 'get_nearby_amenities') {
    const { data, error } = await admin.rpc('get_nearby_amenities', { p_co_no: county, p_parcel_id: pid })
    return { text: error ? `amenities error: ${error.message}` : JSON.stringify(data ?? []), county, pid }
  }
  if (name === 'search_properties') {
    const { data, error } = await admin.rpc('search_properties', { p_co_no: county, p_min_value: input.min_value ?? null, p_max_value: input.max_value ?? null, p_dor_uc: input.land_use ?? null, p_city: input.city ?? null, p_limit: input.limit ?? 25 })
    return { text: error ? `search error: ${error.message}` : JSON.stringify(data ?? []), county, pid: null }
  }
  if (name === 'search_properties_stats') {
    const { data, error } = await admin.rpc('search_properties_stats', { p_co_no: county, p_min_value: input.min_value ?? null, p_max_value: input.max_value ?? null, p_dor_uc: input.land_use ?? null, p_city: input.city ?? null })
    return { text: error ? `stats error: ${error.message}` : JSON.stringify(data ?? {}), county, pid: null }
  }
  if (name === 'search_encumbered_parcels') {
    const { data, error } = await admin.rpc('get_encumbered_parcels', { p_co_no: county, p_doc_class: input.doc_class ?? null, p_limit: input.limit ?? 50 })
    return { text: error ? `encumbered search error: ${error.message}` : JSON.stringify(data ?? []), county, pid: null }
  }
  if (name === 'find_contractors') {
    const { data, error } = await admin.rpc('search_contractors', { p_trade: input.trade ?? null, p_city: input.city ?? null, p_county: county, p_active_only: true, p_limit: 20 })
    return { text: error ? `contractor search error: ${error.message}` : JSON.stringify(data ?? []), county, pid: null }
  }
  return { text: `Unknown tool ${name}.`, county, pid: null }
}

export async function POST(req: NextRequest) {
  if (!process.env.ANTHROPIC_API_KEY) return NextResponse.json({ error: 'Assistant not configured.' }, { status: 503 })
  const user = await getSessionUser()
  if (!user) return NextResponse.json({ error: 'Not authenticated.' }, { status: 401 })

  const body = await req.json().catch(() => ({} as any))
  const incoming: { role: string; content: string }[] = Array.isArray(body.messages) ? body.messages : []
  if (!incoming.length) return NextResponse.json({ error: 'No messages.' }, { status: 400 })
  const sessionId = typeof body.sessionId === 'string' ? body.sessionId.slice(0, 200) : null
  const ipHdr = req.headers.get('cf-connecting-ip') ?? req.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ?? ''
  const ip = /^[0-9a-fA-F:.]+$/.test(ipHdr) ? ipHdr : null
  const lastUserQuery = [...incoming].reverse().find(m => m.role === 'user')?.content ?? null

  const admin = getSupabaseAdmin()
  const anthropic = new Anthropic()

  // Grounded, correctable definitions in context (roz_glossary) — consistent, not recalled.
  let glossaryRows: { term: string; aliases: string[] | null; definition: string; florida_nuance: string | null; authority: string | null }[] = []
  // ORDER BY term so the injected glossary text is byte-stable across requests — otherwise the
  // cached system prefix changes every call and prompt caching never hits (item 12).
  try { const { data } = await admin.from('roz_glossary').select('term,aliases,definition,florida_nuance,authority').order('term'); glossaryRows = data ?? [] } catch { /* glossary is best-effort */ }
  const glossaryText = glossaryRows.length
    ? '\n\nGLOSSARY — general-knowledge definitions. State these WITHOUT a payload field (they are not property claims), then say separately what the record shows. Prefer this wording over recall:\n'
      + glossaryRows.map(g => `- ${g.term}: ${g.definition}${g.florida_nuance ? ' [FL: ' + g.florida_nuance + ']' : ''}${g.authority ? ' [' + g.authority + ']' : ''}`).join('\n')
    : ''
  const systemText = SYSTEM + glossaryText

  const messages: Anthropic.MessageParam[] = incoming.map(m => ({ role: m.role === 'assistant' ? 'assistant' : 'user', content: m.content }))
  const trace: { tool: string; county: number }[] = []
  const payloadParts: string[] = []
  let reply = '', inTok = 0, outTok = 0, cacheRead = 0, cacheCreate = 0, calls = 0, cacheMarks = 0
  let targetParcel: string | null = null, targetCounty = 74
  let success = true, errorMsg: string | null = null
  const t0 = Date.now()
  const encoder = new TextEncoder()

  // Friendly labels for the tool-progress line the client shows during the loop. The 36s average is
  // mostly the tool round-trips before the answer starts, so naming what Roz is doing is the real
  // perceived-quality win — the final answer then streams token-by-token (item 13).
  const TOOL_LABEL: Record<string, string> = {
    find_parcel: 'Looking up the parcel', get_property_record: 'Pulling the full property record',
    get_nearby_amenities: 'Finding nearby amenities', search_properties: 'Searching properties',
    search_properties_stats: 'Aggregating property stats', search_encumbered_parcels: 'Checking recorded encumbrances',
    find_contractors: 'Finding licensed contractors',
  }

  // NDJSON event stream: {type:'status',label} tool running · {type:'delta',text} answer token ·
  // {type:'reset'} discard partial (a tool turn emitted interstitial prose) · {type:'done',...} final.
  const stream = new ReadableStream<Uint8Array>({
    async start(controller) {
      const send = (o: unknown) => { try { controller.enqueue(encoder.encode(JSON.stringify(o) + '\n')) } catch { /* client disconnected */ } }
      try {
        for (let guard = 0; guard < 8; guard++) {
          let turnText = ''
          const s = anthropic.messages.stream({
            model: MODEL, max_tokens: 8192, thinking: { type: 'adaptive' }, tools: TOOLS, messages,
            // Cache breakpoint on the system prompt (stable honesty contract + glossary, re-read every call).
            system: [{ type: 'text', text: systemText, cache_control: { type: 'ephemeral' } }],
          })
          // Stream answer tokens live. If the turn turns out to call a tool, we send a reset so the
          // client drops the interstitial prose (rare — the prompt answers from tools).
          s.on('text', (delta: string) => { turnText += delta; send({ type: 'delta', text: delta }) })
          const resp = await s.finalMessage()
          calls++
          const u = resp.usage
          inTok += u?.input_tokens ?? 0; outTok += u?.output_tokens ?? 0
          cacheRead += u?.cache_read_input_tokens ?? 0; cacheCreate += u?.cache_creation_input_tokens ?? 0
          if (resp.stop_reason === 'refusal') { if (turnText) send({ type: 'reset' }); reply = 'I can’t help with that request.'; send({ type: 'delta', text: reply }); break }
          messages.push({ role: 'assistant', content: resp.content })
          const toolUses = resp.content.filter((b): b is Anthropic.ToolUseBlock => b.type === 'tool_use')
          if (resp.stop_reason === 'end_turn' || toolUses.length === 0) {
            reply = resp.content.filter((b): b is Anthropic.TextBlock => b.type === 'text').map(b => b.text).join('\n').trim()
            // Correct the client if the assembled text differs from what streamed (multi-block joins).
            if (turnText.trim() !== reply) { send({ type: 'reset' }); send({ type: 'delta', text: reply }) }
            break
          }
          // Tool turn: discard any interstitial prose we streamed, show a status line instead.
          if (turnText.trim()) send({ type: 'reset' })
          const results: Anthropic.ToolResultBlockParam[] = []
          for (const tu of toolUses) {
            send({ type: 'status', label: TOOL_LABEL[tu.name] ?? 'Working' })
            const outcome = await runTool(tu.name, (tu.input ?? {}) as any, admin)
            trace.push({ tool: tu.name, county: outcome.county })
            payloadParts.push(outcome.text)
            if (outcome.pid) targetParcel = outcome.pid
            targetCounty = outcome.county
            // Cache large payloads (the parcel findings block) so follow-up turns about the same
            // property re-read them from cache at 0.1x. Cap at 2 so total breakpoints (system+tools+2) ≤ 4.
            const cacheable = outcome.text.length > 2000 && cacheMarks < 2
            if (cacheable) cacheMarks++
            results.push({ type: 'tool_result', tool_use_id: tu.id,
              content: cacheable ? [{ type: 'text', text: outcome.text, cache_control: { type: 'ephemeral' } }] : outcome.text })
          }
          messages.push({ role: 'user', content: results })
        }
      } catch (err) {
        success = false; errorMsg = (err instanceof Error ? err.message : String(err)).slice(0, 500)
        if (!reply) { reply = 'Roz hit an error handling that. Please try again.'; send({ type: 'reset' }); send({ type: 'delta', text: reply }) }
      }

      // payload_hash = the record Roz actually saw (for later verifiability of an opinion)
      const payloadHash = createHash('sha256').update(payloadParts.join('\n')).digest('hex')
      // Cache-aware cost: uncached input at 1x, cache writes 1.25x, cache reads 0.1x, output 1x.
      const cost = Number((inTok * RATE_IN + cacheCreate * RATE_IN * CACHE_WRITE_MULT
        + cacheRead * RATE_IN * CACHE_READ_MULT + outTok * RATE_OUT).toFixed(6))
      const totalInput = inTok + cacheCreate + cacheRead // total input the model saw (for comparability)
      let queryLogId: string | null = null
      try {
        const { data } = await admin.rpc('roz_log_query', {
          p_account_id: user.id, p_user_query: lastUserQuery, p_response_text: reply, p_roz_version: ROZ_VERSION,
          p_payload_hash: payloadHash, p_model: MODEL, p_input_tokens: totalInput, p_output_tokens: outTok, p_cost: cost,
          p_query_type: trace.some(t => t.tool.startsWith('search')) ? 'cross_property' : trace.length ? 'structured' : 'natural_language',
          p_parcel_id: targetParcel, p_county: String(targetCounty), p_latency_ms: Date.now() - t0, p_success: success,
          p_error: errorMsg, p_ip: ip, p_user_agent: req.headers.get('user-agent'), p_session_id: sessionId, p_model_calls: calls,
          p_cache_read: cacheRead, p_cache_creation: cacheCreate, // item 12 — measure caching instead of logging 0
        })
        queryLogId = (data as string) ?? null
      } catch { /* logging is best-effort; never fail the response on it */ }

      // Which glossary terms did she ask about — free product research on which labels need plain language.
      if (queryLogId && lastUserQuery && glossaryRows.length) {
        const ql = lastUserQuery.toLowerCase()
        const hits = glossaryRows.filter(g => [g.term, ...(g.aliases ?? [])]
          .some(n => n && n.length > 2 && ql.includes(n.toLowerCase()))).map(g => g.term)
        if (hits.length) {
          try { await admin.from('roz_glossary_hit').insert(hits.map(term => ({ query_log_id: queryLogId, term }))) } catch { /* best-effort */ }
        }
      }

      send({ type: 'done', queryLogId, trace, parcelId: targetParcel, reply: reply || '(no response)' })
      controller.close()
    },
  })

  return new Response(stream, {
    headers: { 'Content-Type': 'application/x-ndjson; charset=utf-8', 'Cache-Control': 'no-cache, no-transform', 'X-Accel-Buffering': 'no' },
  })
}
