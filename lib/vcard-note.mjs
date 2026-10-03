// The NOTE line of the downloadable contact card (ruling 912).
//
// A card leaves our site and is kept - we cannot correct it after it is downloaded. So it never asserts
// "Licensed contractor" (that was served for licences absent from the latest state file), and it never states
// a status without the date of the file that stated it. A licence absent from the latest file says so; a
// record with no file date states no status at all.

const ABSENT = 'absent_from_latest_file'

const LABELS = { active: 'active', inactive: 'inactive', not_stated: 'not stated' }

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

// Formatted by hand, not toLocaleDateString: ICU versions differ ("Sep" vs "Sept") and a card is permanent.
function fileDate(iso) {
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(String(iso ?? ''))
  if (!m || +m[2] < 1 || +m[2] > 12) return null
  return `${+m[3]} ${MONTHS[+m[2] - 1]} ${m[1]}`
}

// c: { license_number, license_status, register_file_date, register_file_state }
export function vcardLicenceNote(c, profileUrl) {
  const lic = c.license_number ? `Florida licence ${c.license_number}` : 'Florida licence record'
  const date = fileDate(c.register_file_date)
  const check = `This card does not update - check current standing at ${profileUrl} or myfloridalicense.com.`
  if (c.register_file_state === ABSENT) {
    return `${lic}: not in the latest state records we retrieved${date ? ` (last seen ${date})` : ''}. ${check}`
  }
  const label = LABELS[String(c.license_status ?? '').toLowerCase()]
  if (date && label) return `${lic}: status ${label} as retrieved ${date}. ${check}`
  return `${lic}. ${check}`
}
