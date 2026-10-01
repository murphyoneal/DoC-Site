// lib/report-gate.mjs
// The report page's decision, extracted so it can be tested where the change is (ruling 880): which of
// notfound / paywall / error / report a request gets. The page maps the result to elements; nothing here
// renders. Dependencies are injected so the test can stub the sockets without a database, a ledger row or
// a deployment.
//
//   deps.preview(coNo, parcelId)  -> { meta, parcelState, countyName, address, frameLabel } | null  (179a/181a)
//   deps.unlocked(coNo, parcelId) -> boolean                                    (the purchase gate)
//   deps.report(coNo, parcelId)   -> PirReport | null, and THROWS on an error   (ruling 197 transport)
//   deps.onBuildError(err)        -> void (logging only)
//
// The ordering is the point (ruling 875): an unpaid visitor never pays for the full build, and a paying
// buyer whose build fails gets the retryable error state - never a bare 500 and never a partial report.

export async function resolveReportView(coNo, parcelId, deps) {
  const [preview, unlocked] = await Promise.all([
    deps.preview(coNo, parcelId),
    deps.unlocked(coNo, parcelId),
  ])

  // 181a: a parcel that does not resolve is never offered, paid or not. The state names the cause.
  if (preview && preview.parcelState && preview.parcelState !== 'present') {
    return { kind: 'absent', state: preview.parcelState, countyName: preview.countyName ?? null }
  }

  if (!unlocked) {
    if (!preview) return { kind: 'notfound' }
    return { kind: 'paywall', address: preview.address ?? '', frameLabel: preview.frameLabel ?? null }
  }

  // The transport throws on an error body - a statement timeout arrives as HTTP 500 / 57014 - so the catch
  // is what reaches the error state. A null without a throw is kept for completeness; in practice the
  // transport throws first.
  let report = null
  try {
    report = await deps.report(coNo, parcelId)
  } catch (err) {
    if (deps.onBuildError) deps.onBuildError(err)
    return { kind: 'error' }
  }
  if (!report) return { kind: 'error' }
  return { kind: 'report', report }
}

// The checkout's own gate (181a). The page is not the only way to reach /api/checkout, so the route asks the
// same question independently. Returns null when the parcel may be sold, else the refusal to send (404).
export function checkoutRefusal(preview, coNo, parcelId) {
  if (preview && preview.parcelState === 'present') return null
  const state = preview?.parcelState ?? 'none_recorded'
  const county = preview?.countyName ? `${preview.countyName} County` : `county ${coNo}`
  return {
    status: 404,
    body: {
      error: state === 'not_available' ? `We don't hold records for ${county}.` : `Parcel ${parcelId} is not in the ${county} parcel roll we hold.`,
      parcelState: state,
    },
  }
}
