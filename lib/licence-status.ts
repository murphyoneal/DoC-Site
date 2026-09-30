// How a licence's state-file record is shown. One place for the profile, the scan landing and the
// licence list.
//
// Since 138a each licence carries the date of the state file it was last seen in
// (register_file_date) and whether it is in the latest file (register_file_state). Until those
// columns exist the fields are undefined and the callers fall back to the single register date.

export const ABSENT = 'absent_from_latest_file'

const STATUS_LABELS: Record<string, string> = {
  active: 'Active',
  inactive: 'Inactive',
  not_stated: 'Not stated in the state file',
  unknown: 'Unknown',
}

export function statusLabel(status: string | null | undefined): string {
  const s = String(status ?? '').trim().toLowerCase()
  if (!s) return 'Unknown'
  return STATUS_LABELS[s] ?? s.charAt(0).toUpperCase() + s.slice(1).replace(/_/g, ' ')
}

// "2026-09-07" -> "7 Sep 2026". Dates are calendar dates, so format in UTC.
export function fileDate(iso: string | null | undefined): string | null {
  if (!iso) return null
  const d = new Date(String(iso).slice(0, 10) + 'T00:00:00Z')
  if (isNaN(d.getTime())) return null
  return d.toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric', timeZone: 'UTC' })
}

export const ABSENT_NOTE =
  'This licence was not in the most recent state licence file we hold. The state’s download leaves out ' +
  'licences that are null and void, delinquent or involuntarily inactive, and a licence renewed late can be ' +
  'missing for a while, so absence is not by itself evidence that the licence has lapsed. The details shown ' +
  'are as last recorded. Confirm current standing at myfloridalicense.com.'

// What a no-match means (789 / ruling 649). Our Florida register is the Construction Industry Licensing
// Board file only; electrical contractors are licensed by a separate board we do not hold yet. A no-match
// is a statement about our coverage, never about the business's licence.
export const NOT_HELD_NOTE =
  'We reproduce Florida’s construction licence register. Electrical contractors are licensed by a separate ' +
  'state board whose register we do not hold yet, so an electrician will not appear here — that says nothing ' +
  'about their licence. Check any Florida licence directly at myfloridalicense.com.'
