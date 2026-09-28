// What an approved contractor claim allows (work order 712 item 3; rulings R1, R2). The business's
// own details live in business_profile, keyed on the business - never in the DBPR copy, whose
// contractors_public view is readable by anyone. Every read and write is a service_role SECURITY
// DEFINER function; editing is behind the same gate as the photo gallery (an approved claim, and a
// signed-in session with that claim's email).

const SB = 'https://eaifqorwmgayiqmbtzcg.supabase.co/rest/v1'
const KEY = process.env.SUPABASE_SECRET_KEY ?? ''
const H = { apikey: KEY, Authorization: 'Bearer ' + KEY, 'Content-Type': 'application/json' }

export type DeclaredInsurance = { kind: 'general_liability' | 'workers_comp' | 'other'; carrier: string; cover_note: string | null; expires_on: string | null }

export type PublicBusinessProfile = {
  phone?: string
  email?: string
  website?: string
  description?: string
  specialties?: string[]
  other_specialties?: string
  counties?: string[]
  // the business's own statement of where it works (733); never inferred from the licence
  coverage?: { scope: 'nationwide' | 'statewide' | 'counties'; state?: string; counties?: string[] }
  logo?: string
  years_in_business?: number
  insurance?: (DeclaredInsurance & { declared_at: string; check_note: string })[]
  updated_on?: string
}

export type EditorProfile = {
  public_phone: string | null; public_email: string | null; website: string | null; description: string | null
  specialties: string[] | null; other_specialties: string | null; counties_worked: string[] | null; years_in_business: number | null
  publish_phone: boolean; publish_email: boolean; publish_website: boolean; publish_description: boolean
  publish_specialties: boolean; publish_counties: boolean; publish_years: boolean
  coverage_scope: 'nationwide' | 'statewide' | 'counties' | null; coverage_state_geo_id: string | null; publish_coverage: boolean
  logo_path: string | null; publish_logo: boolean
}

export type Gate = { allowed: boolean; reason: string; profile?: EditorProfile | null; insurance?: (DeclaredInsurance & { publish: boolean })[] }

async function rpc<T>(fn: string, body: unknown, revalidate?: number): Promise<T | null> {
  try {
    const r = await fetch(`${SB}/rpc/${fn}`, {
      method: 'POST', headers: H, body: JSON.stringify(body),
      ...(revalidate === undefined ? { cache: 'no-store' as const } : { next: { revalidate } }),
    })
    return r.ok ? ((await r.json()) as T) : null
  } catch { return null }
}

// Published fields of a CLAIMED business only; null when unclaimed or nothing saved.
// Uncached: an owner who saves must see the change on the next view (work order 730).
export const getPublicBusinessProfile = (slug: string) =>
  rpc<PublicBusinessProfile | null>('business_profile_public', { p_slug: slug })

export const getEditorProfile = (slug: string, email: string | null) =>
  rpc<Gate>('business_profile_get', { p_slug: slug, p_email: email })

export const saveBusinessProfile = (slug: string, email: string, p: unknown) =>
  rpc<{ allowed: boolean; saved?: boolean; reason?: string; field?: string; business_id?: string }>('business_profile_save', { p_slug: slug, p_email: email, p })
