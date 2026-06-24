import type { Metadata } from 'next'
import HomeMapShell from './components/HomeMapShell'

export const metadata: Metadata = {
  title: 'Find Licensed Contractors Near You | Department of Construction',
  description:
    'Search 268,000+ licensed contractors across Florida and beyond. Verify licence status, find emergency services, and discover local professionals — powered by official government registry data.',
}

export default function HomePage() {
  return <HomeMapShell />
}
