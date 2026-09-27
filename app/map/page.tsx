import type { Metadata } from 'next'
import HomeMapShell from '../components/HomeMapShell'

// The contractor map, on the contractor site (ruling 2026-09-27). Until the finder redesign merges
// the register search and the map into one page, the DoC home is the register search and the map
// lives here. No property-address box: that is Department of Property's.
export const metadata: Metadata = {
  title: 'Contractor map',
  description:
    'Florida’s licensed construction contractors on a map, from the state licence file. Pick a trade, or search by name, licence number, city or county.',
}

export default function MapPage() {
  return <HomeMapShell withPropertyLookup={false} />
}
