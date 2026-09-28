import { NextRequest, NextResponse } from 'next/server'
import type { EmailOtpType } from '@supabase/supabase-js'
import { getSupabaseAuth } from '@/lib/supabase/ssr-server'

// The link in the set-password email (work order 725). Verifies the one-time token server-side,
// which signs the person in (session cookie on THIS host), then sends them to choose a password and on
// to the page they claimed. An expired or used link says so and offers a new one - never a blank door.
export async function GET(req: NextRequest) {
  const u = req.nextUrl
  const token_hash = u.searchParams.get('token_hash') ?? ''
  const type = (u.searchParams.get('type') ?? '') as EmailOtpType
  const next = u.searchParams.get('next') ?? '/account'
  const safeNext = next.startsWith('/') && !next.startsWith('//') ? next : '/account'
  if (!token_hash || !['invite', 'recovery'].includes(type)) {
    return NextResponse.redirect(new URL('/auth/forgot?link=invalid', u.origin))
  }
  const supabase = await getSupabaseAuth()
  const { error } = await supabase.auth.verifyOtp({ token_hash, type })
  if (error) return NextResponse.redirect(new URL('/auth/forgot?link=expired', u.origin))
  const to = new URL('/auth/set-password', u.origin)
  to.searchParams.set('next', safeNext)
  return NextResponse.redirect(to)
}
