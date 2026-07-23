
=========================================================
## DOR STATEWIDE TAX ROLL (NAL + SDF) INGEST (2026-07-23)
Purpose: authoritative ground-truth to reconcile ArcGIS parcel pulls; homestead/exemption source.
Source: FL DOR Property Tax Oversight PTO Data Library (SharePoint), 2025 FINAL roll.
Scripts: ~/dor_load.py (single), ~/dor_bulk.py (all 67, resumable), ~/dor_plan.json (the map).
Log: ~/dor_bulk.log. Tables: <slug>_nal_dor_source (165 cols), <slug>_sdf_dor_source (23 cols).

### DOWNLOAD MECHANISM (enumerated via SharePoint REST, not the web UI)
BASE=floridarevenue.com/property/dataportal
List folder: {BASE}/_api/web/GetFolderByServerRelativeUrl('<rel>')/Files  (Accept: application/json;odata=verbose)
Tax Roll Data Files/{NAL,SDF}/2025F/  -> 67 per-county zips each, e.g.
  "Baker 12 Final NAL 2025.zip" -> contains NAL12F202502VAB.csv (VAB = post-value-adjustment-board, most final)
Direct download: HOST + quote(ServerRelativeUrl). Files are public, anonymous GET works.
FILENAME QUIRKS: "Dade 23" (=Miami-Dade), "Indin River 41" (typo), "Dixie...SDF 2025..zip" (double dot),
  "Collier...SDF  2025.zip" (double space). co_no is parsed from the filename, not the name text.

### FORMAT (per 2025 User's Guide, read in full)
CSV, comma-delimited, FIELD NAMES IN HEADER ROW (NOT fixed-width -- the fixed-width era was DBF).
NAL = 165 fields, SDF = 23. Load RAW: all columns text (PARCEL_ID is zero-padded, must stay text).

### KEY FIELD MAP (NAL) -- for the pairing audit + homestead signal
  CO_NO(1)          DOR county number 11-77 (alphabetical, Miami-Dade coded "Dade"=23). Join partition.
  PARCEL_ID(2)      up to 26 alnum, county-specific format. **The join key to our parcel tables.** text.
  DOR_UC(8)         DOR land use code 000-099 (full table captured). PA_UC(9)=county use code.
  JV(11)            just value = market value (~ FL "just value" in our contract).
  AV_SD/AV_NSD(14/15) assessed (school / non-school). TV_SD/TV_NSD(16/17) taxable.
  JV_HMSTD/AV_HMSTD(18/19)  homestead (Save-Our-Homes) just/assessed -- OWNER-OCCUPANCY signal.
  EXMPT_01(110)     homestead exemption $ (up to 25k). EXMPT_02(111)=additional. => homestead flag.
  APP_STAT(89)      homestead applicant status.
  OWN_NAME(74); OWN_ADDR1/2,OWN_CITY,OWN_STATE,OWN_ZIPCD (75-79)  = MAILING address.
  PHY_ADDR1/2,PHY_CITY,PHY_ZIPCD (99-102) = PHYSICAL/SITUS address.
    => owner-occupancy: homesteaded parcel => situs ~= mailing (the misattribution-defense signal).
  ALT_KEY(103); S_LEGAL(88) short legal; STATE_PAR_ID(162) DOR uniform parcel id; CENSUS_BK(98).
SDF key fields: CO_NO,PARCEL_ID,DOR_UC,SALE_PRC(19),SALE_YR/MO(17/18),QUAL_CD(16),
  OR_BOOK/OR_PAGE/CLERK_NO(13/14/15) -> links sales to Official Records.

### GOVERNANCE
Each table: RLS ON, ZERO policies => service_role only. PARCEL_ID indexed. Provenance in table comment.

### EMERGING RECONCILIATION SIGNAL (report only; root-cause is the task-3 pairing audit)
DOR NAL is consistently SLIGHTLY SMALLER than our ArcGIS parcel count, modest (~0.5-1%):
  Baker  13,064 vs 13,265  (-201)     Alachua 108,389 vs 109,057 (-668)
Direction is consistent (DOR < ArcGIS). Plausible: ArcGIS layers carry extra geometry features
(condo/sub-parcels, ROW slivers) or DOR excludes centrally-assessed/confidential rows. DO NOT
conclude before the pairing audit joins on PARCEL_ID.

### *** BONUS: DOR NAL FILLS OUR WALLED COUNTIES ***
6 counties have NO live parcel table -- exactly the ones we WALLED:
  18 Charlotte, 40 Holmes, 59 Osceola, 63 Polk, 66 St Lucie, 77 Washington.
Their DOR NAL lands with no delta comparison, but gives us authoritative parcel-level records
(owner/value/use/homestead/legal, no geometry) for counties where the ArcGIS pull failed.

### PENDING (task 3, GATED -- do not start): PARCEL_ID pairing audit DOR<->ArcGIS per county;
owner-occupancy (situs~=mailing) misattribution-defense signal from homestead+address fields.
