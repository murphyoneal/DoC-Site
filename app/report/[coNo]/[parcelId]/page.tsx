import { notFound } from 'next/navigation'
import Link from 'next/link'
import { pirSocket } from '@/lib/sockets/pir'
import { CompassBadgeGrid, type CompassBadgeData } from '@/app/components/AmenityCompass'
import PropertyReportMap from '@/app/components/PropertyReportMap'
import WindDial from '@/app/components/WindDial'
import PrintButton from '@/app/components/PrintButton'
import { FLOOD_STYLE, ZONING_STYLE } from '@/lib/pir-colors'
import type { PirReport, PirEconOverlay } from '@/types/pir'

// ── formatting helpers ──────────────────────────────────────────────────────────
const usd = (n?: number | null) => n == null ? '—' : `$${Math.round(n).toLocaleString('en-US')}`
const num = (n?: number | null) => n == null ? '—' : n.toLocaleString('en-US')
const mi = (m?: number | null) => m == null ? '—' : `${(m / 1609.344).toFixed(1)} mi`
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
    ['Permit history', r.permits.count > 0],
    ['Ownership / sale history', r.transactions.count > 0],
    ['Air quality', r.air.aqiAnnualAvg != null],
    ['Elevation & land', r.land.elevationFt != null],
    ['Water & flood', r.flood.zone != null],
    ['Climate & wind', !!r.wind.prevailingDirection],
    ['Zoning & future land use', !!r.zoning.zoneCode],
    ['Economic overlays', Object.values(r.economic ?? {}).some(v => v != null)],
    ['Census / demographics', r.census.population != null],
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
        <Section title="Property">
          <div className="pir-grid">
            <Fact l="Owner" v={<>{titleCase(p.ownerName)} {p.ownerOccupied ? riskChip('Owner-occupied', true) : null}</>} />
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

        <Section title="Assessed values" note="Improvement value = just value − land − special-feature value.">
          <div className="pir-tiles">
            <Tile l="Just (market) value" v={usd(v.justValue)} sub={`${v.assessedYear ?? ''} roll`} />
            <Tile l="Assessed value" v={usd(v.assessedValue)} sub="capped/SOH" />
            <Tile l="Land value" v={usd(v.landValue)} />
            <Tile l="Improvement value" v={usd(v.improvementValue)} />
            <Tile l="Special features" v={usd(v.specialFeatureValue)} />
          </div>
        </Section>

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
        <Section title={`Permit history — ${r.permits.count} on record`}
          note="Every permit on file is listed; the count matches the list. Where the county record carries no final status, that is stated rather than assumed. 1980s records occasionally merge the work-description and contractor fields at the source.">
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {r.permits.items.map((pm, i) => {
              const statusText = pm.status ? `County status ${pm.status}` : pm.completionDate ? 'Completed — final status not on file' : 'Issued — no confirmed outcome'
              return (
                <div key={i} style={permitCard}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', gap: 10, flexWrap: 'wrap' }}>
                    <span style={{ fontFamily: 'Georgia, serif', fontWeight: 700, color: 'var(--color-navy)', fontSize: 14 }}>
                      {titleCase(pm.workDescription) || 'Permit'} {pm.tradeCategory && pm.tradeCategory !== 'other' ? `· ${pm.tradeCategory.toUpperCase()}` : ''}
                    </span>
                    <span style={{ fontSize: 12, color: 'var(--color-sage)' }}>#{pm.permitNumber}</span>
                  </div>
                  <div style={{ display: 'flex', gap: 18, flexWrap: 'wrap', marginTop: 6, fontSize: 12, color: 'var(--color-ink)' }}>
                    <span><b>Filed</b> {fmtDate(pm.permitDate)}</span>
                    <span><b>Completed</b> {fmtDate(pm.completionDate)}</span>
                    {pm.jobValue ? <span><b>Job value</b> {usd(pm.jobValue)}</span> : null}
                    {pm.contractorName ? <span><b>Contractor</b> {titleCase(pm.contractorName)}</span> : null}
                  </div>
                  <div style={{ marginTop: 6 }}>{riskChip(statusText, !!pm.status || !!pm.completionDate)}</div>
                </div>
              )
            })}
          </div>
        </Section>

        <Section title={`Ownership & sale history — ${r.transactions.count} on record`}
          note="Recorded deed transfers beyond the assessor's last-qualified-sale are not present in this dataset; only what is on file is shown, and the count matches the list.">
          {r.transactions.items.length ? (
            <table style={tableStyle}>
              <thead><tr>{['Date', 'Price', 'Instrument', 'Grantor → Grantee'].map(h => <th key={h} style={thStyle}>{h}</th>)}</tr></thead>
              <tbody>
                {r.transactions.items.map((t, i) => (
                  <tr key={i}>
                    <td style={tdStyle}>{fmtDate(t.saleDate ?? t.recordingDate)}</td>
                    <td style={tdStyle}>{usd(t.salePrice)}</td>
                    <td style={tdStyle}>{t.instrumentType ?? '— (assessor sale record)'}</td>
                    <td style={tdStyle}>{t.grantor || t.grantee ? `${t.grantor ?? '—'} → ${t.grantee ?? '—'}` : 'Parties not on file'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          ) : <div className="pir-note">No recorded transfers on file.</div>}
        </Section>
      </Sheet>

      {/* ═══ PAGE 3 — ENVIRONMENTAL ═══ */}
      <Sheet page={3} total={5} title="Environmental Facts" r={r}>
        <Section title="Flood & area — 5-mile radius"
          note="Parcel flood zone is a property-level classification; area FEMA repetitive-loss figures are county context, not a claim about this parcel.">
          <div className="pir-maprow">
            <PropertyReportMap coNo={co} parcelId={parcelId} layer="flood" />
            <div>
              <Legend entries={floodLegend} />
              <div style={{ marginTop: 12, display: 'flex', flexDirection: 'column', gap: 8 }}>
                <Fact l="Parcel flood zone" v={<>{r.flood.zone ?? '—'} {r.flood.inHazardArea === false ? riskChip('Not in SFHA', true) : r.flood.inHazardArea ? riskChip('In hazard area', false) : null}</>} />
                <Fact l="Flood events (area, 10 yr)" v={num(r.flood.floodEvents10yr)} />
                <Fact l="Area repetitive loss" v={r.flood.areaRepetitiveLoss ? `${num(r.flood.areaRepetitiveLoss.properties)} props · ${num(r.flood.areaRepetitiveLoss.totalLosses)} losses` : '—'} />
              </div>
            </div>
          </div>
        </Section>

        <Section title="Air"
          note={sourceLine(r.environmentSources, ['aqi_pm', 'noise', 'light_pollution', 'wildfire_smoke'])}>
          <div className="pir-tiles">
            <Tile l="Air quality index" v={r.air.aqiAnnualAvg ?? '—'} sub={r.air.aqiAnnualAvg != null && r.air.aqiAnnualAvg <= 50 ? 'Good (annual avg)' : 'Annual avg'} />
            <Tile l="PM2.5 / PM10" v={`${r.air.pm25 ?? '—'} / ${r.air.pm10 ?? '—'}`} sub="µg/m³" />
            <Tile l="Ozone" v={r.air.ozone ?? '—'} sub="ppb" />
            <Tile l="Wildfire smoke" v={`${r.air.wildfireSmokeDays ?? '—'} days`} sub="per year" />
            <Tile l="Noise (day)" v={`${r.air.noiseDbDay ?? '—'} dB`} />
            <Tile l="Light pollution" v={r.air.lightPollutionIndex ?? '—'} />
          </div>
          <div style={{ marginTop: 14 }}><WindDial wind={r.wind} /></div>
        </Section>

        <Section title="Land"
          note={<>Elevation, radon and sinkhole are property/area facts. Soil type & drainage classification is not sourced for Volusia and is omitted rather than guessed. {sourceLine(r.environmentSources, ['radon', 'sinkhole', 'water_quality'])}</>}>
          <div className="pir-grid">
            <Fact l="Ground elevation" v={r.land.elevationFt != null ? `${r.land.elevationFt} ft` : '—'} />
            <Fact l="Radon zone" v={r.land.radonZone != null ? `Zone ${r.land.radonZone}` : '—'} />
            <Fact l="Sinkhole risk" v={<>{titleCase(r.land.sinkholeRisk)} {r.land.sinkholeHistoryCount != null ? `· ${r.land.sinkholeHistoryCount} on record` : ''}</>} />
            <Fact l="Water service area" v={r.land.waterUtility
              ? <span>{r.land.waterUtility} <span style={{ fontSize: 11, color: 'var(--color-sage)' }}>(county service area — not confirmed per parcel)</span></span>
              : <span style={{ color: 'var(--color-sage)' }}>Not evaluated</span>} />
            <Fact l="Lead service line" v={titleCase(r.land.leadServiceLineRisk)} />
            <Fact l="Sewer / septic" v={<span style={{ color: 'var(--color-sage)' }}>Not evaluated — no parcel-level sewer/septic determination in the record</span>} />
            <Fact l="Protected species" v={r.land.gopherTortoiseInside ? riskChip('Within gopher tortoise habitat overlay', false) : r.land.gopherTortoiseNearestM != null ? `Nearest habitat ${mi(r.land.gopherTortoiseNearestM)}` : 'None mapped nearby'} />
            <Fact l="Sun / solar" v={r.climate.solarKwhM2Day != null ? `${r.climate.solarKwhM2Day} kWh/m²/day · ${r.climate.solarPeakHours} peak hrs` : '—'} />
          </div>
        </Section>

        <Section title="Water" note="One badge per off-property water feature and boat ramp within range. Flood-zone designation is folded into this page (above), not a separate section.">
          <Fact l="Nearest water" v={r.water.nearestWaterM != null ? `${r.water.nearestWaterM} m` : '—'} />
          <div style={{ marginTop: 12 }}>
            {waterBadges.length ? <CompassBadgeGrid badges={waterBadges} /> : <div className="pir-note">No mapped water features within range.</div>}
          </div>
        </Section>
      </Sheet>

      {/* ═══ PAGE 4 — NEIGHBORHOOD ═══ */}
      <Sheet page={4} total={5} title="Neighborhood Data" r={r}>
        <Section title="Zoning & future land use — 5-mile radius"
          note="Boundaries are real county geometry, dissolved to the standard land-use colour categories. Legend to the side.">
          <div className="pir-maprow">
            <PropertyReportMap coNo={co} parcelId={parcelId} layer="zoning" />
            <div>
              <Legend entries={zoningLegend} />
              <div style={{ marginTop: 12, display: 'flex', flexDirection: 'column', gap: 8 }}>
                <Fact l="Zoning" v={<>{r.zoning.zoneCode ?? '—'} {r.zoning.pudName ? `· ${titleCase(r.zoning.pudName)}` : ''}</>} />
                <Fact l="Future land use" v={r.zoning.futureLandUseName ? `${titleCase(r.zoning.futureLandUseName)}${r.zoning.futureLandUseCode ? ` (${r.zoning.futureLandUseCode})` : ''}` : '—'} />
              </div>
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

        <Section title="Census & demographics" note={`Block group ${r.census.blockGroup ?? '—'} (American Community Survey).`}>
          <div className="pir-tiles">
            <Tile l="Population" v={num(r.census.population)} sub="block group" />
            <Tile l="Median household income" v={usd(r.census.medianHouseholdIncome)} />
            <Tile l="Housing units" v={num(r.census.housingUnits)} />
          </div>
          <div style={{ marginTop: 14 }}><WindDial wind={r.wind} /></div>
        </Section>
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
