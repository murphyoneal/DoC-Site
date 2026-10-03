// How a register row's state is shown (ruling 978 item 4). 212a restored state from the state file, and the file uses a
// numeric placeholder ('99') where it records no state. A placeholder is not a state: it is omitted, and the page says
// the file records none. Every real value is shown exactly as published - never rewritten to FL, which is the overwrite
// 212a undid.
export function stateForDisplay(state: string | null | undefined): { value: string | null; unrecorded: boolean } {
  const s = String(state ?? '').trim()
  if (!s) return { value: null, unrecorded: true }
  if (/^\d+$/.test(s)) return { value: null, unrecorded: true }
  return { value: s, unrecorded: false }
}

// The country a published state/province code belongs to, for an address that must name one (the vCard). 212a restored
// Canadian provinces (BC, ON, QC...) that the June load had overwritten with FL, so "US" is no longer a safe constant.
const CA_PROVINCES = new Set(['AB','BC','MB','NB','NL','NS','NT','NU','ON','PE','QC','SK','YT'])
const US_CODES = new Set(['AL','AK','AZ','AR','CA','CO','CT','DE','DC','FL','GA','HI','ID','IL','IN','IA','KS','KY','LA','ME','MD','MA','MI','MN',
  'MS','MO','MT','NE','NV','NH','NJ','NM','NY','NC','ND','OH','OK','OR','PA','RI','SC','SD','TN','TX','UT','VT','VA','WA','WV','WI','WY',
  'PR','VI','GU','AS','MP','AA','AE','AP','FM','MH','PW'])
export function countryForState(state: string | null | undefined): 'US' | 'CA' | null {
  const s = String(state ?? '').trim().toUpperCase()
  if (CA_PROVINCES.has(s)) return 'CA'
  if (US_CODES.has(s)) return 'US'
  return null
}
