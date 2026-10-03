import type { Metadata } from 'next'
import HomeMapShell from './components/HomeMapShell'
import PropertyHome from './components/PropertyHome'
import { DOMAIN_SPLIT } from '@/lib/site'

// "/" on departmentofproperty.com. (On departmentofconstruction.com, proxy.ts serves the contractor
// register landing instead and this page is never reached.)
//
// Before the domain split this is still the contractor map, exactly as today. After it, the map
// lives at departmentofconstruction.com/map and this is Department of Property's own home: the two
// registers, agents and contractors (work order 712; the property lookup is parked).
export const metadata: Metadata = DOMAIN_SPLIT
  ? {
      title: { absolute: 'Department of Property — Florida’s licensed agents and contractors' },
      description:
        'Florida’s licensed real estate agents and contractors, from the state licence files that hold them, with the date each was read.',
    }
  : {
      // absolute: the layout's title.template does not apply to the page in its own segment, so
      // the root page states its full title once.
      title: { absolute: 'Find Licensed Contractors Near You | Department of Property' },
      description:
        // Measured 2026-09-24: 98,749 businesses from 114,104 DBPR licence records, all Florida.
        'More than 110,000 Florida contracting businesses from the state construction licence file, on a map. Search by trade, name, licence number, city or county, and see each licence’s status as recorded.',
    }

export default function HomePage() {
  return DOMAIN_SPLIT ? <PropertyHome /> : <HomeMapShell />
}
