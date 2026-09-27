import type { Metadata } from 'next'
import HomeMapShell from './components/HomeMapShell'
import PropertyHome from './components/PropertyHome'
import { DOMAIN_SPLIT } from '@/lib/site'

// "/" on departmentofproperty.com. (On departmentofconstruction.com, proxy.ts serves the contractor
// register landing instead and this page is never reached.)
//
// Before the domain split this is still the contractor map, exactly as today. After it, the map
// lives at departmentofconstruction.com/map and this is Department of Property's own home: the
// property lookup (ruling 2026-09-27).
export const metadata: Metadata = DOMAIN_SPLIT
  ? {
      title: { absolute: 'Department of Property — the public record for a Florida property' },
      description:
        'Look up a Florida address to see what government registers hold about it: flood zone, zoning, ownership, permits and more.',
    }
  : {
      // absolute: the layout's title.template does not apply to the page in its own segment, so
      // the root page states its full title once.
      title: { absolute: 'Find Licensed Contractors Near You | Department of Property' },
      description:
        // Measured 2026-09-24: 98,749 businesses from 114,104 DBPR licence records, all Florida.
        'Nearly 100,000 Florida contracting businesses from the state construction licence file, on a map. Search by trade, name, licence number, city or county, and see each licence’s status as recorded.',
    }

export default function HomePage() {
  return DOMAIN_SPLIT ? <PropertyHome /> : <HomeMapShell />
}
