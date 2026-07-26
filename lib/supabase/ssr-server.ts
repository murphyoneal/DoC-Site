import { createServerClient } from '@supabase/ssr'
import { cookies } from 'next/headers'

// Auth (session) client — cookie-bound, uses the PUBLISHABLE (anon) key, never the
// secret key. This is only for identifying who is asking; all DATA access stays on
// getSupabaseAdmin() (secret key, server-side only) via the SECURITY DEFINER functions.
// cookies() is async in this Next build — awaited once, then getAll/setAll are sync.
export async function getSupabaseAuth() {
  const cookieStore = await cookies()
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL
  const anon = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
  if (!url) throw new Error('NEXT_PUBLIC_SUPABASE_URL is not set')
  if (!anon) throw new Error('NEXT_PUBLIC_SUPABASE_ANON_KEY is not set')
  return createServerClient(url, anon, {
    cookies: {
      getAll() {
        return cookieStore.getAll()
      },
      setAll(cookiesToSet) {
        // In a Server Component this throws (read-only); the proxy refreshes the
        // session, so swallowing it here is safe.
        try {
          cookiesToSet.forEach(({ name, value, options }) => cookieStore.set(name, value, options))
        } catch {}
      },
    },
  })
}

// The signed-in user, or null. Uses getUser() (verifies the JWT with the auth server),
// never getSession() alone.
export async function getSessionUser() {
  const supabase = await getSupabaseAuth()
  const { data: { user } } = await supabase.auth.getUser()
  return user
}
