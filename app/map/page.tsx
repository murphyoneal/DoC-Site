import type { Metadata } from 'next'
import FinderShell from '../components/FinderShell'
import { getFinder } from '@/lib/finder'
import { CATEGORY_LABELS } from '@/lib/tradeCategories'
import { countyLabel, COUNTY_KEYS } from '@/lib/county'

// The contractor finder on departmentofconstruction.com (work order 697). Every filter lives in the
// URL (?q=&county=&trade=), so each view is a real, server-rendered page: a list of named businesses
// with their trade and county, linked to their profiles. That list is what a search engine can read.

type SP = Promise<{ [k: string]: string | string[] | undefined }>

function one(v: string | string[] | undefined): string {
  return (Array.isArray(v) ? v[0] : v ?? '').trim()
}
function clean(sp: Awaited<SP>) {
  const county = one(sp.county).toLowerCase()
  const trade = one(sp.trade).toLowerCase()
  const page = Math.min(Math.max(parseInt(one(sp.page), 10) || 1, 1), 2000)
  return {
    page,
    q: one(sp.q).slice(0, 80),
    county: (COUNTY_KEYS as readonly string[]).includes(county) ? county : '',
    trade: CATEGORY_LABELS[trade] ? trade : '',
  }
}

export async function generateMetadata({ searchParams }: { searchParams: SP }): Promise<Metadata> {
  const { q, county, trade, page } = clean(await searchParams)
  const what = trade ? `${CATEGORY_LABELS[trade]} contractors` : 'Licensed contractors'
  const where = county ? `${countyLabel(county)} County, Florida` : 'Florida'
  return {
    title: (q ? `“${q}” — ${what} in ${where}` : `${what} in ${where}`) + (page > 1 ? ` (page ${page})` : ''),
    description: `${what} in ${where}, from the state construction licence file: name, trade, city and licence status as recorded. Listed alphabetically, never ranked.`,
  }
}

export default async function MapPage({ searchParams }: { searchParams: SP }) {
  const { q, county, trade, page } = clean(await searchParams)
  const data = await getFinder(q, county, trade, page)
  return <FinderShell data={data} q={q} county={county} trade={trade} page={page} />
}
