import { headers } from 'next/headers'
import { DOC_URL, DOP_URL, CONTRACTOR_URL, DOMAIN_SPLIT, isDocHost } from './site'

// What each host calls itself. One object per product, so the header, footer, metadata, JSON-LD,
// robots and sitemap cannot disagree about which site a page is on (ruling 2026-09-27).

export type NavLink = { label: string; href: string }

export type Brand = {
  key: 'doc' | 'dop'
  name: string
  mark: string
  url: string
  description: string
  titleDefault: string
  nav: NavLink[]
  footer: NavLink[]
  footerLine: string
}

const DOC: Brand = {
  key: 'doc',
  name: 'Department of Construction',
  mark: 'DoC',
  url: DOC_URL,
  description:
    'Florida’s licensed construction contractors from the state licence file: search by trade, name, licence number, city or county, and see each licence’s status as recorded.',
  titleDefault: 'Florida contractor register | Department of Construction',
  nav: [
    { label: 'Search', href: '/c' },
    { label: 'Map', href: '/map' },
    { label: 'Florida', href: '/florida' },
    { label: 'Disclaimer', href: '/disclaimer' },
  ],
  footer: [
    { label: 'Florida contractors', href: '/florida' },
    { label: 'Construction-defect deadlines', href: '/rights' },
    { label: 'Disclaimer', href: '/disclaimer' },
    { label: 'Department of Property', href: `${DOP_URL}/about.html` },
  ],
  footerLine: 'Licensed contractor records from the Florida DBPR state licence file.',
}

// DoP after the split: land, PIR, agents.
const DOP_SPLIT: Brand = {
  key: 'dop',
  name: 'Department of Property',
  mark: 'DoP',
  url: DOP_URL,
  description:
    'Florida’s licensed real estate agents and contractors, from the government registers that hold them.',
  titleDefault: 'Department of Property',
  nav: [
    { label: 'Agents', href: '/agents.html' },
    { label: 'Contractors', href: `${CONTRACTOR_URL}/c` },
    { label: 'Disclaimer', href: '/disclaimer' },
  ],
  footer: [
    { label: 'About', href: '/about.html' },
    { label: 'Agent register', href: '/agents.html' },
    { label: 'Contractor register', href: `${CONTRACTOR_URL}/c` },
    { label: 'Privacy', href: '/privacy.html' },
    { label: 'Terms', href: '/terms.html' },
  ],
  footerLine: 'Property and licence records from the government registers that hold them.',
}

// DoP BEFORE the split is still the contractor finder, exactly as it is today: its home is the map,
// so its nav and title must not claim otherwise until DOMAIN_SPLIT flips.
const DOP_LEGACY: Brand = {
  key: 'dop',
  name: 'Department of Property',
  mark: 'DoP',
  url: DOP_URL,
  description:
    'Search Florida construction contractors by trade and location, and see each licence’s status as recorded in the state licence file.',
  titleDefault: 'Find Licensed Contractors Near You | Department of Property',
  nav: [
    { label: 'Florida', href: '/florida' },
    { label: 'Disclaimer', href: '/disclaimer' },
  ],
  footer: [
    { label: 'Florida contractors', href: '/florida' },
    { label: 'Volusia County', href: '/florida/volusia' },
    { label: 'Disclaimer', href: '/disclaimer' },
  ],
  footerLine: 'Licensed contractor search from the Florida DBPR state licence file.',
}

const DOP = DOMAIN_SPLIT ? DOP_SPLIT : DOP_LEGACY

export function brandFor(host: string | null | undefined): Brand {
  return isDocHost(host) ? DOC : DOP
}

/** The brand of the host this request came in on. Reading headers makes the caller dynamic. */
export async function requestBrand(): Promise<Brand> {
  return brandFor((await headers()).get('host'))
}
