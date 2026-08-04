import { getSupabaseAdmin } from '@/lib/supabase/server'

// Reads construction_defect_law — the primary-verified construction-defect
// statute-of-repose rows that back the /rights state landing pages. Only
// primary_verified rows are ever served: an unverified legal row is treated as
// absent, never guessed.

export type LegalStateRow = {
  state_code: string
  state_name: string
  slug: string
  repose_years: number | null
  repose_cite: string | null
  repose_note: string | null
  statute_quote: string | null
  limitations_note: string | null
  limitations_cite: string | null
  warranty_regime: string | null
  warranty_cite: string | null
  presuit_required: boolean | null
  presuit_days: number | null
  presuit_cite: string | null
  presuit_note: string | null
  fraud_exempts_repose: boolean | null
  fraud_exception_cite: string | null
  other_exceptions: string[] | null
  rights_you_have: string | null
  what_to_do_now: string | null
  homeowner_summary: string | null
  primary_source_url: string | null
  seo_keywords: string[] | null
}

export function stateSlug(stateName: string): string {
  return stateName.toLowerCase().trim().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '')
}

function withSlug(row: Record<string, unknown>): LegalStateRow {
  return { ...(row as object), slug: stateSlug(String(row.state_name)) } as LegalStateRow
}

export const legalSocket = {
  // All primary-verified states, for the /rights hub and generateStaticParams.
  // Served via the get_verified_construction_law SECURITY DEFINER RPC — the same
  // pattern as get_pir_report — because the table is not granted to the REST role
  // (only verified rows are ever exposed, and no table is opened up wholesale).
  async listVerifiedStates(): Promise<LegalStateRow[]> {
    const sb = getSupabaseAdmin()
    const { data, error } = await sb.rpc('get_verified_construction_law')
    if (error || !Array.isArray(data)) {
      // Never fail silently: an empty legal hub should be a logged fault, not a blank page.
      console.error('[legalSocket] get_verified_construction_law failed:', error?.message ?? `unexpected data (${typeof data})`)
      return []
    }
    return (data as Record<string, unknown>[]).map(withSlug)
  },

  // One verified state by URL slug (derived from state_name). Null if not verified.
  async stateBySlug(slug: string): Promise<LegalStateRow | null> {
    const rows = await this.listVerifiedStates()
    return rows.find(r => r.slug === slug) ?? null
  },
}
