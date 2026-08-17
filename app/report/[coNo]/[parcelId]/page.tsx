import { notFound } from 'next/navigation'
import Link from 'next/link'
import { pirSocket } from '@/lib/sockets/pir'
import { purchaseSocket } from '@/lib/sockets/purchase'
import ReportPaywall from '@/app/components/ReportPaywall'
import ReportError from '@/app/components/ReportError'
import { CompassBadgeGrid, type CompassBadgeData } from '@/app/components/AmenityCompass'
import PropertyReportMap from '@/app/components/PropertyReportMap'
import PrintButton from '@/app/components/PrintButton'
import { FLOOD_STYLE, ZONING_STYLE } from '@/lib/pir-colors'
import type { PirReport, PirEconOverlay } from '@/types/pir'
import { formatDistance } from '@/lib/units'
import { taxDeedView, disclosuresView, selectLead } from '@/lib/report-coverage.mjs'
import { renderMarineBlock, renderFloodBlock, renderFact, renderContaminationFacilities, renderValuesBlock, renderCensusBlock, renderOwnersBlock, renderTransactionsBlock, renderPermitsBlock, renderZoningBlock, renderSinkholeBlock, renderRestrictionsBlock, renderBrownfieldBlock } from '@/lib/fact-render.mjs'

// ── formatting helpers ──────────────────────────────────────────────────────────
const usd = (n?: number | null) => n == null ? '—' : `$${Math.round(n).toLocaleString('en-US')}`
const num = (n?: number | null) => n == null ? '—' : n.toLocaleString('en-US')
const mi = formatDistance
const titleCase = (s?: string | null) => !s ? '' : s.replace(/\b\w/g, c => c.toUpperCase())
const fmtDate = (d?: string | null) => {
  if (!d) return '—'
  const dt = new Date(d)
  return isNaN(dt.getTime()) ? d : dt.toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' })
}
const today = () => new Date().toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' })

// Per-request: the purchase gate must reflect a just-completed payment immediately,
// and the payload is built on view so it always shows the current data vintage.
export const dynamic = 'force-dynamic'

export async function generateMetadata({ params }: { params: Promise<{ coNo: string; parcelId: string }> }) {
  const { parcelId } = await params
  return { title: `Property Intelligence Report · Parcel ${parcelId}`, robots: { index: false } }
}

// ── small presentational pieces (server components) ─────────────────────────────
function Fact({ l, v }: { l: string; v: React.ReactNode }) {
  return <div className="pir-fact"><div className="l">{l}</div><div className="v">{v}</div></div>
}
const MARINE_PRED_LABEL: Record<string, string> = {
  built_year: 'Built', area_sqft: 'Footprint', grade: 'Grade',
  replacement_cost_new: 'Replacement cost', depreciated_value: 'Depreciated value',
  pct_depreciated: 'Depreciation', service_life_vs_age: 'Service life',
}
function TierBadge({ tier }: { tier?: string }) {
  const m: Record<string, { t: string; c: string }> = {
    county_assessor_record: { t: 'county', c: 'var(--color-sage)' },
    government_derived: { t: 'state roll', c: 'var(--color-sage)' },
    derived: { t: 'derived', c: 'var(--color-sage)' },
    analysis_inference: { t: 'our estimate', c: 'var(--color-terracotta, #b5502f)' },
  }
  const b = tier ? m[tier] : null
  if (!b) return null
  return <span style={{ fontSize: 9, textTransform: 'uppercase', letterSpacing: '0.06em', color: b.c, border: `1px solid ${b.c}`, borderRadius: 4, padding: '0 4px', marginLeft: 6, verticalAlign: 'middle' }}>{b.t}</span>
}
function Tile({ l, v, sub }: { l: string; v: React.ReactNode; sub?: React.ReactNode }) {
  return (
    <div className="pir-tile">
      <div className="l" style={{ fontSize: 10.5, color: 'var(--color-sage)', textTransform: 'uppercase', letterSpacing: '0.04em' }}>{l}</div>
      <div className="v">{v}</div>
      {sub && <div style={{ fontSize: 11, color: 'var(--color-sage)', marginTop: 2 }}>{sub}</div>}
    </div>
  )
}
function Section({ title, children, note }: { title: string; children: React.ReactNode; note?: React.ReactNode }) {
  return (
    <div className="pir-section">
      <h3>{title}</h3>
      {children}
      {note && <div className="pir-note">{note}</div>}
    </div>
  )
}
// A continuous, numbered section group — replaces the five fixed print "sheets" (fork 1). Sections determine
// the page breaks (CSS page-break-inside: avoid), not the reverse.
function Grp({ n, title, children }: { n: number; title: string; children: React.ReactNode }) {
  return (
    <section className="pir-group">
      <h2 className="pir-grouphead"><span className="pir-grpn">{n}</span>{title}</h2>
      {children}
    </section>
  )
}

function Legend({ entries }: { entries: Array<{ color: string; label: string }> }) {
  return (
    <div>
      <div style={{ fontSize: 10.5, color: 'var(--color-sage)', textTransform: 'uppercase', letterSpacing: '0.04em', marginBottom: 6 }}>Legend</div>
      {entries.map(e => (
        <div key={e.label} style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 4 }}>
          <span style={{ width: 14, height: 14, borderRadius: 3, background: e.color, border: '1px solid rgba(0,0,0,0.15)', flexShrink: 0 }} />
          <span style={{ fontSize: 11.5, color: 'var(--color-ink)' }}>{e.label}</span>
        </div>
      ))}
    </div>
  )
}

function overlayLine(o: PirEconOverlay | null, insideLabel: string): React.ReactNode {
  // Item 112: a coverage gap is NOT a negative finding. Never say "None mapped" when the
  // truth is we don't hold that overlay for this county — that reads as "not in a zone".
  if (!o || o.field_status === 'not_available' || o.field_status === 'not_established') {
    return <span style={{ color: 'var(--color-sage)' }}>Not evaluated{o?.who_can_answer ? <> — ask {o.who_can_answer}</> : null}</span>
  }
  if (o.field_status === 'present' || o.inside) {
    const name = o.name ?? o.tract ?? o.zone
    return `${insideLabel}${name ? ` (${name})` : ''}`
  }
  // none_intersecting — a real negative in a covered county
  const name = o.name ?? o.tract ?? o.zone
  return o.distanceM != null
    ? `Not within — nearest ${mi(o.distanceM)}${name ? ` (${name})` : ''}`
    : 'Not within any we hold for this county'
}

// "Covered" = we could actually answer: parcel is in a zone, or the county is covered and it
// genuinely isn't (a real negative). not_available / not_established are coverage gaps -> §7.
function econCovered(o: PirEconOverlay | null | undefined): boolean {
  return o?.field_status === 'present' || o?.field_status === 'none_intersecting'
}

function riskChip(text: string, good: boolean) {
  const c = good ? { bg: '#e4efe4', fg: '#3f5a3f' } : { bg: '#fae1cb', fg: '#8a4a17' }
  return <span style={{ background: c.bg, color: c.fg, padding: '2px 9px', borderRadius: 20, fontSize: 11.5, fontWeight: 700 }}>{text}</span>
}

// THE LEAD — frame + the single most consequential regulatory fact, ranked by what a buyer must act on:
// contamination containment → SFHA flood mandate → GWCA well prohibition → institutional control → lead-paint
// → historic district. First present wins; causally-linked facts combine (contamination + GWCA), ceiling of
// TWO clauses. When none are present it SAYS SO — section 7 immediately qualifies what we could not check, so
// silence never reads as clearance. Nothing here is originated; every clause traces to a rendered fact.
function buildLead(r: PirReport): { identity: string; regulatory: string; none: boolean } {
  const idf: any = (r as any).identityFrame ?? null
  const p = r.property
  const owner = idf?.signals?.owner ? titleCase(String(idf.signals.owner)) : (p.ownerName ? titleCase(p.ownerName) : null)
  const frameLabel = idf?.frame_label ? String(idf.frame_label).toLowerCase() : null
  const identity = [frameLabel ? `This is ${/^[aeiou]/i.test(frameLabel) ? 'an' : 'a'} ${frameLabel}` : 'This property',
    owner ? `owned by ${owner}` : null].filter(Boolean).join(', ')

  const fb = renderFloodBlock(r.floodBlock)
  const rb = renderRestrictionsBlock(r.landRestrictions)
  const restr = rb.established ? rb.items : []
  const gwca = restr.find((it: any) => /well|62-524|groundwater/i.test(`${it.value ?? ''} ${it.label ?? ''}`))
  const ic = restr.find((it: any) => /institutional control/i.test(it.label ?? ''))
  // Ranking lives in report-coverage.mjs (selectLead) so it is unit-tested in plain node.
  const sel = selectLead({
    contamOn: idf?.signals?.contamination_on_parcel === true,
    gwca: !!gwca,
    ic: !!ic,
    inSfha: fb.determination?.inSfha === true,
    sfhaZone: fb.determination?.zone ?? null,
    leadPaint: !!(p.yearBuilt && p.yearBuilt < 1978),
    yearBuilt: p.yearBuilt,
    historic: idf?.signals?.historic_on_parcel === true,
  })
  return { identity, regulatory: sel.regulatory, none: sel.none }
}

// =============================================================================
export default async function ReportPage({ params }: { params: Promise<{ coNo: string; parcelId: string }> }) {
  const { coNo, parcelId } = await params
  const co = Number(coNo)
  if (isNaN(co) || !parcelId) notFound()

  const [r, unlocked] = await Promise.all([
    pirSocket.forParcel(co, parcelId),
    purchaseSocket.isUnlocked(co, parcelId),
  ])

  // FAILURE CASE: if the buyer paid but the report failed to build, never show a blank
  // page or a 404 — their purchase is safe in the ledger, and generation is retryable.
  if (!r) {
    if (unlocked) return <ReportError />
    notFound()
  }

  // GATE: not purchased → preview + buy at this same URL. Buying unlocks the full report
  // here (per-parcel), so a shared link works and the recipient buys their own parcel.
  if (!unlocked) {
    return (
      <ReportPaywall
        coNo={co}
        parcelId={parcelId}
        address={titleCase(r.property.address ?? '')}
        identity={buildLead(r).identity}
      />
    )
  }

  const p = r.property, v = r.values, tax = r.tax
  const idf: any = (r as any).identityFrame ?? null
  const lead = buildLead(r)
  const ob = renderOwnersBlock(r.ownerFacts)
  const tb = renderTransactionsBlock(r.transactionFacts)
  const pb = renderPermitsBlock(r.permitFacts)
  const fb = renderFloodBlock(r.floodBlock)
  const rb = renderRestrictionsBlock(r.landRestrictions)
  const dv = disclosuresView(r.disclosures)
  const tv = taxDeedView(r.taxDeedStatus)
  // Brownfield is a CONTAMINATION fact, not an incentive (ruling 74 C2). Split it: the designated
  // area is §3 (on this parcel), the nearby FDEP sites + distances are §4 — never under an incentive heading.
  const bf = renderBrownfieldBlock(r.economic.brownfield)
  // Gopher-tortoise habitat: containment (inside/covered) is §3; the nearest-habitat DISTANCE is §4 (C1).
  const gopherNearbyMi = (r.land.gopherTortoiseCoverage !== 'not_available'
    && r.land.gopherTortoiseInside !== true && r.land.gopherTortoiseNearestM != null)
    ? r.land.gopherTortoiseNearestM : null

  // Contamination SPLIT (rule: nothing above §4 carries a distance): on-parcel / active-remediation facilities
  // are §3 (a fact about this ground); everything else + the area-context count is §4 (proximity).
  const cf = renderContaminationFacilities(r.contaminationFacilities)
  const cfOn = cf.facilities.filter((f: any) => f.onParcel || /ACTIVE/i.test(f.remediation || ''))
  const cfNear = cf.facilities.filter((f: any) => !(f.onParcel || /ACTIVE/i.test(f.remediation || '')))

  // Marine SPLIT: the improvements are §3 (on-parcel); the permit-vs-assessor cross-examination is §6 (open q).
  const mbSt = r.marineBlock?.field_status
  const marine = (r.marineBlock && mbSt !== 'not_available' && mbSt !== 'none_recorded') ? renderMarineBlock(r.marineBlock) : null

  const amenityBadges: CompassBadgeData[] = r.amenities.map(a => ({
    icon: a.iconName ?? '📍', label: a.displayName, sublabel: a.name, distanceM: a.distanceM, bearingDegrees: a.bearingDegrees,
  }))
  const waterBadges: CompassBadgeData[] = [
    ...r.water.features.map(f => ({
      icon: f.ftype === 'SwampMarsh' ? 'wetland' : f.ftype === 'LakePond' ? 'lake' : 'water',
      label: f.name ?? (f.ftype === 'SwampMarsh' ? 'Wetland' : f.ftype === 'LakePond' ? 'Lake / pond' : 'Water'),
      sublabel: f.ftype, distanceM: f.distanceM, bearingDegrees: f.bearingDegrees, tone: 'sage' as const,
    })),
    ...r.water.boatRamps.map(b => ({
      icon: 'ramp', label: 'Boat ramp', sublabel: b.name ?? b.waterbody, distanceM: b.distanceM, bearingDegrees: b.bearingDegrees,
    })),
  ]
  const schoolBadges: CompassBadgeData[] = r.schools
    .filter(s => s.distanceM != null)
    .map(s => ({ icon: 'school', label: s.level, sublabel: s.name, distanceM: s.distanceM!, bearingDegrees: s.bearingDegrees ?? 0 }))

  const floodLegend = ['VE', 'AE', 'AH', 'A', 'X'].map(z => FLOOD_STYLE[z])
  const zoningLegend = Object.values(ZONING_STYLE)

  // completeness — reframed in §7 as a checklist of who-answers, not an apology
  const completeness: Array<[string, boolean, string]> = [
    ['Property basics', !!p.yearBuilt, ''],
    ['Assessed & market values', (v.valuesFacts as any)?.just_value?.field_status === 'present', ''],
    ['Tax & exemptions', tax.taxableValueCounty != null, ''],
    ['Nearby amenities', r.amenities.length > 0, ''],
    // Item 112: keyed on schoolsCoverage, not schools.length — a [] off-Volusia is a coverage gap
    // (we hold no assignment layer), NOT "no assigned schools".
    ['Assigned schools', r.schoolsCoverage?.field_status === 'assigned', r.schoolsCoverage?.who_can_answer ?? 'the county school district'],
    ['Protected species / habitat', r.land.gopherTortoiseCoverage === 'covered', 'the Florida Fish & Wildlife Conservation Commission'],
    ['Permit history', (pb.count ?? 0) > 0, "the county / municipal building department"],
    ['Ownership / sale history', (tb.count ?? 0) > 0, 'the county Clerk of Court'],
    ['Elevation & land', r.groundElevation != null, ''],
    ['Water & flood', fb.determination?.established === true, 'FEMA (msc.fema.gov)'],
    ['Marine improvements', (marine?.improvements?.length ?? 0) > 0, 'the county Property Appraiser'],
    ['Tax-deed status', r.taxDeedStatus.on_lands_available_list != null, 'the county Clerk'],
    ['Zoning & future land use', r.zoningFacts?.field_status === 'present', 'the local planning department'],
    // Item 112: one row per overlay. "Covered" = we could actually answer (present OR a real
    // none_intersecting negative). not_available/not_established falls to §7 with who-answers.
    ['Opportunity Zone', econCovered(r.economic?.opportunityZone), r.economic?.opportunityZone?.who_can_answer ?? 'the U.S. Treasury CDFI Fund'],
    ['HUBZone', econCovered(r.economic?.hubZone), r.economic?.hubZone?.who_can_answer ?? 'the U.S. Small Business Administration'],
    ['Enterprise Zone', econCovered(r.economic?.enterpriseZone), r.economic?.enterpriseZone?.who_can_answer ?? 'Florida Commerce'],
    ['Community Redevelopment Area', econCovered(r.economic?.cra), r.economic?.cra?.who_can_answer ?? 'the local Community Redevelopment Agency'],
    ['Census / demographics', r.censusFacts?.field_status === 'present', 'the U.S. Census Bureau (ACS)'],
    ['Crime / safety statistics', false, 'the county Sheriff / FDLE'],
    ['Neighborhood news (live)', false, 'live web search'],
  ]
  const have = completeness.filter(c => c[1]).length
  const havePct = Math.round((have / completeness.length) * 100)
  const gaps = completeness.filter(c => !c[1])

  return (
    <div className="pir-doc">
      <style>{CSS}</style>

      <div className="pir-toolbar no-print">
        <Link href="/" style={{ color: 'var(--color-bronze)', textDecoration: 'none', fontSize: 13 }}>← Department of Property</Link>
        <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
          <span style={{ fontSize: 12, color: 'var(--color-sage)' }}>{have}/{completeness.length} sections ({havePct}%)</span>
          <PrintButton />
        </div>
      </div>

      <article className="pir-report">
        <header className="pir-head">
          <div>
            <div className="addr">{titleCase(r.property.address ?? '—')}</div>
            <div className="ref">{[titleCase(r.property.city), 'FL', r.property.zip].filter(Boolean).join(', ')}</div>
          </div>
          <div style={{ textAlign: 'right' }}>
            <div className="ref">Parcel {r.meta.parcelId} · {r.meta.countyName} County</div>
            <div className="ref">Property Intelligence Report · {today()}</div>
          </div>
        </header>

        <div className="pir-body">
          {/* THE LEAD — frame + the single most consequential regulatory fact (contamination-first). */}
          <div className="pir-lead">
            <div className="pir-lead-id">{lead.identity}.</div>
            <div className="pir-lead-reg">
              {lead.none
                ? 'No federal or state regulatory constraint is recorded on this parcel in the layers we hold. That is not a clearance — see section 7 for exactly what was and was not checked.'
                : `It is ${lead.regulatory}.`}
            </div>
          </div>

          {/* ═══ 1 — WHAT THIS IS ═══ */}
          <Grp n={1} title="What this is">
            {/* Source limitations moved to §7 (ruling 74 C6) — a source-limit is not an identity fact
                and must not be the first thing a reader meets. */}
            <Section title="Property">
              <div className="pir-grid">
                <Fact l={ob.established && (ob.ownerCount?.value ?? 0) > 1 ? `Owners of record (${ob.ownerCount!.value})` : 'Owner of record'}
                  v={ob.established
                    ? <>{ob.owners.map((o: any) => titleCase(o.name)).filter(Boolean).join('; ')} {p.ownerOccupied ? riskChip('Owner-occupied', true) : null}</>
                    : <span style={{ color: 'var(--color-sage)' }}>{ob.coverageNote ?? 'Not established'}</span>} />
                <Fact l="Use" v={titleCase(p.propertyType?.replace('_', ' ')) || '—'} />
                <Fact l="Year built" v={p.yearBuilt ? `${p.yearBuilt}${p.effectiveYearBuilt ? ` (eff. ${p.effectiveYearBuilt})` : ''}` : '—'} />
                <Fact l="Living area" v={p.livingSqft ? `${num(p.livingSqft)} sq ft` : '—'} />
                <Fact l="Total under roof" v={p.totalSqft ? `${num(p.totalSqft)} sq ft` : '—'} />
                <Fact l="Beds / baths" v={p.bedrooms != null ? `${p.bedrooms} bd · ${p.bathrooms} ba` : '—'} />
                <Fact l="Stories / buildings" v={`${p.stories ?? '—'} / ${p.numBuildings ?? '—'}`} />
                <Fact l="Lot (GIS-calc)" v={p.gisAcres != null ? `${p.gisAcres.toFixed(2)} ac` : '—'} />
                <Fact l="Subdivision" v={titleCase(p.subdivision) || '—'} />
                <Fact l="Neighborhood" v={titleCase(p.neighborhood) || '—'} />
                <Fact l="Jurisdiction" v={`${p.incorporation ?? ''} ${p.jurisdiction ?? ''}`.trim() || '—'} />
                <Fact l="Sec-Twp-Rng" v={[p.section, p.township, p.range].filter(Boolean).join('-') || '—'} />
              </div>
              <div className="pir-note">Legal: {p.legal ?? '—'}.{p.livingAreaSource ? ` Living area from ${p.livingAreaSource}.` : ''}</div>
            </Section>

            {/* RULING 266 — three render requirements, each guarding a different failure:
                1. owner_count is its OWN fact. 844 must read as 844, never as a truncated list.
                2. the TENANCY FORM renders beside the owners ALWAYS — a creditor of one
                   tenancy-by-the-entirety spouse generally cannot reach the property, while any
                   one of 844 tenants in common can force a partition sale. Different right.
                3. shareCheck FALSE gets its own VISIBLE line, never a footnote; NULL renders
                   NOTHING, because a null that renders as anything is the Zone D bug. */}
            {ob.established ? (
              <Section title="Ownership"
                note={<>{ob.ownerCount?.note}
                  {ob.tenancy?.mixed
                    ? ` More than one tenancy form is recorded on this parcel (${ob.tenancy.formsRecorded}); which whole the shares divide cannot be determined.`
                    : ob.tenancy?.form ? ` Tenancy on file: ${ob.tenancy.form}.` : ''}</>}>
                {ob.shareCheck?.failed ? (
                  <div style={{ border: '1px solid var(--color-terracotta, #b5502f)', borderLeft: '3px solid var(--color-terracotta, #b5502f)', borderRadius: 6, padding: '10px 13px', marginBottom: 10 }}>
                    <div style={{ fontSize: 14, fontWeight: 600 }}>Recorded ownership shares do not account for the whole interest</div>
                    <div style={{ fontSize: 12.5, color: 'var(--color-sage)', marginTop: 4 }}>{ob.shareCheck.note}</div>
                  </div>
                ) : null}
                <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
                  {ob.owners.map((o: any, i: number) => (
                    <div key={o.ownseq ?? i} style={{ border: '1px solid var(--color-line, #d9d3c6)', borderRadius: 6, padding: '9px 12px' }}>
                      <div style={{ fontSize: 14, fontWeight: 600 }}>
                        {titleCase(o.name)}
                        {o.pctOwn != null ? <span style={{ fontWeight: 400, color: 'var(--color-sage)' }}> — {o.pctOwn}% as recorded</span> : null}
                        {o.ownershipType ? <span style={{ fontWeight: 400, color: 'var(--color-sage)' }}> · {o.ownershipType}</span> : null}
                        <TierBadge tier={o.provenance?.tier} />
                      </div>
                      {o.nameDetail ? <div style={{ fontSize: 12.5, color: 'var(--color-sage)', marginTop: 2 }}>{titleCase(o.nameDetail)}</div> : null}
                      <div style={{ fontSize: 11.5, color: 'var(--color-sage)', marginTop: 3 }}>{o.provenance?.as_of}</div>
                    </div>
                  ))}
                </div>
                {ob.tenancy?.note ? <div className="pir-note" style={{ marginTop: 8 }}>{ob.tenancy.note}</div> : null}
              </Section>
            ) : (
              <Section title="Ownership" note="Owner of record from the county/state record.">
                <div className="pir-note">{ob.coverageNote}</div>
              </Section>
            )}

            <Section title="Parcel boundary"
              note="Subject parcel (gold) and neighbouring parcels within ~150 ft, drawn from real county parcel geometry.">
              <PropertyReportMap coNo={co} parcelId={parcelId} layer="parcels" height={300} />
            </Section>
          </Grp>

          {/* ═══ 2 — WHAT LEGALLY BINDS THIS PROPERTY (regulatory only; no distances) ═══ */}
          <Grp n={2} title="What legally binds this property">
            {/* Flood: THE finding is the SFHA determination (federal_regulatory). A coverage gap renders
                "not established — about our data", NEVER "not in a flood zone" (the St Pete failure). */}
            <Section title="Flood determination" note="The FEMA determination is the finding; zone and base flood elevation are supporting detail. This is a containment fact about the parcel, not a distance.">
              <div className="pir-maprow">
                <PropertyReportMap coNo={co} parcelId={parcelId} layer="flood" />
                <div>
                  <Legend entries={floodLegend} />
                  <div style={{ marginTop: 12, display: 'flex', flexDirection: 'column', gap: 8 }}>
                    {/* Undetermined must NOT paint calm. A two-way colour test renders Zone D in the
                        same reassuring sage as a genuine clearance — the false clearance surviving as
                        colour after the words were fixed. Ruling 251. */}
                    <div style={{ border: '1px solid var(--color-line, #d9d3c6)', borderLeft: `3px solid ${fb.determination?.inSfha ? 'var(--color-terracotta, #b5502f)' : fb.determination?.undetermined ? 'var(--color-ochre, #c08a2e)' : 'var(--color-sage)'}`, borderRadius: 6, padding: '10px 13px' }}>
                      <div style={{ fontSize: 14, fontWeight: 600 }}>{fb.determination?.label}<TierBadge tier={fb.determination?.tier} /></div>
                      {fb.determination?.headline ? <div style={{ fontSize: 12.5, color: 'var(--color-sage)', marginTop: 4 }}>{fb.determination.headline}</div> : null}
                    </div>
                    {fb.bfe ? <Fact l="Base flood elevation" v={fb.bfe.label} /> : null}
                    {/* in_sfha === null is UNDETERMINED (Zone D — FEMA performed no analysis), NOT a
                        clearance. A truthy test renders null exactly like false, which is the false
                        clearance this fix exists to remove. Three states, three renderings. Ruling 251. */}
                    {fb.zones.length ? <Fact l="Flood zones (share of parcel)" v={fb.zones.map((z: any) => `${z.zone}${z.in_sfha === true ? ' · SFHA' : z.in_sfha == null ? ' · undetermined, not a clearance' : ''}${z.pct_of_parcel != null ? ` ${z.pct_of_parcel}%` : ''}`).join('   ·   ')} /> : null}
                    {fb.elevationComparison?.withheld ? <p className="pir-note" style={{ marginTop: 2 }}>Elevation vs. BFE — {fb.elevationComparison.reason}</p> : null}
                  </div>
                </div>
              </div>
            </Section>

            {/* Recorded land-use restrictions (get_parcel_restrictions): GWCA well prohibition, institutional
                controls, regulated on-parcel wells. Renders EVEN WHEN EMPTY — the honest "not a clearance"
                absence statement is itself the finding. A containment test, not a distance. */}
            <Section title="Recorded land-use restrictions" note="State/federal constraints recorded against this location — groundwater-contamination areas, institutional controls, regulated on-parcel wells.">
              {rb.established ? rb.items.map((it: any, i: number) => (
                <div key={i} style={{ marginBottom: 10, borderLeft: '3px solid var(--color-terracotta, #b5502f)', paddingLeft: 12 }}>
                  <div style={{ fontWeight: 600 }}>{it.label} {riskChip(it.relation === 'contains' ? 'On this parcel' : 'Overlapping', false)} <TierBadge tier="government_derived" /></div>
                  <div className="pir-note" style={{ fontStyle: 'normal' }}>
                    {it.value}{it.authority ? ` — ${it.authority}` : ''}{it.asOf ? ` (${it.asOf})` : ''}.{it.caveat ? <> {it.caveat}</> : null}
                  </div>
                </div>
              )) : (
                <div className="pir-note">{rb.absenceNote}</div>
              )}
            </Section>

            <Section title="Disclosure & designation duties">
              <div className="pir-grid">
                <Fact l="Lead-paint disclosure" v={
                  p.yearBuilt == null
                    ? <span style={{ color: 'var(--color-sage)' }}>Year built not recorded — the pre-1978 disclosure duty cannot be determined here; ask the seller</span>
                    : p.yearBuilt < 1978
                      ? riskChip(`Pre-1978 (${p.yearBuilt}) — federal lead-paint disclosure duty applies on sale or lease`, false)
                      : `Built ${p.yearBuilt} — post-1978, no federal lead-paint disclosure duty`} />
                {idf?.signals?.historic_on_parcel === true
                  ? <Fact l="Historic designation" v={idf.signals.historic_relation === 'district_membership'
                      ? riskChip('Within a listed National Register historic district — an indication to confirm against the NPS record (boundaries are nomination-derived, not survey); it constrains alteration/demolition and gates rehabilitation tax credits', false)
                      : riskChip('National Register resource on this parcel — commonly triggers local review; affects historic tax-credit eligibility', false)} />
                  : null}
              </div>
              <div className="pir-note" style={{ marginTop: 10 }}>
                <strong>Universal (every Florida parcel):</strong> Florida ss. 872.02 / 872.05 protect unmarked human burials statewide; the statute applies to all land, so its applicability here is a standing rule, not a finding about this property.
              </div>
            </Section>

            {/* Construction-defect repose window (get_parcel_repose_window): computed from act_yr_blt + FL
                s.95.11(3)(b) 7-year repose. Rights-first, and it states ONLY whether the statutory WINDOW has
                or has not closed — NEVER that a claim exists. "Approximately" is load-bearing (act_yr_blt is the
                assessor year, not the CO date). Builder AS RECORDED, related-by-name. */}
            {(() => {
              const rw: any = (r as any).reposeWindow
              if (rw?.field_status !== 'present') return null
              const open = rw.window_status === 'open'
              return (
                <Section title="Construction-defect window (Florida)">
                  <div style={{ border: '1px solid var(--color-line, #d9d3c6)', borderLeft: `3px solid ${open ? 'var(--color-bronze, #9a6a3a)' : 'var(--color-line, #d9d3c6)'}`, borderRadius: 6, padding: '11px 14px' }}>
                    <div style={{ fontSize: 15, fontWeight: 600 }}>{rw.headline}</div>
                    <div style={{ fontSize: 13, marginTop: 6, color: 'var(--color-ink)' }}>{rw.body}</div>
                    {rw.presuit ? <div className="pir-note" style={{ fontStyle: 'normal', marginTop: 6 }}>{rw.presuit}</div> : null}
                    {rw.builder_note ? <div className="pir-note" style={{ marginTop: 4 }}>{rw.builder_note}</div> : null}
                    <div className="pir-note" style={{ marginTop: 6 }}>{rw.note}</div>
                    <div className="pir-note" style={{ marginTop: 4 }}>{rw.who_can_answer ? <>Who can answer: {rw.who_can_answer}. </> : null}{rw.repose_cite ? <>Authority: {rw.repose_cite}.</> : null}</div>
                    {/* Conversion path: the deadline finding is the moment a reader wants to know what it means
                        for them. get_parcel_repose_window is FL-gated, so "present" ⇒ Florida ⇒ always among the
                        verified 21 (never a 404). A future multi-state PIR should derive this slug from the parcel
                        and fall back to /rights (the hub, whose spread stands on its own) for any unverified state. */}
                    <div style={{ marginTop: 9 }}>
                      <Link href="/rights/florida" style={{ fontSize: 12.5, fontWeight: 600, color: 'var(--color-bronze, #9a6a3a)' }}>
                        What this means for you — your rights as a Florida homeowner →
                      </Link>
                    </div>
                  </div>
                </Section>
              )
            })()}
          </Grp>

          {/* ═══ 3 — WHAT'S ON OR UNDER THIS PARCEL (contains relation only; no distances) ═══ */}
          <Grp n={3} title="What's on or under this parcel">
            {cfOn.length ? (
              <Section title="Contamination — on this parcel" note="On-parcel and active-remediation facilities, named individually. Nearby sites are area context in section 4.">
                {cfOn.map((f: any, i: number) => (
                  <div key={i} style={{ marginBottom: 10, borderLeft: '3px solid var(--color-terracotta, #b5502f)', paddingLeft: 12 }}>
                    <div style={{ fontWeight: 600 }}>{titleCase(f.name)} {f.onParcel ? riskChip('On this parcel', false) : null} {/ACTIVE/i.test(f.remediation || '') ? riskChip('Active remediation', false) : null}</div>
                    <div className="pir-note" style={{ fontStyle: 'normal' }}>
                      {[f.type, f.status, f.where, f.remediation].filter(Boolean).join(' · ')}. {f.cleanup}.
                      {f.documentsUrl ? <> <a href={f.documentsUrl} target="_blank" rel="noopener noreferrer">FDEP file</a></> : null}
                      {f.watchUrl ? <> · <a href={f.watchUrl} target="_blank" rel="noopener noreferrer">monitor</a></> : null}
                    </div>
                  </div>
                ))}
              </Section>
            ) : null}

            {/* Brownfield DESIGNATION on this parcel (ruling 74 C2) — a contamination fact, moved out of the
                §5 "Economic zones" grid. The nearby FDEP sites + their distances render in §4. */}
            {bf.established && bf.insideArea ? (
              <Section title="Brownfield — on this parcel" note="An FDEP-designated brownfield area covers this parcel. A brownfield is a contamination-related designation that carries a cleanup and redevelopment framework — surfaced here as a fact about the ground, not an incentive.">
                <div style={{ borderLeft: '3px solid var(--color-terracotta, #b5502f)', paddingLeft: 12 }}>
                  <div style={{ fontWeight: 600 }}>Within the {titleCase(bf.insideArea.name)} brownfield area {riskChip('Designated brownfield', false)}<TierBadge tier="government_derived" /></div>
                  <div className="pir-note" style={{ fontStyle: 'normal' }}>
                    {[bf.insideArea.acreageAc ? `${bf.insideArea.acreageAc.toLocaleString()} ac` : null, bf.insideArea.resolutionNumber ? `resolution ${bf.insideArea.resolutionNumber}` : null, bf.insideArea.resolutionDate].filter(Boolean).join(' · ')}.{bf.note ? <> {bf.note}</> : null}
                  </div>
                </div>
              </Section>
            ) : null}

            {marine ? (
              <Section title="Marine improvements" note="Every figure is a sourced assessor fact. The permit-vs-assessor cross-examination is in section 6.">
                {marine.improvements.map((imp: any, i: number) => (
                  <div key={i} style={{ marginBottom: 14 }}>
                    <div style={{ fontSize: 13, fontWeight: 600, marginBottom: 6 }}>{titleCase(imp.improvement)} · built {imp.built}</div>
                    <div className="pir-grid">
                      {Object.entries(imp.rendered).filter(([, f]: [string, any]) => f.hasValue).map(([pred, f]: [string, any]) => (
                        <Fact key={pred} l={MARINE_PRED_LABEL[pred] ?? pred} v={<>{f.label} <TierBadge tier={f.provenance?.tier} /></>} />
                      ))}
                    </div>
                  </div>
                ))}
                {marine.material ? <p className="pir-note" style={{ marginTop: 8 }}>{marine.material.text}</p> : null}
              </Section>
            ) : mbSt === 'not_available' ? null : (
              <Section title="Marine improvements" note="The county appraiser has assessed no marine improvement on this parcel.">
                <div className="pir-note">Unassessed, unpermitted or newly built structures may still exist.</div>
              </Section>
            )}

            <Section title="Land"
              note="Ground elevation is a USGS-derived property fact; the gopher-tortoise overlay is a mapped spatial layer. Soil type & drainage is not sourced and is omitted rather than guessed.">
              <div className="pir-grid">
                <Fact l="Ground elevation" v={(() => {
                  const ge: any = r.groundElevation || {}
                  const rf = renderFact(r.groundElevation)
                  // withheld / not_recorded -> the deterministic sentence, unchanged. present -> value in feet
                  // (nearest foot) with source+datum, then the two-clause caveat and the surveyor-certificate
                  // routing, EVERY render. No ground-vs-BFE difference is ever computed (ruling 212).
                  if (ge.field_status !== 'present') {
                    return <span style={{ color: 'var(--color-sage)' }}>{rf.label}</span>
                  }
                  return (
                    <span style={{ color: 'var(--color-sage)' }}>
                      <strong>{rf.label}</strong>{ge.vertical_datum ? ` (${ge.source ?? 'USGS EPQS'}, ${ge.vertical_datum})` : ''}
                      {ge.caveat ? <span className="pir-note" style={{ display: 'block', marginTop: 4 }}>{ge.caveat}</span> : null}
                      {ge.note ? <span className="pir-note" style={{ display: 'block' }}>{ge.note}</span> : null}
                    </span>
                  )
                })()} />
                <Fact l="Sewer / septic" v={<span style={{ color: 'var(--color-sage)' }}>Not evaluated — no parcel-level sewer/septic determination in the record</span>} />
                {/* Containment only — the nearest-habitat DISTANCE lives in §4 (hard rule: no distance above §4). */}
                <Fact l="Protected species" v={
                  r.land.gopherTortoiseCoverage === 'not_available'
                    ? <span style={{ color: 'var(--color-sage)' }}>Not evaluated — habitat overlay held for Volusia only; ask the Florida Fish and Wildlife Conservation Commission</span>
                    : r.land.gopherTortoiseInside ? riskChip('Within gopher tortoise habitat overlay', false)
                    : gopherNearbyMi != null ? <span style={{ color: 'var(--color-sage)' }}>Not on this parcel — nearest mapped habitat is in section 4</span>
                    : 'None mapped on or near this parcel'} />
              </div>
            </Section>

            {/* Wetland (get_parcel_wetland): CONTAINMENT, Deepwater + open-water Lake EXCLUDED by category
                (the sentinel catch). The TYPE is the finding — different types carry different permitting/
                development consequences. Both regimes cited in parallel. The regional-inventory-vs-delineation
                gap renders in §7 (who answers). Renders only when a real wetland type is present. */}
            {(() => {
              const wl: any = (r as any).wetland
              if (wl?.field_status !== 'present') return null
              const types: string[] = Array.isArray(wl.wetland_types) ? wl.wetland_types : []
              return (
                <Section title="Wetland (NWI)" note="Mapped in the USFWS National Wetlands Inventory. Deepwater and open-water lakes are excluded — these are wetland categories. This is a regional inventory, not a jurisdictional delineation (section 7).">
                  <div style={{ borderLeft: '3px solid var(--color-terracotta, #b5502f)', paddingLeft: 12 }}>
                    <div style={{ fontWeight: 600 }}>{riskChip('Mapped wetland on this parcel', false)} {types.map(t => titleCase(t)).join(' · ')}<TierBadge tier="government_derived" /></div>
                    <div className="pir-note" style={{ fontStyle: 'normal' }}>
                      The wetland <strong>type</strong> drives permitting and development — {types.join(', ')} carry different Environmental Resource Permit and mitigation consequences. Regulated under BOTH regimes in parallel: <strong>Florida s.373 Part IV</strong> (state Environmental Resource Permit — FDEP / Water Management District) and <strong>Section 404 of the Clean Water Act</strong> (federal — U.S. Army Corps of Engineers). A buyer needs both.
                    </div>
                  </div>
                </Section>
              )
            })()}
          </Grp>

          {/* ═══ 4 — WHAT'S NEARBY (everything with a distance) ═══ */}
          <Grp n={4} title="What's nearby">
            {(cfNear.length || cf.areaContext) ? (
              <Section title="Contamination — nearby" note="Sites near, but not on, this parcel. Ranked by status then distance — an active remediation outranks a closed site.">
                {cfNear.map((f: any, i: number) => (
                  <div key={i} style={{ marginBottom: 10, borderLeft: '3px solid var(--color-line, #d9d3c6)', paddingLeft: 12 }}>
                    <div style={{ fontWeight: 600 }}>{titleCase(f.name)}</div>
                    <div className="pir-note" style={{ fontStyle: 'normal' }}>
                      {[f.type, f.status, f.where, f.remediation].filter(Boolean).join(' · ')}. {f.cleanup}.
                      {f.documentsUrl ? <> <a href={f.documentsUrl} target="_blank" rel="noopener noreferrer">FDEP file</a></> : null}
                    </div>
                  </div>
                ))}
                {cf.areaContext ? <p className="pir-note">Area context: {cf.areaContext.tanks} storage-tank facilities and {cf.areaContext.cleanups} cleanup site(s) within ~1,600 ft.</p> : null}
              </Section>
            ) : null}

            {(() => {
              const sb = renderSinkholeBlock(r.sinkholeFacts)
              return (
                <Section title="Sinkhole incidents (FGS)" note="Documented reports (Florida Geological Survey) near the parcel — area context, never a per-parcel prediction, never a risk score.">
                  {!sb.established
                    ? <div className="pir-note">{sb.coverageNote}</div>
                    : <div className="pir-note" style={{ fontStyle: 'normal' }}>{sb.nearest
                        ? <>Nearest documented incident <b>{num(sb.nearest.distanceFt)} ft</b> away{sb.nearest.eventDate ? ` (${fmtDate(sb.nearest.eventDate)})` : ''} — {sb.nearest.verifiedLabel}. {sb.within1mi} within 1 mi{sb.verifiedWithin1mi ? `, ${sb.verifiedWithin1mi} confirmed` : ''}. Zero nearby is not a guarantee of stability.</>
                        : <>The county incident layer is held but shows none near this parcel.</>}</div>}
                </Section>
              )
            })()}

            <Section title="Nearby amenities"
              note="One compass badge per amenity type with data for this county. Absent categories are shown honestly, not filled in.">
              {amenityBadges.length ? <CompassBadgeGrid badges={amenityBadges} /> : <div className="pir-note">No covered amenity types returned for this parcel.</div>}
            </Section>

            <Section title="Water" note="One badge per off-property water feature and boat ramp within range.">
              <Fact l="Nearest water" v={mi(r.water.nearestWaterM)} />
              <div style={{ marginTop: 12 }}>
                {waterBadges.length ? <CompassBadgeGrid badges={waterBadges} /> : <div className="pir-note">No mapped water features within range.</div>}
              </div>
            </Section>

            <Section title="Assigned schools"
              note={`Zoned attendance schools for this parcel${r.schools.length ? ': ' + r.schools.map(s => `${s.level} — ${titleCase(s.name)}`).join(' · ') : ''}. Distance and bearing are to each school's location.`}>
              {schoolBadges.length
                ? <CompassBadgeGrid badges={schoolBadges} />
                : <div className="pir-note">{r.schoolsCoverage?.field_status === 'not_available'
                    ? <>Zoned-school assignments are not in the data we hold for this county — this is a coverage gap, not a finding that the parcel has no assigned schools. Ask {r.schoolsCoverage?.who_can_answer ?? 'the county school district'}.</>
                    : 'No school assignment on file for this parcel.'}</div>}
            </Section>

            {/* Brownfield — NEARBY (ruling 74 C2): FDEP sites and their distances belong in §4, never under
                an incentive heading. The on-parcel designation, if any, is in §3. */}
            {bf.established && (bf.sites || (!bf.insideArea && bf.nearestArea)) ? (
              <Section title="Brownfield — nearby" note="FDEP-designated brownfield areas and sites near, but not on, this parcel.">
                <div className="pir-note" style={{ fontStyle: 'normal' }}>
                  {!bf.insideArea && bf.nearestArea ? <>Nearest brownfield area: {titleCase(bf.nearestArea.name)} ({bf.nearestArea.distanceFt?.toLocaleString()} ft). </> : null}
                  {bf.sites ? <>{bf.sites.countWithin1mi} FDEP brownfield site{bf.sites.countWithin1mi === 1 ? '' : 's'} within 1 mile{bf.sites.nearest ? <> — nearest {titleCase(bf.sites.nearest.name)} at {bf.sites.nearest.distanceFt?.toLocaleString()} ft{bf.sites.nearest.remediationStatus ? ` (${titleCase(bf.sites.nearest.remediationStatus)})` : ''}</> : null}. {bf.sites.nearest?.remediationStatusNote ? <span style={{ color: 'var(--color-clay)' }}>{bf.sites.nearest.remediationStatusNote}</span> : null}</> : null}
                </div>
              </Section>
            ) : null}

            {/* Gopher-tortoise nearest-habitat DISTANCE (ruling 74 C1) — moved out of §3, where a distance
                reads as "on the parcel". */}
            {gopherNearbyMi != null ? (
              <Section title="Protected species — nearby" note="Mapped gopher-tortoise habitat near, but not on, this parcel. It is a distance, so it belongs in section 4.">
                <Fact l="Nearest gopher-tortoise habitat" v={mi(gopherNearbyMi)} />
              </Section>
            ) : null}
          </Grp>

          {/* ═══ 5 — THE RECORD (facts with their as_of) ═══ */}
          <Grp n={5} title="The record">
            {(() => {
              const vb = renderValuesBlock(v.valuesFacts)
              const byKey = (k: string) => vb.fields.find((f: any) => f.key === k)
              const valTile = (l: string, key: string) => {
                const f = byKey(key)
                if (!f) return <Tile key={key} l={l} v="—" />
                const rd = f.rendered
                const deriv = rd.provenance?.derivation
                return <Tile key={key} l={l}
                  v={rd.hasValue ? rd.label : <span style={{ color: 'var(--color-sage)' }}>{rd.label}</span>}
                  sub={rd.hasValue ? <>{f.asOf}<TierBadge tier={rd.provenance?.tier} />
                    {deriv?.formula ? <div className="pir-note" style={{ marginTop: 2, fontStyle: 'normal' }}>= {String(deriv.formula).replace(/_/g, ' ')}</div> : null}</> : null} />
              }
              return (
                <Section title="Assessed values"
                  note={<>Improvement value = just value − land − special-feature value.{vb.rollSpan?.mixed ? ` ${vb.rollSpan.note}` : ''}</>}>
                  <div className="pir-tiles">
                    {valTile('Just (market) value', 'justValue')}
                    {valTile('Assessed value', 'assessedValue')}
                    {valTile('Land value', 'landValue')}
                    {valTile('Special features', 'specialFeatureValue')}
                    {valTile('Improvement value', 'improvementValue')}
                  </div>
                </Section>
              )
            })()}

            <Section title="Tax & exemptions"
              note="Taxable values by authority and exemptions on file; the computed annual bill and per-authority millage are not in this dataset, so they are not shown rather than estimated.">
              <div className="pir-grid">
                <Fact l="Homestead" v={tax.homesteadExempt ? riskChip('Homestead exemption on file', true) : 'None on file'} />
                <Fact l="Homestead exemption" v={tax.homesteadExemption1 != null ? `${usd(tax.homesteadExemption1)} + ${usd(tax.homesteadExemption2)}` : '—'} />
                <Fact l="Taxable — county" v={usd(tax.taxableValueCounty)} />
                <Fact l="Taxable — school" v={usd(tax.taxableValueSchool)} />
                <Fact l="Taxing authority" v={tax.taxAuthorityCode ?? '—'} />
              </div>
            </Section>

            <Section title={`Ownership & sale history — ${tb.count} on record`}
              note="Only sales the county qualifies as arm’s-length are shown as a sale price. Quit-claims, certificates of title, and nominal transfers are real conveyances shown as consideration — never as value.">
              {tb.established && tb.lastMarketSale ? (
                <div style={{ border: '1px solid var(--color-line, #d9d3c6)', borderLeft: '3px solid var(--color-bronze, #9a6a3a)', borderRadius: 6, padding: '10px 13px', marginBottom: 12 }}>
                  <div style={{ fontSize: 14, fontWeight: 600 }}>Last qualified market sale: {tb.lastMarketSale.amountLabel} · {fmtDate(tb.lastMarketSale.date)} · {tb.lastMarketSale.instrumentType}<TierBadge tier="analysis_inference" /></div>
                  <div style={{ fontSize: 12.5, color: 'var(--color-sage)', marginTop: 3 }}>The most recent sale we read as an arm’s-length market transaction — the value-relevant one. {tb.lastMarketSale.legalCrossReference ? 'The county’s legal description cites this same deed.' : ''}</div>
                </div>
              ) : tb.established ? (
                <div className="pir-note" style={{ marginBottom: 12 }}>{tb.coverageNote}</div>
              ) : null}
              {tb.established && tb.conveyances.length ? (
                <table style={tableStyle}>
                  <thead><tr>{['Date', 'Amount', 'Instrument', 'Grantor → Grantee'].map(h => <th key={h} style={thStyle}>{h}</th>)}</tr></thead>
                  <tbody>
                    {tb.conveyances.map((c: any, i: number) => (
                      <tr key={i}>
                        <td style={tdStyle}>{fmtDate(c.date)}</td>
                        <td style={tdStyle}>{c.amountLabel ?? '—'}{c.multiParcel ? <span style={{ color: 'var(--color-terracotta, #b5502f)' }}> · {c.parcelsOnInstrument}-parcel sale</span> : null}</td>
                        <td style={tdStyle}>
                          {c.instrumentType ?? '—'}
                          {c.marketSignal === 'non_market' && c.nominalReason ? <div style={{ fontSize: 11, color: 'var(--color-sage)', marginTop: 2 }}>{c.nominalReason}</div> : null}
                          {c.ourNote ? <div style={{ fontSize: 11, color: 'var(--color-terracotta, #b5502f)', marginTop: 2 }}>{c.ourNote}</div> : null}
                        </td>
                        <td style={tdStyle}>{c.grantor || c.grantee ? `${titleCase(c.grantor) ?? '—'} → ${titleCase(c.grantee) ?? '—'}` : 'Parties not on file'}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              ) : <div className="pir-note">{tb.coverageNote ?? 'No recorded transfers on file.'}</div>}
            </Section>

            {pb.established ? (
              <Section title={`Permit history — ${pb.count} on record`}
                note={pb.closeoutNotRecordedCount > 0
                  ? `${pb.closeoutNotRecordedCount} of ${pb.count} permits have no recorded closeout — the county record does not confirm they were signed off. Any open permit can transfer to a buyer at closing; verify with the building department.`
                  : 'Every permit on file is listed; the count matches the list.'}>
                <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
                  {pb.permits.map((pm: any, i: number) => (
                    <div key={i} style={permitCard}>
                      <div style={{ display: 'flex', justifyContent: 'space-between', gap: 10, flexWrap: 'wrap' }}>
                        <span style={{ fontFamily: 'Georgia, serif', fontWeight: 700, color: 'var(--color-navy)', fontSize: 14 }}>{titleCase(pm.workDescription) || 'Permit'}</span>
                        <span style={{ fontSize: 12, color: 'var(--color-sage)' }}>#{pm.number}{pm.issuingAuthority ? ` · ${pm.issuingAuthority}` : ''}</span>
                      </div>
                      <div style={{ display: 'flex', gap: 18, flexWrap: 'wrap', marginTop: 6, fontSize: 12, color: 'var(--color-ink)' }}>
                        <span><b>Filed</b> {fmtDate(pm.date)}</span>
                        {pm.declaredValueLabel ? <span><b>Value</b> {pm.declaredValueLabel}</span> : null}
                        {pm.contractor ? <span><b>Contractor</b> {titleCase(pm.contractor)}</span> : null}
                      </div>
                      <div style={{ marginTop: 6 }}>
                        {pm.closeout.finaled
                          ? riskChip(`Finaled ${fmtDate(pm.closeout.finaledDate)}`, true)
                          : <span style={{ fontSize: 12, color: 'var(--color-terracotta, #b5502f)' }}>{pm.closeout.disclosure}</span>}
                      </div>
                      {pm.contractorLicence?.matched && pm.contractorLicence.finding
                        ? <div className="pir-note" style={{ marginTop: 6, color: 'var(--color-terracotta, #b5502f)' }}>Contractor licence: {pm.contractorLicence.finding}</div> : null}
                      {pm.contractorLicence?.matched && pm.contractorLicence.corroboration
                        ? <div className="pir-note" style={{ marginTop: 6 }}>Contractor licence: {pm.contractorLicence.corroboration}<TierBadge tier="analysis_inference" /></div> : null}
                      {pm.contractorLicence && pm.contractorLicence.matched === false
                        ? <div className="pir-note" style={{ marginTop: 6 }}>{pm.contractorLicence.note}</div> : null}
                    </div>
                  ))}
                </div>
              </Section>
            ) : (
              <Section title="Permit history" note="Permits from the county building record.">
                <div className="pir-note">{pb.coverageNote}</div>
              </Section>
            )}

            <Section title="Zoning & future land use"
              note="Zoning (what may be built now) and future land use (what the plan says it should become) are SEPARATE facts. Codes are the jurisdiction's own vocabulary — never normalized. Municipal zoning governs inside city limits.">
              <div className="pir-maprow">
                <PropertyReportMap coNo={co} parcelId={parcelId} layer="zoning" />
                <div>
                  <Legend entries={zoningLegend} />
                  {(() => {
                    const zb = renderZoningBlock(r.zoningFacts)
                    if (!zb.established) return <div className="pir-note" style={{ marginTop: 12 }}>{zb.coverageNote}</div>
                    const zf = (f: any, label: string) => f ? (
                      f.municipalNotHeld ? (
                        <Fact l={label} v={<span style={{ color: 'var(--color-sage)' }}>{f.coverageNote}</span>} />
                      ) :
                      <Fact l={label} v={<>
                        <b>{f.code}</b>{f.description ? ` · ${titleCase(f.description)}` : ''}
                        {f.jurisdictionLevel === 'municipal' ? <span style={{ color: 'var(--color-sage)' }}> · {f.jurisdiction}</span> : null}
                        <TierBadge tier="government_derived" />
                        {f.definitionNote ? <div className="pir-note" style={{ marginTop: 2 }}>{f.definitionNote}{f.definitionUrl ? <> — <a href={f.definitionUrl}>code definition</a></> : null}</div> : null}
                        {f.unconfirmedNote ? <div className="pir-note" style={{ marginTop: 2, color: 'var(--color-clay)' }}>⚠ {f.unconfirmedNote}</div> : null}
                        {f.municipalNote ? <div className="pir-note" style={{ marginTop: 2 }}>{f.municipalNote}</div> : null}
                      </>} />
                    ) : null
                    return (
                      <div style={{ marginTop: 12, display: 'flex', flexDirection: 'column', gap: 8 }}>
                        {zf(zb.zoning, 'Zoning (what may be built now)')}
                        {zf(zb.futureLandUse, 'Future land use (what the plan says)')}
                        {zb.relationship ? <div className="pir-note" style={{ marginTop: 4 }}>{zb.relationship}</div> : null}
                      </div>
                    )
                  })()}
                </div>
              </div>
            </Section>

            <Section title="Economic zones"
              note="Where the parcel falls inside one it is marked “Within”; otherwise the nearest of each is given as area context.">
              <div className="pir-grid">
                <Fact l="Opportunity Zone" v={overlayLine(r.economic.opportunityZone, 'Within Opportunity Zone')} />
                <Fact l="HUB Zone" v={overlayLine(r.economic.hubZone, 'Within HUB Zone')} />
                <Fact l="Community Redevelopment Area" v={overlayLine(r.economic.cra, 'Within a CRA')} />
                <Fact l="Enterprise Zone" v={overlayLine(r.economic.enterpriseZone, 'Within Enterprise Zone')} />
                {/* Brownfield removed from this incentive grid (ruling 74 C2) — it is a contamination fact:
                    on-parcel designation renders in §3, nearby FDEP sites in §4. */}
              </div>
            </Section>

            {(() => { return (
              <Section title={tv.title}
                note={tv.mode === 'present'
                  ? `County Lands Available for Taxes register — snapshot ${tv.asOf}. Confirm current status with the county clerk before relying on it.`
                  : tv.note}>
                {tv.mode === 'present' ? (
                  <>
                    <div className="pir-grid">
                      <Fact l="On Lands Available list" v={riskChip('County-held — unsold at tax-deed auction', false)} />
                      {tv.availabilityStatus === 'listed_not_yet_available'
                        ? <Fact l="Availability" v={riskChip('Listed — not yet purchasable', false)} />
                        : (tv.dateAvailable ? <Fact l="Available to public" v={fmtDate(tv.dateAvailable)} /> : null)}
                      {/* two DISTINCT money concepts — a floor vs an estimate — never rendered as a price */}
                      {tv.openingBid != null ? <Fact l="Opening bid (a floor, not a price)" v={usd(tv.openingBid)} /> : null}
                      {tv.estimatedPrice != null ? <Fact l="Est. purchase price (an estimate, not final)" v={usd(tv.estimatedPrice)} /> : null}
                      {tv.certificate ? <Fact l="Certificate no." v={tv.certificate} /> : null}
                      {tv.publishedEscheat
                        ? <Fact l="Escheat date (county-published)" v={fmtDate(tv.publishedEscheat)} />
                        : (tv.computedEscheat ? <Fact l="Escheat date (computed, approx.)" v={fmtDate(tv.computedEscheat)} /> : null)}
                      <Fact l="Snapshot date" v={tv.asOf ?? '—'} />
                    </div>
                    {tv.availabilityStatus === 'listed_not_yet_available' && tv.availabilityNote
                      ? <p className="pir-note" style={{ marginTop: 10 }}>{tv.availabilityNote}</p> : null}
                    {(tv.openingBidNote || tv.estimatedPriceNote)
                      ? <p className="pir-note" style={{ marginTop: 10 }}>{tv.openingBidNote || tv.estimatedPriceNote}</p> : null}
                    {/* The escheat QUESTION moved to §6 (ruling 74 C5) — status is a record fact here; the
                        "does not add up, who to ask" belongs in Open questions. */}
                    <p className="pir-note" style={{ marginTop: 10 }}>{tv.meaning}</p>
                    <p className="pir-note">{tv.staleness} {tv.notLegalAdvice}</p>
                  </>
                ) : <div className="pir-note">{tv.body}</div>}
              </Section>
            ); })()}

            {(() => {
              const cb = renderCensusBlock(r.censusFacts)
              if (!cb.established) return (
                <Section title="Census & demographics" note="These figures describe the surrounding census block group, not the parcel itself.">
                  <div className="pir-note">{cb.coverageNote}</div>
                </Section>
              )
              const fig = (key: string) => cb.fields.find((f: any) => f.key === key)?.rendered
              const tile = (l: string, key: string, sub: React.ReactNode) => {
                const rd = fig(key)
                return <Tile l={l} v={rd?.hasValue ? rd.label : <span style={{ color: 'var(--color-sage)' }}>{rd?.label ?? '—'}</span>} sub={sub} />
              }
              const mhiNote = fig('medianHouseholdIncome')?.provenance?.note
              return (
                <Section title="Census & demographics"
                  note={<>These figures describe <strong>the census block group (GEOID {cb.geography.geoid})</strong> that contains this parcel — area estimates, not parcel facts. {cb.vintage?.asOf ?? 'American Community Survey.'}</>}>
                  <div className="pir-note" style={{ marginBottom: 10 }}>
                    This parcel is contained within {cb.geography.name}
                    {cb.containment ? <> (established by point-in-polygon on {cb.containment.source}<TierBadge tier={cb.containment.tier} />)</> : null}.
                  </div>
                  <div className="pir-tiles">
                    {tile('Median household income', 'medianHouseholdIncome', <>block group<TierBadge tier="federal_statistical" /></>)}
                    {tile('Population', 'population', 'block group')}
                    {tile('Housing units', 'housingUnits', 'block group')}
                  </div>
                  {mhiNote ? <div className="pir-note" style={{ marginTop: 8 }}>{mhiNote}</div> : null}
                </Section>
              )
            })()}
          </Grp>

          {/* ═══ 6 — OPEN QUESTIONS (what doesn't add up; who to ask) ═══ */}
          <Grp n={6} title="Open questions & due diligence">
            {idf?.triggers?.length ? (
              <Section title="What the record raises" note="Each is a question the record itself surfaces — a contradiction, an anomaly, or an identity worth confirming — with where to look.">
                <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
                  {idf.triggers.map((t: any, i: number) => (
                    <div key={i} style={{ borderLeft: '3px solid var(--color-bronze, #9a6a3a)', paddingLeft: 12 }}>
                      <div style={{ fontWeight: 600, fontSize: 13.5 }}>{titleCase(String(t.observation ?? ''))}</div>
                      <div className="pir-note" style={{ fontStyle: 'normal' }}>Ask: {t.query}{t.target ? <> — <span style={{ color: 'var(--color-sage)' }}>{t.target}</span></> : null}</div>
                    </div>
                  ))}
                </div>
              </Section>
            ) : null}

            {/* Tax-deed escheat QUESTION (ruling 74 C5) — the status is a record fact in §5; when the
                escheat is a computed claim rather than a confirmed status (e.g. still listed past its
                computed date), the "what does not add up, who to ask" belongs here. */}
            {tv.mode === 'present' && tv.escheatNote ? (
              <Section title="Tax-deed escheat — a computed claim, not a confirmed status" note="This parcel is on the county Lands Available register (§5). When it escheats to the county is computed from the statute, not confirmed by the Clerk.">
                <div style={{ borderLeft: '3px solid var(--color-bronze, #9a6a3a)', paddingLeft: 12 }}>
                  <div className="pir-note" style={{ fontStyle: 'normal' }}>{tv.escheatNote}</div>
                  {tv.countyContactName ? <div className="pir-note" style={{ marginTop: 4 }}>Ask: {tv.countyContactName}{tv.countyContactPhone ? ` (${tv.countyContactPhone})` : ''}.</div> : null}
                </div>
              </Section>
            ) : null}

            {marine?.openQuestions?.headline ? (
              <Section title="Cross-examination — permit vs. assessor">
                <div style={{ fontSize: 15, fontWeight: 600, marginBottom: 6 }}>{marine.openQuestions.headline}</div>
                <ul style={{ margin: 0, paddingLeft: 18, display: 'flex', flexDirection: 'column', gap: 4 }}>
                  {marine.openQuestions.items.map((q: string, i: number) => <li key={i} style={{ fontSize: 13, lineHeight: 1.5 }}>{q}</li>)}
                </ul>
              </Section>
            ) : null}

            {marine ? marine.improvements.map((imp: any, i: number) => (
              (imp.rendered.built_year?.corroboration ?? []).length
                ? <div key={i} className="pir-note" style={{ fontStyle: 'normal' }}>{imp.rendered.built_year.corroboration.map((c: any, j: number) => (
                    <div key={j}>Permit cross-check ({titleCase(imp.improvement)}): {c.text} — <strong>{c.independence}</strong>{c.gloss ? ` — ${c.gloss}` : ''}</div>
                  ))}</div>
                : null
            )) : null}

            {(!idf?.triggers?.length && !marine?.openQuestions?.headline && !(tv.mode === 'present' && tv.escheatNote))
              ? <Section title="What the record raises"><div className="pir-note">The record surfaces no anomaly or contradiction on this parcel that we can compute. Absence of a computed open question is not a warranty; the checklist in section 7 lists what was not evaluated.</div></Section>
              : null}
          </Grp>

          {/* ═══ 7 — WHAT WE COULDN'T TELL YOU (a service, not an apology — who answers) ═══ */}
          <Grp n={7} title="What we couldn't tell you">
            <Section title="Not evaluated — and who can answer"
              note={<>Report coverage: {have} of {completeness.length} sections populated ({havePct}%).</>}>
              {gaps.length ? (
                <div style={{ display: 'flex', flexDirection: 'column', gap: 7 }}>
                  {gaps.map(([label, , who]) => (
                    <div key={label} style={{ display: 'flex', alignItems: 'baseline', gap: 8, fontSize: 12.5 }}>
                      <span style={{ color: '#b08968', fontWeight: 700 }}>○</span>
                      <span><strong style={{ color: 'var(--color-ink)' }}>{label}</strong>{who ? <span style={{ color: 'var(--color-sage)' }}> — not held here; ask {who}.</span> : <span style={{ color: 'var(--color-sage)' }}> — not yet sourced for this parcel.</span>}</span>
                    </div>
                  ))}
                </div>
              ) : <div className="pir-note">Every section we track is populated for this parcel.</div>}
              {/* The wetland DELINEATION gap — the most consequential caveat in the NWI layer: mapped ≠
                  jurisdictional. Appears when a wetland is mapped; routes to who produces a determination. */}
              {(r as any).wetland?.field_status === 'present' ? (
                <div style={{ marginTop: 14, borderTop: '1px solid var(--color-line, #d9d3c6)', paddingTop: 12, fontSize: 12.5 }}>
                  <strong style={{ color: 'var(--color-ink)' }}>Wetland — mapped, not delineated.</strong>{' '}
                  <span style={{ color: 'var(--color-sage)' }}>The wetland above is a USFWS National Wetlands Inventory hit — a <em>regional inventory</em>, which USFWS states is not for project-level analysis. It means &ldquo;mapped as wetland,&rdquo; not &ldquo;is a wetland.&rdquo; A jurisdictional determination — the line that governs what may be built — requires a field <strong>delineation</strong> by a qualified wetland delineator, confirmed through the state Environmental Resource Permit (FDEP / Water Management District, s.373 Part IV) and the federal Section 404 process (U.S. Army Corps of Engineers).</span>
                </div>
              ) : null}
            </Section>

            {/* Source limitations (ruling 74 C6) — moved here from §1. A stated limit of the public record
                itself: what the county source does not publish. A finding about the data, distinct from a
                coverage gap. This is exactly what §7 is for. */}
            {dv.mode === 'source_limit' ? (
              <Section title={dv.title} note={dv.note}>
                <ul style={{ margin: 0, paddingLeft: 18, display: 'flex', flexDirection: 'column', gap: 6 }}>
                  {dv.items.map((it, i) => <li key={i} style={{ fontSize: 14, lineHeight: 1.5 }}>{it.text}</li>)}
                </ul>
              </Section>
            ) : null}
          </Grp>

          {/* ═══ 8 — FURTHER DUE DILIGENCE (web, tier-separated) ═══ */}
          <Grp n={8} title="Further due diligence">
            <Section title="Crime & safety"
              note="Confirmed real sources exist (county Sheriff active-calls; FDLE statewide feed) but a victim-privacy-filtered integration is not yet wired in. Sensitive categories are excluded by policy before anything appears — so nothing is shown rather than shown unfiltered.">
              <div className="pir-note" style={{ fontStyle: 'normal' }}>Not yet integrated for this jurisdiction — the county Sheriff and FDLE hold it.</div>
            </Section>
            <Section title="Neighborhood news & web"
              note="Government findings (.gov: agendas, project records) are reported as findings with their date; listing/market results are Tier-4 dated observations, separate. Live web search is not wired into this checkpoint build.">
              <div className="pir-note" style={{ fontStyle: 'normal' }}>No web items retrieved at generation time.</div>
            </Section>
          </Grp>

          {/* ═══ 9 — SOURCES ═══ */}
          <Grp n={9} title="Sources">
            <div style={{ fontSize: 11.5, color: 'var(--color-sage)', lineHeight: 1.6 }}>
              <p style={{ margin: '0 0 8px' }}>
                Sources: County Property Appraiser & GIS (parcel, values, permits, zoning, future land use, economic overlays, boundaries);
                State DOR (assessment roll, use codes, statewide building descriptors); Federal — FEMA (flood), EPA/FDEP (contamination, Superfund, brownfield),
                USGS (elevation), NPS (National Register), U.S. Census/ACS (demographics).
              </p>
              <p style={{ margin: 0, color: 'var(--color-ink)' }}>
                This report reflects public records as drawn on {today()}. This is not a certified or verified record of ownership or title.
              </p>
            </div>
          </Grp>
        </div>
      </article>

      <div className="pir-toolbar no-print" style={{ paddingBottom: 40 }}>
        <span style={{ fontSize: 11, color: 'var(--color-sage)' }}>Generated {fmtDate(r.meta.generatedAt)} · source {r.meta.source ?? '—'}</span>
      </div>
    </div>
  )
}

function sourceLine(src: Record<string, string> | null | undefined, keys: string[]): string {
  if (!src) return ''
  const vals = keys.map(k => src[k]).filter(Boolean)
  return vals.length ? `Sources: ${Array.from(new Set(vals)).join('; ')}.` : ''
}

const permitCard: React.CSSProperties = { border: '1px solid var(--color-light-gray)', borderRadius: 8, padding: '12px 14px', background: 'var(--color-cream)' }
const tableStyle: React.CSSProperties = { width: '100%', borderCollapse: 'collapse', fontSize: 12.5 }
const thStyle: React.CSSProperties = { textAlign: 'left', padding: '6px 8px', borderBottom: '2px solid var(--color-light-gray)', color: 'var(--color-sage)', fontSize: 10.5, textTransform: 'uppercase', letterSpacing: '0.04em' }
const tdStyle: React.CSSProperties = { padding: '7px 8px', borderBottom: '1px solid var(--color-light-gray)', color: 'var(--color-ink)' }

const CSS = `
.pir-doc { background: var(--color-cream); min-height: 100vh; padding: 22px 12px; }
.pir-toolbar { max-width: 840px; margin: 0 auto 18px; display: flex; justify-content: space-between; align-items: center; gap: 12px; flex-wrap: wrap; }
.pir-report { max-width: 840px; margin: 0 auto 24px; background: #fff; border: 1px solid var(--color-light-gray); border-radius: 8px; box-shadow: 0 4px 22px rgba(0,0,0,0.06); overflow: hidden; }
.pir-head { display: flex; justify-content: space-between; align-items: flex-start; gap: 12px; padding: 13px 28px; border-bottom: 2px solid var(--color-navy); background: var(--color-cream); flex-wrap: wrap; }
.pir-head .addr { font-family: Georgia, serif; font-weight: 700; color: var(--color-navy); font-size: 15px; }
.pir-head .ref { font-size: 11px; color: var(--color-sage); line-height: 1.5; }
.pir-body { padding: 20px 28px 28px; }
.pir-lead { border: 1px solid var(--color-navy); border-left: 4px solid var(--color-navy); border-radius: 8px; padding: 16px 20px; margin-bottom: 26px; background: var(--color-cream); page-break-inside: avoid; }
.pir-lead-id { font-family: Georgia, serif; font-size: 18px; font-weight: 700; color: var(--color-navy); line-height: 1.35; }
.pir-lead-reg { font-size: 14px; color: var(--color-ink); margin-top: 8px; line-height: 1.5; }
.pir-group { margin-bottom: 30px; page-break-inside: auto; }
.pir-grouphead { font-family: Georgia, serif; color: var(--color-navy); font-size: 20px; margin: 0 0 16px; padding-bottom: 8px; border-bottom: 2px solid var(--color-navy); page-break-after: avoid; }
.pir-grpn { display: inline-flex; align-items: center; justify-content: center; width: 26px; height: 26px; margin-right: 12px; border-radius: 50%; background: var(--color-navy); color: #fff; font-size: 14px; vertical-align: middle; }
.pir-section { margin-bottom: 24px; page-break-inside: avoid; }
.pir-section > h3 { font-family: Georgia, serif; color: var(--color-navy); font-size: 13px; margin: 0 0 12px; padding-bottom: 5px; border-bottom: 1px solid var(--color-light-gray); text-transform: uppercase; letter-spacing: 0.05em; page-break-after: avoid; }
.pir-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(160px, 1fr)); gap: 12px 20px; }
.pir-fact .l { font-size: 10.5px; color: var(--color-sage); text-transform: uppercase; letter-spacing: 0.04em; margin-bottom: 2px; }
.pir-fact .v { font-size: 13.5px; color: var(--color-ink); font-weight: 600; display: flex; align-items: center; gap: 6px; flex-wrap: wrap; }
.pir-tiles { display: grid; grid-template-columns: repeat(auto-fill, minmax(150px, 1fr)); gap: 12px; }
.pir-tile { background: var(--color-cream); border: 1px solid var(--color-light-gray); border-radius: 8px; padding: 12px; }
.pir-tile .v { font-family: Georgia, serif; font-size: 20px; font-weight: 700; color: var(--color-navy); }
.pir-note { font-size: 11px; color: var(--color-sage); font-style: italic; margin-top: 10px; line-height: 1.5; }
.pir-maprow { display: grid; grid-template-columns: 1fr 200px; gap: 18px; align-items: start; }
@media (max-width: 720px) { .pir-maprow { grid-template-columns: 1fr; } }
.pir-map-snapshot { display: none; }
@media print {
  .pir-doc { background: #fff; padding: 0; }
  .no-print { display: none !important; }
  .pir-report { box-shadow: none; border: none; border-radius: 0; margin: 0; max-width: none; }
  .pir-map-live { display: none !important; }
  .pir-map-snapshot { display: block !important; }
}
`
