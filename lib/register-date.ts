// Server-side only: reads with the secret key.
import { fileDate } from '@/lib/licence-status'

// The date DBPR published the construction file we serve (posted_date, from the file's Last-Modified header),
// NOT the date we retrieved it - the two are stored separately in dbpr_snapshot_log and must not be conflated.
export async function getRegisterPostedDate(): Promise<string | null> {
  const key = process.env.SUPABASE_SECRET_KEY ?? ''
  try {
    const res = await fetch(
      'https://eaifqorwmgayiqmbtzcg.supabase.co/rest/v1/dbpr_snapshot_log?is_register_source=eq.true&select=posted_date&order=posted_date.desc&limit=1',
      { headers: { apikey: key, Authorization: 'Bearer ' + key }, next: { revalidate: 3600 } }
    )
    if (!res.ok) return null
    return fileDate((await res.json())?.[0]?.posted_date)
  } catch {
    return null
  }
}
