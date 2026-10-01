// lib/report-gate.test.mjs - the report page's branch, tested where it is (ruling 880). No database, no ledger.
//   node --test lib/
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { resolveReportView, checkoutRefusal } from './report-gate.mjs'

const PREVIEW = { meta: { coNo: 74 }, parcelState: 'present', countyName: 'Volusia', address: '227 DAYTONA BLVD', frameLabel: 'Commercial property' }
const REPORT = { meta: { coNo: 74 }, property: { address: '227 DAYTONA BLVD' } }
const timeout = () => Object.assign(new Error('canceling statement due to statement timeout'), { status: 500, code: '57014' })

function deps({ preview = PREVIEW, unlocked = false, report = REPORT, reportThrows = null } = {}) {
  const calls = { report: 0, errors: [] }
  return {
    calls,
    preview: async () => preview,
    unlocked: async () => unlocked,
    report: async () => { calls.report++; if (reportThrows) throw reportThrows; return report },
    onBuildError: (e) => calls.errors.push(e),
  }
}

test('a paying buyer whose full build times out gets the error state, not a throw (the 875 defect)', async () => {
  const d = deps({ unlocked: true, reportThrows: timeout() })
  const v = await resolveReportView(74, '522305000010', d)
  assert.equal(v.kind, 'error')
  assert.equal(d.calls.errors.length, 1, 'the failure is logged')
  assert.equal(d.calls.errors[0].code, '57014')
})

test('a paying buyer whose build succeeds gets the full report (the other direction)', async () => {
  const d = deps({ unlocked: true })
  const v = await resolveReportView(74, '522305000010', d)
  assert.equal(v.kind, 'report')
  assert.equal(v.report, REPORT)
  assert.equal(d.calls.errors.length, 0)
})

test('an unpaid visitor gets the paywall and the full report is never built', async () => {
  const d = deps({ unlocked: false })
  const v = await resolveReportView(74, '522305000010', d)
  assert.equal(v.kind, 'paywall')
  assert.equal(v.address, '227 DAYTONA BLVD')
  assert.equal(v.frameLabel, 'Commercial property')
  assert.equal(d.calls.report, 0, 'the 6-12 s build must not run for an unpaid visitor')
})

test('an unpaid visitor never sees a build error, because no build runs', async () => {
  const d = deps({ unlocked: false, reportThrows: timeout() })
  const v = await resolveReportView(74, '522305000010', d)
  assert.equal(v.kind, 'paywall')
  assert.equal(d.calls.errors.length, 0)
})

test('no preview for an unpaid visitor is not found', async () => {
  const v = await resolveReportView(74, 'x', deps({ unlocked: false, preview: null }))
  assert.equal(v.kind, 'notfound')
})

test('a null report for a paying buyer is the error state, never a blank page', async () => {
  const v = await resolveReportView(74, 'x', deps({ unlocked: true, report: null }))
  assert.equal(v.kind, 'error')
})

test('a parcel id not in the roll is absent with its cause, and never reaches the paywall (181a)', async () => {
  const d = deps({ unlocked: false, preview: { meta: {}, parcelState: 'none_recorded', countyName: 'Volusia', address: null, frameLabel: null } })
  const v = await resolveReportView(74, '000000000000', d)
  assert.equal(v.kind, 'absent')
  assert.equal(v.state, 'none_recorded')
  assert.equal(v.countyName, 'Volusia')
  assert.equal(d.calls.report, 0)
})

test('an absent parcel is absent even if something claims it is unlocked', async () => {
  const d = deps({ unlocked: true, preview: { meta: {}, parcelState: 'not_available', countyName: null, address: null, frameLabel: null } })
  const v = await resolveReportView(99, 'x', d)
  assert.equal(v.kind, 'absent')
  assert.equal(v.state, 'not_available')
  assert.equal(d.calls.report, 0)
})

test('checkout refuses a parcel that is not in the roll, naming the cause (181a second gate)', () => {
  const r = checkoutRefusal({ parcelState: 'none_recorded', countyName: 'Volusia' }, 74, '000000000000')
  assert.equal(r.status, 404)
  assert.match(r.body.error, /not in the Volusia County parcel roll/)
  const u = checkoutRefusal({ parcelState: 'not_available', countyName: null }, 99, 'x')
  assert.match(u.body.error, /don't hold records for county 99/)
  assert.equal(checkoutRefusal(null, 74, 'x').status, 404, 'no preview is a refusal, never a sale')
})

test('checkout allows a parcel that is present', () => {
  assert.equal(checkoutRefusal({ parcelState: 'present', countyName: 'Volusia' }, 74, '633001001890'), null)
})
