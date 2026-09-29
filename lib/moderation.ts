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
export type SlotResult = { slot: 'classification' | 'hash_match'; provider: string; model_version?: string | null; state: ScanState; detail?: unknown }

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

// The policy IN FORCE, recorded with every scan so an old decision stays readable after a retune
// (ruling 765.1). Thresholds are per provider and live in the adapter; they are echoed here when set.
export function currentPolicy() {
  return {
    // whether the switch is on; a person is still required unless hash matching also passed (see decide)
    auto_publish_switch: (process.env.MODERATION_AUTO_PUBLISH ?? '').trim().toLowerCase() === 'true',
    classifier: (process.env.MODERATION_CLASSIFIER ?? '').trim() || null,
    hash_matcher: (process.env.MODERATION_HASH_MATCHER ?? '').trim() || null,
    classifier_threshold: (process.env.MODERATION_CLASSIFIER_THRESHOLD ?? '').trim() || null,
    decided_by: 'lib/moderation.ts decide() v2 (ruling 768: a person is the gate)',
  }
}

// The publication decision (ruling 768). A PERSON is the gate: the classifier is a pre-filter, and a pass
// sends the image to the review page, where Murphy approves it. There is NO automatic publish path until
// hash matching (PhotoDNA) is live AND returns a pass AND MODERATION_AUTO_PUBLISH=true is set on purpose.
//   hold    - a hash match or a classifier flag; never published automatically
//   review  - passed the pre-filter; waiting for a person
//   pending - the pre-filter has not run (no provider, or an error); re-scanned later
//   publish - only with hash-match pass + classifier pass + auto-publish deliberately on
export function decide(results: SlotResult[]): 'publish' | 'review' | 'hold' | 'pending' {
  const c = results.find(r => r.slot === 'classification')
  const h = results.find(r => r.slot === 'hash_match')
  if (h?.state === 'match' || c?.state === 'flag') return 'hold'
  if (c?.state !== 'pass') return 'pending'
  const autoPublish = (process.env.MODERATION_AUTO_PUBLISH ?? '').trim().toLowerCase() === 'true'
  return h?.state === 'pass' && autoPublish ? 'publish' : 'review'
}
