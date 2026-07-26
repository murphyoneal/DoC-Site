'use client'

import { createBrowserClient } from '@supabase/ssr'

// Browser auth client — publishable (anon) key only. Used by the login page to
// signInWithPassword; the resulting session cookie is what the proxy reads.
export function getSupabaseBrowser() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL!
  const anon = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  return createBrowserClient(url, anon)
}
