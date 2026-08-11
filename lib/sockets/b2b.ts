import type { B2BAccount, QueryLogEntry, AssistantQueryLogEntry, PropertySearchRow } from '@/types/b2b'

// Raw https → Supabase PostgREST, same pattern as the other sockets.
const SB_HOST = 'eaifqorwmgayiqmbtzcg.supabase.co'
const SB_KEY = process.env.SUPABASE_SECRET_KEY!
const SB_HEADERS = { 'apikey': SB_KEY, 'Authorization': 'Bearer ' + SB_KEY }

function httpGet(path: string): Promise<any[]> {
  return new Promise(function(resolve, reject) {
    const https = require('https')
    https.get({ hostname: SB_HOST, path, headers: SB_HEADERS }, function(res: any) {
      let d = ''
      res.on('data', (c: any) => { d += c })
      res.on('end', () => { try { resolve(JSON.parse(d)) } catch { resolve([]) } })
    }).on('error', reject)
  })
}

function httpPost(path: string, body: unknown, prefer?: string): Promise<any> {
  return new Promise(function(resolve, reject) {
    const https = require('https')
    const payload = JSON.stringify(body)
    const headers: Record<string, string> = Object.assign({}, SB_HEADERS, {
      'Content-Type': 'application/json',
      'Content-Length': String(Buffer.byteLength(payload)),
    })
    if (prefer) headers['Prefer'] = prefer
    const req = https.request({ hostname: SB_HOST, path, method: 'POST', headers }, function(res: any) {
      let d = ''
      res.on('data', (c: any) => { d += c })
      res.on('end', () => { try { resolve(d ? JSON.parse(d) : null) } catch { resolve(null) } })
    })
    req.on('error', reject)
    req.write(payload)
    req.end()
  })
}

export const b2bSocket = {
  // Resolve an account from its API key. Null if missing or inactive.
  getAccountByKey: async function(apiKey: string): Promise<B2BAccount | null> {
    const rows = await httpGet(
      '/rest/v1/b2b_accounts?select=id,name,tier,allowed_co_no,api_key,active' +
      '&api_key=eq.' + encodeURIComponent(apiKey) + '&active=eq.true&limit=1'
    )
    const r = rows?.[0]
    if (!r) return null
    return {
      id: r.id,
      name: r.name,
      tier: r.tier,
      allowedCoNo: r.allowed_co_no != null ? Number(r.allowed_co_no) : null,
      apiKey: r.api_key,
      active: r.active,
    }
  },

  // Map a county NAME → DOR county number (for tools that take a county by name).
  resolveCountyNo: async function(name: string): Promise<{ coNo: number; countyName: string } | null> {
    const rows = await httpGet(
      '/rest/v1/county_registry?select=dor_county_no,county_name&county_name=ilike.' +
      encodeURIComponent(name.trim()) + '&limit=1'
    )
    const r = rows?.[0]
    if (!r || r.dor_county_no == null) return null
    return { coNo: Number(r.dor_county_no), countyName: r.county_name }
  },

  countyName: async function(coNo: number): Promise<string> {
    const rows = await httpGet(
      '/rest/v1/county_registry?select=county_name&dor_county_no=eq.' + coNo + '&limit=1'
    )
    return rows?.[0]?.county_name ?? `County ${coNo}`
  },

  // Write one event-log row. Best-effort — never throw into the request path.
  logQuery: async function(e: QueryLogEntry): Promise<void> {
    try {
      await httpPost('/rest/v1/b2b_query_log', {
        account_id: e.accountId,
        user_query: e.userQuery,
        tool_name: e.toolName,
        tool_args: e.toolArgs,
        county_no: e.countyNo,
        allowed: e.allowed,
        denial_reason: e.denialReason,
        result_summary: e.resultSummary,
      }, 'return=minimal')
    } catch (err) {
      console.error('[b2b.logQuery]', err)
    }
  },

  // Write one per-ASSISTANT-CALL telemetry row (cost/tokens/latency + demand signal).
  // Best-effort — never throw into the request path. Logs failures and retries too.
  logAssistantQuery: async function(e: AssistantQueryLogEntry): Promise<void> {
    try {
      await httpPost('/rest/v1/assistant_query_log', {
        account_id: e.accountId,
        tier: e.tier,
        model: e.model,
        input_tokens: e.inputTokens,
        output_tokens: e.outputTokens,
        cache_read_tokens: e.cacheReadTokens,
        cache_creation_tokens: e.cacheCreationTokens,
        model_calls: e.modelCalls,
        cost_usd: e.costUsd,
        query_type: e.queryType,
        parcel_id: e.parcelId,
        county: e.county,
        latency_ms: e.latencyMs,
        success: e.success,
        error: e.error,
        rows_returned: e.rowsReturned,
        db_query_ms: e.dbQueryMs,
        ip_address: e.ipAddress,
        user_agent: e.userAgent,
        session_id: e.sessionId,
      }, 'return=minimal')
    } catch (err) {
      console.error('[b2b.logAssistantQuery]', err)
    }
  },

  // Total assistant cost_usd for one account since a timestamp (guardrail windows).
  // Returns 0 on any error so a telemetry outage never hard-blocks the assistant.
  costSince: async function(accountId: string, since: Date): Promise<number> {
    try {
      const res = await httpPost('/rest/v1/rpc/assistant_cost_since', {
        p_account_id: accountId,
        p_since: since.toISOString(),
      })
      const n = Number(Array.isArray(res) ? res[0] : res)
      return Number.isFinite(n) ? n : 0
    } catch (err) {
      console.error('[b2b.costSince]', err)
      return 0
    }
  },

  // Record a guardrail breach (24h threshold / monthly soft-warn / hard-cap),
  // deduped per account+kind within dedupeHours so it isn't written every request.
  logCostAlert: async function(a: {
    accountId: string; kind: string; windowHours: number | null; costUsd: number; thresholdUsd: number; dedupeHours?: number
  }): Promise<void> {
    try {
      await httpPost('/rest/v1/rpc/assistant_maybe_alert', {
        p_account_id: a.accountId, p_kind: a.kind, p_window_hours: a.windowHours,
        p_cost_usd: a.costUsd, p_threshold: a.thresholdUsd, p_dedupe_hours: a.dedupeHours ?? 6,
      })
    } catch (err) {
      console.error('[b2b.logCostAlert]', err)
    }
  },

  // Address → candidate parcels within a county (find_parcels RPC).
  findParcels: async function(coNo: number, query: string, limit = 8): Promise<PropertySearchRow[]> {
    const res = await httpPost('/rest/v1/rpc/find_parcels', { p_co_no: coNo, p_query: query, p_limit: limit })
    return mapRows(res)
  },

  // Pro cross-property search (search_properties RPC).
  searchProperties: async function(f: {
    coNo?: number | null; minValue?: number | null; maxValue?: number | null; dorUc?: string | null; city?: string | null; limit?: number
  }): Promise<PropertySearchRow[]> {
    const res = await httpPost('/rest/v1/rpc/search_properties', {
      p_co_no: f.coNo ?? null, p_min_value: f.minValue ?? null, p_max_value: f.maxValue ?? null,
      p_dor_uc: f.dorUc ?? null, p_city: f.city ?? null, p_limit: f.limit ?? 25,
    })
    return mapRows(res)
  },

  // Pro aggregate stats (search_properties_stats RPC).
  searchPropertiesStats: async function(f: {
    coNo?: number | null; minValue?: number | null; maxValue?: number | null; dorUc?: string | null; city?: string | null
  }): Promise<{ matchCount: number; avgValue: number | null; minValue: number | null; maxValue: number | null }> {
    const res = await httpPost('/rest/v1/rpc/search_properties_stats', {
      p_co_no: f.coNo ?? null, p_min_value: f.minValue ?? null, p_max_value: f.maxValue ?? null,
      p_dor_uc: f.dorUc ?? null, p_city: f.city ?? null,
    })
    const r = Array.isArray(res) ? res[0] : res
    return {
      matchCount: Number(r?.match_count ?? 0),
      avgValue: r?.avg_value != null ? Number(r.avg_value) : null,
      minValue: r?.min_value != null ? Number(r.min_value) : null,
      maxValue: r?.max_value != null ? Number(r.max_value) : null,
    }
  },
}

function mapRows(res: any): PropertySearchRow[] {
  const rows = Array.isArray(res) ? res : []
  return rows.map((r: any): PropertySearchRow => ({
    parcelId: String(r.parcel_id),
    coNo: Number(r.co_no),
    situsAddress: r.phy_addr1 ?? '',
    city: r.phy_city ?? '',
    justValue: Number(r.just_value ?? 0),
    dorUc: String(r.dor_uc ?? ''),
  }))
}
