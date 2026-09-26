import type { Metadata } from 'next'
import HomeMapShell from './components/HomeMapShell'

export const metadata: Metadata = {
  // absolute: the layout's title.template does not apply to the page in its own segment, so
  // the root page states its full title once.
  title: { absolute: 'Find Licensed Contractors Near You | Department of Property' },
  description:
    // Measured 2026-09-24: 98,749 businesses from 114,104 DBPR licence records, all Florida.
    // The previous "268,000+ … across Florida and beyond" was neither.
    'Nearly 100,000 Florida contracting businesses from the state construction licence file, on a map. Search by trade, name, licence number, city or county, and see each licence’s status as recorded.',
}

export default function HomePage() {
  return <HomeMapShell />
}
