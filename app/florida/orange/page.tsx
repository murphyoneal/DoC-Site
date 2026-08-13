import type { Metadata } from 'next'
import CountyLanding from '@/app/components/CountyLanding'
import { getCounty } from '@/lib/florida-counties'

const county = getCounty('orange')!

export const metadata: Metadata = {
  title: `${county.name} Licensed Contractors`,
  description: `Find licensed contractors in ${county.name}, Florida — ${county.cities.map(c => c.name).join(', ')}. DBPR verified licence data.`,
  alternates: { canonical: `/florida/${county.slug}` },
  openGraph: {
    title: `${county.name} Licensed Contractors | Department of Construction`,
    description: county.blurb,
    url: `/florida/${county.slug}`,
    type: 'website',
  },
}

export default function Page() {
  return <CountyLanding county={county} />
}
