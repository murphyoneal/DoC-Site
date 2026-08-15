// Shared PostgREST transport for every socket.
//
// RULING 197. The bug this exists to kill:
//
//   res.on('end', () => { try { resolve(JSON.parse(d)) } catch { resolve([]) } })
//
// A PostgREST ERROR BODY IS VALID JSON. It parses cleanly, the catch never fires,
// and the caller receives {message, code, hint} where it expects rows. On 3 August
// service_role lost SELECT on 2,169 of 2,215 tables; every read returned
//   401 {"code":"42501","message":"permission denied for table b2b_accounts"}
// which parsed fine, so `rows?.[0]` was undefined and the account lookup reported
// "Invalid or inactive account key". AN AUTH FAILURE RENDERED AS A DATA ANSWER,
// and the backend was silently offline for twelve days.
//
// Same class as an empty result meaning "no data" rather than "the query never ran".
// So: an error THROWS. It never resolves to [] or null. The three states stay
// distinct — rows / genuinely empty / the query did not run.
//
// None of the old sockets checked res.statusCode either, so a 4xx with a JSON body
// was indistinguishable from success. That is checked here first.

export class PostgrestError extends Error {
  readonly status: number
  readonly code?: string
  readonly hint?: string
  readonly details?: string
  readonly path: string

  constructor(args: { status: number; path: string; message: string; code?: string; hint?: string; details?: string }) {
    super(args.message)
    this.name = 'PostgrestError'
    this.status = args.status
    this.code = args.code
    this.hint = args.hint
    this.details = args.details
    this.path = args.path
  }

  /** True when the backend identity cannot read the table — the 3 August failure mode. */
  get isPermissionDenied(): boolean {
    return this.code === '42501' || this.status === 401 || this.status === 403
  }

  /** A line safe to log and to surface as an ERROR (never as a data answer). */
  toString(): string {
    const bits = [`${this.status}`, this.code, this.message].filter(Boolean)
    return `PostgrestError(${bits.join(' ')})${this.hint ? ` hint: ${this.hint}` : ''}`
  }
}

/** Does a successfully-parsed body actually describe a PostgREST error? */
function looksLikeError(v: any): boolean {
  return (
    v != null &&
    typeof v === 'object' &&
    !Array.isArray(v) &&
    typeof v.message === 'string' &&
    ('code' in v || 'hint' in v || 'details' in v)
  )
}

const SB_HOST = 'eaifqorwmgayiqmbtzcg.supabase.co'

function serviceKey(): string {
  const k = process.env.SUPABASE_SECRET_KEY
  // Fail loudly at call time rather than sending `Bearer undefined` and getting a
  // 401 that then has to be diagnosed as a permissions problem.
  if (!k) throw new PostgrestError({ status: 0, path: '(config)', message: 'SUPABASE_SECRET_KEY is not set in this environment' })
  return k
}

export function pgRequest(
  method: 'GET' | 'POST',
  path: string,
  body?: unknown,
  extraHeaders?: Record<string, string>,
): Promise<any> {
  return new Promise(function (resolve, reject) {
    let key: string
    try { key = serviceKey() } catch (e) { return reject(e) }

    const https = require('https')
    const payload = body === undefined ? null : JSON.stringify(body)
    const headers: Record<string, string> = Object.assign(
      { apikey: key, Authorization: 'Bearer ' + key },
      payload != null ? { 'Content-Type': 'application/json', 'Content-Length': String(Buffer.byteLength(payload)) } : {},
      extraHeaders || {},
    )

    const req = https.request({ hostname: SB_HOST, path, method, headers }, function (res: any) {
      let d = ''
      res.on('data', function (c: any) { d += c })
      res.on('end', function () {
        const status: number = res.statusCode

        // 1. HTTP status is the first gate. A 4xx/5xx is NEVER data.
        if (status < 200 || status >= 300) {
          let parsed: any = null
          try { parsed = d ? JSON.parse(d) : null } catch { /* body may not be JSON */ }
          return reject(new PostgrestError({
            status, path,
            message: parsed?.message ?? (d ? d.slice(0, 300) : `HTTP ${status} with empty body`),
            code: parsed?.code, hint: parsed?.hint, details: parsed?.details,
          }))
        }

        // 2. Empty body on a 2xx (e.g. Prefer: return=minimal) is a legitimate null.
        if (!d) return resolve(null)

        // 3. Malformed JSON THROWS. Previously this resolved to [] / null, which is
        //    how a truncated or proxied response became "no results".
        let parsed: any
        try {
          parsed = JSON.parse(d)
        } catch {
          return reject(new PostgrestError({
            status, path,
            message: `response was not valid JSON (${d.length} bytes): ${d.slice(0, 200)}`,
          }))
        }

        // 4. A 2xx carrying an error-shaped object is still an error.
        if (looksLikeError(parsed)) {
          return reject(new PostgrestError({
            status, path, message: parsed.message,
            code: parsed.code, hint: parsed.hint, details: parsed.details,
          }))
        }

        resolve(parsed)
      })
    })
    req.on('error', reject)
    if (payload != null) req.write(payload)
    req.end()
  })
}

/** GET returning rows. Throws on error; an empty table is [] and that is a real answer. */
export async function pgGet(path: string): Promise<any[]> {
  const v = await pgRequest('GET', path)
  if (v == null) return []
  if (!Array.isArray(v)) {
    // A non-array from a table read means the shape assumption is wrong — surface it
    // rather than letting `rows?.[0]` quietly yield undefined.
    throw new PostgrestError({ status: 200, path, message: `expected an array of rows, got ${typeof v}` })
  }
  return v
}

/** POST (RPC or insert). Throws on error. */
export function pgPost(path: string, body: unknown, prefer?: string): Promise<any> {
  return pgRequest('POST', path, body, prefer ? { Prefer: prefer } : undefined)
}
