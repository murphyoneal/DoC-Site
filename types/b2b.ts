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
