// lib/coverage-siblings.test.mjs
//   node lib/coverage-siblings.test.mjs
//
// ITEM 250. A coverage sibling is not finished when the payload carries it. It is finished when a READER
// can see it. boatRampsCoverage has been honest in the payload since ruling 203 item 5 - with the intent
// written into types/pir.ts, "an empty boatRamps[] ... must NOT be read as no ramp near this parcel: read
// boatRampsCoverage" - and no page has ever read it. One of four siblings was consumed.
//
// Why this is a TEST and not a rule in CLAUDE.md: the failure mode is that shipping the DB half is safe
// AND FEELS COMPLETE, because the payload really is honest afterwards. A discipline that depends on
// remembering at exactly the moment you feel finished is the one that fails. This fires instead.
//
// The check: every *Coverage field declared in types/pir.ts must be referenced at least once OUTSIDE
// types/ - in app/ or lib/. A declared-but-unread sibling is a private note to ourselves.
//
// KNOWN LIMIT, STATED RATHER THAN DISCOVERED LATER: this reads the TYPE file, so a coverage key that the
// database serves but nobody has typed yet is invisible to it. floodCoverage and zoningCoverage (item 227)
// are in that state right now - served by get_pir_map_geojson, not yet in types/pir.ts. Typing them is what
// puts them under this check, which is the right order: type it, then it must be rendered.

import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';

const ROOT = new URL('..', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');
const TYPES = join(ROOT, 'types', 'pir.ts');

const walk = (dir, out = []) => {
  let entries;
  try { entries = readdirSync(dir); } catch { return out; }
  for (const e of entries) {
    if (e === 'node_modules' || e === '.next' || e === '.git' || e === 'worktrees') continue;
    const p = join(dir, e);
    let st; try { st = statSync(p); } catch { continue; }
    if (st.isDirectory()) walk(p, out);
    // EXCLUDE TEST FILES. Two reasons, and the first one bit immediately: this file NAMES every key it
    // searches for, so without this it finds itself and reports boatRampsCoverage as read. That is
    // CLAUDE.md invariant 4 - a liveness check must not self-match - in a different costume.
    // The second reason outlives the first: a test reading a key is not a READER SEEING IT. Only shipped
    // UI counts as rendering a coverage state.
    else if (/\.(ts|tsx|mjs|js)$/.test(e) && !/\.test\.(ts|tsx|mjs|js)$/.test(e)) out.push(p);
  }
  return out;
};

const types = readFileSync(TYPES, 'utf8');

// Field declarations like `schoolsCoverage?: PirSchoolsCoverage | null`
const declared = [...new Set(
  [...types.matchAll(/^\s*(\w*Coverage)\??\s*:/gm)].map(m => m[1])
)];

const files = [...walk(join(ROOT, 'app')), ...walk(join(ROOT, 'lib'))]
  .filter(f => !f.includes(join('types', 'pir.ts')));

const unread = [];
for (const key of declared) {
  const hits = files.filter(f => readFileSync(f, 'utf8').includes(key));
  if (hits.length === 0) unread.push(key);
}

if (declared.length === 0) {
  console.log('FAIL - the check found no *Coverage fields at all in types/pir.ts. A check that cannot fail is not a check; the pattern probably changed.');
  process.exit(1);
}

console.log(`\n${unread.length === 0
  ? `PASS - all ${declared.length} coverage siblings declared in types/pir.ts are read somewhere outside types/: ${declared.join(', ')}`
  : `FAIL - ${unread.length}/${declared.length} coverage sibling(s) are DECLARED AND NEVER READ. The payload is honest and the reader still sees nothing:\n` +
    unread.map(k => `  ${k}`).join('\n') +
    `\n\nA coverage sibling is not done until something renders it (item 250).`}`);
process.exit(unread.length === 0 ? 0 : 1);
