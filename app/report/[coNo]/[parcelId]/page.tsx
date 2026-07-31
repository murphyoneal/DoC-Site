import { notFound } from 'next/navigation'
import Link from 'next/link'
import { pirSocket } from '@/lib/sockets/pir'
import { CompassBadgeGrid, type CompassBadgeData } from '@/app/components/AmenityCompass'
import PropertyReportMap from '@/app/components/PropertyReportMap'
import PrintButton from '@/app/components/PrintButton'
import { FLOOD_STYLE, ZONING_STYLE } from '@/lib/pir-colors'
import type { PirReport, PirEconOverlay } from '@/types/pir'
import { formatDistance } from '@/lib/units'
import { taxDeedView, disclosuresView } from '@/lib/report-coverage.mjs'
import { renderMarineBlock, renderFloodBlock, renderFact, renderContaminationFacilities, renderValuesBlock, renderCensusBlock, renderOwnersBlock, renderTransactionsBlock, renderPermitsBlock, renderZoningBlock, renderSinkholeBlock, renderRestrictionsBlock } from '@/lib/fact-render.mjs'

// ── formatting helpers ──────────────────────────────────────────────────────────
const usd = (n?: number | null) => n == null ? '—' : `$${Math.round(n).toLocaleString('en-US')}`
const num = (n?: number | null) => n == null ? '—' : n.toLocaleString('en-US')
// US units: feet for short spans, miles above ~1000 ft (was miles-only, which read "0.1 mi" for a habitat next door).
const mi = formatDistance
const titleCase = (s?: string | null) => !s ? '' : s.replace(/\b\w/g, c => c.toUpperCase())
const fmtDate = (d?: string | null) => {
  if (!d) return '—'
  const dt = new Date(d)
  return isNaN(dt.getTime()) ? d : dt.toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' })
}
const today = () => new Date().toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' })

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
// Three visually distinct provenance tiers so a reader never mistakes our estimate for the county's figure.
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
function Sheet({ page, total, title, r, children }: { page: number; total: number; title: string; r: PirReport; children: React.ReactNode }) {
  const addr = r.property.address ?? '—'
  const cityLine = [titleCase(r.property.city), 'FL', r.property.zip].filter(Boolean).join(', ')
  const agent = r.salesAgent?.[0] ?? null
  return (
    <section className="pir-sheet">
      <header className="pir-head">
        <div>
          <div className="addr">{titleCase(addr)}</div>
          <div className="ref">{cityLine}</div>
        </div>
        <div style={{ textAlign: 'right' }}>
          <div className="ref">Parcel {r.meta.parcelId} · {r.meta.countyName} County</div>
          <div className="ref">{agent?.value ? `${titleCase(agent.value)} (self-reported)` : 'No agent listed'}</div>
        </div>
      </header>
      <div className="pir-body">
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: 14 }}>
          <h2 className="pir-h2">{title}</h2>
          <span className="pir-pageno">Page {page} of {total}</span>
        </div>
        {children}
      </div>
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

// nearest-overlay phrasing: inside ⇒ badge-worthy; else honest "nearest" context
function overlayLine(o: PirEconOverlay | null, insideLabel: string): string {
  if (!o) return 'None mapped within 5 mi'
  if (o.inside) return insideLabel
  const name = o.name ?? o.tract ?? o.zone
  return `Not within — nearest ${mi(o.distanceM)}${name ? ` (${name})` : ''}`
}

function riskChip(text: string, good: boolean) {
  const c = good ? { bg: '#e4efe4', fg: '#3f5a3f' } : { bg: '#fae1cb', fg: '#8a4a17' }
  return <span style={{ background: c.bg, color: c.fg, padding: '2px 9px', borderRadius: 20, fontSize: 11.5, fontWeight: 700 }}>{text}</span>
}

// =============================================================================
export default async function ReportPage({ params }: { params: Promise<{ coNo: string; parcelId: string }> }) {
  const { coNo, parcelId } = await params
  const co = Number(coNo)
  if (isNaN(co) || !parcelId) notFound()

  const r = await pirSocket.forParcel(co, parcelId)
  if (!r) notFound()

  const p = r.property, v = r.values, tax = r.tax
  // Owners are multi-valued: one fact per owner, count stated, percentages never normalized. A single
  // "Owner" line is wrong by design when there are two owners of record.
  const ob = renderOwnersBlock(r.ownerFacts)
  // Transactions: qualification gates the money — a market sale is a price, everything else is
  // consideration. The deed chain is kept whole (a $100 quit-claim can hide a real $2.125M warranty deed).
  const tb = renderTransactionsBlock(r.transactionFacts)
  // Permits: subject is the permit; closeout is a disclosure (a dated completion => finaled; else "not
  // recorded", never open/closed). Contractor licence is checked as of the permit date against DBPR.
  const pb = renderPermitsBlock(r.permitFacts)

  // amenity badges (individual compass per type)
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
  // Assigned school zones — one badge per level (elementary / middle / high).
  const schoolBadges: CompassBadgeData[] = r.schools
    .filter(s => s.distanceM != null)
    .map(s => ({ icon: 'school', label: s.level, sublabel: s.name, distanceM: s.distanceM!, bearingDegrees: s.bearingDegrees ?? 0 }))

  const floodLegend = ['VE', 'AE', 'AH', 'A', 'X'].map(z => FLOOD_STYLE[z])
  const zoningLegend = Object.values(ZONING_STYLE)

  // completeness checklist
  const completeness: Array<[string, boolean]> = [
    ['Property basics', !!p.yearBuilt],
    ['Assessed & market values', v.justValue != null],
    ['Tax & exemptions', tax.taxableValueCounty != null],
    ['Nearby amenities', r.amenities.length > 0],
    ['Assigned schools', r.schools.length > 0],
    ['Permit history', (pb.count ?? 0) > 0],
    ['Ownership / sale history', (tb.count ?? 0) > 0],
    ['Elevation & land', r.groundElevation != null],
    ['Water & flood', renderFloodBlock(r.floodBlock).determination?.established === true],
    ['Marine improvements', (renderMarineBlock(r.marineBlock).improvements?.length ?? 0) > 0],
    ['Tax-deed status', r.taxDeedStatus.on_lands_available_list != null],
    ['Zoning & future land use', r.zoningFacts?.field_status === 'present'],
    ['Economic overlays', Object.values(r.economic ?? {}).some(v => v != null)],
    ['Census / demographics', r.censusFacts?.field_status === 'present'],
    ['Crime / safety statistics', false],
    ['Neighborhood news (live)', false],
  ]
  const have = completeness.filter(c => c[1]).length
  const havePct = Math.round((have / completeness.length) * 100)

  return (
    <div className="pir-doc">
      <style>{CSS}</style>

      <div className="pir-toolbar no-print">
        <Link href="/" style={{ color: 'var(--color-bronze)', textDecoration: 'none', fontSize: 13 }}>← Department of Property</Link>
        <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
          <span style={{ fontSize: 12, color: 'var(--color-sage)' }}>{have}/{completeness.length} sections ({havePct}%) · source record {r.meta.dataQualityScore ?? '—'}/100</span>
          <PrintButton />
        </div>
      </div>

      {/* ═══ PAGE 1 — PROPERTY FACTS ═══ */}
      <Sheet page={1} total={5} title="Property Facts" r={r}>
        {/* Source limitations render FROM disclosuresView (lib/report-coverage) — the get_pir_report
            `disclosures` array. A source/disclose defect is a FINDING with weight (a stated limit of the
            county's public record), styled deliberately UNLIKE the muted .pir-note coverage-gap copy:
            "the county doesn't publish this" is a different sentence from "we don't hold this layer".
            report-coverage.test.mjs asserts the county scope (Volusia's 8.8% never leaks to another county). */}
        {(() => { const dv = disclosuresView(r.disclosures); if (dv.mode !== 'source_limit') return null; return (
          <div className="pir-disclosure" style={{
            border: '1px solid var(--color-line, #d9d3c6)', borderLeft: '3px solid var(--color-ink, #2b2b2b)',
            borderRadius: 6, padding: '13px 16px', marginBottom: 18, background: 'var(--color-paper-2, rgba(0,0,0,0.02))' }}>
            <div style={{ fontSize: 10.5, letterSpacing: '0.08em', textTransform: 'uppercase', fontWeight: 600, marginBottom: 6 }}>{dv.title}</div>
            <div style={{ fontSize: 12.5, color: 'var(--color-sage)', marginBottom: 8 }}>{dv.note}</div>
            <ul style={{ margin: 0, paddingLeft: 18, display: 'flex', flexDirection: 'column', gap: 6 }}>
              {dv.items.map((it, i) => <li key={i} style={{ fontSize: 14, lineHeight: 1.5 }}>{it.text}</li>)}
            </ul>
          </div>
        ); })()}
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

        {/* Ownership renders FROM the fact index (get_parcel_owner_facts). ONE row per owner — each with
            its own OWNSEQ, PCTOWN (as recorded, NEVER normalized), tenancy type, and per-source as_of. The
            parcel's owner_count is stated. as_of is load-bearing: CAMA is the live file; a DOR/NAL owner is
            a 1-January snapshot that can lag a recorded deed by ~19 months. A coverage gap is about our
            data, not the parcel. */}
        {ob.established ? (
          <Section title="Ownership"
            note={<>{ob.ownerCount?.note}{ob.tenancy?.form ? ` Tenancy on file: ${ob.tenancy.form}.` : ''}</>}>
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

        {/* Values render FROM the fact index (get_parcel_values_facts, surfaced as values.valuesFacts).
            Each dollar figure carries its OWN per-field roll year + authority (CAMA 2026 vs NAL 2025) —
            a block-level year would MISDATE a field when the coalesce mixes sources, so the asymmetry is
            surfaced in the section note, never silently reconciled. Absent field → the fixed NULL string,
            never a number. corroborators are [] by design (CAMA/NAL share DOR lineage — not independent). */}
        {(() => {
          const vb = renderValuesBlock(v.valuesFacts)
          const byKey = (k: string) => vb.fields.find((f: any) => f.key === k)
          const valTile = (l: string, key: string) => {
            const f = byKey(key)
            if (!f) return <Tile key={key} l={l} v="—" />
            const rd = f.rendered
            return <Tile key={key} l={l}
              v={rd.hasValue ? rd.label : <span style={{ color: 'var(--color-sage)' }}>{rd.label}</span>}
              sub={rd.hasValue ? <>{f.asOf}<TierBadge tier={rd.provenance?.tier} /></> : null} />
          }
          return (
            <Section title="Assessed values"
              note={<>Improvement value = just value − land − special-feature value.{vb.rollSpan?.mixed ? ` ${vb.rollSpan.note}` : ''}</>}>
              <div className="pir-tiles">
                {valTile('Just (market) value', 'justValue')}
                {valTile('Assessed value', 'assessedValue')}
                {valTile('Land value', 'landValue')}
                {valTile('Improvement value', 'improvementValue')}
                <Tile l="Special features" v={usd(v.specialFeatureValue)} />
              </div>
            </Section>
          )
        })()}

        <Section title="Tax & exemptions"
          note="This dataset carries taxable values by authority and exemptions on file; it does not include the computed annual tax bill or per-authority millage, so those are not shown rather than estimated.">
          <div className="pir-grid">
            <Fact l="Homestead" v={tax.homesteadExempt ? riskChip('Homestead exemption on file', true) : 'None on file'} />
            <Fact l="Homestead exemption" v={tax.homesteadExemption1 != null ? `${usd(tax.homesteadExemption1)} + ${usd(tax.homesteadExemption2)}` : '—'} />
            <Fact l="Taxable — county" v={usd(tax.taxableValueCounty)} />
            <Fact l="Taxable — school" v={usd(tax.taxableValueSchool)} />
            <Fact l="Taxing authority" v={tax.taxAuthorityCode ?? '—'} />
          </div>
        </Section>

        <Section title="Parcel boundary"
          note="Subject parcel (gold) and neighbouring parcels within ~150 ft, drawn from real county parcel geometry.">
          <PropertyReportMap coNo={co} parcelId={parcelId} layer="parcels" height={300} />
        </Section>

        <Section title="Nearby amenities"
          note="One compass badge per amenity type with data for this county. Absent categories (grocery, transit, library, parks…) are not yet in the county coverage layer — their absence is shown honestly, not filled in.">
          {amenityBadges.length ? <CompassBadgeGrid badges={amenityBadges} /> : <div className="pir-note">No covered amenity types returned for this parcel.</div>}
        </Section>

        <Section title="Assigned schools"
          note={`Zoned attendance schools for this parcel (Volusia County School District)${r.schools.length ? ': ' + r.schools.map(s => `${s.level} — ${titleCase(s.name)}`).join(' · ') : ''}. Distance and bearing are to each school's location.`}>
          {schoolBadges.length ? <CompassBadgeGrid badges={schoolBadges} /> : <div className="pir-note">No school assignment on file for this parcel.</div>}
        </Section>

        <Section title="Listing & agent"
          note={r.salesAgent?.[0]
            ? 'Self-reported by a licensed agent from firsthand knowledge, corroborated to a recorded sale where one attached — not from an MLS and not the county record’s own fact. Verify at the Clerk with the instrument number.'
            : undefined}>
          {r.salesAgent?.[0] ? (() => {
            const a = r.salesAgent![0]
            return (
              <div className="pir-grid">
                <Fact l="Sales agent (self-reported)" v={titleCase(a.value) || '—'} />
                <Fact l="FL licence" v={a.license_number ?? '—'} />
                <Fact l="Represented a party in" v={a.sale_date ? `${fmtDate(a.sale_date)} sale${a.sale_price != null ? ` · ${usd(a.sale_price)}` : ''}` : '—'} />
                <Fact l="Recorded instrument" v={[a.sale_instrument, a.sale_instr_no].filter(Boolean).join(' ') || '—'} />
              </div>
            )
          })() : (
            <div style={{ display: 'flex', alignItems: 'center', gap: 12, flexWrap: 'wrap' }}>
              <span style={{ fontSize: 13, color: 'var(--color-ink)' }}>The county record does not name a sales agent, and no licensed agent has claimed this property.</span>
              <span className="no-print" style={{ background: 'var(--color-bronze)', color: '#fff', padding: '6px 14px', borderRadius: 8, fontSize: 12, fontWeight: 600 }}>Claim this listing →</span>
            </div>
          )}
        </Section>
      </Sheet>

      {/* ═══ PAGE 2 — PROPERTY HISTORY ═══ */}
      <Sheet page={2} total={5} title="Property History" r={r}>
        {/* Permits render FROM the fact index (get_parcel_permit_facts). Subject is the PERMIT
            (attaches_by_key). Closeout is a disclosure: a dated completion => finaled; otherwise
            "closeout not recorded" is an affirmative line (an authorized-but-unfinaled permit can be
            inherited at closing), never "open"/"closed" — the numeric STATUS code is opaque and NOT
            decoded. AMOUNT is declared value, not cost. The contractor licence is checked AS OF THE
            PERMIT DATE against DBPR (a different agency): active = independent corroboration, inactive =
            a finding. Marine build-year cross-exam is NOT duplicated here — it lives in Marine. */}
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

        {/* Transactions render FROM the fact index (get_parcel_transaction_facts). Qualification GATES the
            money: a market sale (qualified warranty deed) shows a SALE PRICE; a quit-claim / certificate of
            title / unqualified / nominal transfer shows CONSIDERATION and says why — the number is never
            presented as value. The whole deed chain is kept (the $100 transfers pair ownership; deleting
            them breaks the chain). The county's qualification and OUR market-signal reading are distinct;
            where we downgrade a technically-qualified sale, that note is visibly ours. */}
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
                    <td style={tdStyle}>
                      {c.amountLabel ?? '—'}{c.multiParcel ? <span style={{ color: 'var(--color-terracotta, #b5502f)' }}> · {c.parcelsOnInstrument}-parcel sale</span> : null}
                    </td>
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
      </Sheet>

      {/* ═══ PAGE 3 — ENVIRONMENTAL ═══ */}
      <Sheet page={3} total={5} title="Environmental Facts" r={r}>
        {/* Flood renders from floodView (lib/report-coverage) — the FEMA NFHL coverage-aware shape.
            not_available / parcel_not_resolved is a COVERAGE GAP, never "not in a flood zone" (the
            St Pete incident). report-coverage.test.mjs asserts the gap copy. */}
        {/* Flood renders FROM the fact index (get_parcel_flood_block via renderFloodBlock). THE finding is
            the SFHA determination (federal_regulatory tier); a coverage gap renders "not established —
            about our data, not the parcel", NEVER "not in a flood zone" (the St Pete failure). Datum is
            surfaced; the elevation-vs-BFE comparison is withheld with its reason visible. */}
        {(() => { const fb = renderFloodBlock(r.floodBlock); const det = fb.determination; return (
        <Section title="Flood & area — 5-mile radius" note="The FEMA determination is the finding; zone and base flood elevation are supporting detail.">
          <div className="pir-maprow">
            <PropertyReportMap coNo={co} parcelId={parcelId} layer="flood" />
            <div>
              <Legend entries={floodLegend} />
              <div style={{ marginTop: 12, display: 'flex', flexDirection: 'column', gap: 8 }}>
                <div style={{ border: '1px solid var(--color-line, #d9d3c6)', borderLeft: `3px solid ${det?.inSfha ? 'var(--color-terracotta, #b5502f)' : 'var(--color-sage)'}`, borderRadius: 6, padding: '10px 13px' }}>
                  <div style={{ fontSize: 14, fontWeight: 600 }}>{det?.label}<TierBadge tier={det?.tier} /></div>
                  {det?.headline ? <div style={{ fontSize: 12.5, color: 'var(--color-sage)', marginTop: 4 }}>{det.headline}</div> : null}
                </div>
                {fb.bfe ? <Fact l="Base flood elevation" v={fb.bfe.label} /> : null}
                {fb.zones.length ? <Fact l="Flood zones (share of parcel)" v={fb.zones.map((z: any) => `${z.zone}${z.in_sfha ? ' · SFHA' : ''}${z.pct_of_parcel != null ? ` ${z.pct_of_parcel}%` : ''}`).join('   ·   ')} /> : null}
                {fb.elevationComparison?.withheld ? <p className="pir-note" style={{ marginTop: 2 }}>Elevation vs. BFE — {fb.elevationComparison.reason}</p> : null}
                <Fact l="Area repetitive loss" v={
                  r.floodBlock?.areaRepetitiveLoss && r.floodBlock.areaRepetitiveLoss.field_status === 'present'
                    ? `${num(r.floodBlock.areaRepetitiveLoss.properties)} properties · ${num(r.floodBlock.areaRepetitiveLoss.totalLosses)} losses (county context)`
                    : <span style={{ color: 'var(--color-sage)' }}>Not held for this county</span>} />
              </div>
            </div>
          </div>
        </Section>
        ); })()}

        {/* Air + Wind removed 2026-07-29 — every property_environmental (v_env) air field AND
            every property_hazard_risk (v_haz) wind field was a single fabricated value statewide,
            including the FBC design wind speed (130/zone II everywhere). Both stripped from
            get_pir_report; see anchor §9. */}

        {/* radon / sinkhole / water service / lead service line removed 2026-07-29 — fabricated
            v_env constants (single value across all 313,578 rows), not per-parcel facts. Only
            elevation (USGS) and the gopher-tortoise overlay (real spatial) remain. */}
        <Section title="Land"
          note="Ground elevation is a USGS-derived property fact and the gopher-tortoise overlay is a mapped spatial layer. Soil type & drainage classification is not sourced for Volusia and is omitted rather than guessed.">
          <div className="pir-grid">
            {/* Elevation VALUE is withheld (get_ground_elevation_fact): parcel_elevations carries no vertical
                datum, so a foot-level figure would imply precision we lack — the 5th fabrication. Renders the
                asymmetry, never the number. */}
            <Fact l="Ground elevation" v={<span style={{ color: 'var(--color-sage)' }}>{renderFact(r.groundElevation).label}</span>} />
            <Fact l="Sewer / septic" v={<span style={{ color: 'var(--color-sage)' }}>Not evaluated — no parcel-level sewer/septic determination in the record</span>} />
            <Fact l="Protected species" v={r.land.gopherTortoiseInside ? riskChip('Within gopher tortoise habitat overlay', false) : r.land.gopherTortoiseNearestM != null ? `Nearest habitat ${mi(r.land.gopherTortoiseNearestM)}` : 'None mapped nearby'} />
            {/* Sinkhole renders FROM the fact index (get_parcel_sinkhole_facts): DOCUMENTED FGS subsidence
                incidents near the parcel — area context, never a per-parcel risk score (the purged
                fabrication), never "no risk" where we hold no layer. */}
            {(() => {
              const sb = renderSinkholeBlock(r.sinkholeFacts)
              if (!sb.established) return <Fact l="Sinkhole incidents" v={<span style={{ color: 'var(--color-sage)' }}>{sb.coverageNote}</span>} />
              return <Fact l="Sinkhole incidents (FGS)" v={<>
                {sb.nearest
                  ? <>Nearest documented incident <b>{num(sb.nearest.distanceFt)} ft</b> away{sb.nearest.eventDate ? ` (${fmtDate(sb.nearest.eventDate)})` : ''} — {sb.nearest.verifiedLabel}. {sb.within1mi} within 1 mi{sb.verifiedWithin1mi ? `, ${sb.verifiedWithin1mi} confirmed` : ''}.</>
                  : <>The county incident layer is held but shows none near this parcel.</>}
                <div className="pir-note" style={{ marginTop: 2 }}>Documented reports (Florida Geological Survey), not a prediction this parcel will subside; zero nearby is not a guarantee of stability.</div>
              </>} />
            })()}
          </div>
        </Section>

        <Section title="Water" note="One badge per off-property water feature and boat ramp within range. Flood-zone designation is folded into this page (above), not a separate section.">
          <Fact l="Nearest water" v={mi(r.water.nearestWaterM)} />
          <div style={{ marginTop: 12 }}>
            {waterBadges.length ? <CompassBadgeGrid badges={waterBadges} /> : <div className="pir-note">No mapped water features within range.</div>}
          </div>
        </Section>

        {/* Marine improvements (Tier 1 #1) + Tax-deed status (#36) render FROM lib/report-coverage
            (marineView / taxDeedView) — the module report-coverage.test.mjs asserts — so a coverage
            gap (not_available) can never read as "no dock" / "no tax exposure". */}
        {/* Contamination facilities render FROM the fact index (get_parcel_contamination_facilities). On-parcel
            and ACTIVE-remediation facilities are NAMED (not folded into an "N tanks nearby" count); null cleanup
            renders as a question, never blank. report-coverage.test.mjs asserts these. Item 82 / 316 Main St. */}
        {(() => { const cf = renderContaminationFacilities(r.contaminationFacilities); if (!cf.facilities.length && !cf.areaContext) return null; return (
          <Section title="Contamination — on & near this parcel" note="On-parcel and active-remediation facilities are named individually; the surrounding count is area context only.">
            {cf.facilities.map((f: any, i: number) => {
              const flag = f.onParcel || /ACTIVE/i.test(f.remediation || '')
              return (
                <div key={i} style={{ marginBottom: 10, borderLeft: `3px solid ${flag ? 'var(--color-terracotta, #b5502f)' : 'var(--color-line, #d9d3c6)'}`, paddingLeft: 12 }}>
                  <div style={{ fontWeight: 600 }}>{titleCase(f.name)} {f.onParcel ? riskChip('On this parcel', false) : null} {/ACTIVE/i.test(f.remediation || '') ? riskChip('Active remediation', false) : null}</div>
                  <div className="pir-note" style={{ fontStyle: 'normal' }}>
                    {[f.type, f.status, f.where, f.remediation].filter(Boolean).join(' · ')}. {f.cleanup}.
                    {f.documentsUrl ? <> <a href={f.documentsUrl} target="_blank" rel="noopener noreferrer">FDEP file</a></> : null}
                    {f.watchUrl ? <> · <a href={f.watchUrl} target="_blank" rel="noopener noreferrer">monitor</a></> : null}
                  </div>
                </div>
              )
            })}
            {cf.areaContext ? <p className="pir-note">Area context (not on-parcel): {cf.areaContext.tanks} storage-tank facilities and {cf.areaContext.cleanups} cleanup site(s) within ~1,600 ft.</p> : null}
          </Section>
        ); })()}
        {/* Land-use RESTRICTIONS render FROM the fact index (get_parcel_restrictions via renderRestrictionsBlock).
            A delineated Groundwater Contamination Area (Ch. 62-524) is a state_regulatory CONSTRAINT — a criminal-
            penalty bar on new potable wells, treated like the flood mandate (containment, not distance). UNLIKE
            contamination facilities, this section renders EVEN WHEN EMPTY: the honest "not a clearance — historic
            use isn't in any register" absence statement is itself the finding. fact-render.test.mjs asserts it. */}
        {(() => {
          const rb = renderRestrictionsBlock(r.landRestrictions)
          return (
            <Section title="Recorded land-use restrictions" note="State/federal constraints recorded against this location — groundwater-contamination areas, institutional controls, regulated on-parcel wells. A containment test, not a distance.">
              {rb.established ? rb.items.map((it: any, i: number) => (
                <div key={i} style={{ marginBottom: 10, borderLeft: '3px solid var(--color-terracotta, #b5502f)', paddingLeft: 12 }}>
                  <div style={{ fontWeight: 600 }}>{it.label} {riskChip(it.relation === 'contains' ? 'On this parcel' : 'Overlapping', false)} <TierBadge tier="government_derived" /></div>
                  <div className="pir-note" style={{ fontStyle: 'normal' }}>
                    {it.value}{it.authority ? ` — ${it.authority}` : ''}{it.asOf ? ` (${it.asOf})` : ''}.
                    {it.caveat ? <> {it.caveat}</> : null}
                  </div>
                </div>
              )) : (
                <div className="pir-note">{rb.absenceNote}</div>
              )}
            </Section>
          )
        })()}
        {/* Marine improvements render FROM the fact index (get_parcel_marine_block via renderMarineBlock).
            The cross-examination headline (permit vs. assessor) leads; the improvements are context. Three
            provenance tiers stay visually distinct (county / derived / OUR estimate). A coverage gap
            (non-Volusia) never reads as "no dock". report-coverage.test.mjs asserts these. */}
        {(() => {
          const mb = r.marineBlock
          const st = mb?.field_status
          if (!mb || st === 'not_available') return (
            <Section title="Marine improvements" note="Coverage gap, not a finding — the county other-improvements file is held for Volusia only.">
              <div className="pir-note">Whether this parcel has waterfront structures (dock, seawall, lift, boat house) is not known here — its absence is not evidence either way.</div>
            </Section>
          )
          if (st === 'none_recorded') return (
            <Section title="Marine improvements" note="The county appraiser has assessed no marine improvement on this parcel.">
              <div className="pir-note">Unassessed, unpermitted or newly built structures may still exist.</div>
            </Section>
          )
          const rb = renderMarineBlock(mb)
          return (
            <Section title="Marine improvements" note="Every figure is a sourced assessor fact; build years are cross-examined against county building permits.">
              {rb.openQuestions.headline ? (
                <div style={{ border: '1px solid var(--color-line, #d9d3c6)', borderLeft: '3px solid var(--color-terracotta, #b5502f)', borderRadius: 6, padding: '12px 15px', marginBottom: 16, background: 'var(--color-paper-2, rgba(0,0,0,0.02))' }}>
                  <div style={{ fontSize: 10.5, letterSpacing: '0.08em', textTransform: 'uppercase', fontWeight: 600, marginBottom: 6 }}>Cross-examination — permit vs. assessor</div>
                  <div style={{ fontSize: 15, fontWeight: 600, marginBottom: 6 }}>{rb.openQuestions.headline}</div>
                  <ul style={{ margin: 0, paddingLeft: 18, display: 'flex', flexDirection: 'column', gap: 4 }}>
                    {rb.openQuestions.items.map((q: string, i: number) => <li key={i} style={{ fontSize: 13, lineHeight: 1.5 }}>{q}</li>)}
                  </ul>
                </div>
              ) : null}
              {rb.improvements.map((imp: any, i: number) => (
                <div key={i} style={{ marginBottom: 14 }}>
                  <div style={{ fontSize: 13, fontWeight: 600, marginBottom: 6 }}>{titleCase(imp.improvement)} · built {imp.built}</div>
                  <div className="pir-grid">
                    {Object.entries(imp.rendered).filter(([, f]: [string, any]) => f.hasValue).map(([pred, f]: [string, any]) => (
                      <Fact key={pred} l={MARINE_PRED_LABEL[pred] ?? pred} v={<>{f.label} <TierBadge tier={f.provenance?.tier} /></>} />
                    ))}
                  </div>
                  {(imp.rendered.built_year?.corroboration ?? []).map((c: any, j: number) => (
                    <p key={j} className="pir-note" style={{ marginTop: 6 }}>Permit cross-check: {c.text} — <strong>{c.independence}</strong>{c.gloss ? ` — ${c.gloss}` : ''}</p>
                  ))}
                </div>
              ))}
              {rb.material ? <p className="pir-note" style={{ marginTop: 8 }}>{rb.material.text}</p> : null}
            </Section>
          )
        })()}

        {(() => { const tv = taxDeedView(r.taxDeedStatus); return (
          <Section title={tv.title}
            note={tv.mode === 'present'
              ? `County Lands Available for Taxes register — snapshot ${tv.asOf}. Confirm current status with the county clerk before relying on it.`
              : tv.note}>
            {tv.mode === 'present' ? (
              <>
                <div className="pir-grid">
                  <Fact l="On Lands Available list" v={riskChip('County-held — unsold at tax-deed auction', false)} />
                  {tv.openingBid != null ? <Fact l="Opening bid" v={usd(tv.openingBid)} /> : null}
                  {tv.certificate ? <Fact l="Certificate no." v={tv.certificate} /> : null}
                  {tv.dateAvailable ? <Fact l="Available to public" v={tv.dateAvailable} /> : null}
                  <Fact l="Snapshot date" v={tv.asOf ?? '—'} />
                </div>
                <p className="pir-note" style={{ marginTop: 10 }}>{tv.meaning}</p>
                <p className="pir-note">{tv.staleness} {tv.notLegalAdvice}</p>
              </>
            ) : <div className="pir-note">{tv.body}</div>}
          </Section>
        ); })()}
      </Sheet>

      {/* ═══ PAGE 4 — NEIGHBORHOOD ═══ */}
      <Sheet page={4} total={5} title="Neighborhood Data" r={r}>
        <Section title="Zoning & future land use — 5-mile radius"
          note="Boundaries are real county geometry, dissolved to the standard land-use colour categories. Legend to the side.">
          <div className="pir-maprow">
            <PropertyReportMap coNo={co} parcelId={parcelId} layer="zoning" />
            <div>
              <Legend entries={zoningLegend} />
              {/* Zoning renders FROM the fact index (get_parcel_zoning_facts). Zoning (what may be built
                  now) and future land use (what the plan says it should become) are SEPARATE facts, never
                  merged. Codes are the jurisdiction's OWN vocabulary — never normalized (B-5 in Ocala != B-5
                  in DeLand). Municipal zoning governs inside city limits. A code with no definition shows
                  the caveat + a pointer to the land development code, never an invented meaning. */}
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
                    {/* unconfirmed placeholder: value shown verbatim above, caveat said HERE (in the output, not just the registry) */}
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
          note="Confirmed Volusia economic-development layers. Where the parcel falls inside one it is marked “Within”; otherwise the nearest of each is given as area context — absence is itself informative.">
          <div className="pir-grid">
            <Fact l="Opportunity Zone" v={overlayLine(r.economic.opportunityZone, 'Within Opportunity Zone')} />
            <Fact l="HUB Zone" v={overlayLine(r.economic.hubZone, 'Within HUB Zone')} />
            <Fact l="Community Redevelopment Area" v={overlayLine(r.economic.cra, 'Within a CRA')} />
            <Fact l="Enterprise Zone" v={overlayLine(r.economic.enterpriseZone, 'Within Enterprise Zone')} />
            <Fact l="Brownfield Area" v={overlayLine(r.economic.brownfield, 'Within Brownfield Area')} />
          </div>
        </Section>

        {/* Census renders FROM the fact index (get_parcel_census_facts). The SUBJECT IS THE BLOCK GROUP,
            not the parcel — the geography is NAMED and the parcel's contained_within relationship stated,
            so a figure never reads as "this property's income" (DEF-014). Tier federal_statistical (a
            5-year SAMPLE estimate); the un-carried MOE is stated, never invented; the vintage shows its
            unconfirmed status; a coverage gap is about our data, not the parcel. */}
        {(() => {
          const cb = renderCensusBlock(r.censusFacts)
          if (!cb.established) {
            return (
              <Section title="Census & demographics" note="These figures describe the surrounding census block group, not the parcel itself.">
                <div className="pir-note">{cb.coverageNote}</div>
              </Section>
            )
          }
          const fig = (key: string) => cb.fields.find((f: any) => f.key === key)?.rendered
          const tile = (l: string, key: string, sub: React.ReactNode) => {
            const rd = fig(key)
            return <Tile l={l}
              v={rd?.hasValue ? rd.label : <span style={{ color: 'var(--color-sage)' }}>{rd?.label ?? '—'}</span>}
              sub={sub} />
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
      </Sheet>

      {/* ═══ PAGE 5 — SUPPORTING INFORMATION ═══ */}
      <Sheet page={5} total={5} title="Supporting Information" r={r}>
        <Section title="Data completeness"
          note="The report's primary trust signal: what is populated from confirmed records versus not yet sourced. Nothing here is inferred to fill a gap. The two figures below measure different things and are not expected to match.">
          <div style={{ marginBottom: 10, fontSize: 13, lineHeight: 1.6 }}>
            <div><b>Report coverage:</b> {have} of {completeness.length} sections populated ({havePct}%).</div>
            <div><b>Source-record quality:</b> {r.meta.dataQualityScore ?? '—'}/100 — the county appraiser record's own completeness/confidence score for this parcel, independent of how many report sections are shown.</div>
          </div>
          <div className="pir-grid" style={{ gridTemplateColumns: 'repeat(auto-fill, minmax(220px, 1fr))' }}>
            {completeness.map(([label, ok]) => (
              <div key={label} style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 12.5 }}>
                <span style={{ color: ok ? '#3f5a3f' : '#b08968', fontWeight: 700 }}>{ok ? '●' : '○'}</span>
                <span style={{ color: ok ? 'var(--color-ink)' : 'var(--color-sage)' }}>{label}</span>
              </div>
            ))}
          </div>
        </Section>

        <Section title="Crime & safety"
          note="Honest gap. Confirmed real sources exist (Volusia Sheriff active-calls feed; CrimeMapping Volusia hub; FDLE statewide stolen-property/wanted feed) but a machine-readable, victim-privacy-filtered integration is not yet wired in. Sensitive categories (sex offenses, domestic disturbance and similar) are excluded by policy before anything appears here — matching official practice — so nothing is shown rather than shown unfiltered.">
          <div className="pir-note" style={{ fontStyle: 'normal' }}>Not yet integrated for this jurisdiction.</div>
        </Section>

        <Section title="Neighborhood news"
          note="Populated by live web search at report-generation time (new retail, transit changes, development announcements within ~5 mi), paraphrased and cited by outlet — never reproduced at length. Live search is not wired into this checkpoint build, so no items are shown rather than placeholder headlines.">
          <div className="pir-note" style={{ fontStyle: 'normal' }}>No items retrieved.</div>
        </Section>

        <Section title="Sources & disclaimer">
          <div style={{ fontSize: 11.5, color: 'var(--color-sage)', lineHeight: 1.6 }}>
            <p style={{ margin: '0 0 8px' }}>
              Sources: County Property Appraiser & GIS (parcel, values, permits, zoning, future land use, economic overlays, boundaries);
              State DOR (assessment roll, use codes); Federal — FEMA (flood), NOAA (climate & storms), EPA (air, radon, water),
              USGS (elevation), U.S. Census/ACS (demographics).
            </p>
            <p style={{ margin: 0, color: 'var(--color-ink)' }}>
              This report reflects public records as drawn on {today()}. This is not a certified or verified record of ownership or title.
            </p>
          </div>
        </Section>
      </Sheet>

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
.pir-sheet { max-width: 840px; margin: 0 auto 24px; background: #fff; border: 1px solid var(--color-light-gray); border-radius: 8px; box-shadow: 0 4px 22px rgba(0,0,0,0.06); overflow: hidden; }
.pir-head { display: flex; justify-content: space-between; align-items: flex-start; gap: 12px; padding: 13px 28px; border-bottom: 2px solid var(--color-navy); background: var(--color-cream); flex-wrap: wrap; }
.pir-head .addr { font-family: Georgia, serif; font-weight: 700; color: var(--color-navy); font-size: 15px; }
.pir-head .ref { font-size: 11px; color: var(--color-sage); line-height: 1.5; }
.pir-body { padding: 20px 28px 28px; }
.pir-pageno { font-size: 10px; color: var(--color-sage); text-transform: uppercase; letter-spacing: 0.08em; white-space: nowrap; }
.pir-h2 { font-family: Georgia, serif; color: var(--color-navy); font-size: 19px; margin: 0; }
.pir-section { margin-bottom: 24px; }
.pir-section > h3 { font-family: Georgia, serif; color: var(--color-navy); font-size: 13px; margin: 0 0 12px; padding-bottom: 5px; border-bottom: 1px solid var(--color-light-gray); text-transform: uppercase; letter-spacing: 0.05em; }
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
  .pir-sheet { box-shadow: none; border: none; border-radius: 0; margin: 0; max-width: none; page-break-after: always; }
  /* Swap the live WebGL canvas for its baked snapshot so the PDF captures a rendered map. */
  .pir-map-live { display: none !important; }
  .pir-map-snapshot { display: block !important; }
}
`
