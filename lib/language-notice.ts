// Ruling 761: the language check is a NOTICE, not a gate. A save always succeeds; when the database
// records NEW flags for it, Murphy is told - naming the profile, the field and the text, with a link to
// the page. Every notice's delivery is recorded (sent / failed with a reason) - never a silent success.
//
// Deliberately NOT in the notice: a one-click "switch this field off" link. Ruling 762 - destructive
// actions are not links in an email, because mail clients and scanners prefetch them. The switch-off
// is a POST from the review page (762 part 5); the notice says so.

export type LanguageFlag = { id: number; field: string; text: string; rules: string[] }

const HOST = 'https://eaifqorwmgayiqmbtzcg.supabase.co'
const FORMSPREE_URL = 'https://formspree.io/f/xrpgyrjp'

async function recordNotice(flagId: number, state: 'sent' | 'failed', detail: string) {
  const key = process.env.SUPABASE_SECRET_KEY ?? ''
  try {
    await fetch(`${HOST}/rest/v1/rpc/record_language_flag_notice`, {
      method: 'POST', cache: 'no-store',
      headers: { apikey: key, Authorization: 'Bearer ' + key, 'Content-Type': 'application/json' },
      body: JSON.stringify({ p_flag_id: flagId, p_channel: 'formspree', p_state: state, p_detail: detail }),
    })
  } catch (e) { console.error('[language-notice] delivery not recorded', flagId, e) }
}

export async function notifyLanguageFlags(flags: LanguageFlag[] | undefined | null, where: { what: string; subject: string; page: string | null }) {
  if (!flags || flags.length === 0) return
  let state: 'sent' | 'failed' = 'failed'
  let detail = ''
  try {
    const r = await fetch(FORMSPREE_URL, {
      method: 'POST', headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
      body: JSON.stringify({
        _subject: `Language flag: ${where.what} ${where.subject}`,
        source: 'language check (ruling 761) - the save went through; this is a notice, not a refusal',
        page: where.page ?? '(not public)',
        flagged: flags.map(f => `${f.field}: "${f.text}" [${f.rules.join(', ')}]`).join('\n'),
        what_to_do: 'Nothing was blocked. If a field should not be public, switch it off from the review page (coming, ruling 762 part 5). We unpublish, never edit a business\'s words.',
      }),
    })
    state = r.ok ? 'sent' : 'failed'
    detail = r.ok ? 'formspree accepted' : `formspree ${r.status}: ${(await r.text()).slice(0, 300)}`
  } catch (e) {
    detail = 'formspree unreachable: ' + (e instanceof Error ? e.message : String(e))
  }
  for (const f of flags) await recordNotice(f.id, state, detail)
}
