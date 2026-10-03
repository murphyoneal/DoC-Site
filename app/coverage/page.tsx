import type { Metadata } from 'next'
import { notFound } from 'next/navigation'

// TAKEN DOWN (rulings 990-992, Murphy 2026-10-03): /coverage was a national map coloured by what WE HOLD - "a
// disclosure of weakness and a worklist for a competitor". A coverage map is an internal instrument, never a route;
// the rights map (/rights) is the one that ships. The map component was deleted (ruling 1005), so nothing here can
// be revived by un-commenting a line. The route answers 404.
export const metadata: Metadata = {
  title: 'Not found',
  robots: { index: false, follow: false },
}

export default function CoveragePage() {
  notFound()
}
