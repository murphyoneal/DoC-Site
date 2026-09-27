// Server-side data for the finder page (/map on departmentofconstruction.com). The browser never
// calls contractor_finder: the page renders the list on the server so it arrives as real text and
// links (work order 697: text ranks, pins do not). The function is service_role-only.

const SB_HOST = 'eaifqorwmgayiqmbtzcg.supabase.co'
const SB_KEY = process.env.SUPABASE_SECRET_KEY ?? ''

export type FinderRow = {
  slug: string
  name: string
  trade: string | null
  trade_key: string | null
  trades: string[]
  city: string
  county: string | null
  lat: number | null
  lng: number | null
  claimed: boolean
  record_dated: boolean | null
  absent_from_latest_file: boolean
}

export type FinderResult =
  | { mode: 'counties'; counties: { county: string; businesses: number }[]; source_retrieved: string | null }
  | {
      mode: 'results'
      field_status?: string
      note?: string
      count: number
      returned: number
      order?: string
      trades: { trade: string; businesses: number }[]
      source_retrieved?: string | null
      coverage_note?: string
      results: FinderRow[]
    }
  | { mode: 'error'; message: string }

export async function getFinder(q: string, county: string, trade: string): Promise<FinderResult> {
  try {
    const res = await fetch(`https://${SB_HOST}/rest/v1/rpc/contractor_finder`, {
      method: 'POST',
      headers: { apikey: SB_KEY, Authorization: 'Bearer ' + SB_KEY, 'Content-Type': 'application/json' },
      body: JSON.stringify({ q: q || null, county: county || null, trade: trade || null, lim: 60 }),
      next: { revalidate: 300 },
    })
    if (!res.ok) return { mode: 'error', message: `The register could not be searched (${res.status}).` }
    return (await res.json()) as FinderResult
  } catch {
    return { mode: 'error', message: 'The register could not be searched just now.' }
  }
}
