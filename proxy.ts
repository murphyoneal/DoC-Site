import { NextResponse, type NextRequest } from 'next/server'
import { createServerClient } from '@supabase/ssr'

// Session gate. Next 16 renamed `middleware` -> `proxy` (see node_modules/next/dist/docs
// .../file-conventions/proxy.md). Refreshes the Supabase session cookie on every matched
// request and redirects unauthenticated users away from the Roz surface.
export async function proxy(request: NextRequest) {
  let response = NextResponse.next({ request })

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll()
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value))
          response = NextResponse.next({ request })
          cookiesToSet.forEach(({ name, value, options }) => response.cookies.set(name, value, options))
        },
      },
    }
  )

  // getUser() verifies the JWT; do not gate on getSession() alone.
  const { data: { user } } = await supabase.auth.getUser()
  const path = request.nextUrl.pathname

  if (!user) {
    if (path.startsWith('/api/roz') || path.startsWith('/api/agent')) {
      return NextResponse.json({ error: 'Not authenticated.' }, { status: 401 })
    }
    if (path.startsWith('/roz') || path.startsWith('/agent')) {
      const url = request.nextUrl.clone()
      url.pathname = '/login'
      url.searchParams.set('next', path)
      return NextResponse.redirect(url)
    }
  }

  return response
}

// The authenticated agent surface (Roz + the agent claim/verify tools) is gated; everything else
// (public site, B2B assistant) is untouched.
export const config = {
  matcher: ['/roz/:path*', '/api/roz/:path*', '/agent/:path*', '/api/agent/:path*'],
}
