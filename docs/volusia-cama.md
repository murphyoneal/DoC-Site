
=========================================================
## DOR NAL FIX (12 urban-core) + VOLUSIA CAMA INGEST (2026-07-23)

### DOR TASK A -- 12 empty NAL fixed
Root cause: single COPY of a large NAL (200k-1M rows x165 cols) exceeded pooler statement_timeout,
died mid-stream ~line 256-370k. NOT memory/parse. Fix (~/dor_fix.py): SET statement_timeout=0 +
chunked COPY (50k/batch) + post-load assert count>0 + FAILED list + full 67x2 table.
Result: ALL 67x2 NON-EMPTY. NAL total=10,998,001  SDF total=2,122,122.
Skip predicate already keyed on count>0 (not existence) -- empty tables reloaded, not skipped.
*** CONDO-STACKING SIGNATURE in the deltas (DOR NAL vs our GIS parcels): ***
  Broward +200,462   PalmBeach +173,744   Pasco +10,047   Volusia +23,343  (DOR >> GIS)
  vs Miami-Dade -57,153  Duval -9,547  Lee -6,908 (GIS >= DOR, minor)
  The big +deltas are condo counties: DOR NAL lists each condo unit as a parcel; our polygon GIS
  stacks/omits them. This is exactly the GeoPlan condo-stacking fix the user described.

### VOLUSIA CAMA -- new source, SUPERSEDES DOR NAL for Volusia
Source: https://vcpa.vcgov.org/files/database/CAMA_DATA_EXPORT.zip (219MB zip -> 1.44GB .accdb,
ACE12). Layout: https://vcpa.vcgov.org/files/download/newLayout.pdf. Data current 2026-07-20
(weekly), retrieved 2026-07-23 -- vs DOR NAL's Jan-1-2025 snapshot (19 months stale).
Tooling: mdbtools reads the .accdb (mdb-tables/mdb-count/mdb-export). 18 tables (doc says 17;
+VCPA_CAMA_AGLAND). All keyed on PARID (=AltKey). Loaded via mdb-export -> chunked COPY.
Tables volusia_cama_<suffix>, service_role only (RLS on, no policies), PARID indexed, provenance
comment (source/current-as-of/retrieved). Total 7,249,446 rows, all 18 non-empty.

*** VERIFICATION GATE PASSED: AltKey 3671058 -> 2 owner rows (OWNSEQ 0 MCNEELY GENE, 1 MCNEELY
IRIS). Relational, NOT flattened. Round-trip confirmed in the loaded volusia_cama_owner too. ***

### THE SOURCE-HIERARCHY ANSWER (Volusia real-property parcel count, most->least complete):
  VCPA CAMA REAL-active (CUR=Y,ROLLTYPE=REAL) = 313,619   [weekly, 3 days old]  == CAMA_LEGAL 313,619
  DOR NAL 2025 Final                           = 309,344   [Jan-1-2025 snapshot, 19 mo]
  our volusia_parcels_govt_source (ArcGIS)     = 286,001   [GIS export]
  => CAMA > DOR NAL > GIS on BOTH completeness (+27,618 / +23,343 vs GIS) AND currency.
  For any SINGLE county, the county's own CAMA beats DOR on both axes. DOR's only edge was
  one-schema-for-all-67. Confirms: county CAMA is the spine where available.
Owner distinct PARID=343,841 (incl PP accounts). Homestead exemptions: 159,448 parcels (codes
01/04/05/24/26/27) -- the owner-occupancy signal, ~51% of real parcels.
Key value-add vs DOR NAL: multi-owner (OWNER table, OWNSEQ), full sales history 1.6M rows back to
1960s, buildings (RES_BLDG beds/baths), permits 992k, land lines, situs -- the 1:many
relationships the NAL flattens away.

### SCOPING (does the Volusia open-weekly-CAMA model generalize?) -- PRELIMINARY, don't-pull scan
Checked Baker, Broward, Palm Beach, Wakulla (the 4 with no owner column in our GIS):
  Baker (bakerpa.com): tax roll viewable; bulk only via TaxNetUSA (3rd-party, paid). No open export.
  Broward (bcpa.net): has a CAMA system (RFP-BCPA-CAMA.pdf) but bulk via Regrid/TaxNetUSA or request.
  Palm Beach (pbcpao.gov): some downloadable parcel datasets; bulk needs an account.
  Wakulla (qpublic/mywakullapa.com): hosted qPublic portal; parcel data via Dynamo Spatial/TaxNetUSA
    shapefile. No open CAMA export.
VERDICT: Volusia's open self-serve weekly relational CAMA zip appears UNCOMMON. The 4 checked
route bulk data through vendors / account-gated requests / hosted portals -- none an equivalent
open download. BUT the DOR NAL we already loaded fills the flattened owner/value/homestead gap for
all of them; the open question is only the FULLER relational per-county export, which is not freely
available for these 4. Definitive per-county answer needs direct site checks (not done -- scan only).
NOTE: this is a summary-search scan; qPublic/GSA portals sometimes have download links worth a
direct look before concluding a county has nothing.
