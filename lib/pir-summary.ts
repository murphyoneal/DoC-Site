// Narration of a get_pir_report payload for the assistant.
//
// RULING 197. Roz used to assemble its own payload in TypeScript from
// get_site_intelligence, so twelve concepts wired into get_pir_report during the
// week — water, historic, wetland, sinkhole, aquifer, mining, surface geology,
// zoning, permits, transactions, tax deed, land restrictions — NEVER REACHED THE
// NARRATION LAYER. The report was rebuilt; the assistant was not, and the two
// paths silently diverged.
//
// The fix is one source of truth (get_pir_report) AND a renderer that cannot
// drift from it: every top-level block is walked GENERICALLY. A concept wired
// tomorrow shows up tomorrow without touching this file. Curated labels only
// improve wording — they never gate what is shown, so nothing is silently
// dropped the way it was before.
//
// Honesty rules encoded here:
//  * A value is never printed without its field_status when the status is not
//    "present" — the three coverage states (present / none-recorded /
//    not-available) must survive into the prose.
//  * source and as_of travel WITH the value. Roz previously reported
//    "elevation 21.9 ft" with no provenance at all; that is the fabrication
//    surface, because a number with no source reads as authoritative.

import { landUseLabel } from './dor-use-codes'

const CLEAN_STATUSES = new Set(['present', 'assigned', 'covered'])

/** A "fact" in this codebase: {predicate, value, field_status, source, as_of, ...}. */
function isFact(v: any): boolean {
  return v != null && typeof v === 'object' && !Array.isArray(v) && 'predicate' in v && 'field_status' in v
}

function label(key: string): string {
  const curated: Record<string, string> = {
    floodBlock: 'Flood', groundElevation: 'Ground elevation', water: 'Water',
    wetland: 'Wetland (parcel relation)', wetlandFacts: 'Wetland (NWI detail)', historicFacts: 'Historic',
    historicDesignations: 'Historic designations', sinkholeFacts: 'Sinkhole (reported)',
    sinkholeSusceptibility: 'Sinkhole susceptibility', aquiferVulnerability: 'Aquifer vulnerability',
    miningFacts: 'Mining', surfaceGeology: 'Surface geology', zoningFacts: 'Zoning',
    permitFacts: 'Permits', transactionFacts: 'Conveyances', taxDeedStatus: 'Tax deed status',
    landRestrictions: 'Land restrictions', contaminationFacilities: 'Contamination facilities',
    pollutionNotices: 'Pollution notices', censusFacts: 'Census / demographics',
    economic: 'Economic zones', marineBlock: 'Marine improvements', reposeWindow: 'Statute of repose',
    waterService: 'Water service', schoolsCoverage: 'Schools coverage', ownerFacts: 'Ownership',
    salesAgent: 'Listing agent', plat: 'Plat', land: 'Land overlays', amenities: 'Amenities',
    schools: 'Schools', disclosures: 'Disclosures', identityFrame: 'Identity frame',
  }
  if (curated[key]) return curated[key]
  return key.replace(/([a-z])([A-Z])/g, '$1 $2').replace(/^./, c => c.toUpperCase())
}

function fmt(v: any): string {
  if (v == null) return 'null'
  if (typeof v === 'boolean') return v ? 'yes' : 'no'
  if (typeof v === 'number') return String(v)
  return String(v)
}

/** Provenance suffix — the part whose absence made "elevation 21.9 ft" a fabrication surface. */
function provenance(o: any): string {
  const bits: string[] = []
  if (o?.source) bits.push(String(o.source))
  if (o?.source_tier) bits.push(String(o.source_tier))
  if (o?.as_of) bits.push('as of ' + String(o.as_of))
  return bits.length ? ` [${bits.join('; ')}]` : ''
}

/**
 * One array element as a short human phrase.
 *
 * The naive version fell back to JSON.stringify().slice(), which rendered permits
 * and conveyances as truncated JSON fragments — technically "shown", actually
 * unreadable, and the kind of output a narrator will either ignore or misread.
 * Known record shapes are named explicitly; the JSON fallback remains only so an
 * UNKNOWN shape is still visible rather than silently dropped.
 */
function describeItem(x: any): string {
  if (x == null) return '—'
  if (typeof x !== 'object') return String(x)

  // A fact inside an array (e.g. ownerFacts.owners[]) — render it as a fact.
  if (isFact(x)) {
    const pct = x.pct_own != null ? ` (${x.pct_own}%)` : ''
    return `${fmt(x.value)}${pct}`
  }

  // Conveyance
  if (x.instrument_number || (x.book && x.page)) {
    const amt = x.sale_price != null ? `$${Number(x.sale_price).toLocaleString()}`
              : x.consideration != null ? `$${Number(x.consideration).toLocaleString()} (consideration)` : 'no price'
    const mkt = x.market_signal?.value ? `, ${x.market_signal.value}` : ''
    return `${x.date ?? '—'} ${x.instrument_type ?? ''} OR ${x.book ?? '?'}/${x.page ?? '?'} ${amt}${mkt}`.replace(/\s+/g, ' ').trim()
  }

  // Permit
  if (x.subject?.permit_number || x.permit_number) {
    const num = x.subject?.permit_number ?? x.permit_number
    const closeout = x.closeout?.field_status === 'not_recorded' ? ', closeout not recorded' : ''
    return `${x.date ?? '—'} #${num}${x.description ? ' ' + x.description : ''}${closeout}`
  }

  // Flood zone / generic geometry share
  if (x.zone) return `${x.zone}${x.pct_of_parcel != null ? ` ${x.pct_of_parcel}%` : ''}${x.in_sfha ? ' (SFHA)' : ''}`

  const named = x.name || x.displayName || x.kind || x.title || x.aquifer || x.material ||
                x.wetland_type || x.cover || x.area
  if (named) {
    const extra = [
      x.pct_of_parcel != null ? `${x.pct_of_parcel}%` : null,
      x.acres_on_parcel != null ? `${x.acres_on_parcel} ac` : null,
      x.shoreline_ft != null ? `${x.shoreline_ft} ft shoreline` : null,
      x.distance_ft != null ? `${x.distance_ft} ft` : null,
      x.drastic_index != null ? `DRASTIC ${x.drastic_index}` : null,
      x.dominant_failure ? `failure: ${x.dominant_failure}` : null,
      x.character ? `(${x.character})` : null,
      x.nwi_code ? `[${x.nwi_code}]` : null,
    ].filter(Boolean)
    return `${named}${extra.length ? ' ' + extra.join(' ') : ''}`
  }

  // Unknown shape: keep it VISIBLE rather than dropping it, but flag it so the
  // gap in this renderer is obvious instead of looking like data.
  return `[unrecognised record: ${Object.keys(x).slice(0, 6).join(',')}]`
}

function renderFact(name: string, f: any): string {
  const status = f.field_status
  if (!CLEAN_STATUSES.has(status)) {
    // NOT a value. Say what we do not know and why, never a bare blank or a false.
    const why = f.derivation?.note || f.determination_note || f.note || f.coverage_note
    return `${name}: ${status}${why ? ` — ${why}` : ''}${provenance(f)}`
  }
  const note = f.determination_note || f.note
  return `${name}: ${fmt(f.value)}${note ? ` — ${note}` : ''}${provenance(f)}`
}

/** Summarise one top-level block without assuming its shape. */
function renderBlock(key: string, b: any): string[] {
  const name = label(key)
  if (b == null) return []

  if (Array.isArray(b)) {
    if (!b.length) return [`${name}: none recorded`]
    const head = b.slice(0, 5).map(describeItem)
    return [`${name}: ${b.length}${b.length > 5 ? ` (first 5: ${head.join(' | ')})` : ` — ${head.join(' | ')}`}`]
  }

  if (typeof b !== 'object') return [`${name}: ${fmt(b)}`]
  if (isFact(b)) return [renderFact(name, b)]

  const out: string[] = []
  const status = b.field_status
  const caveat = b.coverage_note || b.coverage_caveat

  if (status && !CLEAN_STATUSES.has(status)) {
    out.push(`${name}: ${status}${caveat ? ` — ${caveat}` : ''}${provenance(b)}`)
    return out
  }

  // Present (or unstated): pull out nested facts, then salient scalars/arrays.
  const parts: string[] = []
  for (const [k, v] of Object.entries(b)) {
    if (k === 'field_status' || k === 'coverage_note' || k === 'coverage_caveat' ||
        k === 'subject' || k === 'parcel' || k === 'who_can_answer' || k === 'note') continue
    if (isFact(v)) { parts.push(renderFact(k, v)); continue }
    if (Array.isArray(v)) {
      if (!v.length) continue
      // Same describeItem as the top-level branch — nested arrays (permits[],
      // conveyances[], owners[]) were rendering as truncated JSON because this
      // path had its own weaker extractor.
      const head = v.slice(0, 4).map(describeItem)
      parts.push(`${k}: ${v.length}${v.length > 4 ? ` (first 4: ${head.join(' | ')})` : ` — ${head.join(' | ')}`}`)
      continue
    }
    if (v != null && typeof v === 'object') {
      // e.g. water_body_adjacent {adjacent, name, kind, shoreline_ft}
      const inner = Object.entries(v)
        .filter(([, iv]) => iv != null && typeof iv !== 'object')
        .map(([ik, iv]) => `${ik}=${fmt(iv)}`)
      if (inner.length) parts.push(`${k}: ${inner.join(', ')}`)
      continue
    }
    if (v != null && v !== '') parts.push(`${k}=${fmt(v)}`)
  }

  if (!parts.length) return [`${name}: recorded, no detail fields populated`]
  out.push(`${name}: ${parts.join('; ')}${caveat ? ` — NOTE: ${caveat}` : ''}${provenance(b)}`)
  return out
}

// Rendered explicitly at the top; excluded from the generic sweep below.
const CORE = new Set(['meta', 'property', 'values', 'tax'])

export function summarisePirReport(r: any, countyName: string): string {
  const meta = r?.meta ?? {}
  const p = r?.property ?? {}
  const lines: string[] = []

  lines.push(`Parcel ${meta.parcelId ?? '—'} — ${meta.countyName ?? countyName} County`)
  if (p.address || p.city) lines.push(`Address: ${p.address ?? '—'}, ${p.city ?? '—'} ${p.zip ?? ''}`.trim())
  if (p.ownerName) lines.push(`Owner: ${p.ownerName}${p.ownerOccupied != null ? ` (homestead: ${fmt(p.ownerOccupied)})` : ''}`)
  // DEFECT roz-glosses-opaque-codes-with-invented-meaning. This rendered
  // `Use: — (DOR 092)` when the payload carries a code but no propertyType (which
  // is the case for the Palm Beach parcel that produced the defect). A dash and a
  // naked number is an invitation to explain it, and the narrator accepted.
  // Fall back to landUseLabel, which names the code as UNDEFINED when we hold no
  // description rather than presenting it as a label with a word missing.
  if (p.propertyType || p.landUseCode) {
    // landUseLabel already embeds the code when it has no description, so only
    // append "(DOR nnn)" alongside a real propertyType.
    lines.push(p.propertyType
      ? `Use: ${p.propertyType}${p.landUseCode ? ` (DOR ${p.landUseCode})` : ''}`
      : `Use: ${landUseLabel(p.landUseCode)}`)
  }
  if (p.yearBuilt) lines.push(`Year built: ${p.yearBuilt}${p.effectiveYearBuilt ? ` (effective ${p.effectiveYearBuilt})` : ''}`)
  if (p.livingSqft || p.totalSqft) {
    lines.push(`Area: living ${p.livingSqft ?? '—'} sqft, total ${p.totalSqft ?? '—'} sqft` +
      (p.livingAreaSource ? ` [${p.livingAreaSource}]` : ''))
  }
  // Assessor vs GIS lot size stays side by side — a missing assessor value is
  // "not recorded", never 0.
  lines.push(`Lot size: GIS-calculated ${p.gisAcres != null ? Number(p.gisAcres).toFixed(2) + ' ac' : 'not available'}`)
  if (p.subdivision) lines.push(`Subdivision: ${p.subdivision}`)
  if (p.legal) lines.push(`Legal: ${String(p.legal).slice(0, 200)}`)

  // valuesFacts is an OBJECT KEYED BY PREDICATE (just_value, land_value, ...), not
  // an array. An earlier draft tested Array.isArray and silently fell through to
  // "roll year only" — dropping just value, which the previous tool DID report.
  // That is a regression the generic sweep would not have caught, because `values`
  // is rendered here rather than in the sweep.
  const vFacts = r?.values?.valuesFacts
  const rollYear = r?.values?.rollYear ?? r?.values?.assessedYear ?? 'not recorded'
  if (vFacts && typeof vFacts === 'object') {
    const entries = Array.isArray(vFacts)
      ? vFacts.map((f: any) => [f.predicate ?? 'value', f] as [string, any])
      : Object.entries(vFacts)
    const rendered = entries.filter(([, f]) => f != null).map(([k, f]) =>
      isFact(f) ? renderFact(k, f) : `${k}: ${fmt(f)}`)
    lines.push(rendered.length
      ? `Values (roll year ${rollYear}): ${rendered.join(' | ')}`
      : `Values: roll year ${rollYear}, no value facts recorded`)
  } else if (r?.values) {
    lines.push(`Values: roll year ${rollYear}, no value facts recorded`)
  }
  if (r?.tax) lines.push(...renderBlock('tax', r.tax))

  // ── Generic sweep: EVERY remaining block, in payload order. ──
  // This is the anti-drift mechanism. Nothing is filtered out by an allow-list,
  // so a concept wired into get_pir_report appears here without a code change.
  for (const key of Object.keys(r ?? {})) {
    if (CORE.has(key)) continue
    try {
      lines.push(...renderBlock(key, r[key]))
    } catch {
      lines.push(`${label(key)}: present but could not be summarised (shape unexpected) — report this`)
    }
  }

  return lines.join('\n')
}

/** Concepts present in the payload, for telemetry/debugging. */
export function pirConceptCount(r: any): number {
  return Object.keys(r ?? {}).length
}
