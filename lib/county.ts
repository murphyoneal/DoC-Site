// Florida county keys exactly as the contractor register holds them (contractors.county_name),
// and how to show them. One place for the app: the profile's county line, its related-list
// heading and county link, and the /c search's county filter all read from here.
// (The DoC register page in the DoC-Public repo carries its own copy of the same 67 keys.)

export const COUNTY_KEYS = [
  'alachua','baker','bay','bradford','brevard','broward','calhoun','charlotte','citrus','clay','collier',
  'columbia','dade','desoto','dixie','duval','escambia','flagler','franklin','gadsden','gilchrist','glades',
  'gulf','hamilton','hardee','hendry','hernando','highlands','hillsborough','holmes','indian_river','jackson',
  'jefferson','lafayette','lake','lee','leon','levy','liberty','madison','manatee','marion','martin','monroe',
  'nassau','okaloosa','okeechobee','orange','osceola','palm_beach','pasco','pinellas','polk','putnam',
  'santa_rosa','sarasota','seminole','st_johns','st_lucie','sumter','suwannee','taylor','union','volusia',
  'wakulla','walton','washington',
] as const

const SPECIAL: Record<string, string> = { dade: 'Miami-Dade', desoto: 'DeSoto', st_johns: 'St. Johns', st_lucie: 'St. Lucie' }

// "indian_river" -> "Indian River", "dade" -> "Miami-Dade"; null/blank -> null (never "this").
export function countyLabel(key: string | null | undefined): string | null {
  const k = String(key ?? '').trim().toLowerCase()
  if (!k) return null
  return SPECIAL[k] ?? k.split('_').map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(' ')
}

// County landing pages that exist under /florida, keyed by the HELD key (the data says "dade",
// the route says "miami-dade").
const LANDINGS: Record<string, string> = {
  volusia: '/florida/volusia', dade: '/florida/miami-dade', orange: '/florida/orange',
  seminole: '/florida/seminole', osceola: '/florida/osceola', lake: '/florida/lake',
}
export function countyLanding(key: string | null | undefined): string {
  return LANDINGS[String(key ?? '').trim().toLowerCase()] ?? '/florida'
}
