// Suspension (ruling 762 part 4). The STATE lives in the database, derived from moderation_action and
// written only by set_business_suspension(), which refuses anyone who is not an operator. This module
// does what a database function cannot: the public COPIES of the business's files. While suspended, the
// logo's public copy and every public gallery copy are removed, so nothing the business supplied is
// served even to someone holding the URL. Reinstatement restores them from the private copies, which
// are never touched (765.3: the artefact is retained).

const HOST = 'https://eaifqorwmgayiqmbtzcg.supabase.co'
const key = () => process.env.SUPABASE_SECRET_KEY ?? ''
const auth = () => ({ apikey: key(), Authorization: 'Bearer ' + key() })

export async function rpc<T = unknown>(fn: string, args: object): Promise<T | null> {
  try {
    const r = await fetch(`${HOST}/rest/v1/rpc/${fn}`, { method: 'POST', cache: 'no-store', headers: { ...auth(), 'Content-Type': 'application/json' }, body: JSON.stringify(args) })
    if (!r.ok) { console.error(`[suspension] ${fn} ${r.status}`, await r.text()); return null }
    return (await r.json()) as T
  } catch (e) { console.error(`[suspension] ${fn}`, e); return null }
}

export async function isSuspended(slug: string): Promise<boolean> {
  const s = await rpc<{ suspended: boolean }>('business_public_state', { p_slug: slug })
  return s?.suspended === true
}

export async function businessIdFor(slug: string): Promise<string | null> {
  const rows = await get(`businesses?slug=eq.${encodeURIComponent(slug)}&select=id`)
  return (rows as { id: string }[])[0]?.id ?? null
}

async function get(path: string) {
  const r = await fetch(`${HOST}/rest/v1/${path}`, { headers: auth(), cache: 'no-store' })
  return r.ok ? r.json() : []
}
async function removePublic(bucket: string, paths: string[]) {
  if (!paths.length) return
  await fetch(`${HOST}/storage/v1/object/${bucket}`, { method: 'DELETE', headers: { ...auth(), 'Content-Type': 'application/json' }, body: JSON.stringify({ prefixes: paths }) })
}
async function copyPrivateToPublic(fromBucket: string, fromPath: string, toBucket: string, toPath: string, type: string) {
  const g = await fetch(`${HOST}/storage/v1/object/${fromBucket}/${fromPath}`, { headers: auth(), cache: 'no-store' })
  if (!g.ok) return false
  const body = new Uint8Array(await g.arrayBuffer())
  const p = await fetch(`${HOST}/storage/v1/object/${toBucket}/${toPath}`, { method: 'POST', headers: { ...auth(), 'Content-Type': type, 'x-upsert': 'true' }, body })
  return p.ok
}

// Returns a short account of what was done, for the action log and the operator's screen.
export async function applySuspensionToStorage(businessId: string, suspended: boolean): Promise<string[]> {
  const done: string[] = []
  const prof = (await get(`business_profile?business_id=eq.${businessId}&select=logo_path,publish_logo`))[0]
  const lic = await get(`business_licences?business_id=eq.${businessId}&select=contractor_id`)
  const ids = (lic as { contractor_id: string }[]).map(l => l.contractor_id)
  const imgs = ids.length
    ? await get(`work_contribution?contractor_id=in.(${ids.join(',')})&visibility=eq.public&select=id,work_contribution_image(public_path,held_path)`)
    : []
  const pubPaths = (imgs as { work_contribution_image: { public_path: string | null; held_path: string | null }[] }[])
    .flatMap(c => c.work_contribution_image).filter(i => i.public_path)
  if (suspended) {
    if (prof?.logo_path) { await removePublic('logo-public', [`${businessId}.png`]); done.push('logo public copy removed') }
    await removePublic('work-public', pubPaths.map(i => i.public_path!))
    done.push(`${pubPaths.length} gallery public copies removed`)
  } else {
    if (prof?.logo_path && prof.publish_logo) {
      const ok = await copyPrivateToPublic('logo-private', prof.logo_path, 'logo-public', `${businessId}.png`, 'image/png')
      done.push(ok ? 'logo public copy restored' : 'logo restore FAILED')
    }
    let n = 0
    for (const i of pubPaths) if (i.held_path && await copyPrivateToPublic('work-private', i.held_path, 'work-public', i.public_path!, 'image/jpeg')) n++
    done.push(`${n} of ${pubPaths.length} gallery public copies restored`)
  }
  return done
}
