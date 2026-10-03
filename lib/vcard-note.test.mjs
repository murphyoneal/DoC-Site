import { test } from 'node:test'
import assert from 'node:assert/strict'
import { vcardLicenceNote } from './vcard-note.mjs'

const URL = 'https://departmentofconstruction.com/c/x'

test('card never says "Licensed contractor", for any state (ruling 912)', () => {
  for (const s of ['active', 'inactive', 'not_stated', 'not_in_latest_file', 'unknown', null]) {
    for (const f of ['in_latest_file', 'absent_from_latest_file', null]) {
      const n = vcardLicenceNote({ license_number: 'CGC1', license_status: s, register_file_date: '2026-09-07', register_file_state: f }, URL)
      assert.doesNotMatch(n, /licensed contractor/i)
    }
  }
})

test('a licence absent from the latest file never reads active on the card', () => {
  const n = vcardLicenceNote({ license_number: 'CAC010332', license_status: 'active', register_file_date: '2026-06-27', register_file_state: 'absent_from_latest_file' }, URL)
  assert.doesNotMatch(n, /\bactive\b/i)
  assert.match(n, /not in the latest state records we retrieved/)
  assert.match(n, /27 Jun 2026/)
})

test('an in-file status is stated with its file date', () => {
  const n = vcardLicenceNote({ license_number: 'CGC1', license_status: 'active', register_file_date: '2026-09-07', register_file_state: 'in_latest_file' }, URL)
  assert.match(n, /status active as retrieved 7 Sep 2026/)
  assert.match(n, /does not update/)
})

test('no file date or unrecognised status: no status asserted', () => {
  for (const c of [
    { license_number: 'CGC1', license_status: 'active', register_file_date: null, register_file_state: 'in_latest_file' },
    { license_number: 'CGC1', license_status: 'unknown', register_file_date: '2026-09-07', register_file_state: 'in_latest_file' },
  ]) {
    const n = vcardLicenceNote(c, URL)
    assert.doesNotMatch(n, /status|active/i)
  }
})
