# THE LENS

> GENERATED FILE - DO NOT HAND-EDIT.
> The source is the `lens` table. Regenerate with `SELECT export_lens_markdown();`.
> An edit made here is not in the source and will be discarded by the next export.
> Append and supersede in the table, never delete: set `superseded_by` on the old row
> and insert the new one.

Live entries: 39 | superseded (retained as history): 2

---

## 00-purpose

### 1. THE LENS IS THIS TABLE, NOT THE MARKDOWN

`principle` | measured: 2026-08-16 | claude

docs/THE_LENS.md is an EXPORT. This table is the source, because a markdown file in a working tree drifts, gets overwritten by a sync, or is lost to a git clean - all three happened to something on this project in one day.
APPEND AND SUPERSEDE, NEVER DELETE. Set superseded_by on the old row and insert the new one, so the reasoning trail survives and a future reader can see WHY a rule changed rather than only what it now says.
Both agents read: select * from lens where superseded_by is null order by section, ordinal.

## 01-where-answers-live

### 1. THREE ATTRIBUTES BELONG ON THE TABLE, ONE RELATION BELONGS IN A REGISTRY

`principle` | measured: 2026-08-16 | claude

WHAT IS THIS (LADM class, register, agency), WHAT DOES EACH COLUMN MEAN, and HOW DOES IT JOIN are PROPERTIES OF THE TABLE and belong on it. WHICH TABLE ANSWERS THIS CONCEPT FOR THIS PLACE is a RELATION between tables and belongs in layer_resolution.
A LABEL ON THE CARD CANNOT BE SEPARATED FROM THE CARD. A notebook about the cards can, and on 16 August the notebook and the deck came apart five ways: table_inventory drifted on 328 rows, 48 geom_column values pointed at columns that do not exist, 7 column-map entries pointed at row identifiers, palmbeach_zoning was labelled zoning and was not, and 54 municipal layers sat registered and unread for weeks. EVERY ONE WAS IN THE LEDGER, NONE IN A TABLE COMMENT.
Roughly two thirds of what was built is attribute that was put in a ledger. That is the shuffling.

## 02-declaration

### 1. THE DECLARATION LINE - AGENCY ABBREVIATION, NEVER THE URL

`rule` | measured: 2026-08-16 | claude

One structured line per table in the PostgreSQL table comment:
  PROVENANCE: <agency> | <register> | <ladm_class> | <authority> | <as_of>
  KEY: <column> [transform] | GEOM: <column> | ROLES: <role>=<column>, ...
  NOTE: <anything a human needs>
AGENCY ABBREVIATION ONLY - FEMA, FDEP, FWC, USFWS, DOR, USGS, EPA, NPS, SFWMD, SJRWMD, or the county name.
A REPORT THAT PRINTS A HYPERLINK HANDS THE SOURCING TO WHOEVER READS IT. The URL lives in data_source_registry for the refresh job and never leaves the database.

### 2. THE SYNC OVERWRITES - THE HAZARD IS NARROWER THAN FIRST STATED

`correction` | measured: 2026-08-16 | cc

sync_table_provenance_comments() overwrites the WHOLE comment. CC MEASURED THE ACTUAL EXPOSURE: it only visits tables registered as ACTIVE SOURCES, and there are ZERO non-PROVENANCE comments on registered tables. Nothing written so far is at risk.
THE HAZARD STARTS THE MOMENT A DECLARATION LINE IS WRITTEN ONTO A REGISTERED TABLE. Teach it to merge before that, not before anything else. 988 of 2,112 populated tables carry a comment.

## 02A-ladm

### 1. THE VOCABULARY IS ISO 19152. A STANDARD YOU INVENTED CANNOT BE CHECKED BY ANYONE.

`mapping` | authority: ISO 19152 multi-part | measured: 2026-08-16 | murphy

19152-1:2024 generic conceptual model - party, RRR, BAUnit, spatial unit, versioned object, source
19152-2:2025 LAND REGISTRATION   -> the JURIDICAL register   prefix PART2_ / LA_
19152-3:2024 marine              -> not used
19152-4:2025 VALUATION           -> the FISCAL register      prefix PART4_ / VM_
19152-5:2025 SPATIAL PLAN        -> the REGULATORY register  prefix PART5_
NAMING RULE: col_role is <class>_<attribute> in lower snake - vm_valuationunit_id, la_party_name, la_spatialunit_area, la_administrativesource_book. Genuinely outside land administration takes ext_.
PRE-STANDARD ROLES ARE NOT RETROFITTED. owner, grantor, grantee, zone, code, bfe, contractor stay until each is next touched. Rewriting 436 rows to prove a point would risk live readers for no gain.

### 2. PART 4 CORRECTS THE_FISCAL_CADASTRE_PROBLEM - THE TAX ROLL IS INSIDE THE STANDARD

`correction` | authority: ISO 19152-4:2025 | measured: 2026-08-16 | claude

THE_FISCAL_CADASTRE_PROBLEM.md says taxation and valuation are explicitly OUTSIDE LADM scope. TRUE OF ISO 19152:2012. FALSE OF THE 2024/2025 MULTI-PART EDITION.
Part 4 IS valuation and it BUILDS ON Parts 1 and 2 - a compliant valuation system must be modelled using or extending party, RRR, BAUnit, spatial unit and versioned object. THE FISCAL REGISTER IS NOT A FOREIGN OBJECT BOLTED ONTO THE MODEL.
Ten classes: VM_ValuationUnit, VM_ValuationUnitGroup, VM_SpatialUnit, VM_Building, VM_CondominiumUnit, VM_Valuation, VM_MassAppraisal, VM_Transaction, VM_SalesStatistic, VM_ValuationSource.
VM_CondominiumUnit IS THE SARASOTA DEFECT WITH A NAME. We derived the lot-versus-interest split by getting one condo wrong - one unit, two valid records, the owner and the HOA, 58,000 parcels. Part 4 lists valuation units as parcel, BUILDING, CONDOMINIUM UNIT and group. Four levels where we had one.
The fiscal-versus-juridical framing still explains WHY the data behaves as it does. It was wrong only about the standard having a gap.

## 03-authority

### 1. AUTHORITY IS A LABEL ON EVERY REPORTED LAYER, NOT A RANKING

`principle` | measured: 2026-08-16 | murphy

WE REPORT EVERY LAYER. WE DO NOT PICK A WINNER. Four flood layers means four reported findings, each carrying who published it. The tier is DISCLOSURE, not selection.
  originator     the agency that created the determination - FEMA for NFHL, FDEP for contamination
  republisher    a county or agency serving someone else data back, often at an older vintage
  derived        computed by us
  unestablished  source not recorded - CANNOT SUPPORT A NEGATIVE FINDING
Derivable today from the existing source_url with no research: republisher 341 tables / 49.1M rows, unestablished 108 / 11.8M, originator 84 / 12.8M, derived 16 / 2.6M.
A TIER DERIVED FROM A URL IS A CLAIM ABOUT THE URL. dep.state.fl.us is originator for FDEP own layers and republisher for anything FDEP mirrors. Mark it derived_from_url until confirmed.
precedence IS JURISDICTION LEVEL - municipal over county over state - AND IS NOT AUTHORITY. All 67 flood layers sit at precedence 2 and that is CORRECT: they are all county-level and all four authority tiers are represented among them.

## 04-registry

### 1. CONCEPT_REGISTRY IS THE SKELETON KEY AND IT DOES NOT GROW PER STATE

`principle` | authority: ISO 19152-1 generic conceptual model | measured: 2026-08-16 | murphy

What is the flood zone is the same question in Florida, Arkansas and British Columbia. 65 rows today; adding a state adds ZERO. LADM says the same - the model is generic, the PROFILE is per-country.
Mapping 67 counties to each other is 2,211 mappings. Mapping each to a standard is 67. Hub and spoke, not mesh.
ADDING A STATE: attributes are per-table and unavoidable either way; relations are ~150 rows; the standard is unchanged.

### 2. A CONCEPT IS ONLY HONEST IF EVERY MEMBER SHARES THE SAME OBLIGATION

`rule` | measured: 2026-08-16 | claude

If two layers under one concept oblige a buyer to do different things - hire a biologist and file a federal permit, versus nothing at all - IT IS A BUCKET, NOT A CONCEPT, and it will render a false finding.
environmental_overlay was RETIRED 16 August, 8 layers to 0, for exactly this: it rendered a $30,650-per-acre federal take permit and a 29-year-old unfunded wish list IDENTICALLY, because it named no authority.
Split into listed_species_habitat (ESA / BGEPA / FWC), conservation_land (designated, managing agency named) and conservation_acquisition_interest (NOMINATED - 606 of 629 never acquired).

### 3. CLASSIFY BY OBLIGATION, NOT BY SHAPE

`rule` | measured: 2026-08-16 | claude

FOUR TABLES WERE CLASSED AS CONTEXT AND ARE RESTRICTIONS:
  miamidade_taxing_cdd    Ch.190 CDD - a NON-AD-VALOREM ASSESSMENT on every parcel inside, often 30 years
  lee_mstbus              MSTU/MSBU - levies millage or a per-unit assessment
  palmbeach_seniors_community  55-plus is an OCCUPANCY RESTRICTION under the Housing for Older Persons Act
  pinellas_assisted_housing    carries subsidyexpire - the date the affordability restriction LAPSES
ALL FOUR ARE BOUNDARIES, AND A BOUNDARY LOOKS LIKE AN ADMINISTRATIVE LAYER.
THE TEST: DOES CROSSING THIS BOUNDARY CHANGE WHAT THE OWNER OWES OR WHAT THEY MAY DO?
  Taxing districts, overlay districts, occupancy-restricted communities, affordability covenants - YES.
  Patrol zones, EMS areas, garbage routes, polling places - NO.
This is the environmental_overlay lesson in a different bucket. A CLASS THAT GROUPS BY SHAPE RATHER THAN BY
OBLIGATION WILL ALWAYS MIX A RESTRICTION WITH SCENERY.

## 05-reading

### 1. SEVEN TESTS BEFORE DECLARING A TABLE. NEVER FROM THE NAME.

`test` | measured: 2026-08-16 | claude

1 DISTINCT VALUES on the answer column. Zero answers nothing. Equal to the row count is an IDENTIFIER - six column-map entries pointed at objectid or ogc_fid. EXCEPTION: a district-level layer legitimately has one polygon per value (westpalmbeach zoneclass 87/87 is CORRECT).
2 SAMPLE THE VALUES. rezone had twelve plausible values and was the ordinance field, not the district.
3 ROW COUNT AGAINST THE POPULATION. 15 rows for a city zoning is a district map or a defect. 1,597 polygons for 682,984 parcels is a GENERALISED map wearing a precise label.
4 LOOK FOR THE HISTORY COLUMN. Nine found: originalzone, rezone, prevflum, previouszoning, previous_zoning, flupy_zone_from, priorusety, stlucie previouszo/previous_1/2/3. A ZONING TABLE VERY OFTEN CARRIES ITS OWN HISTORY AND THE HISTORY COLUMN IS NAMED PLAUSIBLY.
5 SINGLE-VALUED FLAG IS A SENTINEL, NOT CLEARANCE. cor_status A on all 436. confidential NO on all 527,837. Either filtered at source or dead - ask, never assume.
6 NUMBERED SIBLING COLUMNS ARE ONE OF TWO THINGS. ownerline1..5 are ORDINAL PARTS of one value - read one, leak four. flu_l1/flu_l2 are a HIERARCHY with different value domains, disagreeing on 227 of 401 rows. COMPARE THE VALUE DOMAINS.
7 NEGATIVE CONTROL ON THE SUBSET WHERE THE FIELD VARIES. A 99.94% agreement had a 94.23% chance rate because 97% of parcels had one address. On the varying subset: 98.02% vs 37.77%. A POPULATION DOMINATED BY ONE VALUE WILL PASS ANY TEST.

### 2. A POPULATED TEST MUST btrim. BLANK-NOT-NULL DEFEATS THE TEST EVERYONE WRITES.

`test` | measured: 2026-08-16 | claude

IS NOT NULL AND <> '' IS NOT ENOUGH. A whitespace string passes both.
MEASURED: fl_erp_conservation_easements BOOKNO returned 687 of 687 populated on the naive test. THE VALUES ARE SPACES. With btrim: 291 of 687, 42.4%. PAGENO 288. So 396 recorded conservation easements carry NO BOOK NUMBER and the naive test says they all do.
THIS IS THE SENTINEL CLASS IN ITS QUIETEST FORM. Every prior instance was a value that MEANT absence - 999 INCORPORATED, -9999 BFE, occu=2. THIS ONE IS ABSENCE WEARING THE SHAPE OF PRESENCE.
STANDARD PREDICATE EVERYWHERE: btrim(coalesce(col,'')) <> ''.
And it was caught by PRINTING A SAMPLE, not by a count. Counts agree with a wrong assumption; a sample argues with it.

### 3. A 60% MATCH RATE IS OFTEN A TWO-LEVEL MODEL, NOT A BAD KEY

`test` | measured: 2026-08-16 | claude

Before recording a poor match rate, LOOK FOR A PARENT COLUMN. Miami-Dade folio measured 60.6% against the spine and
the combined parent-or-self key measured 98.83%.
The rows that failed were not unmatched. THEY WERE MATCHED AT A DIFFERENT LEVEL - condo units whose complex, not
whose unit, is the taxable object.
SAME SHAPE, DIFFERENT NAMES, ACROSS THE DATABASE: parent_folio (Miami-Dade), nparno (GeoPlan statewide key),
(co_no, parcel_id) (our own composite). All three are answering "which object is the one the register keys on".

### 4. A TWO-DIGIT YEAR HAS NO CENTURY. THE PIVOT IS NOT A BUG, AND CROSS-FIELD COHERENCE IS THE ONLY RECOVERABLE SIGNAL.

`test` | measured: 2026-08-16 | cc

REPORTED AS "7 COMPL_DATE values parsed 1927-1930". MEASURED, IT IS A DEFECT 173x LARGER WEARING A
SEVEN-ROW DISGUISE.

volusia_cama_permits.COMPL_DATE and .PERMDT are BOTH text, and all 427,978 populated COMPL_DATE values
share ONE format: MM/DD/YY. regexp_replace(btrim(col),'[0-9]','N','g') returns exactly one distinct
pattern - that one query is the fastest way to find this class anywhere. THE CENTURY IS ABSENT FROM THE
SOURCE FIELD. It was never lost by us and cannot be recovered from the field.

cama_date() resolves it with a FIXED pivot of 2026, the extract vintage, so any yy > 26 becomes 19yy.
THAT IS CORRECT FOR THE HISTORICAL BULK - yy 57 -> 1957, yy 68/69 -> 1968/1969, 55 rows of genuinely
mid-century permits - AND WRONG FOR A DATE IN THE FUTURE, which is exactly where 1927-1930 came from.
NO PIVOT FIXES THIS. Raising it to catch 2027 re-dates the real 1957 and 1969 records. A two-digit year
is a lossy encoding and the pivot only chooses WHICH cases are wrong, never whether any are. The pivot
being a documented deliberate constant rather than a drifting default is the correct design already.

SO DO NOT CHECK THE YEAR. CHECK THE FIELDS AGAINST EACH OTHER. A permit cannot be completed before it was
issued. Over 427,493 permits carrying both dates:
  1,214  complete BEFORE they were issued
     13  of those by more than 50 years   <- the century flip, containing all 7 reported rows
  1,035  by less than a year              <- ordinary data entry, NOT a century problem
GROUPING BY "LOOKS LIKE A WRONG CENTURY" WOULD HAVE FOUND 13 AND MISSED 1,201. The visible symptom was
the rarest form of the defect.

AND THE CHECK HAS A BLIND SIDE THAT MUST BE STATED: a future completion date lands before the issue date
ONLY because the issue date is 20xx. A future completion on a PRE-2000 permit passes this check while
still being wrong by a century. The coherence test is the best available signal, not a complete one.

DISPOSITION IS disclose, NOT repair. The county published these strings; rewriting a stored value
destroys the evidence of what the source said (11-traceability/1). Decline to assert a date known to be
incoherent, put the raw string in date_note, and say why. Registered as
permit-completion-date-precedes-issue-date; detection returns ok=false, examined 427,493, hit 1,214.

## 05A-family

### 1. DECLARE BY FAMILY - 17 SIGNATURES COVER 796 TABLES

`rule` | measured: 2026-08-16 | claude

Find families with md5(string_agg(column_name ORDER BY column_name)) over information_schema.columns. Tables sharing a signature share a loader, a source AND A DEFECT SURFACE. Verify the key ONCE on one member, declare the family, the set lands together.
RESULT 2026-08-16: ladm_declaration 51 -> 948 tables. layer_column_map 436 -> 2,999 rows across 1,037 of 2,112 populated tables.

### 2.1. ONE SUFFIX HID TWO PRODUCTS, AND I NAMED THEM BACKWARDS UNTIL I READ THE SOURCE

`correction` | authority: FGDL parcels metadata crosswalk, UF GeoPlan Center | measured: 2026-08-16 | murphy

parcels_govt_source is not two schemas of one thing. IT IS TWO DIFFERENT PRODUCTS AT DIFFERENT STAGES OF PROCESSING.
  96-column = THE RAW COUNTY / DOR SUBMISSION.        KEY IS parno.     parcelid 100% NULL.
              Dixie, Taylor, Suwannee, Madison, Gilchrist, Lafayette, Union - 111,777 rows.
              Dixie carries 31 of 31 original-submission fields.
  75-column = THE FGDL / UF GEOPLAN CLEANED PRODUCT.  KEY IS parcelid.  nparno is the STATEWIDE key.
              Liberty, Calhoun, Jefferson, Bradford, Gadsden, Gulf, Franklin.
              Calhoun carries 1 original field and 13 GeoPlan-added ones.
I CALLED THE RAW ONE THE FGDL VARIANT FROM A COLUMN COUNT. FGDL PUBLISHES ITS CROSSWALK AND THE FIRST LINE IS
PARNO = PARCELID - the ORIGINAL county field is PARNO and GeoPlan RENAMES it. I had the direction of the arrow
backwards and would never have caught it from inside the database.
NPARNO IS THE STATEWIDE-UNIQUE KEY: 12-013- prefixed to parcelid = STATE FIPS + COUNTY FIPS + LOCAL ID. GeoPlan
ships as one column what parcels_staging builds by hand as a (co_no, parcel_id) composite.
THE DANGER REMAINS AND IS UNCHANGED: keying the raw variant on parcelid returns ZERO ROWS AND NO ERROR, which
renders as none_recorded and reads as a clean parcel.

### 2.2. THE CLEANED PRODUCT ALREADY PERFORMS THREE REPAIRS WE HAVE BEEN DOING BY HAND

`correction` | authority: UF GeoPlan Center, Florida statewide parcel compilation | measured: 2026-08-16 | claude

From the UF GeoPlan Center published description of the statewide parcel compilation:
 1. IT RESOLVES DUPLICATE PARCEL IDS AND JOINS MULTI-PART PARCELS TO A SINGLE RECORD. THAT IS DEF-003 - 97,380
    fragmented parcels, worst case 1,215 fragments, which hid a historic district on Vizcaya and 16 of 19
    contamination facilities on a Collier parcel. THE CLEANED PRODUCT HAS ALREADY FIXED IT.
 2. IT CREATES STACKED POLYGONS FOR CONDO UNITS where a county files units separately - THE SARASOTA
    LOT-VERSUS-INTEREST DEFECT - adding roughly 370,000 condo owners statewide that a raw county layer lacks.
 3. It adds standardised city and zip on the physical address, and land-use descriptions against DOR codes.
TEN DUPLICATES SURVIVE EVEN SO: Calhoun gcid 10,985 of 10,985 unique; parcelid and nparno both 10,975. GEOPLAN
REDUCES DUPLICATION, IT DOES NOT ELIMINATE IT.
DATA_JOIN_FINDINGS FLAGGED THIS IN JULY - a remediated version exists, evaluate it before building our own - AND IT
WAS NEVER ACTIONED. We have since spent significant effort on fragment aggregation and condo unit-versus-complex
resolution that GeoPlan performs as a published step.
AND IT CHANGES EVERY COUNT COMPARISON: Broward -211,121, Palm Beach -202,191, Manatee +114,576 were read as county
versus spine. THEY ARE ALSO RAW VERSUS CLEANED. Manatee +114,576 against a known 29% duplicate-key defect is
exactly what an UNRESOLVED raw submission looks like.
AUTHORITY LABEL: the raw submission is the ORIGINAL RECORD. The GeoPlan product is DERIVED and must never be
labelled originator.

### 3. KEYS VERIFIED BY FAMILY, WITH THE NEGATIVE CONTROL

`measurement` | measured: 2026-08-16 | claude

Every family key carries a measured wrong-county control. A high match rate alone proves a row came back, not that
the RIGHT row came back.
  DOR NAL      67 tables  99.55%  control 0
  DOR SDF      67 tables  99.73%  control 0    PARCEL_ID deliberately NOT unique - a parcel has many sales
  cadastral     1 table   99.10%  control 0.05%  LIFT 2,127x
  FGDL parcels  9 tables  99.60%  control 0     key is parno
Where a family has no parcel key at all - amenities, disaster declarations, burn history - it is EXT_ and joins
SPATIALLY or not at all. A school has no RRR over the subject parcel and can never be a restriction.

## 06-source-first

### 1. START FROM THE SOURCE. THE DATABASE CANNOT TELL YOU WHAT A TABLE IS.

`principle` | measured: 2026-08-16 | murphy

TWICE IN ONE SESSION AN ANSWER EXISTED ONLY OUTSIDE THE DATABASE:
 1. I named the two parcel products backwards from a column count. FGDL PUBLISHES A CROSSWALK and its first line is
    PARNO = PARCELID. Both schemas look like plausible county files from the inside; only the publisher says which
    direction the rename goes - and the same document revealed that the cleaned product ALREADY RESOLVES DUPLICATE
    PARCEL IDS, JOINS MULTI-PART PARCELS, AND STACKS CONDO UNITS. That is DEF-003 and the Sarasota defect, fixed
    upstream, while we built our own.
 2. ISO 19152-4:2025 covers VALUATION. I had written that the tax roll was outside the standard. True of the 2012
    edition, false since. The correction came from the standard, not the data.
THE RULE: WHEN A TABLE IS UNFAMILIAR, READ THE PUBLISHER BEFORE READING THE ROWS. Row counts, column names and
distinct values tell you what IS there. Only the source tells you WHAT IT IS, what has already been done to it, and
what the publisher itself says is unreliable.
AND THE PUBLISHER SOMETIMES SAYS SO IN THE DATA: the FDEP family carries source_url AND layer_note PER ROW - "DRASTIC
Floridan - MODELLED INDEX", "NWI - REGIONAL inventory, NOT a jurisdictional delineation", "Released phosphate mine -
reclamation discharged, altered fill persists". THAT IS THE DECLARATION LINE, ALREADY BUILT, ON 17 TABLES. Copy the
pattern rather than inventing it.

### 2. CARDINALITY IS STILL THE TELL - 140 VALUES IN 687 ROWS IS NOT A CLASSIFICATION

`test` | measured: 2026-08-16 | claude

fl_erp_conservation_easements.TYPE looked like an easement classification. It is a GIS technician talking to
themselves: "eyballed in", "looks odd on doq", "seems ok", "possibly ok", "manually adjusted to doq", "poly
relocated per district requ", "no doq in middle of nowhere on d".
Mixed with genuine classes - Conservation Easement, Proprietary, Regulatory, Perpetual, Mangrove Swamp - and with
spelling variants of each: Concservation Easement A, Forested Wetalnds, Cypress Dome and Wet Prairrie.
AND SOME OF THE NOTES ARE THEMSELVES FINDINGS: "May not be recorded" and "No legal description" are the publisher
telling you this easement may not be enforceable as mapped. THAT IS WORTH MORE THAN THE CLASSIFICATION WOULD HAVE
BEEN, and serving TYPE as a code would have destroyed it.
DO NOT MAP IT. Serve presence, the recording reference where btrim shows one, and the caveat.

## 07-acquisition

### 1. THE COUNTY LAYER ACQUISITION SYSTEM

`rule` | measured: 2026-08-16 | claude

ArcGIS Hub DCAT-US feed: every county hub publishes .../api/feed/dcat-us/1.1.json listing every dataset with its REST endpoint. Parse title and accessURL where format is ArcGIS GeoServices REST API. This is how Putnam and Lake were enumerated on 20 July.
READ THE SERVICE DIRECTORY, NEVER PROBE A GUESSED LAYER PATH. .../MapServer?f=json lists every layer with its name and ID.
PARCELS USUALLY ARE NOT ON THE COUNTY HUB - they sit on the Property Appraiser own server, and the statewide spine already covers them.
FOR THE 20 COUNTIES WITH NO ZONING LAYER, TWO REGIONAL SERVERS COVER 14: SRWMD 8, ARPC 6. Two directories, not twenty.

### 2. ACQUISITION INVARIANTS, EACH BOUGHT WITH A FAILURE

`rule` | measured: 2026-08-16 | claude

returnIdsOnly SET-DIFF IS THE ONLY COMPLETENESS CHECK. A page loop cannot detect its own truncation. Citrus at exactly 6,000 and Sumter at exactly 4,000 are open suspects.
FDEP PUBLISHES EPSG 6439 (NAD83 Florida GDL Albers, metres). Treat it as the FDEP default, not an exception.
BUT DO NOT REPROJECT AT PULL - land native, reproject in Postgres into a SECOND column. All 1,574 spatial tables are 4326 today and NOTHING holds a native projection, so the loss is universal and the forward fix is deleting a parameter.
PAGE SIZE: NPS caps at 250. NHD MaxRecordCount is 1000, not 2000.
NPS NRHP filters on State=FLORIDA, not FL.
ABORT ON ZERO. An empty return is a sentinel for a wrong filter, never an answer.
reltuples ROUNDS for large tables. Only exact count(*) proves a round number is truncation.
statement_timeout=0 IS FOR A LOAD YOU HAVE DECIDED TO WAIT FOR. On an exploratory query it removes the only signal that the design is wrong - it cost CC 12 minutes of self-inflicted lock contention.

## 08-serving

### 1. THE RESOLVER TEST - PASSED 16 AUGUST

`closed` | measured: 2026-08-16 | cc

ONE of 75 served functions called resolve_layer. So registered 419->557 and in-resolver 375->492 were PROVENANCE AND REACHABILITY, NOT SERVING.
CC RAN THE TEST AND IT PASSED. A 60th sinkhole layer registered with column names nothing in the code knows - incident_dt, confirmed_flag, depth_feet, shape - MADE THE REPORT CHANGE WITH NO DEPLOY. Removing it changed it back.
AND THE PREMISE WAS HALF WRONG, WHICH IS WHY IT WAS WORTH RUNNING. get_parcel_sinkhole_facts ALREADY read layer_resolution - the TABLE choice was data-driven. What was hardcoded was the COLUMNS, and the 59 maps declared exactly one role. THE MECHANISM THE TEST PROVES DID NOT EXIST UNTIL THE DAY IT WAS TESTED.
STANDING TEST FOR ANY CONCEPT: register a new layer for a place, confirm a report changes with no deploy, remove it, confirm it reverts. A CONCEPT IS NOT DONE WHEN ITS LAYERS ARE DECLARED. IT IS DONE WHEN A NEW LAYER CHANGES A REPORT WITH NO DEPLOY.

### 2. AN UNDECLARED LAYER IS NOT INERT, IT IS LOAD-BEARING

`closed` | measured: 2026-08-16 | cc

get_pir_report was RAISING - returning no payload at all - for 17 counties INCLUDING PALM BEACH. _zoning_lookup built its query with format(%I, code_column) on a NULL, ONE LINE BEFORE the exception handler that would have caught it. Twenty zoning layers sat in the resolver with zero column-map rows.
THE BOARD COULD NOT SEE IT BECAUSE AN EXCEPTION IS NOT ok=false. That is the DEF-006 lesson from the other side, twice in one day, opposite directions. NEITHER AGENT READS error_text.
Registering a layer before reading it did not leave it unused. IT TOOK THE WHOLE REPORT DOWN FOR A QUARTER OF THE STATE.

### 3. TWO GUARD FAILURES WORTH KEEPING

`test` | measured: 2026-08-16 | cc

A ZONING PREDICATE PROBED ONLY ROWS WITH THE DEFECT, so fixing all 20 left it examining zero rows and returning NULL. A GUARD THAT CAN ONLY RUN WHILE THE DEFECT EXISTS IS NOT A GUARD. Assert the POPULATION, not the exception.
A GUARD MUST BE GREEN BEFORE A PLANT PROVES ANYTHING. CC ran a plant against a guard already red on 31 pre-existing cases and correctly recorded that it proved nothing - the same class as a plant that fails to plant.
The cama guard went RED CORRECTLY, catching two real pick-mode collisions added since it was built - cama_permits and cama_sales, each with two tables at mode=pick.

### 4. A FUNCTION CAN CALL THE RESOLVER FOR THE TABLE AND STILL HARDCODE THE GEOMETRY COLUMN

`closed` | measured: 2026-08-16 | cc

get_parcel_flood_zone READ LIKE A ROUTED FUNCTION AND WAS NOT ONE. It resolved the table through
flood_layer_selection and the columns through flood_col(), then wrote f.geom literally in THREE places -
ST_Intersection(f.geom,$1), f.geom && $1, ST_Intersects(f.geom,$1). Routing the table while hardcoding the
geometry column means the resolver picks the layer and the code still dictates its shape.

WHY NOBODY SAW IT. MEASURED 2026-08-16: of 539 layer_resolution rows, 464 carry geom_column='geom' and 75
carry NULL. NOT ONE REGISTERED LAYER USES A DIFFERENT NAME. The hardcode was therefore correct on every row
in the table, and would stay correct until the first county that publishes SHAPE or the_geom. A COLUMN THAT
IS RECORDED BUT NEVER EXERCISED IS NOT VERIFIED - it is an untested assumption with a value in it.

THIS CHANGES THE 60TH-LAYER TEST. The sinkhole proof (08-serving/1) registered non-standard ATTRIBUTE names
but left the geometry as geom, so it could not have caught this. A PROBE LAYER MUST USE A NON-geom GEOMETRY
COLUMN, or it proves the table lookup only and leaves the shape path untested.

FLOOD IS NOW ROUTED AND PROVED (2026-08-16, migration ruling_243_route_flood_through_the_resolver).
Safety check before the swap: resolve_layer requires row_count>0, so 67 flood rows / 67 with a table / 67
with row_count>0 / 0 counties with more than one live row - none dropped. Palm Beach 60/00404332000001030
returned Zone AO, 100.0%, in_sfha=true both before and after. The 68th-layer proof used geometry column
SHAPE and zone column fema_zone_cd at precedence 9:
  BEFORE   palmbeach_flood_zones  AO
  REGISTER zz_flood_probe_68      VE, bfe 14.5   <- no deploy, and get_pir_report carried VE
  REMOVE   palmbeach_flood_zones  AO
Both the geometry column and the attribute map were doing real work; neither fell back.

SIX ROWS REGISTER A GEOMETRY COLUMN ON A TABLE THAT HAS NO GEOMETRY - the remainder of the 48-row class from
ruling 218. Five are kind='relational' CAMA (property_permit_history, pinellas_cama_rp_sales,
pinellas_cama_rp_structural_elements, collier_cama_int_accounts, collier_cama_int_values_rp_history) where the
served path never takes a shape. The sixth is id 134, zoning, US-12071, geom_column='geom', row_count 8017,
TABLE_NAME NULL. resolve_layer's WHERE table_name IS NOT NULL AND COALESCE(row_count,0)>0 makes it
unreachable, and its not-found branch reports none_recorded rather than raising. IT IS INERT, NOT FIXED -
its note says "holds no rows or was de-selected" while the row claims 8,017.

### 5. row_count IS A LIVENESS GATE, NOT DOCUMENTATION. A STALE ONE IS A SILENT DE-SELECTION.

`test` | measured: 2026-08-16 | cc

BOTH RESOLVERS GATE ON IT: resolve_layer and resolve_layers each carry
WHERE table_name IS NOT NULL AND COALESCE(row_count,0) > 0. The per-concept VIEWS DO NOT
(zoning_layer_selection has no such filter; flood_layer_selection had none either). So the number in that
column is not a note about the table - IT DECIDES WHETHER THE LAYER IS SERVED AT ALL, and only once the
concept is routed. Until then it is unexercised and drifts unnoticed.

MEASURED 2026-08-16, ROUTING ZONING: 52 zoning/land_use layers recorded row_count 0 or NULL. I counted
every one of them. ALL 52 HOLD ROWS - 342,571 - AND EVERY ONE IS MUNICIPAL. palmbay_city_future_land_use
79,508. hialeah_city_zoning 37,362. ocala_city_future_land_use 24,726. tampa_city_zoning 3,911.
orlando_city_zoning 2,091. Swapping the call without backfilling would have dropped municipal zoning and
future land use for Tampa, Orlando, St. Petersburg, Hialeah, Clearwater and Cape Coral - AND REPORTED
present THROUGHOUT, because the county layer answers underneath. A city parcel would have been served the
county's zoning code with no indication the city's own ordinance was ever consulted. THE FAILURE MODE IS
NOT AN ERROR, IT IS A PLAUSIBLE WRONG ANSWER FROM THE LAYER BELOW.

THE CHECK, BEFORE ROUTING ANY CONCEPT: for every layer in it, compare RECORDED row_count against an
ACTUAL count(*), and treat recorded-0-but-populated as blocking. Confined to those 52 across all 539
registered layers when measured - but it was invisible for as long as the concept stayed unrouted, so
re-measure per concept at the moment of routing, not once globally.

AND CHECK THE OPPOSITE DIRECTION TOO: recorded > 0 against a table that is now empty resolves present and
then serves nothing.

A NOTE ON MEASURING IT. Comparing layer_resolution.table_name against pg_class WHERE relkind IN
('r','p','m') reports registered VIEWS as missing tables. My first pass called 3 flood layers missing on
exactly that error. Include 'v' or use to_regclass.

## 09-juridical

### 1. THE JURIDICAL REGISTER IS WHAT TIES A CLAIM TO A TITLE, AND IT IS ONE COUNTY DEEP

`measurement` | authority: Clerk of the Circuit Court, county recording | measured: 2026-08-16 | claude

A lien, a judgment, a lis pendens and a recorded declaration of restrictions all attach to the LAND and run with it to the next owner. NOTHING IN THE FISCAL REGISTER SHOWS ANY OF THEM. The assessment roll a buyer's agent checks looks clean.
MEASURED IN VOLUSIA, THE ONLY COUNTY WE HOLD:
  JUDGMENT/ORDER  451,371 instruments   2015-01-02 to 2026-07-20
  DEED            158,313               2015-01-02 to 2019-03-06
  SATISFACTION     82,085               2015-01-02 to 2019-03-06
  LIEN             60,550               2015-01-02 to 2026-07-20
  RELEASE          41,813               2015-01-02 to 2019-03-06
  LIS PENDENS      15,396               2015-01-02 to 2026-07-20
  PARTIAL SATIS     3,658               2015-01-02 to 2019-03-06
  RESTRICTIONS      1,155               2015-01-08 to 2026-07-13
THE HOA CASE IS IN THERE: 5,992 lien and judgment instruments naming a homeowners, condominium, property owners or
master association as a party - 1,158 DISTINCT ASSOCIATIONS - running to 20 July 2026.
That is the exact shape of the case that started this: a buyer completes with a trust, a bank and an agent, and
finds delinquent fines and recorded restrictions three months later. IT WAS RECORDED. Nobody looked, because the
only registers anyone joins to a parcel are fiscal.

### 2. THE 2019 FRONTIER IS FOUR DOCTYPES, NOT ONE, AND THE FOUR THAT STOPPED ARE THE DISCHARGES

`measurement` | authority: Clerk of the Circuit Court | measured: 2026-08-16 | claude

EVERY DOCTYPE THAT EXTINGUISHES AN ENCUMBRANCE STOPS AT 2019-03-06. Every doctype that CREATES one runs to 2026.
  STOPPED 2019: DEED, SATISFACTION, RELEASE, PARTIAL SATISFACTION
  CURRENT 2026: LIEN, JUDGMENT/ORDER, LIS PENDENS, RESTRICTIONS
LIENS: 31,026 instruments inside the satisfaction window, 29,524 AFTER IT. Judgments: 267,871 after it.
SO FOR ROUGHLY HALF OF ALL RECORDED LIENS WE HOLD THE CLAIM AND CANNOT HOLD THE DISCHARGE. That is not a
data-completeness footnote - IT IS THE DIFFERENCE BETWEEN "there is a lien" AND "there was a lien and it was paid".
get_parcel_encumbrances handles it correctly today: or_satisfaction_frontier() is DERIVED from the data, so the
three satisfaction states move on their own as the scraper backfills, and no code changes when it does.
THE FIX IS THE PULL, NOT THE CODE.

### 3. 527,317 ENCUMBRANCE INSTRUMENTS, 6,923 MATCHED TO A PARCEL

`principle` | authority: ISO 19152-2 land registration | measured: 2026-08-16 | claude

LIEN + JUDGMENT/ORDER + LIS PENDENS = 527,317 distinct instruments in one county. parcel_encumbrance_match holds
6,923. THAT IS 1.3%.
encumbrance_parcel_candidate holds 10,900 further single-parcel instruments that agree with the confirmed match
6,052 of 6,052 times against a 0.014% negative control - a 7,100x lift - and promotion takes juridical reach from
4,963 Volusia parcels to 11,916.
BUT THE REAL CONSTRAINT IS NOT MATCHING, IT IS THAT MOST INSTRUMENTS NAME A PERSON, NOT A PARCEL. A judgment is
recorded against a DEBTOR and becomes a lien on whatever they own in that county. THAT IS AN LA_Party TO LA_RRR
RELATION WITH NO LA_SpatialUnit IN THE DOCUMENT, and it is why 451,371 judgments resolve to almost nothing.
THE MODEL SAYS WHERE THE JOIN LIVES: party -> RRR -> BAUnit -> spatial unit. We are trying to go straight from
instrument to parcel and skipping the party, which is the only node the document actually names.

### 4. THE SDF IS A JURIDICAL POINTER IN ALL 67 COUNTIES

`mapping` | authority: ISO 19152-4 VM_Transaction / LA_AdministrativeSource | measured: 2026-08-16 | claude

The DOR sales data file carries OR_BOOK, OR_PAGE and CLERK_NO - an LA_AdministrativeSource reference to the
RECORDED INSTRUMENT - for every qualified sale, in all 67 counties, in a file we already hold.
It does not replace the Clerk pull and it carries no liens. What it gives is a VERIFIED BRIDGE: a parcel, a sale, a
date, a price, a qualification code, and the book and page where the deed sits. That is the join key into a county
recording system for any county we later pull.
It was found by declaring the SDF family and reading the columns, not by looking for it.

### 6. MIAMI-DADE PUBLISHES THE LOT-VERSUS-INTEREST RELATION AND NO OTHER COUNTY DOES

`measurement` | authority: Miami-Dade Property Appraiser | measured: 2026-08-16 | claude

miamidade_property_boundaries, 939,136 rows, carries BOTH folio AND parent_folio. MEASURED on a 28,690-row sample:
  rows with NO parent_folio   18,359 - 18,079 join parcels_staging ON THEIR OWN FOLIO   98.5%
  rows WITH a parent_folio    10,492 - only 2 join on own folio (0.02%)
                                     - 10,437 JOIN ON parent_folio                      99.5%
THE UNITS ARE NOT IN THE TAX SPINE. THEIR COMPLEX IS. 36% of rows are condo units whose own folio the spine does not
carry, and the county tells you which complex each belongs to.
COMBINED KEY: coalesce(nullif(btrim(parent_folio),''), folio) -> 28,353 of 28,690 = 98.83%, WRONG-COUNTY CONTROL 0.
THE NAIVE folio KEY MEASURED 60.6% AND LOOKED LIKE A BAD MATCH. IT WAS THE WRONG QUESTION, NOT A BAD KEY. A 60% match
rate is the signature of a two-level model being read as one level - CHECK FOR A PARENT COLUMN BEFORE CONCLUDING A
KEY IS POOR.
IN LADM TERMS: parent_folio is LA_BAUnit, folio is VM_CondominiumUnit where the parent is present and
VM_ValuationUnit where it is not. THIS IS THE SARASOTA DEFECT WITH THE ANSWER SUPPLIED BY THE PUBLISHER - and
Miami-Dade has NO relational CAMA, so this is the only structural ownership signal we hold for the county.

## 11-traceability

### 1. THE HELD RECORD IS THE EVIDENCE - HOLD IT UNCHANGED

`closed` | measured: 2026-08-16 | murphy

A PIR snapshot is the seller and agent proof that they looked, and its value depends on being able to show WHAT THE SOURCE SAID, not what we made of it. Clean a value at ingest and you destroy the only thing that proves the source said it.
THE TEST THAT DECIDES ANY CASE: COULD WE STILL SHOW WHAT THE SOURCE PUBLISHED? If not, it is not a transform, it is a loss.
DISPOSITION VOCABULARY, SPLIT 16 AUGUST:
  container_repair   file will not parse or decode as delivered; NO DATA VALUE CHANGES (JSON trailing comma, BOM)
  normalise_at_read  the fix lives in a join or helper - cama_key, lpad, btrim - NEVER in the stored value
  derive_alongside   transformed form in a NEW column, original RETAINED (geometry validation, reprojection)
  repair             OUR OWN artefacts only - registry rows, resolver rows, column maps, precomputed matches
transform_on_ingest AUTHORISED REWRITING SOURCE DATA and is now constrained out. All nine defects carrying it were reclassified by reading their remediation and NOT ONE SURVIVED AS A TRANSFORM - the disposition named a practice the project does not have.
WHAT COULD NOT BE FIXED: geometry_repair_log holds COUNTS, NOT GEOMETRY. For 138 tables the answer to could we show what the source published is NO. That set is a re-pull question, not a repair.

## 12-standing

### 1. STANDING RULES THAT GOVERN READING

`rule` | measured: 2026-08-16 | claude

NAMES LIE, CONTENTS DO NOT. Four tables on 16 August wore a label their contents contradicted.
SEARCH FOR THE ARTEFACT BEFORE DESCRIBING THE GAP. Five times in one day something declared missing already existed: Polk relational CAMA, table_inventory, layer_column_map, ladm_declaration, and the inbox itself.
A GUARD THAT ERRORS IS NOT A GUARD THAT FAILS. run_defect_detections records error_text separately and a red summary line hides the difference.
limit N WITHOUT ORDER BY IS NOT A SAMPLE. It produced a 36-point error against a verified figure.
JOIN geo_reference ON COUNTY NAME. NEVER WRITE A COUNTY NUMBER BY HAND. Four FIPS-versus-DOR errors on 16 August alone - Polk is 63 not 105, and 20 is Clay not Columbia.
A COUNTY IS NOT LOADED until its key joins, THE JOIN IS INDEXED, and a served function reads it.
READ THE SERVED FUNCTION BEFORE RULING ON THE DATA. Three rulings on 16 August were withdrawn or softened because the serving code already handled what the ruling assumed it did not.
THE INBOX IS to_agent = me AND status = unread, ORDER BY id. There is an index built for exactly that query. Mark read only what you actually read.

### 2. A PII SWEEP SCOPED BY CLASS CANNOT FIND PII IN TABLES CLASSED AS SOMETHING ELSE

`rule` | measured: 2026-08-16 | claude

THREE TIMES IN ONE DAY PII TURNED UP WHERE NOBODY WOULD HAVE LOOKED:
  hialeah_city_zoning / _future_land_use  37,290 owner names, in a ZONING layer
  marion_future_land_use                  owner_name, in a LAND USE layer
  orange_community_organizations          FIFTEEN personal contact fields including an emergency contact HOME
                                          ADDRESS, in a layer classed LOC_amenity
Plus volusia_hoas registered agent - frequently a resident, so a residential address inside a corporate record.
SWEEP FOR COLUMN-NAME PATTERNS ACROSS EVERY TABLE REGARDLESS OF CLASS. Class is exactly what hid these.

## 13-open

### 1. OPEN, IN PRIORITY ORDER

`open` | measured: 2026-08-16 | claude

1 COMMIT docs/THE_LENS.md AND THE_FISCAL_CADASTRE_PROBLEM.md - both untracked. The only items that can lose work.
2 TEACH sync_table_provenance_comments() TO MERGE before any declaration line goes on a REGISTERED table.
3 CC ROUTES flood (67/67 verified), then zoning (77), then land_use (91) - each proved with the 60th-layer test.
4 DERIVE authority_tier for 549 tables, marked derived_from_url. 483 resolve; 108 become a pull list.
5 ENUMERATE SRWMD AND ARPC for the 20 counties with no zoning.
6 RE-PULL fl_cadastral_dor_statewide DECLARING EPSG 6439. SRID 0 blocks the 92,043-parcel orphan attribution, which is a spatial join. Key is verified; geometry is not usable.
7 READ THE 65 UNVERIFIED LAYERS - 37 parcel_geometry_county, 28 address_points - before either is routed.
8 DECIDE THE PINELLAS cama_sales COLLISION - two tables at mode=pick. Same shape on cama_permits.
9 PULL THE DISCHARGE DOCTYPES FROM 2019-03-06 - the frontier is DERIVED, so no code changes when they land.
10 CHARLOTTE COUNTY HCP LAYER - one fetch, county-wide 30-year federal take permit with a published GIS layer.

## 14-completeness

### 1. WHAT IS ACTUALLY FINISHED, AUDITED NOT ASSERTED

`measurement` | measured: 2026-08-16 | murphy

Murphy asked whether everything is being completed and documented. I MEASURED IT RATHER THAN ANSWERING, and the answer was no in three places.
  populated tables                    2,113
  ladm_declaration                      948   (45%)
  has a column map                    1,037   (49%)
  DECLARED WITH NO COLUMN MAP            50   (was 118 - the 68 disaster tables are now mapped)
  MAPPED WITH NO LADM CLASS             207
  DECLARED WITH NO PROVENANCE ROW       708
THE 708 IS THE BIG ONE AND IT IS DELIBERATE ONLY IN PART. Family declaration writes ladm_declaration and
layer_column_map cheaply because the schema is shared, but data_source_registry needs a SOURCE PER TABLE, and a
source is not shared just because a schema is. 68 disaster tables share one FEMA endpoint; 237 amenity tables do
not necessarily share one.
A TABLE IS NOT FINISHED UNTIL IT HAS ALL THREE: an LADM class, a column map with a verified key, and a provenance
row. Two of three is the state most of this database is in, and saying "declared" without saying which of the three
is the same overstatement as saying "wired" when nothing reads it.

### 2. THE THREE-PART TEST FOR A FINISHED TABLE

`rule` | measured: 2026-08-16 | claude

1 ladm_declaration    WHAT IT IS - the class, and why, in the rationale
2 layer_column_map     WHICH COLUMN ANSWERS WHAT - with the key verified against a negative control
3 data_source_registry WHERE IT CAME FROM - agency, and a source that can be refreshed
AND FOR A SERVED CONCEPT, A FOURTH: a new layer changes a report with no deploy.
Report progress as a fraction of all four, never as a count of one. Registered 419->557 was true and told nobody
anything, because nothing read it.

### 3. DECLARED-WITH-NO-COLUMN-MAP IS ZERO. AND CLOSING IT FOUND FOUR MISCLASSIFICATIONS.

`measurement` | measured: 2026-08-16 | claude

118 -> 50 -> 43 -> 0. Every LADM-declared table now carries a column map. 1,155 tables mapped, 3,410 map rows.
CLOSING THE LAST 43 ONE AT A TIME WAS NOT BOOKKEEPING - it found things a family sweep never would:
  hifld_dams carries hazard_potential - Low 433, Significant 335, UNDETERMINED 207, High 105. I had flagged this
    field as MISSING yesterday. It was there. UNDETERMINED IS 19% AND IS NOT LOW.
  pasco_future_land_use.new_flu is a PROPOSED change - the previous-value trap INVERTED, a future value.
  orange_stormwater_drainwell carries yr10/yr25/yr100 flood stage WITH and WITHOUT the well - a modelled
    flood-mitigation dependency, in a table classed EXT_utility.
  daytonabeach_city_control_points is 98 SURVEY CONTROL POINTS - the only genuine survey-grade data in the
    database. Everything else is a tax map.
  marion_railroad_crossings carries whistban and whistdate - a QUIET ZONE designation, a real noise fact, buried in
    250 columns of FRA internals.
