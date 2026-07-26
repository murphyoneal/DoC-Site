import { Suspense } from 'react'
import LoginForm from '@/app/components/LoginForm'

// Single login page. Email + password only — no signup, no reset UI, no profile
// (invite-only alpha; the account is provisioned out of band).
// LoginForm reads the ?next= param via useSearchParams(), which requires a Suspense
// boundary for Next to prerender this route.
export default function LoginPage() {
  return (
    <main style={{ minHeight: '100dvh', display: 'grid', placeItems: 'center', padding: 24 }}>
      <Suspense fallback={null}>
        <LoginForm />
      </Suspense>
    </main>
  )
}
