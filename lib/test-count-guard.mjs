// Ruling 922: a test that does not run is a check that cannot fail.
//
// The custom harnesses here (fact-render, numeric-provenance, qualifier-guard, report-coverage, roz-tourniquet) register
// each case by calling test(...) or check(...) at column 0 and end in a summary + process.exit. A case written AFTER that
// exit never runs and the file still prints PASS - four brownfield cases sat there on 2026-10-01 while 73 ran.
// This counts the declared calls in the harness's own source and reports a failure when fewer ran, so a suite that stops
// short goes red instead of passing quietly.
import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'

export function assertAllRan(metaUrl, ran, fnName = 'test') {
  const src = readFileSync(fileURLToPath(metaUrl), 'utf8')
  const declared = (src.match(new RegExp(`^${fnName}\\(`, 'gm')) || []).length
  if (declared === 0) return `test-count guard: no top-level ${fnName}( calls found - the guard is pointed at the wrong name`
  if (ran !== declared) return `test-count guard: ${declared} ${fnName}() cases declared, ${ran} ran - ${declared - ran} never executed`
  return null
}
