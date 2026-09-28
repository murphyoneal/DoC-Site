// The agent claim (work order 712 item 2; rulings R3-R5). An agent claims a PERSON - their licence.
// The DBPR roster and status files are never written; the claim and the agent's own details live in
// agent_claim_request / agent_public_profile, read and written only through service_role functions.

const SB = 'https://eaifqorwmgayiqmbtzcg.supabase.co/rest/v1'
const KEY = process.env.SUPABASE_SECRET_KEY ?? ''
const H = { apikey: KEY, Authorization: 'Bearer ' + KEY, 'Content-Type': 'application/json' }

export type AgentPage = {
  slug: string
  register: {
    name: string; license_number: string; rank: string | null; county: string | null; first_issued: string | null
    status: string | null; expiry: string | null; brokerage: string | null; status_as_of: string | null; source: string
  }
  own: {
    phone?: string; email?: string; website?: string; bio?: string; counties?: string[]; property_classes?: string[]
    declared_brokerage?: string; updated_on?: string
  }
}

export type AgentEditor = {
  allowed: boolean; reason: string
  profile?: Record<string, unknown> & { slug: string }
  register_brokerage?: string | null
  classes_vocab?: { code: string; label: string }[]
}

export async function rpc<T>(fn: string, body: unknown, revalidate?: number): Promise<T | null> {
  try {
    const r = await fetch(`${SB}/rpc/${fn}`, {
      method: 'POST', headers: H, body: JSON.stringify(body),
      ...(revalidate === undefined ? { cache: 'no-store' as const } : { next: { revalidate } }),
    })
    return r.ok ? ((await r.json()) as T) : null
  } catch { return null }
}

export const getAgentPage = (slug: string) => rpc<AgentPage | null>('agent_public_page', { p_slug: slug }, 60)
export const getAgentEditor = (slug: string, email: string | null) => rpc<AgentEditor>('agent_profile_get', { p_slug: slug, p_email: email })
