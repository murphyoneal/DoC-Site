// Scan before publish (ruling 762, part 3). Two slots, never collapsed into one:
//   classification - adult / explicit / violent. A commodity classifier; a flag HOLDS the image for
//                    Murphy to decide.
//   hash_match     - CSAM hash matching against known material. A match never publishes, is preserved,
//                    and carries legal obligations that are Murphy's counsel's, not ours to design.
// Each slot is ONE swappable call. With no provider configured a slot returns not_available, and
// not_available is NEVER a pass: nothing publishes on an absent check.
//
// Provider choice is Murphy's (measured options on the bus, 2026-09-29): recommended AWS Rekognition
// for classification and Microsoft PhotoDNA for hash matching. Neither is wired until he has the
// account; add an adapter below and set the env var - the pipeline does not change.

export type ScanState = 'pass' | 'flag' | 'match' | 'error' | 'not_available'
export type SlotResult = { slot: 'classification' | 'hash_match'; provider: string; state: ScanState; detail?: unknown }

type Adapter = (bytes: Buffer) => Promise<Omit<SlotResult, 'slot'>>

const notAvailable = (provider: string): Adapter => async () => ({ provider, state: 'not_available' })

const CLASSIFIERS: Record<string, Adapter> = {}   // e.g. rekognition, sightengine - added when chosen
const HASH_MATCHERS: Record<string, Adapter> = {} // e.g. photodna - added when access is granted

function adapter(table: Record<string, Adapter>, name: string | undefined): Adapter {
  const key = (name ?? '').trim().toLowerCase()
  return key && table[key] ? table[key] : notAvailable(key || 'none')
}

async function run(slot: SlotResult['slot'], a: Adapter, bytes: Buffer): Promise<SlotResult> {
  try { return { slot, ...(await a(bytes)) } }
  catch (e) { return { slot, provider: 'error', state: 'error', detail: e instanceof Error ? e.message : String(e) } }
}

export async function scanImage(bytes: Buffer): Promise<SlotResult[]> {
  return Promise.all([
    run('classification', adapter(CLASSIFIERS, process.env.MODERATION_CLASSIFIER), bytes),
    run('hash_match', adapter(HASH_MATCHERS, process.env.MODERATION_HASH_MATCHER), bytes),
  ])
}

// The publication decision. Hash matching is REQUIRED unless MODERATION_REQUIRE_HASH_MATCH=false is set
// deliberately (a decision for Murphy, recorded on the bus). An error or not_available in a required
// slot leaves the image pending - it is re-scanned later, never published by default.
export function decide(results: SlotResult[]): 'publish' | 'hold' | 'pending' {
  const c = results.find(r => r.slot === 'classification')
  const h = results.find(r => r.slot === 'hash_match')
  if (h?.state === 'match' || c?.state === 'flag') return 'hold'
  const requireHash = (process.env.MODERATION_REQUIRE_HASH_MATCH ?? 'true').trim().toLowerCase() !== 'false'
  const classificationOk = c?.state === 'pass'
  const hashOk = h?.state === 'pass' || (!requireHash && h?.state === 'not_available')
  return classificationOk && hashOk ? 'publish' : 'pending'
}
