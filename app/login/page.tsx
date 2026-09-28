import { Suspense } from 'react'
import LoginForm from '@/app/components/LoginForm'
import { requestBrand } from '@/lib/brand'

// The sign-in page on both sites (work order 725). It says what it is for on each: a contractor
// managing their business on DoC, an agent (or a Roz user) on DoP. It never says "Roz" - that is the
// paid assistant, a different user. One account per email, shared by both sites; each site keeps its
// own sign-in, so someone using both signs in on each with the same email and password.
// LoginForm reads the ?next= param via useSearchParams(), which requires a Suspense
// boundary for Next to prerender this route.
export const metadata = { title: 'Sign in', robots: { index: false } }

export default async function LoginPage() {
  const brand = await requestBrand()
  const doc = brand.key === 'doc'
  return (
    <main style={{ minHeight: '100dvh', display: 'grid', placeItems: 'center', padding: 24 }}>
      <Suspense fallback={null}>
        <LoginForm heading="Sign in" sub={doc ? 'to manage your business profile on Department of Construction' : 'to manage your licence page on Department of Property'} />
      </Suspense>
    </main>
  )
}
