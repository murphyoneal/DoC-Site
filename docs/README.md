# DoP data-pipeline documentation

Durable engineering notes for the Florida property/GIS ingestion pipeline (Supabase project
`eaifqorwmgayiqmbtzcg`). These were migrated out of the WSL scratchpad — which resets — so the
hard-won findings survive. Style is terse working-notes; treat them as an engineering log, not
polished prose.

## Start here

- **[harness-invariants.md](harness-invariants.md)** — the non-negotiable ingest rules and the
  incident behind each. The condensed version is in the root `CLAUDE.md` so it loads every run.
- **[DATA_PIPELINE_LOG.md](DATA_PIPELINE_LOG.md)** — the complete chronological master log. The
  authoritative record; everything below is a focused extract of it. Includes earlier work not
  broken out into topic files (county source resolution, city GIS, econ/demographic datasets,
  hazards, insurance, sinkholes, the refresh system, etc.).

## Geographic architecture (multi-state / global spine)

- **[geo-box-arkansas.md](geo-box-arkansas.md)** — first out-of-state box/plug proof (AR/Crittenden).
- **[geo-box-british-columbia.md](geo-box-british-columbia.md)** — ISO-namespaced globalized backbone (BC/Capital-RD).
- **[geo-box-us-ar-rebuild.md](geo-box-us-ar-rebuild.md)** — clean `us_ar` reference implementation; the template FL's plug copies.

## Paging-corruption audit

- **[paging-audit-triage.md](paging-audit-triage.md)** — Prong-1 re-triage; the "column named `objectid` isn't the OID" false-positive class.
- **[paging-audit-prong2.md](paging-audit-prong2.md)** — the authoritative `returnIdsOnly` set-diff across all registered sources.
- **[paging-audit-remediation.md](paging-audit-remediation.md)** — the fix waves, the harness OID bug, and the non-ArcGIS (Prong-3) assessment.
- **[quarantine-procedure.md](quarantine-procedure.md)** — rename-indexes-with-the-table (the collision that broke the Orange re-pull three times).

## Authoritative roll & cadastral sources

- **[dor-tax-roll.md](dor-tax-roll.md)** — FL DOR PTO NAL + SDF statewide ingest; field map, homestead signal, the condo-stacking deltas.
- **[statewide-cadastral.md](statewide-cadastral.md)** — FDEP statewide cadastral FGDB; the `CO_NO=0` orphan finding and the three-way (cadastral / county GIS / NAL) audit.

## County-direct sources (Volusia)

- **[volusia-cama.md](volusia-cama.md)** — the county's full relational CAMA export; source hierarchy (CAMA > NAL > cadastral > county GIS) and the weekly snapshot clock.
- **[volusia-official-records.md](volusia-official-records.md)** — the Clerk of Court Official Records pipeline (private research layer).

## Product specification

- **[PIR_REPORT_SPEC.md](PIR_REPORT_SPEC.md)** — current, canonical Property Intelligence Report
  (PIR) specification (v4). Build against this.
- Superseded: **[archive/PIR_REPORT_SPEC_v3.md](archive/PIR_REPORT_SPEC_v3.md)** (v3) is kept for
  reference. v1 and v2 are dropped.

## Related, added manually (not generated here)

- `DATA_JOIN_FINDINGS.md` — full findings and evidence (referenced by `CLAUDE.md`).
- `PROVIDER_REASONABLE_PROCEDURES.md` — compliance framework (referenced by `CLAUDE.md`).
