// Server-side only: reads with the secret key.
import { fileDate } from '@/lib/licence-status'

// The date WE retrieved the construction register we serve (capture_date in dbpr_snapshot_log). Ruling 994 / work
// order 1002: our retrieval date is published on every record; a source's own posting date is not.
export async function getRegisterRetrievedDate(): Promise<string | null> {
  const key = process.env.SUPABASE_SECRET_KEY ?? ''
  try {
    const res = await fetch(
      'https://eaifqorwmgayiqmbtzcg.supabase.co/rest/v1/dbpr_snapshot_log?is_register_source=eq.true&select=capture_date&order=capture_date.desc&limit=1',
      { headers: { apikey: key, Authorization: 'Bearer ' + key }, next: { revalidate: 3600 } }
    )
    if (!res.ok) return null
    return fileDate((await res.json())?.[0]?.capture_date)
  } catch {
    return null
  }
}
