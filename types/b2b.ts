export {}

// B2B assistant account. `tier` is set manually in Supabase (stands in for the
// Stripe webhook); enforcement reads it the same way once payments are wired.
export interface B2BAccount {
  id: string
  name: string
  tier: 'basic' | 'pro'
  allowedCoNo: number | null // county a Basic account is locked to; ignored for Pro
  apiKey: string
  active: boolean
}

// One row written per tool the assistant runs (or denies) — the intelligence-layer
// event log, from day one.
export interface QueryLogEntry {
  accountId: string
  userQuery: string | null
  toolName: string
  toolArgs: Record<string, unknown>
  countyNo: number | null
  allowed: boolean
  denialReason: string | null
  resultSummary: string | null
}

// One row per ASSISTANT CALL (not per tool) — cost/usage telemetry. Logged for
// every call including failures and retries; never sampled. parcel_id/county
// double as the B2B lead-product demand signal. cost_usd is computed at insert
// from current rates and stored as a literal (never recomputed historically).
export interface AssistantQueryLogEntry {
  accountId: string
  tier: string
  model: string
  inputTokens: number
  outputTokens: number
  cacheReadTokens: number
  cacheCreationTokens: number
  modelCalls: number
  costUsd: number
  queryType: 'natural_language' | 'structured' | 'cross_property'
  parcelId: string | null
  county: string | null
  latencyMs: number
  success: boolean
  error: string | null
  rowsReturned: number | null
  dbQueryMs: number | null
  // Session context — for observe-only anomaly detection (concurrent sessions,
  // impossible travel, device/IP spread). Populated on every call, both paths.
  ipAddress: string | null
  userAgent: string | null
  sessionId: string | null
  // THE AUDIT TRAIL. Without these four the log is a COUNTER, not a record: it
  // says an exchange happened and nothing about what was asked, what was said,
  // which configuration said it, or what data it was looking at. Both defects
  // found on 15 August (flood reported not_available where data exists; DOR 092
  // glossed as "utility/land classification") were UNRECONSTRUCTABLE from the
  // rows they produced. /api/roz has written these since July via roz_log_query;
  // /api/assistant never did, so the columns sat null on every row it wrote.
  userQuery: string | null
  responseText: string | null
  rozVersion: string | null
  // sha256 of the tool output the model actually saw — the record behind the
  // answer, so a later dispute can be settled against the payload rather than
  // re-running a query whose data may have changed underneath it.
  payloadHash: string | null
}

// A cross-property / stats search result row (from search_properties).
export interface PropertySearchRow {
  parcelId: string
  coNo: number
  situsAddress: string
  city: string
  justValue: number
  dorUc: string
}
