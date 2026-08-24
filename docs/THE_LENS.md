# THE LENS

> GENERATED FILE - DO NOT HAND-EDIT.
> The source is the `lens` table. Regenerate with `SELECT export_lens_markdown();`.
> An edit made here is not in the source and will be discarded by the next export.
> Append and supersede in the table, never delete: set `superseded_by` on the old row
> and insert the new one.

Live entries: 305 | superseded (retained as history): 3

---

## 00-purpose

### 1. THE LENS IS THIS TABLE, NOT THE MARKDOWN

`principle` | measured: 2026-08-16 | claude

docs/THE_LENS.md is an EXPORT. This table is the source, because a markdown file in a working tree drifts, gets overwritten by a sync, or is lost to a git clean - all three happened to something on this project in one day.
APPEND AND SUPERSEDE, NEVER DELETE. Set superseded_by on the old row and insert the new one, so the reasoning trail survives and a future reader can see WHY a rule changed rather than only what it now says.
Both agents read: select * from lens where superseded_by is null order by section, ordinal.

### 2. RUN before_you_declare_a_gap() BEFORE SAYING ANYTHING IS MISSING. THIS ENTRY EXISTS SO THE LESSON IS NOT RELEARNED.

`rule` | authority: Murphy, four times | measured: 2026-08-16 | murphy

MURPHY HAD TO TELL ME FOUR SEPARATE TIMES TO RESEARCH BEFORE DECLARING. A rule was not enough, so the check is now an
artefact that runs the searches.
  SELECT * FROM before_you_declare_a_gap('table_name');
Seven checks in one call: provenance_all, the table own per-row source_url, county_coverage_status, ladm_declaration,
layer_column_map, the join-proof tables, and the July nr_final/nr_content profile.
AND provenance_all IS THE OTHER HALF: ONE VIEW OVER FIVE REGISTRIES, so nobody needs to know there are five.
  1 data_source_registry     1,379 - the one we called the source of truth, and the one with the gap
  2 per-row source_url             - the FDEP/FGS family writes its endpoint into EVERY ROW
  3 county_coverage_status      71 - 32 HUB URLS, 15 PULL TECHNIQUES, notes naming every layer and obstacle
  4 county_export_survey        67 - 42 REST endpoints, 20 vendor fingerprints, pagination support, paths_tried
  5 cadence_sweep_request    5,816 - real polled URLs keyed on source_id
  1,277 tables now resolve a source through it. DO NOT ADD A SIXTH REGISTRY - add to the first and let the view fall back.
*** EVERY ONE OF THE SEVEN CHECKS RETURNED, AT LEAST ONCE TODAY, AN ARTEFACT I HAD JUST DESCRIBED AS ABSENT ***
  nr_final                 A COMPLETE GRADED CLASSIFICATION OF 1,226 TABLES from July. I called the content pass abandoned.
  nr_keys / nr_content     key roles for 1,226 tables and top_values for 1,183. I recomputed both by hand all day - and
                           nr_keys had already flagged clay_parcels.pin_dsp and citrus_parcels.alt_id, THE TWO KEYS I
                           HUNTED FOR HOURS AND CALLED UNSOLVABLE.
  table_column_signature   the schema-family method, already built. I rebuilt it with md5(string_agg()).
  county_coverage_status   32 hub URLs. I SAID "NO ENDPOINT WAS RECORDED AT PULL TIME" FOUR TIMES. 130 sources recovered
                           in one UPDATE; unrefreshable fell 237 to 107.
  per-row source_url       16 tables knew their own source while the registry said UNCONFIRMED.
  layer_column_map         I twice described it as missing.
  the inbox                I re-queued work CC had completed and posted at handoff 412.
SEVEN ARTEFACTS. SEVEN TIMES. ONE FAILURE MODE: I TRUST MY OWN MODEL OF THE STATE OVER THE RECORD OF IT.
THE RECORD IS THE ONLY THING THAT IS CURRENT. My model is a memory of the record at some earlier moment, and it is
always the stale copy.
AND THE TECHNIQUE MATTERS AS MUCH AS THE URL: POLK IS AN FTP SERVER THAT REQUIRES TLS 1.2 AND FAILS ON TLS 1.3. No URL
pattern, DCAT feed or ArcGIS enumeration would ever have found that. It was recorded at pull time, in July, in a table
I had never opened.

### 3. LOAD COMPLETE, SCRUB AT RENDER - AND I BROKE IT ON A COLUMN MAP

`principle` | authority: Murphy | measured: 2026-08-17 | murphy

I FILED A PII DEFECT WHOSE REMEDIATION SAID "NEVER MAP OR SERVE contact, address, phone, email". MURPHY: THESE FILTER AT
REPORT, NOT ON THE TABLE. YOU KNOW THIS.
HE IS RIGHT AND IT IS A STANDING RULE IN MY OWN RECORD. THE MAPPING HALF WAS WRONG.
THE COLUMN MAP IS THE CATALOGUE. IT RECORDS WHAT A TABLE HOLDS, INCLUDING - ESPECIALLY - WHAT MUST NEVER BE SERVED.
*** A TABLE WHOSE PII IS UNMAPPED IS A TABLE NOBODY KNOWS CARRIES PII, WHICH IS THE MORE DANGEROUS STATE. *** The next
reader discovers the officer name by accident instead of finding a map row that says PII, render-blocked.
AND IT IS THE LIABILITY POSITION TOO: "we hold these records, we just do not distribute them" is defensible. "We did not
write down that we hold them" is not.
FIXED: mapped as pii_render_blocked. THE FILTER BELONGS AT THE RENDER, WHERE THE LIABILITY SITS.
THIS IS THE SAME SHAPE AS EVERY OTHER ERROR TODAY - I MOVED A CONTROL TO THE WRONG LAYER. The Zone D colour, the
bool_or aggregate, the guard aimed one column off target, and now a scrub applied at the catalogue instead of the
render. THE LAYER AT WHICH A RULE IS ENFORCED IS ITSELF A DECISION AND I KEEP MAKING IT CARELESSLY.

### 4. CHECK THE STANDARD FIRST. SEVEN TIMES TODAY I BUILT SOMETHING LADM ALREADY DEFINED.

`principle` | authority: Murphy; ISO 19152-1/-2/-4/-5 | measured: 2026-08-17 | murphy

MURPHY: WHY ARE YOU NOT REFERRING TO THIS STANDARD WHEN PROCESSING THIS INFORMATION. PEOPLE HAVE DONE THESE SORT OF
THINGS ALL THE TIME.
THE COUNT, AND EVERY ONE WAS FOUND AFTER I HAD ALREADY BUILT OR RULED SOMETHING:
  1 LA_/VM_/SP_ PREFIXES        I invented PART2_/PART4_/PART5_. Table 2 of 19152-4 gives the convention.
  2 VM_TransactionPrice          I used VM_Transaction. Clause 7.3.9 names it, WITH a code list for family transfer
                                 and forced sale - the quit-claim problem I had recorded as a discovery.
  3 VM_ValuationUnit note 3      "the basic registration unit of cadastral systems CAN DIFFER FROM the basic units of
                                 valuation systems" - THE SARASOTA LOT-VERSUS-INTEREST DEFECT AS A DESIGN NOTE.
  4 LA_BAUnit sum(RRR.share)=1   I derived the LA_GroupParty rule from the fraction constraint. The BAUnit constraint
                                 is the real mechanism AND SAYS "PER TYPE" - two words I read past, which then cost
                                 me the life-estate and joint-tenancy cases.
  5 LA_RRR.shareCheck            I proposed populating a sum-verified flag. The standard has the attribute.
  6 VersionedObject              I ran dozens of UPDATEs against ladm_declaration and lost every prior state. Clause 6:
                                 "the contents of the database can be reconstructed as they were at any historical
                                 moment" and "ALL DATA ARE KEPT, ALSO AFTER DELETION".
  7 LA_Source.extArchiveID       I called the per-feature PDF links "a class of column more valuable than the layer".
                                 The standard has a dedicated attribute for a document in an external archive.
  8 LA_Level.structure           TODAY. I filed the Marion split as a novel defect shape - "a false clearance produced
                                 by a table split". The standard distinguishes topological (NO GAPS) from polygon (gaps
                                 not guaranteed) and would have caught it AT REGISTRATION.
EIGHT. AND THE PATTERN IS NOT THAT I DO NOT KNOW THE STANDARD - IT IS THAT I REACH FOR IT TO CONFIRM WHAT I HAVE
ALREADY DECIDED RATHER THAN TO FIND OUT WHAT IS ALREADY SOLVED.
*** THE COST IS NOT THE REBUILD. IT IS THE RULINGS I ISSUED IN BETWEEN. *** The PER TYPE omission produced a shareCheck
that would have fired FALSE on 115,767 of 343,841 Volusia parcels. The VersionedObject omission destroyed the audit
trail of every correction made before I fixed it.
*** THE RULE, AND IT GOES IN THE CATALOGUE METHOD AS STEP ZERO: BEFORE DECLARING A CLASS, BUILDING AN INSTRUMENT OR
RULING ON A SHAPE, ASK WHETHER ISO 19152 ALREADY MODELS IT. LAND ADMINISTRATION IS A SOLVED PROBLEM WITH A FIFTEEN-YEAR
STANDARD AND A COMMITTEE THAT CONSIDERED AND REJECTED ALTERNATIVES WE ARE RE-PROPOSING. ***
before_you_declare_a_gap() RUNS SEVEN SEARCHES AGAINST OUR OWN DATABASE. THE STANDARD DESERVES THE SAME REFLEX.

### 5. AGREEMENT IS NOT INDEPENDENT VALIDATION

`principle` | authority: Perplexity external review; measured against the Glades and scoreboard incidents | measured: 2026-08-19 | murphy

THE SINGLE MOST VALUABLE LINE FROM THE EXTERNAL REVIEWS, AND IT NAMES THE FAILURE THAT COST THE MOST TODAY.
*** TWO AGENTS WHO MAKE THE SAME CATEGORY MISTAKE ARE NOT REDUNDANCY. THEY ARE A CONFIDENCE AMPLIFIER FOR THE SAME
MISTAKE. ***
PROVED TWICE IN ONE SESSION:
  CC MEASURED "0 polygons inside Glades" with WHERE name='Glades' against a column holding "Glades County". ZERO ROWS
  JOINED.
  I "VERIFIED" IT with co_no=26. 26 IS DUVAL. GLADES IS 32.
  TWO BROKEN PREDICATES, THE SAME ZERO, AND THEY AGREED - SO I RECORDED IT AS CONFIRMED AND WROTE A CORRECTION ON TOP
  OF IT. THE AGREEMENT WAS THE EVIDENCE, AND THE AGREEMENT WAS THE ARTEFACT.
AND AGAIN IN THE SCOREBOARD: CC join_proved PREDICATE COULD NOT SEE TWO OF FOUR JOIN TYPES - it exact-matched
containment table_name while 746 of 2,048 runs carry a " [layer_side]" suffix, and it never queried
jurisdiction_verification_run at all. 369 + 227 tables hidden. CC DIAGNOSED "a predicate keyed on a value the data does
not hold" IN THE SAME MESSAGE THAT CONTAINED ONE.
*** SO PEER REVIEW IS WORKING AND THE SHARED EPISTEMOLOGY IS THE HOLE. Two agents reading the same registry with the
same habits catch each other's ARITHMETIC and share each other's ONTOLOGY. ***
THE FIX IS NOT FEWER AGENTS. IT IS AN INDEPENDENT EVIDENCE PATH: a verifier that sees ONLY the served contract and
adversarial fixtures, never the registry, never the implementation, never the other agent conclusion.
AND THE EXTERNAL REVIEWS DEMONSTRATED THE POINT ON THEMSELVES: both proposed building a golden-parcel corpus THAT
ALREADY EXISTS as golden_parcel_run, and one asserted "<120 tables" from grepping function source WHILE THE RESOLVER
REACHES 612 THAT NO GREP CAN SEE. OUTSIDE REVIEW HAS THE SAME FAILURE MODE WE DO WHEN IT REASONS FROM A DESCRIPTION
RATHER THAN THE SYSTEM.

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

### 3. THE PREFIX CONVENTION IS THE STANDARD OWN AND MINE WAS INVENTED

`correction` | authority: ISO 19152-4:2025 Table 2, clause 7.3 | measured: 2026-08-16 | murphy

ISO 19152-4:2025 TABLE 2 IS EXPLICIT:
  LA  = 19152-1 Generic conceptual model AND 19152-2 Land registration - ONE PREFIX FOR BOTH PARTS
  VM  = 19152-4 Valuation information
  SP  = 19152-5 Spatial plan information
THERE IS NO PART2_ / PART4_ / PART5_ CONVENTION. I invented it, then used it inconsistently across 32 class names -
PART2_parcel beside PART2_spatialunit, LA_Party beside LOC_actor, REG_hazard beside REG_geohazard.
AND THE CLASS NAME I HAD BEEN USING MOST WAS WRONG: Part 4 clause 7.3.9 is VM_TransactionPrice, NOT VM_Transaction.
MIGRATED 2026-08-16: 1,373 of 1,396 declarations rewritten to real class names, legacy_class retained on every row.
32 invented classes -> 16 in use from a 25-row controlled vocabulary. ladm_declaration.declared_class is now a
FOREIGN KEY to ladm_class_vocabulary, so A NEW CLASS CANNOT BE INVENTED IN AN INSERT - it must be added to the
vocabulary with its source clause first.

### 4. THE STANDARD ALREADY NAMES THE DEFECTS WE DISCOVERED BY BREAKING THINGS

`mapping` | authority: ISO 19152-4:2025 clauses 3.1 and 7.3; ISO 19152-5:2025 | measured: 2026-08-16 | claude

READING THE ACTUAL TEXT RATHER THAN A SUMMARY:
VM_ValuationUnit 3.1.17 - the object of valuation may be a parcel alone, a building alone, parcel plus building, a
  CONDOMINIUM UNIT, or A SHARE IN LAND PARCELS. Note 2: "FOR ANY BAUnit THERE CAN BE MULTIPLE VALUATION UNITS".
  Note 3: "THE BASIC REGISTRATION UNIT OF CADASTRAL SYSTEMS CAN DIFFER FROM THE BASIC UNITS OF VALUATION SYSTEMS".
  THAT IS THE SARASOTA LOT-VERSUS-INTEREST DEFECT, WRITTEN DOWN AS A DESIGN NOTE IN THE STANDARD.
VM_TransactionPrice 3.1.12 - transaction type may be exchange, FAMILY TRANSFER, FORCED SALE, inheritance, open
  market sale, voluntary transfer. THE STANDARD ANTICIPATES THE QUIT-CLAIM PROBLEM. polk_sales "Other
  Disqualified", volusia STEB_DESC "Transfer other than by WD", pasco sale_qualified U are all non-open-market
  types it already has vocabulary for.
VM_CondominiumUnit 3.1.5 - includes ACCESSORY PARTS assigned for exclusive use, garages and storage. We had not
  considered that a garage is part of the unit.
VM_Valuation 3.1.14 - "A PROPERTY OR PROPERTY UNIT CAN HAVE MORE THAN ONE VALUE". jv, av_sd, tv_sd and every
  exemption class are separate valuations, not competing versions of one.
SP_Permit - 19152-5 carries req/spatialplan/permitregistration. PERMITS ARE PART 5, NOT PART 4. I had ten permit
  tables filed as VM_Building.
THE PATTERN: EVERY DEFECT WE FOUND THE EXPENSIVE WAY IS A DISTINCTION THE STANDARD DRAWS ON PURPOSE.

### 5. A LOCAL EXTENSION MUST DECLARE ITSELF AS ONE

`rule` | measured: 2026-08-16 | claude

LADM HAS NO CLASS FOR A FLOOD ZONE, A SCHOOL OR AN ADDRESS POINT. Pretending otherwise by inventing a
standard-looking name is worse than admitting the extension.
ladm_class_vocabulary.is_standard IS THE FLAG. 21 classes are ISO with a source clause; 4 are LOCAL and say so:
  EXT_Regulatory - an agency overlay that CREATES an LA_RRR restriction over what it covers. THE LAYER IS THE
    SOURCE OF A RESTRICTION; THE RESTRICTION ATTACHES TO THE BAUnit. Subtyped flood/contamination/geohazard in a
    second column rather than by minting more class names.
  EXT_Context - NO RRR over the subject parcel. Schools, hospitals, parks, transport, air quality, census.
    THE TEST IS THE OBLIGATION TEST: does crossing this boundary change what the owner owes or may do?
  EXT_Address, SYSTEM - the same, declared honestly.
SUBTYPE IN A COLUMN, NEVER IN A CLASS NAME. That is what stopped 32 classes becoming 60.

### 6. HOW 27 OWNERS ROUTE IN LADM - AND THE BAUnit CONSTRAINT DECIDES TE VERSUS TIC FOR US

`mapping` | authority: ISO 19152-1 LA_RRR.share, LA_RRR.shareCheck, LA_BAUnit constraint sum(RRR.share)=1 | measured: 2026-08-16 | claude

THE STANDARD CARRIES THE ANSWER IN TWO PLACES I HAD NOT READ:
  LA_RRR    + share: Rational [0..1]   + shareCheck: Boolean [0..1]
  LA_BAUnit CONSTRAINT: {sum(RRR.share) = 1 per type if not ends _S or _B}
*** THAT CONSTRAINT DECIDES THE MODELLING. IT IS NOT A CHOICE. ***
219 GRAHAM ST, 27 OWNERS, ALL TIC:
  27 x LA_Right, each over ONE LA_BAUnit, each with share = Rational(1,6), (1,18), (1,42), (1,66), (1,168)
  MEASURED SUM: EXACTLY 100.000% = 1. THE PARCEL SATISFIES THE BAUnit CONSTRAINT NATIVELY.
  27 x LA_Party, NO LA_GroupParty. Each right is SEVERABLE and ALIENABLE - any one holder can convey their share or
  force a partition sale - so they are 27 separate rights, not one right held jointly.
1778 EARHART CT, GENE AND IRIS, TE, BOTH PCTOWN 100:
  As two LA_Rights the shares would sum to 2, WHICH VIOLATES THE CONSTRAINT. So it CANNOT be modelled that way.
  1 x LA_Right with share = Rational(1,1), holder = LA_GroupParty, 2 x LA_PartyMember.
  THE CONSTRAINT FORCES THE GROUP PARTY. I ruled it earlier from the fraction rule alone; the BAUnit sum constraint is
  the actual mechanism and it is stronger - it makes the group form the ONLY conformant option.
*** SO THE TENANCY CODE IS NOT OUR HEURISTIC, IT IS THE DISCRIMINATOR THE STANDARD REQUIRES ***
  TE  -> one LA_Right, share 1/1, LA_GroupParty, LA_PartyMember per spouse. Survivorship. Not severable.
  TIC -> n LA_Rights, real fractions summing to 1, no group party. Each severable and partitionable.
  FS  -> one LA_Right, share 1/1, single LA_Party.
THE TEST IS SEVERABILITY. A group party is for parties acting as ONE; tenants in common do not act as one, which is
precisely why heirs property is fragile.
*** AND shareCheck IS THE STANDARD OWN VERSION OF OUR DISCIPLINE ***
LA_RRR.shareCheck is a BOOLEAN RECORDING WHETHER THE SUM HAS BEEN VERIFIED. That is the three-coverage-state rule
inside the standard: a share is present, or absent, or PRESENT-AND-UNVERIFIED, and the model refuses to conflate them.
We should populate it - for 219 Graham St it is TRUE, measured at 100.000.
*** ONE HISTORICAL NOTE THAT MATTERS ***
The 2010 LADM development papers explored an explicit LA_RRR_Group class for exactly this problem and REJECTED IT in
favour of the BAUnit sum constraint. So there is no group-of-rights construct by design: the whole is enforced
arithmetically, not structurally. Anyone reaching for an RRR group in our profile is re-proposing something the
committee considered and declined.

### 7. LA_Level.structure NAMES THE MARION SPLIT - topological MEANS NO GAPS, polygon DOES NOT GUARANTEE IT

`mapping` | authority: ISO 19152 LA_Level.structure, LA_StructureType; ISO/DIS 19152:2010 clause on levels | measured: 2026-08-17 | murphy

MURPHY ASKED WHAT LADM SAYS ABOUT THE SPLIT. IT HAS THE EXACT DISTINCTION AND WE HAVE NOT BEEN CARRYING IT.
LA_Level: + structure: LA_StructureType | + registerType: LA_Register | + type: LA_LevelContentType
LA_StructureType VALUES: text | point | line | POLYGON | TOPOLOGICAL
*** THE STANDARD DEFINES THE DIFFERENCE VERBATIM: "THE TOPOLOGICAL SPATIAL UNITS ARE DEFINED BY A CONSISTENT
TOPOLOGICAL STRUCTURE (WITH NO GAPS, OVERLAPS OR INTERSECTIONS), WHICH IS IN CONTRAST WITH A SET OF POLYGONS, WHERE A
CONSISTENT TOPOLOGICAL STRUCTURE IS NOT GUARANTEED." ***
AND "A LEVEL IS A COLLECTION OF SPATIAL UNITS WITH A GEOMETRICAL/TOPOLOGICAL OR THEMATIC COHERENCE."
*** THAT IS THE MARION DEFECT, NAMED. *** A FIRM IS A TOPOLOGICAL LEVEL - FEMA partitions the county completely, every
point is IN or OUT, no gaps. Marion publishes it as TWO TABLES:
  marion_fema_flood_zones_2017   4,514 rows ALL sfha_tf = T
  marion_fema_flood_other_areas  5,134 rows ALL sfha_tf = F
EACH TABLE ALONE IS A polygon-STRUCTURED LEVEL - IT HAS GAPS. TOGETHER THEY ARE THE topological LEVEL THE FIRM ACTUALLY
IS. QUERYING ONE AND GETTING NOTHING IS A GAP IN A LEVEL THAT SHOULD HAVE NONE, AND THE READER CANNOT TELL A GAP FROM
AN "OUT".
*** SO THE FIX IS NOT A COMPOSE PATH BOLTED ON - IT IS A DECLARED PROPERTY OF THE LEVEL. *** If layer_resolution
carried structure = topological, a zero result from a topological level would be a DETECTABLE CONTRADICTION rather than
a silent clearance. THE STANDARD WOULD HAVE CAUGHT THIS AT REGISTRATION.
IT ALSO SETTLES THREE EARLIER RULINGS AT ONCE:
  DUVAL 20% PARCEL COVERAGE - a polygon level. Absence means not_available. CORRECT to keep out of the pick.
  ZONING 168 LAYERS / 96 PLACES - polygon levels that must compose, which is ruling 245 restated in the standard.
  TILING_COVERAGE verdicts - those layers ARE topological levels, and 100% of probes hitting is the SIGNATURE of one,
    not a defect.
AND LADM ANTICIPATES EXACTLY OUR CASE IN ITS OWN EXAMPLES OF WHY LEVELS EXIST: "ONE LEVEL OF SPATIAL UNITS TO DEFINE
BASIC ADMINISTRATIVE UNITS ASSOCIATED WITH RIGHTS AND ANOTHER LEVEL FOR THOSE ASSOCIATED WITH RESTRICTIONS."
ADD structure TO layer_resolution: topological | polygon | point | line | text. IT IS ONE COLUMN AND IT MAKES THE
FALSE-CLEARANCE-BY-TABLE-SPLIT DETECTABLE INSTEAD OF INVISIBLE.

### 8. LA_RRR IS ABSTRACT - I DECLARED 174 TABLES AGAINST A PARENT CLASS, AND THE SUBCLASS I HAD NEVER USED IS THE ONE THAT MATTERS

`mapping` | authority: ISO 19152-1 Administrative package; LA_RestrictionType, LA_ResponsibilityType code lists | measured: 2026-08-18 | murphy

READING THE REMAINING EXT_Regulatory TABLES SENT ME BACK TO THE STANDARD, AND THE STANDARD SAID SOMETHING I HAD NOT
NOTICED IN A DAY OF USING THE CLASS.
*** LA_RRR IS ABSTRACT. ITS CONCRETE SUBCLASSES ARE LA_Right, LA_Restriction AND LA_Responsibility, PLUS LA_Mortgage.
DECLARING A TABLE AS LA_RRR DECLARES IT AS A PARENT AND IS NOT A CLASSIFICATION AT ALL. ***
*** AND THE DISTINCTION I HAD BEEN MISSING ALL DAY: A RESTRICTION SAYS WHAT YOU MAY NOT DO. A RESPONSIBILITY SAYS WHAT
YOU MUST DO. ***
  LA_Restriction   192   flood zones, brownfield designations, the CCCL, historic designation, archaeological survey
                         triggers, sea turtle lighting, easements, rights of way, wind design standards
  LA_Responsibility 14   EVACUATION ZONES - under Ch.252 F.S. a mandatory order creates an obligation ON THE OCCUPANT
                         TO LEAVE. Nothing about permitted use changes; THE DUTY IS TO ACT, and it is triggered by an
                         event rather than permanently in force.
                         AND ASSESSMENTS - a Ch.190 CDD levy and an impact fee ARE OBLIGATIONS TO PAY, not prohibitions.
                         A buyer inherits a CDD assessment for 20-30 years and NOTHING ABOUT WHAT THEY MAY BUILD CHANGES.
IT ALSO SETTLES THE admin_boundary QUESTION I HAD LEFT OPEN AND REFUSED TO GUESS AT: AN EVACUATION ROUTE IS CONTEXT AND
AN EVACUATION ZONE IS A RESPONSIBILITY. Only the standard names the difference, and I had flagged the mix without being
able to resolve it.
LA_Right IS ADDED FOR COMPLETENESS AND HOLDS NOTHING - WHICH IS ITSELF A FINDING. Our ownership tables are declared
LA_Party and VM_ValuationUnit. THE RIGHT ITSELF - THE THING OWNSEQ, PCTOWN AND OWNTYPE1 DESCRIBE - HAS NO TABLE OF ITS
OWN. We model the PARTY and the VALUATION UNIT and not the RIGHT that connects them, which is a modelling gap rather
than a naming one, and it is the same gap the LA_BAUnit sum(share)=1 constraint operates over.
NINTH TIME TODAY THE STANDARD HELD SOMETHING I BUILT AROUND.

### 9. A DISCRIMINATING RATE DOES NOT PROVE polygon - IT IS ALSO THE SIGNATURE OF HALF A SPLIT topological LEVEL

`rule` | authority: ISO 19152 LA_Level.structure; measured on the Marion split | measured: 2026-08-18 | cc

CC PROPOSED DERIVING LA_Level.structure FROM THE CONTAINMENT EVIDENCE: TILING_COVERAGE = topological, PASS WITH A
DISCRIMINATING RATE = polygon. THEY ASKED FOR CONFIRMATION BEFORE BUILDING ON IT. I TESTED IT AND THE SECOND HALF IS
WRONG - AND IT WOULD HAVE RE-ENCODED THE EXACT DEFECT THE GATE EXISTS TO PREVENT.
*** THE PROOF IS THE MARION PAIR, MEASURED: ***
  marion_fema_flood_zones_2017    9.00% of 200 probes    ALL sfha_tf = T
  marion_fema_flood_other_areas  91.00% of 200 probes    ALL sfha_tf = F
  9.00 + 91.00 = 100.00 EXACTLY.
UNDER CC RULE THE 9% LAYER IS "polygon" - GAPS BY DESIGN, ABSENCE MEANS not_available. IT IS NOT. IT IS HALF OF A
TOPOLOGICAL LEVEL WHOSE OTHER HALF IS 91%, AND FILING IT AS polygon WOULD MAKE THE FALSE-CLEARANCE-BY-TABLE-SPLIT
PERMANENT AND INVISIBLE.
AND THE CONTROL CASES CONFIRM IT: marion_fema_flood_1983 AND marion_fema_flood_2008 BOTH MEASURE 100.00% - COMPLETE
FIRMS, GENUINELY TOPOLOGICAL. lee_firm_panels 100.00%. volusia_zoning 97.50%.
*** THE RULING ***
  100% OR TILING_COVERAGE -> structure = topological. EVIDENCED, SAFE TO WRITE.
  ANYTHING BELOW      -> structure STAYS NULL, MEANING NOT ASSESSED. NEVER WRITE polygon FROM A RATE.
polygon MUST BE DECLARED FROM KNOWING THE LAYER - wetlands, easements and brownfields have gaps BY DESIGN and that is a
fact about the phenomenon, not about a probe.
*** AND A DETECTOR FALLS OUT, BUT IT IS A LEAD AND NOT A PROOF. *** Two layers in the SAME SCOPE whose rates sum to
~100 are a candidate split pair. I ran it: it finds the real Marion pair at exactly 100.00 - AND ALSO FINDS
lee_archaeological_sensitivity + lee_coastal_building_zone AT 101.50, WHICH IS MEANINGLESS COINCIDENCE ACROSS DIFFERENT
CONCEPTS.
SO THE DETECTOR REQUIRES SAME SCOPE AND SAME CONCEPT, AND EVEN THEN IT FLAGS FOR A READ RATHER THAN DECIDING. A
coincidence of arithmetic is not a structural fact - which is the low-entropy-anchor lesson in a new form.

### 10. YES - THE REGISTER IS A PARTY WITH A ROLE, NOT AN ENUM. CI_RoleCode ALREADY DISTINGUISHES custodian FROM distributor.

`mapping` | authority: ISO 19152-1 LA_Source.source: CI_Responsibility; ISO 19115 CI_RoleCode; ISO 19152-2:2025 scope | measured: 2026-08-18 | murphy

MURPHY ASKED WHETHER LADM ANSWERS THE REGISTER QUESTION. IT DOES, AND IT ANSWERS THE HARDER HALF OF IT - the half CC
measured and could not resolve.
LA_Source CARRIES + source: CI_Responsibility, WHICH IS ISO 19115. CI_Responsibility IS A PARTY PLUS A ROLE, AND
CI_RoleCode IS A CODE LIST:
  resourceProvider | CUSTODIAN | owner | user | DISTRIBUTOR | ORIGINATOR | pointOfContact |
  principalInvestigator | processor | publisher | author
*** THAT IS CC FINDING, ALREADY IN THE VOCABULARY. FEMA IS THE originator AND custodian OF A FIRM. THE COUNTY THAT
REPUBLISHES IT IS THE distributor. TWO PARTIES, TWO ROLES, ONE SOURCE. ***
CC MEASURED IT WITHOUT HAVING THE NAME FOR IT: ONLY 5 OF 54 FLOOD TABLES CARRY A FEMA HOST; THE OTHER 49 CAME FROM
COUNTY HOSTS SERVING FEDERAL DATA. They called it "register and supply diverge". THE STANDARD CALLS IT custodian AND
distributor AND ALLOWS BOTH TO BE RECORDED ON ONE SOURCE.
*** SO OUR register_type ENUM IS THE WRONG SHAPE, NOT THE WRONG IDEA. *** federal|state|county|municipal is ONE VALUE
where the standard models a SET OF (party, role) PAIRS. A FIRM republished by a county has two responsible parties and
our column can hold one.
IT IS A DEFENSIBLE PROFILE SIMPLIFICATION IF AND ONLY IF WE SAY WHICH ROLE IT MEANS. register_type = custodian, ALWAYS,
AND THE DISTRIBUTOR IS RECORDED SEPARATELY IN provenance_all WHERE THE HOST ALREADY LIVES. Written down, that is a
profile decision. Unwritten, it is an ambiguity that will be read as whichever the reader assumes.
*** AND THE PART 2 SCOPE STATEMENT DESCRIBES MURPHY SHELF IN THE STANDARD OWN WORDS: ***
"INTERNATIONAL LAW, CONSTITUTIONAL LAW, PUBLIC LAW AND PRIVATE LAW DEFINE DIFFERENT GEOGRAPHICAL SPACES THAT JUXTAPOSE
OR OVERLAP EACH OTHER TO PRODUCE A COMPLEX LEGAL REALITY. HARMONIZING AND INTEGRATING THE ACTIVITIES RELATED TO
MANAGEMENT OF THESE LEGAL SPACES IS THE OVERARCHING IDEA OF THE LAND ADMINISTRATION PARADIGM."
FEDERAL, STATE, COUNTY AND LOCAL SPACES OVERLAPPING ON ONE PARCEL. THAT IS THE SHELF, AND IT IS THE STATED PURPOSE OF
THE STANDARD RATHER THAN A THING WE INVENTED.
AND IT NAMES THE FOUR PARTS WE HAVE BEEN BUILDING SEPARATELY ALL DAY: "LEGAL ACTORS - INDIVIDUALS, ORGANIZATIONS,
STATES - (PARTY) CREATE AMONG THEMSELVES SETS OF OBLIGATIONS (RIGHTS, RESTRICTIONS, RESPONSIBILITIES) WITH THE
SPECIFICITY OF HAVING A GEOGRAPHICAL COMPONENT (SPATIAL UNIT)... ALL THESE ELEMENTS ARE RECOGNIZED THROUGH LEGAL
INSTRUMENTS AND OFFICIAL DOCUMENTS (SOURCE)."
Party, RRR, SpatialUnit, Source. lee_easements holds all four in one row and we found that by accident yesterday.
TENTH TIME THE STANDARD HELD SOMETHING WE BUILT AROUND.

### 11. LADM DOES NOT MODEL INSURANCE, AND THE REASON IS PRECISE RATHER THAN AN OVERSIGHT

`mapping` | authority: ISO 19152-4:2025 scope; FLOIR ISU Jan 2026; Citizens 2026-04-30 | measured: 2026-08-19 | murphy

MURPHY ASKED WHETHER INSURANCE CAN BE MAPPED TO A STANDARDISED LADM TABLE. I CHECKED THE SCOPE BEFORE BUILDING.
*** ISO 19152-4:2025 COVERS FOUR THINGS: ASSESSED VALUES AND VALUATION PROCEDURES, TRANSACTION PRICES, SALES
STATISTICS, AND VALUATION UNITS. AN INSURANCE PREMIUM IS NONE OF THEM. ***
A VALUATION IS WHAT THE THING IS WORTH. A PREMIUM IS WHAT IT COSTS TO HOLD. Part 4 models the first and is silent on
the second, and that silence is DELIBERATE - a cadastre records value, use and rights, not carrying costs. Nor is it
ExtTaxation: insurance is a private contract, not a levy.
SO fl_insurance_avg_premiums AND fl_citizens_policies_by_county WERE DECLARED VM_Valuation AND THAT WAS WRONG - it
asserted that the state regulator publishes a valuation of Florida property. FLOIR PUBLISHES WHAT INSURERS CHARGE.
*** BUT THE STANDARD DOES GIVE THE GRANULARITY: VM_ValuationUnitGroup IS ONE OF PART 4 FOUR UNIT CONSTRUCTS, AND OUR
DATA IS COUNTY-LEVEL - A GROUP OF VALUATION UNITS, NOT ONE UNIT. *** insurability_by_group attaches by geo_id to that
class. Attaching it to VM_ValuationUnit would assert a parcel-level fact we do not have.
AND THE RISK BEHIND THE PREMIUM IS ALREADY LADM: wind zones, flood zones and the windborne debris region are
LA_Restriction. THE PREMIUM IS THE PRICED CONSEQUENCE OF A RESTRICTION WE ALREADY MODEL, which is why it belongs beside
the restriction rather than inside it.
*** BUILT: insurability_by_group, 67 COUNTIES, ALL COMPLETE. ***
  average wind share 44.5%, MAXIMUM 77.4%
  FOUR COUNTIES WHERE CITIZENS IS AT OR ABOVE THE PRIVATE MARKET - MONROE $7,668 vs $7,829 at 77.4% wind, FRANKLIN
  $5,459 vs $5,235 (ABOVE), GULF $4,022 vs $3,759 (ABOVE), OKALOOSA $3,869 vs $3,891.
*** IN THREE OF THE FOUR THE INSURER OF LAST RESORT IS NOW MORE EXPENSIVE THAN THE MARKET IT EXISTS TO BACKSTOP. THAT
IS NOT A PRICING QUIRK - IT IS THE MEASURABLE SIGNATURE OF A WITHDRAWN PRIVATE MARKET, AND ALL FOUR ARE COASTAL
PANHANDLE OR KEYS. ***
ELEVENTH TIME THE STANDARD ANSWERED A QUESTION I WOULD OTHERWISE HAVE GUESSED - AND THE ANSWER WAS NO, WHICH IS ITSELF
THE FINDING: THIS IS THE 543-TABLE PATTERN AGAIN. WHAT A BUYER NEEDS AND WHAT A CADASTRE DOES NOT RECORD.

### 12. THE LOCAL EXTENSIONS NOW FOLLOW LADM OWN CONVENTION - Ext<Thing>, NOT AN INVENTED BUCKET

`mapping` | authority: ISO 19152-1 external stereotype classes; ISO 19152-4 VM_ValuationUnitGroup | measured: 2026-08-19 | murphy

MURPHY: CREATE THAT DATA CLASSIFICATION USING LADM OWN EXAMPLES. NO SENSE MISSING THESE DATASETS WHEN THEY ARE
IMPORTANT.
*** THE STANDARD NAMES ITS EXTERNAL BLUEPRINTS Ext<Thing>: ExtAddress, ExtLandCover, ExtPhysicalUtilityNetwork,
ExtTaxation, ExtArchive, ExtParty. WE INVENTED EXT_Context - A BUCKET THE STANDARD DOES NOT HAVE - AND A BUCKET IS NOT
A CLASSIFICATION. ***
FIVE LOCAL BLUEPRINTS DECLARED IN THE STANDARD OWN FORM, 668 TABLES MIGRATED:
  ExtAmenity                348  POIs near a parcel holding no interest in it. AND THE MEASURED RULE THAT TRAVELS WITH
    THEM: across eight infrastructure layers THE CAPABILITY FIELD IS THE ONE THAT IS EMPTY - hydrant flow rate, bridge
    clearance, sidewalk width, stormwater invert, bus headway. AN INFRASTRUCTURE LAYER IS A PRESENCE LAYER UNLESS
    PROVED OTHERWISE.
  ExtHazardEvent            195  a dated event over a jurisdiction. NOT a restriction - BUT STILL A MATERIAL DISCLOSURE
    FACT UNDER Johnson v. Davis AND s.627.7073 F.S. Joins by jurisdiction or FIPS, never by parcel.
  ExtContaminationSite       66  a facility point whose obligation runs with the SITE. The test that split contamination
    86 one way and 55 the other: DOES THE INSTRUMENT ATTACH TO THE PARCEL.
  ExtAdministrativeBoundary  59  determines WHICH authority applies. AN EVACUATION ROUTE IS THIS; AN EVACUATION ZONE IS
    LA_Responsibility, and only the standard resolved that split.
  ExtInsurance                2  the priced consequence of a restriction we already model, at VM_ValuationUnitGroup
    granularity.
*** WHY THIS MATTERS AND IS NOT COSMETIC: A CLASS NAMED FOR WHAT IT IS CAN BE TESTED AGAINST THE STANDARD. A CLASS
NAMED "Context" CANNOT - IT ASSERTS ONLY THAT SOMETHING IS NOT IN THE MODEL, WITHOUT SAYING WHAT IT IS INSTEAD. That is
why 155 unsubtyped rows are still unclassifiable: THE BUCKET HID THEM. ***
30 ISO CLASSES, 11 DECLARED LOCAL BLUEPRINTS, ALL FK-ENFORCED. legacy_class RETAINED ON EVERY MIGRATED ROW so the
rename is reversible and auditable per VersionedObject.
AND THE FINDING UNDERNEATH IS UNCHANGED: THE STANDARD IS SILENT ON THESE BECAUSE THEY ARE NOT LAND ADMINISTRATION
FACTS. A school near your house holds no interest in your parcel; a hurricane declaration over your county imposes
nothing on you; AN INSURANCE PREMIUM IS NOT A VALUATION. THEY ARE WHAT A BUYER NEEDS AND WHAT A CADASTRE DOES NOT
RECORD - AND THAT GAP IS THE ENTIRE REASON A PIR EXISTS.

### 13. LADM MODELS TIMESHARE NATIVELY - LA_RRR.timeSpec IS DEFINED AS "OPERATIONAL USE OF A RIGHT IN TIME SHARING"

`mapping` | authority: ISO/DIS 19152 LA_RRR.timeSpec; s.721.05 F.S. | measured: 2026-08-21 | murphy

MURPHY ASKED WHETHER LADM HAS ANYTHING ON TIMESHARE. IT HAS AN ATTRIBUTE BUILT FOR IT, AND THE DEFINITION IS VERBATIM.
ISO/DIS 19152 CLAUSE ON LA_RRR: *** "timeSpec: OPERATIONAL USE OF A RIGHT IN TIME SHARING." *** The maintenance record
adds that the NOTE beneath it describes RECURRING PATTERNS, and the WD3 text gives examples: "a recurring pattern
(every week-end, every summer, etc.)."
THE FULL LA_RRR SIGNATURE IS THE WHOLE TIMESHARE STRUCTURE IN FOUR ATTRIBUTES:
  + description   + share: Rational [0..1]   + shareCheck: Boolean [0..1]   + timeSpec: ExtTime
  AND ON LA_BAUnit THE CONSTRAINT: {sum(RRR.share) = 1 per type}
*** SO A FLORIDA TIMESHARE IS: ONE LA_BAUnit (the unit), 52 LA_Right INSTANCES, EACH WITH share = 1/52 AS A Rational,
EACH WITH A timeSpec GIVING ITS RECURRING WEEK, EACH TO A DIFFERENT LA_Party. AND THE SHARES SUM TO 1, SO THE BAUnit
CONSTRAINT VALIDATES IT RATHER THAN FLAGGING IT. ***
share IS Rational - A NUMERATOR AND A DENOMINATOR - WHICH IS WHY 1/52 IS EXPRESSIBLE EXACTLY. A percent column cannot
hold 1/52 without rounding, AND 52 ROUNDED PERCENTAGES DO NOT SUM TO 100.
AND THE FLORIDA STATUTE USES THE SAME LANGUAGE THE STANDARD DOES: s.721.05 defines a timeshare estate as an interest
under which the right of use "CIRCULATES among the various purchasers... ON A RECURRING BASIS for a period of time."
*** CIRCULATES AND RECURRING IS timeSpec. THE STATUTE AND THE STANDARD DESCRIBE THE SAME OBJECT. ***
*** AND THE TELLING PART: A PUBLISHED LADM ARCGIS IMPLEMENTATION OMITS THE FIELD ENTIRELY - "I omitted the
LA_RRR:timeSpec field because I could not find documentation as to its type or purpose." THE ONE ATTRIBUTE
PURPOSE-BUILT FOR TIMESHARE IS THE ONE IMPLEMENTERS DROP, BECAUSE IT IS UNDER-DOCUMENTED AND LOOKS OPTIONAL. ***
WE HAVE NEITHER share NOR timeSpec ON ANY DECLARED CLASS. Our shareCheck work went straight to the tenancy whitelist -
TIC, TE, JT - and never reached the case the attribute was designed around.
ELEVENTH TIME THE STANDARD HELD SOMETHING WE HAD NOT LOOKED FOR. And this one is the strongest argument yet for the
LADM decision: A THIRD ENTITY LEVEL WOULD HAVE HAD TO BE INVENTED, AND IT DOES NOT - IT IS A RIGHT WITH A SHARE AND A
TIME SPECIFICATION, WHICH THE MODEL ALREADY HAS.

### 14. THE FRAGMENT DEFECT IS COVERED - AND LADM SAYS WE ARE CONFLATING TWO DIFFERENT OBJECTS

`mapping` | authority: ISO 19152 LA_BAUnit / LA_SpatialUnit; van Oosterom TC211 workshop | measured: 2026-08-22 | murphy

MURPHY ASKED WHETHER LADM COVERS THE FRAGMENT DEFECT - 97,380 PARCELS STORED AS MULTIPLE GEOMETRY ROWS SHARING ONE
parcel_id. IT DOES, AND THE ANSWER IS SHARPER THAN "YES".
*** VAN OOSTEROM, ISO/TC211 LADM WORKSHOP, ON THE CORE MODEL: "LA_Party Peter has LA_RRR ownership on LA_BAUnit
Peter's estate CONSISTING OF 2 LA_SpatialUnit PARCELS (WITH SAME LA_RRR)." ***
SO LADM HAS AN EXPLICIT CONSTRUCT FOR ONE OWNERSHIP OVER SEVERAL PARCELS: THE LA_BAUnit. And LA_SpatialUnit carries
area: LA_AreaValue [0..*] - MULTIPLICITY MANY - so a single spatial unit can legitimately carry several area values.
*** THE POINT IS THAT THESE ARE TWO DIFFERENT OBJECTS AND OUR STORAGE CANNOT TELL THEM APART: ***
  ONE SPATIAL UNIT, MULTIPART GEOMETRY   a parcel split by a road, a river or an island. ONE suID. Aggregating the
    pieces is CORRECT and gives the true area.
  SEVERAL SPATIAL UNITS UNDER ONE BAUnit  Peter's estate. TWO parcels, TWO suIDs, one ownership. Aggregating the areas
    is ALSO correct for the estate - BUT THEY ARE SEPARATE LEGAL PARCELS THAT CAN BE SOLD APART.
*** A SHARED parcel_id IN OUR TABLES IS CONSISTENT WITH BOTH, AND THE CONSEQUENCE DIFFERS: in the first case a buyer is
buying one parcel; in the second they may be buying two, and either could be conveyed separately. ***
SO THE JULY RULING - AGGREGATE, NEVER DEDUPE - IS CORRECT FOR AREA IN BOTH CASES, AND IT WAS RIGHT: reading one
fragment gave Vizcaya 36.5 of 50.6 acres, and one parcel had 1,215 fragments where reading one gave a 1,580x error.
*** BUT AGGREGATION ANSWERS THE AREA QUESTION AND HIDES THE LEGAL ONE. LADM WOULD ASSIGN A suID PER SPATIAL UNIT AND
BIND THEM WITH AN LA_BAUnit. WE HAVE NEITHER - NO suID, AND LA_BAUnit HOLDS 4 ROWS. ***
AND ST_Contains MAKES IT WORSE, WHICH IS RULING 284 ARRIVING FROM THE OTHER DIRECTION: ST_Contains AGAINST A FRAGMENT
ASKS WHETHER THE RESTRICTION CONTAINS ONE SHARD. A brownfield covering a whole legal parcel fails ST_Contains against
every fragment that extends beyond it.
WHAT WOULD ACTUALLY RESOLVE IT IS A READ, NOT A RULE: WHERE FRAGMENTS ARE CONTIGUOUS THEY ARE ONE SPATIAL UNIT; WHERE
THEY ARE DISJOINT THEY MAY BE SEVERAL. ST_Touches OR A UNION-AND-COUNT-RINGS TEST DISTINGUISHES THEM, AND NOBODY HAS
RUN IT. Recorded as the open question rather than assumed either way.

### 15. THE FRAGMENT TEST RUN - 51% CONTIGUOUS, 49% DISJOINT. BOTH LADM CASES ARE REAL AND WE CANNOT TELL THEM APART.

`measurement` | authority: ST Johns, 300 groups, measured 2026-08-22 | measured: 2026-08-22 | claude

BACKLOG 181 ASKED WHETHER FRAGMENTS ARE ONE MULTIPART SPATIAL UNIT OR SEVERAL SPATIAL UNITS UNDER ONE BAUnit. RAN IT
ON ST JOHNS - 300 MULTI-ROW parcel_id GROUPS, ST_UnaryUnion THEN COUNT COMPONENTS:
  153 CONTIGUOUS (51%)   ONE LA_SpatialUnit WITH MULTIPART GEOMETRY. Aggregating is correct and complete.
  147 DISJOINT   (49%)   POSSIBLY SEVERAL LA_SpatialUnit UNDER ONE LA_BAUnit - van Oosterom's Peter's estate.
  average 2.5 components, MAXIMUM 27
*** THE SPLIT IS NEARLY EVEN, SO NEITHER SIMPLIFICATION IS AVAILABLE. A rule that treats all fragments as one parcel is
wrong half the time; a rule that treats them as separate parcels is wrong the other half. ***
AND THE 500-GROUP CHECK FIRST: EVERY ONE IS A MULTI-ROW GROUP AND NONE IS A SINGLE MULTIPOLYGON ROW - 2,322 rows across
500 groups. SO THE FRAGMENTATION IS IN THE ROW STRUCTURE, NOT IN THE GEOMETRY TYPE, WHICH IS WHY ST_NumGeometries ON A
SINGLE ROW WOULD HAVE MISSED IT ENTIRELY.
*** DISJOINT DOES NOT PROVE SEPARATE PARCELS - a parcel severed by a road or a river IS ONE LEGAL PARCEL IN TWO PIECES,
and Florida has a great deal of both. WHAT THE 49% ESTABLISHES IS THAT THE QUESTION IS REAL AT SCALE, NOT THAT THE
ANSWER IS "SEVERAL". Distinguishing severed-by-a-feature from genuinely-separate NEEDS THE LEGAL DESCRIPTION, WHICH IS
volusia_cama_legal AND THE DOR SDF, NOT GEOMETRY. ***
AND ST JOHNS WAS ALREADY MEASURED AT 100% ONE OWNER ONE ADDRESS ACROSS 3,443 GROUPS - CONSISTENT WITH THE BAUnit CASE
AND NOT EVIDENCE AGAINST IT. Peter's estate has one owner too.
THE JULY RULING STANDS FOR AREA - AGGREGATE, NEVER DEDUPE - AND IS NOW MEASURED AS NECESSARY IN 100% OF CASES AND
SUFFICIENT IN 51%.

### 16. THE GAP MEASURED - 70% OF DISJOINT FRAGMENTS ARE UNDER 100 FEET APART. THAT IS A ROAD, NOT A SECOND PARCEL.

`measurement` | authority: St Johns, 40 groups, measured 2026-08-22 | measured: 2026-08-22 | cc

CC ASKED THE QUESTION I HAD NOT: NOT WHETHER FRAGMENTS ARE DISJOINT, BUT HOW FAR APART. RAN IT ON ST JOHNS - 40
multi-row groups, 10 genuinely disjoint after ST_UnaryUnion, MINIMUM PAIRWISE GAP PER GROUP:
  7 OF 10 UNDER 100 FEET   MINIMUM 28 FEET
  1 between 100 and 1,000 feet
  2 OVER 1,000 FEET, MAXIMUM 1,112
*** 28 FEET IS A RESIDENTIAL STREET. A PARCEL SEVERED BY A ROAD IS ONE LEGAL PARCEL IN TWO PIECES, AND THAT IS 70% OF
THE DISJOINT CASES. MY 49% DISJOINT FIGURE WAS TRUE AND MEANT SOMETHING DIFFERENT FROM WHAT I IMPLIED BY IT. ***
SO THE SHAPE IS: 51% CONTIGUOUS, PLUS ROUGHLY 34% SEVERED-BY-A-FEATURE, LEAVING ABOUT 15% WHERE THE PIECES ARE FAR
ENOUGH APART TO BE A GENUINE BAUnit QUESTION. NOT HALF. Around one in seven.
*** AND THE TWO OVER 1,000 FEET ARE THE REAL FINDING RATHER THAN THE NOISE. Those cannot be a road. They are either
Peter's estate - two parcels, one ownership, separately conveyable - or a key-collision where one parcel_id has been
reused. EITHER MATTERS TO A BUYER AND THEY ARE OPPOSITE PROBLEMS. ***
DISTANCE IS THE DISCRIMINATOR AND IT IS CHEAP. Geometry answered a question I had said needed the legal description -
I wrote "separating severed-by-a-feature from genuinely-separate REQUIRES the legal description" and it required one
more geometry measurement.
AND THE FIRST ATTEMPT RETURNED ZERO ROWS: ST_Dump SELF-JOINED COMPARES EACH PART TO ITSELF, DISTANCE ZERO, FILTERED OUT
BY gap > 0. RUNG ZERO CAUGHT IT - THE FILTER MATCHED NOTHING, SO THE TEST HAD NOT RUN. Rewritten with an ordered
pairwise join on path index.

### 17. FRAGMENTATION IS A COUNTY RECORDING PRACTICE, NOT A PROPERTY OF FLORIDA PARCELS - 0.5% TO 93.6%

`measurement` | authority: CC per-county; Miami-Dade reproduced 2026-08-22 | measured: 2026-08-22 | cc

CC WENT TO MEASURE THE THRESHOLD I PROPOSED AND FOUND THE THRESHOLD IS THE WRONG INSTRUMENT.
*** MEASURED PER COUNTY, AND I REPRODUCED MIAMI-DADE INDEPENDENTLY AT 91.7% OF 60 GROUPS, MAX 21 COMPONENTS: ***
  MIAMI-DADE  93.6% disjoint, max 39 components
  Broward     80.4%, max 15        co_no 29  81.6%, max 8       co_no 13  74.0%
  ST JOHNS    49%   <- THE COUNTY I MEASURED AND GENERALISED FROM
  VOLUSIA      0.5%, max 2   -- ONE DISJOINT GROUP IN 183
*** A 180-FOLD SPREAD. FRAGMENTATION IS NOT A PROPERTY OF FLORIDA PARCELS - IT IS A PER-COUNTY RECORDING PRACTICE, AND
MY 51/49 IS A ST JOHNS NUMBER I PRESENTED AS A FLORIDA NUMBER. ***
THAT IS THE THIRD TIME THIS WEEK I HAVE GENERALISED FROM ONE SAMPLE: one row to a column, one county to a state, and
one fitting case to a vocabulary rule. THE SAMPLE WAS ALWAYS REAL AND THE POPULATION WAS ALWAYS WRONG.
*** AND A SINGLE THRESHOLD CANNOT BE RIGHT ACROSS THAT RANGE. In Volusia a disjoint group is a genuine anomaly worth
reading; in Miami-Dade it is the normal case and reading them all is 93.6% of the county. ***
CC ALSO KILLED THE SOURCE I NAMED: hillsborough_right_of_way IS ST_MultiLineString - RIGHT-OF-WAY LINES, NOT POLYGONS.
There is no width to measure from it, and widths appear only in free text in a column that is 3.6% populated. I NAMED IT
FROM A COLUMN-MAP NOTE WITHOUT CHECKING ITS GEOMETRY TYPE, WHICH THE CLAIM ALREADY RECORDED.
*** AND CC PROPOSED A BETTER INSTRUMENT THAN ANY THRESHOLD: BUILD THE ST_ShortestLine BETWEEN TWO DISJOINT COMPONENTS
AND ASK WHETHER A ROAD CENTERLINE CROSSES IT. THAT IS EVIDENCE RATHER THAN A PROXY FOR EVIDENCE. ***
BUT IT CANNOT BE VALIDATED WHERE IT MATTERS: ST JOHNS HAS NO ROAD LAYER. VOLUSIA HAS ONE AND ONE DISJOINT GROUP.
MIAMI-DADE HAS 93.6% DISJOINT AND NO ROAD CENTERLINE LAYER. *** ROAD COVERAGE AND FRAGMENTATION DO NOT OVERLAP, SO THE
CLASSIFIER IS UNTESTABLE IN THE COUNTIES WHERE IT WOULD BE USED. THAT IS A COVERAGE GAP, NOT A THRESHOLD QUESTION. ***
AND CC HIT RUNG ZERO AGAIN ON THE WAY - THE WIDTH QUERY RETURNED ZERO ROWS BECAUSE THE GEOMETRY FILTER MATCHED NOTHING,
AND THEY CHECKED RATHER THAN CONCLUDING THE WIDTHS WERE ABSENT.

### 18. MIAMI-DADE DISJOINT PARTS ARE REAL LAND, NOT SLIVERS - 1.7% UNDER 100 SQ FT, LARGEST 26 ACRES

`measurement` | authority: 40 Miami-Dade groups, 115 parts, measured 2026-08-22 | measured: 2026-08-22 | claude

THE OBVIOUS EXPLANATION FOR 93.6% DISJOINT IS DIGITISING SLIVERS - THIN ARTEFACT POLYGONS LEFT BY A BAD SPLIT. I
TESTED IT BEFORE BELIEVING IT AND IT IS FALSE.
MEASURED, 40 MIAMI-DADE MULTI-ROW GROUPS, 115 DISJOINT PARTS AFTER ST_UnaryUnion:
  2 OF 115 UNDER 100 SQ FT - 1.7%. SMALLEST 29.65 SQ FT. LARGEST 1,144,174 SQ FT - TWENTY-SIX ACRES.
*** MIAMI-DADE FRAGMENTS ARE SUBSTANTIAL PARCELS OF LAND, NOT ARTEFACTS. A 26-ACRE COMPONENT SHARING A parcel_id WITH
ANOTHER COMPONENT IS NOT A DIGITISING ERROR - IT IS EITHER A GENUINE MULTI-PARCEL HOLDING OR A REUSED KEY. ***
SO THE THREE CANDIDATE EXPLANATIONS NARROW TO TWO, AND THEY ARE OPPOSITE PROBLEMS:
  PETER'S ESTATE - several LA_SpatialUnit under one LA_BAUnit, separately conveyable, AND THE BUYER NEEDS TO KNOW
  A REUSED parcel_id - a key collision, AND THE REPORT IS DESCRIBING TWO PROPERTIES AS ONE
*** AND THE SECOND WOULD BE THE MOST SERIOUS DEFECT FOUND IN THIS DATABASE, BECAUSE IT MEANS THE PARCEL KEY IS NOT
UNIQUE IN THE COUNTY WITH THE MOST PARCELS. Every join, every report and every containment test assumes it is. ***
THAT IS TESTABLE WITHOUT ROADS AND WITHOUT ACQUISITION: IF THE COMPONENTS OF ONE parcel_id CARRY DIFFERENT own_name,
DIFFERENT phy_addr1 OR DIFFERENT jv, IT IS A COLLISION. IF THEY AGREE, IT IS ONE HOLDING. St Johns was already
measured at 100% ONE OWNER ONE ADDRESS ACROSS 3,443 GROUPS - CONSISTENT WITH THE ESTATE CASE - AND MIAMI-DADE HAS
NEVER BEEN TESTED.
THAT TEST DOES NOT NEED A ROAD LAYER, WHICH IS WHAT BLOCKED THE OTHER PATH. It should run before any acquisition is
scheduled.

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

### 5. A DECLARATION WRITTEN FROM A COLUMN NAME IS UNAUDITABLE. MEASURE THE JOIN OR DO NOT DECLARE.

`test` | measured: 2026-08-16 | murphy

I declared ten county parcel keys from a column-name priority list and never ran the join. MEASURED, 4,000-row sample each, wrong-county control 0 throughout:
  VERIFIED DIRECT        highlands.parcelno 3,966 | putnam.parcelid 3,964 | hendry.parcelno 3,906
  RECOVERED BY TRANSFORM collier 0 -> 4,325 lpad(k,11,'0') | lake 0 -> 4,014 strip dashes from the SPINE
                         walton 0 -> 4,804 strip dashes BOTH sides
  UNRESOLVED             clay 009796-000-00 vs 01-04-23-000001-001-00 | bay 00186-020-000 vs 00001000000
                         citrus altkey is a 7-DIGIT ALTERNATE KEY against a spine using 15E17S12 0RIV0 0001 -
                         A DIFFERENT KEY SPACE, and no transform fixes it
  CORRECT AT ZERO        pinellas_non_recognized_parcels - non-recognized parcels are BY DEFINITION off the roll
SIX OF TEN JOINED AT ZERO. Each would have served nothing while reporting a mapped key, and NOBODY DOWNSTREAM COULD
DISTINGUISH AN EMPTY JOIN FROM AN EMPTY COUNTY.
STANDING RULE: NO KEY IS DECLARED UNTIL THE JOIN IS MEASURED WITH A WRONG-COUNTY CONTROL. A note saying CONTENTS NOT
READ does not make an unmeasured declaration safe - it only makes it documented.

### 6. max() ON A TEXT KEY IS A SAMPLE, NOT A VERDICT

`test` | measured: 2026-08-16 | claude

bay_parcels.a1renum max sorts to "WHITE WESTERN". putnam_parcels.parcelid max sorts to "WT". Both look like a
destroyed key.
THEY ARE FINE. 99.7% and 99.99% of values are numeric, and the alphabetic ones are UNPARCELLED LAND - lakes,
DRAINAGE ROW, PARK, RECREATION PARK, SILVER LAKE, <New parcel>, UNK.
A COUNTY GIS LAYER CARRIES POLYGONS THAT ARE NOT PARCELS. Water bodies, rights of way and park tracts get a
placeholder in the key column because the polygon has to exist and has no parcel number.
Test the DISTRIBUTION (what fraction matches the expected shape), never a single extreme value. And an alpha value in
a numeric key column is a FINDING about unparcelled land, not necessarily a defect.

### 7. A DEAD COLUMN KILLS THE ANSWER, NOT THE QUESTION

`principle` | measured: 2026-08-16 | murphy

I measured pinellas_cama_rp_permits.sign_off_dt at 98.5% null and wrote that it supports no negative inference and an open permit must render not_available. THE MEASUREMENT WAS RIGHT AND THE CONCLUSION WAS THE WRONG SHAPE.
BY ISSUE YEAR:  2005 8.0% signed | 2006 8.9% | 2007 7.4% | 2008 2.9% | 2009 ONWARD ZERO, seventeen years, 63 rows total.
THAT IS A SYSTEM CHANGE AT THE COUNTY, not builders ceasing to close permits. The column is not_available from 2009 and thinly populated before it.
BUT AN UNCLOSED PERMIT USUALLY MEANS NOBODY FOLLOWED UP THE JOB, and that is precisely the buyer-facing fact - title-adjacent, can block a sale. I treated a dead column as though it closed the question.
THE ROUTE TO THE FINDING IS CROSS-EXAMINATION, ALREADY PROVEN: 6,097 of 15,801 Volusia marine improvements have NO permit within a year of their recorded build year, and 5,725 of those sit on parcels that DO have other permits. Two registers disagreeing, no dependence on any county populating a closeout field.
THE RULE: WHEN A COLUMN CANNOT ANSWER, ASK WHICH OTHER REGISTER CAN. Absence of evidence in one register is a reason to look in another, never a reason to withhold the question.

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

### 3. THE UNESTABLISHED 156 ARE A 31-COUNTY JOB, NOT A 400-CITY ONE - AND 9 WERE NOT MUNICIPAL AT ALL

`correction` | authority: ArcGIS Hub v3 search API; county DCAT-US feeds | measured: 2026-08-16 | murphy

I declared 156 layers unestablished on the reasoning that a municipal layer has no family endpoint. TWO THINGS WERE WRONG WITH THAT.
FIRST, NINE WERE NOT MUNICIPAL. Six hifld_ tables (nursing homes, shelters, police stations, dialysis centres, colleges, courthouses) plus fl_historical_aqi_by_area and two environmental_ tables. HIFLD IS ONE PUBLISHER AND 55 SIBLING hifld_ TABLES HAD ALREADY BEEN AGENCY-DECLARED IN THE SAME SESSION. My backfill matched on "has no provenance row" and never asked whether the family was already known. CORRECTED - 156 to 147.
SECOND, THE REMAINING 147 COLLAPSE TO 31 COUNTIES, not 400 municipalities:
  Palm Beach 14 | Miami-Dade 14 | Volusia 14 | Broward 13 | Lee 12 | Pinellas 12 | Orange 9 | Hillsborough 8
  Marion 7 | Brevard 5 | Manatee 4 | Pasco 4 | Polk 4 | + 18 counties with 1-3 each
COUNTY HUBS CARRY CITY LAYERS. Lake County's hub published Fruitland Park, Tavares, Montverde and Astatula FLU - measured 20 July. So enumerating 31 county DCAT feeds recovers most of the 147, and the six biggest counties alone cover 79 layers.
AND THERE IS A GLOBAL FALLBACK I DID NOT KNOW EXISTED: hub.arcgis.com/api/v3/datasets SEARCHES EVERY ArcGIS HUB AT ONCE - 43,149 datasets tagged parcels - returning esriRest and itemPage links per result, JSON:API, page[size] max 100. Per-site OGC API-Records also exists.
I COULD NOT DRIVE IT FROM HERE: the fetch tool strips query parameters, so my search returned an unfiltered default. THAT IS A TOOL LIMIT, NOT A DEAD END - curl in WSL passes params fine.
THE LESSON IS THE ONE I KEEP RELEARNING: I declared a gap structural without checking whether the structure was real. It was 31 directories, not 400.

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

### 6. TWO KINDS OF CONCEPT: RESOLVED AND CONTAINMENT. THEY DO NOT SHARE A MECHANISM.

`principle` | measured: 2026-08-16 | claude

RESOLVED - ONE layer answers for a place, chosen by precedence.
  flood     67 layers / 67 places - EXACTLY 1:1
  sinkhole  60 layers / 59 places
  The chain walks UPWARD, resolve_layer picks, and row_count IS LOAD-BEARING because the picker COMMITS TO A TABLE
  BEFORE LOOKING INSIDE IT.
CONTAINMENT - MANY layers may answer and THE GEOMETRY DECIDES.
  zoning + land_use  168 layers / 96 places
  A parcel is inside Tampa city limits or it is not. ST_Contains adjudicates. THERE IS NO PRECEDENCE QUESTION TO
  ANSWER - there is a candidate set and a spatial test.
THE RULING, AND THE REASON IS THE POINT: FOR A CONTAINMENT CONCEPT THE GEOMETRY IS ALREADY THE GATE. An empty layer
CANNOT contain the point, so it returns nothing - the same outcome row_count would produce, at no risk.
THE GATE IS LOAD-BEARING FOR FLOOD AND REDUNDANT FOR ZONING.
That is why forcing zoning through resolve_layers felt wrong. It answers a question zoning does not ask, and to do
it needed either a SECOND resolution primitive or a dependency on CITY-LIMITS COMPLETENESS - and our municipal
boundaries are 2021 vintage, so every annexation since is invisible. Option A would have made zoning coverage
depend on the stalest geometry we hold.
DO NOT GENERALISE THE FLOOD SUCCESS TO ZONING. Same registry, different question.

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

### 7. THE 2019 FRONTIER IS A SCRAPER THAT STOPPED ASKING, NOT A COUNTY THAT STOPPED PUBLISHING

`correction` | authority: Clerk of the Circuit Court scrape ledger | measured: 2026-08-16 | claude

volusia_or_scrape_progress - an UNDECLARED table nobody had opened - is the resumption ledger. One row per doctype
per week with a status. MEASURED:
  JUDGMENT/ORDER 606 weeks ok, to 2026-07-16 | LIEN 606 | LIS PENDENS 606 | RESTRICTIONS 468 ok + 138 empty
  DEED 218 ok, LAST WEEK 2019-02-28 | SATISFACTION 218 | RELEASE 218 | PARTIAL SATISFACTION 218
ZERO FAILED WEEKS ON ANY DOCTYPE. The four discharge doctypes were NEVER ATTEMPTED past February 2019.
THAT CHANGES THE ITEM FROM A LOSS TO A RESUMABLE JOB - roughly 388 weeks per doctype, no code change, because
or_satisfaction_frontier() is derived and advances as rows land.
AND THE LEDGER ALREADY ENCODES THE THREE COVERAGE STATES FOR THE SCRAPE ITSELF: ok is present, empty is a REAL
NEGATIVE (138 RESTRICTIONS weeks queried and holding nothing), an ABSENT week is not_available.
THE LESSON IS THE SIXTH INSTANCE TODAY: I described a gap for weeks and the artefact explaining it was an undeclared
table three joins away. SEARCH FOR THE ARTEFACT BEFORE DESCRIBING THE GAP.

### 8. THE LOT-VERSUS-INTEREST RELATION HAS THREE PUBLISHED SHAPES AND WE HOLD ALL THREE

`mapping` | authority: ISO 19152-4 VM_CondominiumUnit | measured: 2026-08-16 | claude

MIAMI-DADE publishes parent_folio PER UNIT. miamidade_property_boundaries: rows with a parent join the spine on the
PARENT at 99.5% and on their own folio at 0.02%. Combined key reaches 98.83%.
COLLIER publishes A RANGE. collier_cama_int_subcondos: hdrparcelid is the complex, begparcelid/endparcelid bound the
units, parcelcount says how many. Sample - EAGLE VIEW PROFESSIONAL PARK, header 7010000006, range 7010000022 to
7010000103, parcelcount 5. THE RANGE IS NOT DENSE - 5 parcels across an 81-id span, so JOIN the range, never
generate ids within it.
SARASOTA publishes NOTHING and it had to be inferred - which is where the defect was discovered, 58,000 parcels.
ISO 19152-4 has one class for this, VM_CondominiumUnit, and three counties express it three ways. THE STANDARD IS
WHAT LETS THEM BE THE SAME FACT.

### 9. THE DEED CHAIN IS ALREADY ASSEMBLED AND WAS CLASSED AS A RIGHT RATHER THAN A SOURCE

`measurement` | authority: Clerk of the Circuit Court via Volusia CAMA | measured: 2026-08-16 | claude

parcel_deed_chain - 108,864 instruments with altkey, parcel_id, instrument number, instrument TYPE, sale date,
price AND BOTH PARTIES. Sat as LA_RRR at E3.
IT IS AN LA_AdministrativeSource, NOT A RIGHT. The deed is the EVIDENCE; the right is what it conveys.
KEY VERIFIED: altkey on ALT_KEY, 3,955 of 4,000, wrong-county control 0.
WE HAVE BEEN SAYING THE JURIDICAL REGISTER IS ONE COUNTY DEEP AND UNBUILT. The deed chain for that county was
already built, keyed and joinable - grantor to grantee across 108,864 instruments, which is a CHAIN OF TITLE, not a
list of sales.
And it carries what the CAMA sales table does not: instr_type WARRANTY DEED distinguishes a conveyance that
warrants title from a quit claim that does not, which is the difference between a marketable chain and a gap.

### 10. A THIRD INDEPENDENT SOURCE OF BOOK AND PAGE, IN A TABLE CC CORRECTLY LEFT UNREAD

`measurement` | measured: 2026-08-16 | cc

county_land_interests, 51,200 rows. CC proved the join at 90.83% layer-side AND DECLINED TO DECLARE IT FROM A NAME THAT
HAD ALREADY MISLED BOTH OF US. Reading it:
  document_ref  "OR 5450, Page 4182"  and  "MI 10, Page 347"
  comments      "WARRANTY DEED" | "SPECIAL WARRANTY DEED"
  acquisition_date 1998-04-07 | 2019-07-29 | 1986-07-21     county_name Orange, county_fips 095
*** THAT IS A RECORDED INSTRUMENT POINTER PER ROW, WITH THE INSTRUMENT TYPE BESIDE IT AND THE ACQUISITION DATE. ***
"MI 10" IS A MISCELLANEOUS INSTRUMENTS BOOK, A DIFFERENT SERIES FROM OR - so the parser must read the prefix and must
not assume Official Records.
THIRD INDEPENDENT BOOK-AND-PAGE SOURCE FOUND TODAY: DOR SDF carries OR_BOOK/OR_PAGE/CLERK_NO IN ALL 67 COUNTIES;
volusia_cama_legal embeds OR references in 95.4% of its legal descriptions; AND NOW A COUNTY LAND-INTEREST REGISTER.
THE JURIDICAL REGISTER KEEPS TURNING UP INSIDE FISCAL AND ADMINISTRATIVE TABLES. We have been describing it as one
county deep and unbuilt; the POINTERS are statewide and scattered across tables nobody read.
CLASS: LA_RRR, not SYSTEM as the July pass had it. A county-held fee, easement or right-of-way RUNS WITH THE LAND and
constrains the adjacent or underlying owner.
AND THE NAME LIES TWICE: county_land_interests HAS NO COUNTY PREFIX AND HOLDS ONE COUNTY - extent -81.77..-80.93 /
28.35..28.79, county_fips 095, Orange. Any parcel outside Orange must return not_available.

### 11. sjc_plat_index IS THE PLAT SERIES - A FOURTH BOOK-AND-PAGE SOURCE AND THE FIRST THAT IS NOT A DEED

`measurement` | authority: Ch.177 F.S. | measured: 2026-08-17 | claude

COLUMNS: date_recor, section, township, range, plat_name, MAP_BOOK, PAGE_START, PAGE_END, sub_number, wats_numbe,
who, date_add, note.
AN LA_AdministrativeSource, NOT AN LA_SpatialUnit as declared. map_book + page_start/page_end IS THE RECORDED INSTRUMENT
REFERENCE FOR A SUBDIVISION PLAT UNDER Ch.177 F.S. IT INDEXES THE PLAT, NOT THE PARCELS THE PLAT CREATED, so adding a
parcel key would be wrong rather than missing.
FOURTH INDEPENDENT BOOK-AND-PAGE SOURCE TODAY - after DOR SDF in all 67 counties, volusia_cama_legal at 95.4% of rows,
and county_land_interests - AND THE FIRST IN THE PLAT SERIES RATHER THAN THE DEED SERIES. That is the distinction
"MI 10, Page 347" flagged in county_land_interests: THE BOOK PREFIX NAMES THE SERIES AND THE SERIES ARE DIFFERENT
REGISTERS. OR, MI and plat books are three separate sequences and a parser that assumes OR will silently mis-resolve.
DECLARED E2, NOT E0, AND THIS IS THE POINT: no key join and no containment join applies, AND I WILL NOT INVENT A THIRD
TO MAKE IT GRADE. An instrument index joins by section-township-range or by plat name. THE JOIN TYPE FOR AN INSTRUMENT
INDEX IS AN OPEN QUESTION, NOT A FAILURE, and forcing a grade would be the affirmative-false-permission error applied to
our own evidence.

### 12. SIXTH BOOK-AND-PAGE SOURCE - A PLAT REFERENCE INSIDE A RIGHT-OF-WAY LAYER

`measurement` | measured: 2026-08-17 | claude

hillsborough_right_of_way.plat = "BROOKESIDE PHASE 5A 5B AND 5C P.B. 147, PG 22", with type = "PLAT" beside it.
SIXTH INDEPENDENT BOOK-AND-PAGE SOURCE and the SECOND IN THE PLAT SERIES after sjc_plat_index. The running list:
  DOR SDF            OR_BOOK/OR_PAGE/CLERK_NO in ALL 67 COUNTIES        deed series
  volusia_cama_legal OR references in 95.4% of legal descriptions        deed series, free text
  county_land_interests  "OR 5450, Page 4182" AND "MI 10, Page 347"      deed AND miscellaneous series
  sjc_plat_index     map_book + page_start/page_end                      PLAT series
  flagler_bunnell_zoning  book_page "2489/1198" with from_code/to_code   ordinance, on a REZONING
  hillsborough_right_of_way  "P.B. 147, PG 22" in free text              PLAT series, in a RIGHT-OF-WAY layer
SIX SOURCES, FOUR BOOK SERIES - OR, MI, PLAT AND ORDINANCE - AND THE PREFIX IS WHAT NAMES THE SERIES. A parser that
assumes OR will silently mis-resolve four of the six.
AND notes = "50' PUBLIC R/W" CARRIES THE WIDTH AND WHETHER IT IS PUBLIC. A PRIVATE RIGHT OF WAY MEANS NO COUNTY
MAINTENANCE - a recurring cost the abutting owners carry, and a real finding for a buyer. IT IS IN FREE TEXT, NOT A
CODE, in both Hillsborough and Pasco.

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

### 4. ALL THREE PARTS ARE ZERO. AND THE CONFIDENCE IS NOT UNIFORM.

`measurement` | measured: 2026-08-16 | claude

  declared with no column map   0   (was 118)
  mapped with no LADM class     0   (was 207)
  declared with no provenance   0   (was 708)
  ladm_declaration          1,155 tables | layer_column_map 3,410 rows | data_source_registry 1,368 rows
THE THREE-PART TEST IS SATISFIED FOR EVERY DECLARED TABLE. IT IS NOT SATISFIED EQUALLY, AND THE ROWS SAY WHICH:
  VERIFIED - contents read, key measured against a negative control. DOR NAL 67, DOR SDF 67, FGDL parcels 9,
    cadastral, Miami-Dade property boundaries, sinkhole 60, and every table read individually today.
  FAMILY-DECLARED - agency known with confidence, PER-TABLE ENDPOINT NOT RECORDED, so the row CANNOT DRIVE A
    REFRESH. 552 tables: NAL, SDF, disaster, burn, superfund, brownfield, HIFLD schools/fire/hospitals.
  INFERRED - class derived from the table suffix and the already-declared column roles, NOT from reading the rows.
    ~200 tables backfilled today. LOWER CONFIDENCE. Re-read before any is served as a restriction.
  UNESTABLISHED - 156 municipal layers with no recorded endpoint. THE ROW EXISTS TO MAKE THE GAP COUNTABLE RATHER
    THAN INVISIBLE, and NO NEGATIVE FINDING MAY BE ASSERTED FROM ANY OF THEM.
A MUNICIPAL LAYER HAS NO FAMILY ENDPOINT: ~400 Florida municipalities each publish their own hub, so there is
nothing to declare at family level. The acquisition method is in section 07; the per-table URL was never captured.
REPORTING RULE: never say declared without saying at which confidence. Saying 1,155 declared while 156 cannot be
refreshed and ~200 were inferred is the same overstatement as saying wired when nothing reads it.

## 15-catalogue

### 1. THE CATALOGUE METHOD - SCHEMA AND CONTENTS TOGETHER, NEVER EITHER ALONE

`rule` | measured: 2026-08-16 | murphy

A TITLE TELLS YOU NOTHING. A SCHEMA TELLS YOU WHAT COLUMNS EXIST. ONLY THE VALUES TELL YOU WHAT THEY HOLD.
PER TABLE, IN THIS ORDER:
 1 column list - what exists
 2 SAMPLE A ROW as jsonb - what the values actually look like
 3 DISTRIBUTION on any field you intend to declare - a single row suggests, a distribution decides
 4 KEY: measure the join against parcels_staging WITH A WRONG-COUNTY CONTROL, or declare no key
 5 ladm_declaration with the SAMPLE VALUES quoted in the rationale, so the next reader can audit without re-querying
 6 layer_column_map for each servable role
 7 data_source_registry - agency at minimum
WHAT THIS METHOD FOUND IN ONE AFTERNOON, NONE OF IT VISIBLE IN A SCHEMA:
 pasco_cama_legal row 1 is a SOVEREIGNTY-LAND CAMPSITE LEASE in the Gulf of Mexico - not real property
 collier_cama_int_legal "(HO)" - legal descriptions are FRAGMENTS assembled in seqno order, 2.25 per parcel
 contractor_name truncated at exactly 30 chars on 51,152 rows; owner_name at 24 on 6,671; s_legal mid-word
 pinellas sign_off_dt 8% populated to 2008 then HARD ZERO from 2009 - a county system change
 pasco_cama_building effyrblt 2006 vs actyrblt 1970 - a renovation signal with no permit data at all, 6,943 buildings
 collier tp_history is TANGIBLE PERSONAL PROPERTY keyed on accountid - merging it double-counts tax
 miamidade_pa_parcel row 1 is folio 0000000000000 with every attribute null - 9,103 sentinel rows
 permit_contractor_match_resolved match_ambiguous TRUE on 65,760 of 191,536
 pinellas_cama_rp_land land_size "90x100" is TEXT DIMENSIONS and method FF means units are FRONTAGE not area

### 2. THE SPLIT: CC TAKES SPATIAL, CLAUDE TAKES RELATIONAL

`rule` | measured: 2026-08-16 | claude

737 populated tables remain undeclared. MEASURED SPLIT:
  WITH geometry     560 tables  20,371,573 rows   -> CC
  WITHOUT geometry  177 tables   4,784,290 rows   -> CLAUDE
The split is by competence, not convenience. A spatial table needs SRID, validity, extent and a spatial-join test
before it can be shelved - CC can run those. A relational table needs a key measured against the spine with a
negative control, which is registry DML.
NO TABLE IS SHELVED BY EITHER OF US WITHOUT ITS SAMPLE VALUES QUOTED IN THE RATIONALE. That is what makes the
catalogue auditable by the other agent without re-querying.

### 3. AN INFERRED TABLE MUST SAY SO IN ITS OWN SCHEMA, AND ONE DOES

`rule` | measured: 2026-08-16 | claude

site_hazard_installations carries a column literally named inference_basis. 5,919 rows, hazard_type
generator_fuel_system, capacity_lbs NULL, fuel_type NULL, lat/lng NULL.
IT IS DERIVED FROM PERMIT RECORDS, NOT A REGISTER OF OBSERVED INSTALLATIONS. A propane tank inferred from a
generator permit may never have been installed and may since have been removed.
NEVER SERVE AS A HAZARD PRESENT ON THE PARCEL - it is a prompt to ask. And it is keyed on property_id, OUR id, not a
parcel id.
THE GOOD PRACTICE WORTH COPYING: the table names its own epistemic status in a column. Every derived table should.
Compare permit_contractor_match_resolved, which carries match_ambiguous and is honest for the same reason - 65,760
of 191,536 flagged.

### 4. A CLASSIFIER MAY NOT HAVE AN ELSE BRANCH

`rule` | measured: 2026-08-16 | claude

My suffix-based backfill matched patterns and sent everything else to EXT_amenity. FOUR LARGE TABLES FELL THROUGH:
  polk_sales 3,017,135 rows - THE LARGEST SALES REGISTER WE HOLD, carrying book/page, QUIT CLAIM, "Other
    Disqualified" and an explicit foreclosure boolean. FILED AS AN AMENITY.
  polk_owners 676,232 - a MULTI-OWNER register with ln_num and pctown. A SECOND COUNTY WITH RELATIONAL OWNERSHIP,
    which we believed was Volusia-only.
  citrus_landuse 191,000 and highlands_flum 114,000 - spatial plan. highlands_flum carries BOTH flum AND zon.
AN ELSE CLAUSE IS A SILENT ASSERTION ABOUT EVERYTHING THE PATTERNS MISSED, and EXT_amenity is the most
harmless-looking class in the vocabulary - which is exactly why it hides the worst errors. A sales register filed as
an amenity is never looked at again.
UNMATCHED GOES TO A REVIEW QUEUE, NEVER TO A CLASS.

### 5. A JULY PASS ALREADY COMPARED NAME AGAINST CONTENT AND NOBODY READ IT

`correction` | measured: 2026-08-16 | claude

SEVEN TABLES AT EXACTLY 1,226 ROWS - nr_index, nr_master, nr_fam, nr2_final, rr_final, ladm_three_v3,
name_substr_v2, ladm_map_run1 - are successive classification attempts over the same table set.
ladm_three_v3 CARRIES name_v, schema_v AND content_v: THE THREE-WAY COMPARISON, built in July.
MEASURED: name 1,149 of 1,226 | schema 344 | CONTENT ONLY 266. The content pass was started and abandoned at 22%.
nr2_final FLAGS 103 TABLES WHERE name_class DISAGREES WITH content_class. That is a ready-made list of names that
lie, and it found my polk_sales error.
TWO LESSONS. First, SEARCH FOR THE ARTEFACT BEFORE DESCRIBING THE GAP - seventh instance today. Second, THE PRIOR
PASS IS EVIDENCE, NOT AUTHORITY: its content_class calls duval_parcels_govt_source REG_flood and properties
PART5_plan, both wrong. USE THE DISAGREEMENT LIST AS A QUEUE, NOT AS AN ANSWER.

### 6. STEP 3 APPLIES TO THE TESTS THEMSELVES. I BUILT THE PROBE THAT ENFORCES IT AND PUT A ONE-ROW TEST INSIDE IT.

`test` | measured: 2026-08-16 | cc

THE SPATIAL PROBE DECIDED shelved-vs-QUARANTINED FROM A SINGLE GEOMETRY. It took one row via LIMIT 1 with no
ORDER BY, tested whether a parcel intersected it, and reported the answer as a property of the LAYER.
nhd_flowline came back "no parcel at sample geometry" - and most river segments legitimately have no parcel on
them, so one miss is evidence of nothing. ON 25 ORDERED GEOMETRIES IT IS 23/25. A ONE-ROW TEST WOULD HAVE
QUARANTINED A HEALTHY 480,792-ROW LAYER. Quarantine is a claim about a layer and needs more than one row behind
it. The probe now samples 25 by ctid and reports a HIT RATE, not a boolean.

AND THE SAME ERROR IN THE KEY TEST, MEASURED. An ORDER BY makes a slice DETERMINISTIC, not REPRESENTATIVE.
First-20,000-by-id against a random TABLESAMPLE, same tables, same key:
  polk_parcels_gis.parcelid        head 99.85%  random 97.99%   -1.86
  palmbeach_situs_addresses.pcn    head 98.99%  random 96.67%   -2.32
  miamidade_geoaddress.folio       head 99.16%  random 99.24%   +0.08
TWO OF THREE OVERSTATED. Load order correlates with geography and with vintage, so the head of a county table is
not the county. USE TABLESAMPLE FOR ANY RATE THAT WILL BE WRITTEN DOWN.

WHAT THE EXTENT TEST IS ACTUALLY FOR, AND WHAT IT CANNOT SEE. fl_nwi_wetlands reads
-89.219 24.500 .. -66.885 44.968 - Louisiana to Maine - on a table named fl_. THE CAUSE IS THREE OCEAN
POLYGONS: objectid 400248, 8,239,001 acres and 606,657 vertices, is the Atlantic. A bbox-overlap containment
test COUNTED THOSE AS INSIDE FLORIDA, because their bounding box overlaps the state. The extent found what the
containment test hid, and the containment test found the 491 cross-border panhandle rows the extent could not
separate. RUN BOTH, AND RESOLVE THE DISAGREEMENT BEFORE DECLARING EITHER A DEFECT - here neither was one.

A NAME CAN ALSO UNDERSTATE. lee_building_footprints is not an outline layer: it carries estimatedvalue
1,259,705, valuesource, effectiveyearbuilt, residentialunits, subcondoname and condobldgno - a PER-BUILDING
VALUATION, the VM_Building level 02A-ladm/2 records us as lacking. 359,256 rows over 324,138 parcels.
And the distribution corrected my own reading of it inside one minute: the sample row said valuesource
"Parcel Building Value Split Among Buildings", but the table is 92.8% "Depreciated Value" (333,408) and the
sampled method is not in the top four. I NEARLY DECLARED A MINORITY METHOD AS THE TABLE'S METHOD FROM ROW ONE.

### 7. A HEAD SLICE IS DETERMINISTIC, NOT REPRESENTATIVE - USE TABLESAMPLE

`test` | measured: 2026-08-16 | cc

CC MEASURED THIS AND IT CORRECTS EVERY RATE I RECORDED TODAY.
  polk_parcels_gis.parcelid        head 99.85%   RANDOM 97.99%
  palmbeach_situs_addresses.pcn    head 98.99%   RANDOM 96.67%
  miamidade_geoaddress.folio       head 99.16%   random 99.24%
TWO OF THREE OVERSTATED. ORDER BY makes a slice reproducible; it does not make it representative. A table loaded
county-by-county or id-ordered has its cleanest rows first.
MY OWN 4,000-ROW SAMPLES USED limit WITHOUT ORDER BY, which is arbitrary rather than head-biased - better, but still
not random. EVERY MATCH RATE IN THIS DATABASE SHOULD BE RE-MEASURED WITH TABLESAMPLE before it is treated as the
population figure.

### 8. THE PROBE THAT ENFORCES READING CONTENTS CONTAINED A ONE-ROW TEST

`test` | measured: 2026-08-16 | cc

CC wrote a spatial probe to enforce the catalogue method AND PUT limit 1 WITHOUT ORDER BY INSIDE IT. The join test
took one geometry and let it decide shelved-versus-quarantined.
nhd_flowline came back "no parcel at sample geometry" - MOST RIVER SEGMENTS HAVE NO PARCEL ON THEM, so that is
evidence of nothing. On 25 geometries it is 23/25. A HEALTHY 480,792-ROW LAYER WOULD HAVE BEEN QUARANTINED.
THE RULE APPLIES TO THE INSTRUMENT AS WELL AS THE DATA. A tool built to enforce a discipline is not exempt from it,
and the failure is harder to see there because the tool looks like the authority.

### 9. EXTENT AND CONTAINMENT EACH FIND WHAT THE OTHER HIDES

`test` | measured: 2026-08-16 | cc

fl_nwi_wetlands - A SERVED LAYER - has an extent reaching lon -66.9, lat 45.0. That is MAINE.
CAUSE: three ocean Deepwater polygons, one of 8.2 MILLION ACRES WITH 606,657 VERTICES spanning the Atlantic. Both
serving functions already exclude Estuarine and Marine Deepwater, so they are inert at serve. The other 491
outliers are ordinary panhandle wetlands crossing into Alabama and Georgia. NOT A DEFECT.
BUT THE METHOD POINT IS PERMANENT: A BBOX CONTAINMENT TEST COUNTS THOSE OCEAN POLYGONS AS INSIDE FLORIDA, while the
extent test screams. Run both - extent catches the giant outlier that containment swallows, containment catches the
displaced row that extent averages away.

### 10. THE FAMILY SHORTCUT DOES NOT APPLY TO THE TAIL

`measurement` | measured: 2026-08-16 | cc

CC MEASURED THE SPATIAL LANE: 495 DISTINCT SCHEMA SIGNATURES ACROSS 559 TABLES. Only 91 sit in multi-member
families; 468 ARE ALONE and must be read individually.
"17 signatures cover 796 tables" was TRUE OF THE SET ALREADY DECLARED. The families were declared first BECAUSE they
were easy, and what remains is the long tail by construction.
DO NOT PLAN THE REMAINDER ON THE THROUGHPUT OF THE FAMILIES. The relational lane is the same shape - the CAMA sets
cluster, everything else is a singleton.

### 11. THE SPINE WAS NEVER DECLARED, AND ITS CONTENTS SETTLE ITS CLASS

`correction` | measured: 2026-08-16 | claude

parcels_staging - 10,739,881 rows, 67 counties, 44 columns, THE SPINE OF THE PLATFORM - had a source-registry row
and NO LADM DECLARATION. CC found it in the undeclared 737.
RULED PART4_valuationunit, NOT PART2_spatialunit, ON CONTENTS: jv 142397, lnd_val 33600, dor_uc 001, act_yr_blt
1929, tot_lvg_ar 968, lnd_sqfoot 8712, own_name "SMITH MARTIN T", fidu_name, sale_prc1/yr1. THAT IS THE DOR NAL
ROLL - a mass appraisal output, which is what ISO 19152-4 models. THE GEOMETRY IS AN ATTRIBUTE OF THE VALUATION
UNIT, NOT THE SUBJECT. A PART2_spatialunit is a legal space; this is a BILLABLE INTEREST CARRYING A TAX MAP.
THREE FINDINGS FROM THE VALUES:
 EVERY GEOMETRY IS 3D - 3,000 of 3,000 ST_NDims=3, every vertex [lon, lat, 0]. A DEGENERATE Z THAT IS ALWAYS ZERO,
   inflating 10.7M rows and making any ST_ function that treats 3D differently do so silently.
 alt_key IS A SINGLE SPACE - blank-not-null, populated on 3,000 of 3,000 by a naive test. THE VOLUSIA CAMA TABLES
   JOIN ON alt_key, so its real rate per county must be measured before that join is trusted elsewhere.
 state_par_id "C65-000-828-0274-5" IS POPULATED ON 3,000 OF 3,000 AND NOTHING USES IT. Every join in this database
   is a (co_no, parcel_id) composite. IF IT IS UNIQUE STATEWIDE IT REPLACES THE COMPOSITE EVERYWHERE - the same
   thing nparno is in the GeoPlan product. MEASURE ITS UNIQUENESS.

### 12. E0 IS DEFINED ON A KEY JOIN, AND 91.8% OF THE SPATIAL LANE HAS NO KEY. THE CONTROL FOR A CONTAINMENT LAYER IS DISPLACEMENT.

`test` | measured: 2026-08-16 | cc

MEASURED: of 559 undeclared spatial tables, 513 (91.8%, 5,647,891 rows) HAVE NO PARCEL-KEY COLUMN AT ALL - not a
weak key, none. They answer by CONTAINMENT: is the parcel inside the polygon. Only 46 carry even a plausible
key-shaped column name, and that is an upper bound since names lie.
SO "E0_key_verified_with_control - the only grade that supports serving" CANNOT BE REACHED BY 91.8% OF THE SPATIAL
LANE, INCLUDING LAYERS SERVING IN PRODUCTION TODAY. fl_nwi_wetlands and nhd_flowline are both served and both
keyless. Flood and zoning are containment concepts too (ruling 245). A grade that no served flood layer can reach
is measuring the relational lane and calling it the standard.

THE SPATIAL EQUIVALENT OF A WRONG-COUNTY CONTROL IS A DISPLACED POINT. Take the SAME parcel interior points, move
them out of the layer's coverage, and re-run containment. The layer must (a) DISCRIMINATE in scope - a rate that
is neither 0 nor 100, since a layer containing every parcel answers nothing - and (b) COLLAPSE TO ZERO out of it.
MEASURED on fl_nwi_wetlands, 400 random parcels, Deepwater excluded, one sample throughout:
  in scope, points as they are        17/400   4.25%   <- discriminates
  displaced +9 deg north               0/400   0%      <- clears Florida
  displaced -12 deg west               0/400   0%      <- clears Florida
That is the same shape of evidence as a 0.0000% wrong-county key control.

AND THE CONTROL THAT DOES NOT CLEAR THE COVERAGE DOES NOT MERELY FAIL - IT INVERTS.
  displaced +3 deg north              25/400   HIGHER THAN IN SCOPE
Florida is 6.6 degrees tall and most parcels are in the south, so +3 moves a Miami parcel to central Florida -
still inside the layer, and into WETTER ground. I ran that first and read it as the layer failing its control,
having previously told claude the layer was clean. IT WAS MY CONTROL THAT WAS WRONG, TWICE OVER: too small a
displacement, and in a direction correlated with the very attribute being tested.
A DISPLACEMENT CONTROL MUST EXCEED THE LAYER'S OWN EXTENT AND SHOULD BE RUN IN TWO DIRECTIONS.

WHILE CHECKING IT I ALSO CORRECTED MY OWN EARLIER COUNT. I reported 491 fl_nwi_wetlands rows outside Florida using
bbox overlap. BY INTERIOR POINT IT IS 518, reaching lat 35.31 - Tennessee latitude. Bbox overlap counts a polygon
straddling the border as inside; interior point does not. 0.065% either way and still not a defect, but the two
tests give different numbers and the honest one for containment is the interior point.

## 16-evidence

### 1. THE EVIDENCE GRADE IS THE ONLY HONEST PROGRESS NUMBER

`rule` | authority: ISO 19152 classification pass, July 2026 | measured: 2026-08-16 | claude

ADOPTED FROM THE JULY nr_final PASS, WHICH I SHOULD HAVE STARTED FROM AND INSTEAD REBUILT AROUND.
  E0_key_verified_with_control  contents read AND the join measured against a negative control. THE ONLY GRADE
                                THAT SUPPORTS SERVING.
  E2_own_content_read           this table sampled and its DISTRIBUTION checked
  E1_family_exemplar_read       class inherited from ONE member of a schema family
  E3_name_plus_second_read      name-anchored with a corroborating read elsewhere
  E4_name_only                  a guess wearing a class
  E5_none                       honestly unclassified
MEASURED 2026-08-16 ACROSS 1,396 DECLARATIONS:
  E0 168 | E2 128 | E1 323+ | E3 227 | E4 the remainder | E5 59
ONE HUNDRED AND SIXTY-EIGHT TABLES ARE SERVABLE. That is 12% of what is declared and 8% of what is populated.
NEVER REPORT A DECLARATION COUNT AGAIN. Report the grade distribution.

### 2. E1 IS NOT SAFE AND I PROVED IT TWICE TODAY

`test` | measured: 2026-08-16 | murphy

THE JULY PASS GRADED 555 TABLES E1 - class inherited from one family exemplar. content_reads IN THAT TABLE IS
FAMILY SIZE, NOT READS OF THAT TABLE, AND I MISREAD IT AS A CONTENT COUNT.
E1 FAILS IN BOTH DIRECTIONS AND BOTH WERE MEASURED TODAY:
 parcels_govt_source IS TWO SCHEMAS UNDER ONE SUFFIX - a 96-column raw county submission keyed parno where
   parcelid is 100% NULL, and a 75-column GeoPlan CLEANED product keyed parcelid. One exemplar read gives the
   wrong key for seven counties and 111,777 rows.
 SIX OF TEN COUNTY PARCEL KEYS JOINED THE SPINE AT ZERO. Three recovered by transform, three unresolved, one
   correctly zero.
AND THE JULY CLASSES THEMSELVES DO NOT SURVIVE A CONTENT READ:
 polk_sales          July PART4_valuation E3 -> it is a TRANSACTION register with grantor, grantee, book, page
                     and an explicit foreclosure boolean
 volusia_cama_sales  July PART2_cama E1 -> VM_TransactionPrice
 volusia_cama_permits July PART2_cama E1 -> SP_Permit
PART2_cama IS NOT A CLASS. IT IS A SOURCE-SYSTEM NAME. A sales register and a permit register lumped together
because they arrived in the same export - the environmental_overlay error in a different bucket: GROUPING BY WHERE
IT CAME FROM RATHER THAN BY WHAT IT IS.
UPGRADE E1 AND E3 TO E2 OR E0. DO NOT TRUST THEM AND DO NOT REDO THEM FROM SCRATCH.

### 3. A WHERE NOT EXISTS GUARD PROTECTS THE WRONG THING

`rule` | measured: 2026-08-16 | claude

I declared volusia_cama_permits SP_Permit from a content read. IT SILENTLY DID NOT LAND - a row already existed
from an earlier backfill and my WHERE NOT EXISTS skipped the insert. The table sat as VM_ValuationUnit with a
legacy_class of PART4_valuationunit until a July-versus-today comparison exposed it.
THE GUARD WAS PROTECTING AGAINST DUPLICATES AND SHOULD HAVE BEEN PROTECTING AGAINST A WEAKER ROW OVERRIDING A
STRONGER ONE. Same class as the ELSE branch that filed a 3M-row sales register under amenity: the mechanism did
exactly what it was told and what it was told was wrong.
RULE: AN INSERT THAT CARRIES A HIGHER EVIDENCE GRADE MUST UPSERT, NOT SKIP. Compare grades, keep the stronger,
record the supersession.

### 4. THREE COUNTIES HOLD RELATIONAL OWNERSHIP, NOT ONE - AND ALL THREE WERE MISCLASSED

`measurement` | measured: 2026-08-16 | claude

volusia_cama_owner, pinellas_cama_rp_all_owners AND polk_owners are PARTY REGISTERS. All three were sitting as
VM_ValuationUnit - two at E4 name-only, one at E1 family exemplar.
  volusia_cama_owner   483,754 rows / 343,841 parcels = 1.41 owners per parcel. 139,913 rows at OWNSEQ > 0.
                       KEY VERIFIED: PARID on ALT_KEY, 3,971 of 4,000, control 0.
  pinellas_cama_rp_all_owners  681,923 rows, owner_number 2 on the first row sampled.
  polk_owners          676,232 rows, ln_num and pctown. KEY VERIFIED 3,996 of 4,000, control 0.
"CO-OWNER RECOVERY IS VOLUSIA-ONLY" HAS BEEN FALSE FOR SOME TIME AND NOBODY CHECKED - the tables were declared
from their names and their names do not say party.
AND THE NAME CONVENTIONS DIFFER: Pinellas is "SURNAME, FORENAME" WITH A COMMA, Volusia OWN1 and Polk name are
unpunctuated. Any cross-county holdings match must normalise before comparing.

### 5. THE LA_GroupParty CONTRADICTION IS NOW MEASURED AND NEEDS A RULING

`open` | authority: ISO 19152-1 fraction constraint; PIR_REPORT_SPEC_v5 Part B | measured: 2026-08-16 | claude

MEASURED IN volusia_cama_owner: 447,845 OF 483,754 ROWS (92.6%) CARRY PCTOWN = 100, across 343,841 parcels at 1.41
owners per parcel.
ISO 19152 DEFINES fraction WITH NUMERATOR <= DENOMINATOR. TWO SPOUSES AT 100% EACH CANNOT BE TWO 100% SHARES. The
correct LADM form is ONE RIGHT HELD BY AN LA_GroupParty with each party registered as a member.
PIR_REPORT_SPEC_v5 PART B SAYS PERCENTAGES ARE NEVER NORMALISED AND A SUM OF 200 IS CORRECT.
BOTH ARE TRUE AT DIFFERENT LEVELS - THE SOURCE RECORDS 100 EACH AND MUST BE HELD UNCHANGED; THE MODEL HOLDS ONE
GROUP RIGHT. NOTHING ANYWHERE SAYS SO, AND A READER OF THE SPEC WOULD CONCLUDE THE GROUP-PARTY FORM IS WRONG.
OWNTYPE1 IS THE DECIDING FIELD: FS / TE / TIC. Tenancy by the entirety is a single group right; tenancy in common
is separate shares. The group form applies to TE and NOT to TIC, so the code decides the modelling per row.
NO OWNER RENDERING CHANGES UNTIL THIS IS RULED.

### 5.1. RULED - BOTH OWNERS ARE NAMED. THE GROUP-PARTY FORM NEVER SUPPRESSES A PARTY.

`principle` | authority: ISO 19152-1 LA_GroupParty; Fla. tenancy by the entirety | measured: 2026-08-16 | murphy

THE CASE THAT FOUND THIS IS 1778 EARHART CT, PARID 3671058, AND IRIS WAS DROPPED FROM THE PIR.
MEASURED, THE TWO ROWS AS THEY SIT:
  OWNSEQ 0  OWN1 "MCNEELY GENE"  PCTOWN 100  OWNTYPE1 TE  "Tenancy in the Entirety"  1778 EARHART CT
  OWNSEQ 1  OWN1 "MCNEELY IRIS"  PCTOWN 100  OWNTYPE1 TE  "Tenancy in the Entirety"  1778 EARHART CT
TWO ROWS. TWO PEOPLE. ONE HOUSE. IRIS WAS LOST BY READING ONE ROW.
*** THE RULING ***
BOTH OWNERS ARE NAMED. ALWAYS. THE LA_GroupParty FORM IS A STATEMENT ABOUT THE RIGHT, NOT ABOUT THE PARTIES - one
right, held jointly, BY EACH PARTY REGISTERED AS A MEMBER. LADM requires every member to be registered; the group
is not a way of collapsing them.
So there is NO CONFLICT with PIR_REPORT_SPEC_v5 Part B and I was wrong to frame it as one:
  THE SOURCE records PCTOWN 100 each and is held unchanged. 200 is correct and must never be divided or normalised.
  THE MODEL holds ONE LA_Right whose holder is an LA_GroupParty of Gene and Iris.
  THE REPORT names BOTH, and states the tenancy.
The fraction constraint (numerator <= denominator) is what forbids modelling this as TWO RIGHTS OF 100% EACH. It
says nothing about how many people are named, and I read it as though it did.
*** OWNTYPE1 DECIDES THE FORM, PER ROW ***
  TE  Tenancy in the Entirety  -> ONE right, LA_GroupParty. Survivorship. Neither spouse holds a severable share.
  FS  Fee Simple               -> single party
  TIC Tenancy in Common        -> SEPARATE rights with real fractional shares, and there PCTOWN is a true fraction
TENANCY MATTERS TO A BUYER, NOT ONLY TO A MODEL: under TE a creditor of one spouse generally cannot reach the
property, and the survivor takes automatically without probate. A report that names one owner and omits the
tenancy has lost both facts.
*** THE FAILURE THAT DROPPED IRIS IS THE limit 1 TRAP, AND IT IS THE SAME ONE AS ***
collier_cama_int_legal fragments (2.25 rows per parcel), Volusia geometry fragments (worst 1,215), and CC nhd
probe. ONE ROW FROM A MULTI-ROW RELATION IS NOT A SAMPLE, IT IS A LOSS - and here the loss had a name.

### 5.2. SUPERSEDES 5.1 - EVERY OWNER IS NAMED, HOWEVER MANY, AND THE TENANCY IS STATED

`principle` | authority: ISO 19152 LA_GroupParty and LA_RRR share | measured: 2026-08-16 | murphy

REPLACES the wording of 16-evidence/5.1, which said "both owners" and treated two as the case.
MEASURED: volusia_cama_owner holds up to 27 OWNERS ON ONE PARCEL. 7,288 parcels carry MORE THAN TWO. 47 carry TEN OR MORE.
  1778 EARHART CT   OWNSEQ 0 MCNEELY GENE, OWNSEQ 1 MCNEELY IRIS, both PCTOWN 100, both TE.
                    ONE right, LA_GroupParty, survivorship. IRIS WAS DROPPED BY A limit 1 READ.
  219 GRAHAM ST     27 owners, ALL TIC, shares 1/6 1/18 1/42 1/66 1/168 SUMMING TO EXACTLY 100.
                    TWENTY-SEVEN SEPARATE RIGHTS. Heirs property. Any one holder can force a partition sale.
THE RULE: EVERY OWNER IS NAMED. THE COUNT IS ITS OWN FACT. THE TENANCY CODE IS SERVED BESIDE THEM, because TE and TIC
are different rights and the difference is what a buyer needs.
NEVER WRITE "BOTH" - IT ENCODES AN ASSUMPTION THE DATA DOES NOT SUPPORT.

### 6. AN ASSESSOR WORKING NOTE CARRIES BOTH A FINDING AND A STAFF NAME

`test` | measured: 2026-08-16 | claude

pinellas_cama_rp_sales_history.note ON 926,435 OF 2,392,689 ROWS (38.7%). Sampled:
"2ND PARAGRAPH STATES ONLY CONVEYING 50% OWNED BY THE TRUST///MAY BE UPDATED - PJ"
ONE FIELD, TWO INCOMPATIBLE THINGS. A PARTIAL-INTEREST CONVEYANCE - which the $100 price alone does not reveal and
which is exactly the non-market signal a buyer needs. AND INTERNAL COMMENTARY WITH STAFF INITIALS AND A PROVISIONAL
JUDGEMENT.
IT CANNOT BE SERVED RAW AND IT CANNOT SIMPLY BE DROPPED. The finding is real; the attribution and the provisionality
are not ours to publish.
SAME SHAPE AS fl_erp_conservation_easements.TYPE, where "May not be recorded" and "No legal description" were
technician notes that were themselves findings. WHEN A FREE-TEXT FIELD HOLDS 38% COVERAGE, READ IT BEFORE DECIDING
IT IS EITHER NOISE OR CONTENT.

### 7. A PRIOR-VALUE COLUMN IN A KEY POSITION - pr_strap

`test` | measured: 2026-08-16 | claude

polk_parcels_cama.pr_strap LOOKS LIKE THE KEY AND IS NOT. Measured: populated on 115,562 of 437,843 (26%), DIFFERS
from parcel_id on 115,516 of those, and MATCHED ONLY 159 OF 4,000 against the spine.
IT IS A PRIOR STRAP - the identifier this parcel HELD BEFORE a split, merge or replat. A LINEAGE COLUMN.
parcel_id is the key: 3,969 of 4,000, control 0.
THIS IS THE PREVIOUS-VALUE TRAP - already logged nine times in zoning columns - APPEARING IN A KEY COLUMN FOR THE
FIRST TIME. The trap list must be read as a CLASS, not as a list of nine column names: originalzone, rezone,
prevflum, previouszoning, priorusety, stlucie previouszo 1-4, AND NOW pr_strap.
AND IT IS USEFUL: 115,516 prior identifiers are a parcel-lineage record, which is how you follow a property across
a replat. Declare it as lineage, never as a key.

### 8. A NAME SPLIT ACROSS TWO COLUMNS IS NOT TWO OWNERS - AND READING ONE IS THE EARHART FAILURE INVERTED

`test` | measured: 2026-08-16 | claude

pasco_cama_owners: owner_mail_name1 "SOUTHWEST FLORIDA WATER", owner_mail_name2 "MANAGEMENT DISTRICT".
MEASURED: 61,876 OF 321,781 ROWS (19.2%) CARRY A SECOND NAME LINE.
name2 IS A CONTINUATION, NOT A CO-OWNER. Treating it as a second party INVENTS ONE. Ignoring it TRUNCATES the
first. CONCATENATE.
THIS IS THE MIRROR OF 1778 EARHART: there, TWO ROWS meant TWO PEOPLE and reading one dropped Iris. Here, TWO
COLUMNS mean ONE NAME and reading both as parties would fabricate a district that does not exist.
THE RULE: MULTIPLICITY IS A PROPERTY OF THE DATA, NOT OF THE COLUMN COUNT. Ask what the second slot MEANS before
deciding whether it is another entity or more of the same one. Volusia OWN2 is a genuine second name on one row;
Pasco name2 is a continuation; Collier granteeline2 is an ADDRESS. Three databases, three meanings, same shape.

### 9. A TABLE THAT DOCUMENTS ITS OWN KEY TRANSFORM

`test` | measured: 2026-08-16 | claude

collier_cama_int_parcels CARRIES BOTH folio AND parcelid. MEASURED: folio = lpad(parcelid,11,'0') ON 298,247 OF
298,247 ROWS. ONE HUNDRED PERCENT.
THE LEADING-ZERO TRANSFORM IS PROVED BY IDENTITY, NOT BY SAMPLING. Every other Collier table carries only parcelid
and needs the padded form to reach the spine; this table is the evidence for all of them.
LOOK FOR THE TABLE THAT HOLDS BOTH FORMS. Where a county publishes a key in two shapes, one table usually carries
both, and that beats any transform you infer from a sample. Pinellas does the same with strap and parcel_number in
rp_exemptions - and that one is still unsolved, so the pattern is a lead, not a guarantee.

### 10. THE IMPROVEMENT REGISTER WAS FILED UNDER "misc" AND IT IS THE MOAT

`measurement` | measured: 2026-08-16 | claude

volusia_cama_misc - 363,677 rows in 93 types, declared VM_ValuationUnit at E1 from its name.
SAMPLE: MICODE PTO, MICODE_DESC "PATIO/CONCRETE SLAB", AREA 1026, YRBLT 2021, RCN 7539, RCNLD 6559, GRADE D,
IMPERVIOUS Y, GRANNY_FLAT N.
THIS IS THE TABLE THE 15,801 MARINE IMPROVEMENTS COME FROM. The cross-examination that is the entire product moat -
6,097 improvements with no permit within a year of YRBLT, 5,725 of them on parcels that DO have permits - runs on
rows of a table filed under "misc".
KEY VERIFIED: PARID on ALT_KEY, 3,976 of 4,000, control 0.
AND THREE FACTS IN IT ARE IN NO PAYLOAD: RCN vs RCNLD gives remaining life independent of YRBLT; IMPERVIOUS bears
on stormwater assessment; GRANNY_FLAT is an accessory-dwelling flag bearing on occupancy and rental use.
"misc" IS THE ELSE BRANCH OF A COUNTY SCHEMA. Whatever did not fit the named tables went there, which is exactly
where the interesting things are.

### 11. NON-AD-VALOREM ASSESSMENTS ARE PER-PARCEL AND NEARLY UNIVERSAL

`measurement` | measured: 2026-08-16 | claude

volusia_cama_nonadvalorem: PROJNAM "WEST HIGHLANDS MAINT DIST", RATE 56.7, UNITS 4, AMOUNT 226.8.
308,468 ROWS ACROSS ROUGHLY 307,000 VOLUSIA PARCELS - NEARLY EVERY PARCEL CARRIES AT LEAST ONE.
A recurring charge levied by a special district, RUNNING WITH THE LAND, payable regardless of value. That is an
LA_RRR responsibility, not a valuation - it was sitting as VM_ValuationUnit at E1.
SAME OBLIGATION AS THE MIAMI-DADE CDD AND THE LEE MSTU reclassified earlier today, but THOSE ARE DISTRICT POLYGONS
AND THIS IS PER-PARCEL WITH AN AMOUNT. It is the one that can actually be served.
AND THE CONTROL WAS NOT ZERO: 49 of 4,000 Volusia alt_keys also exist in Putnam (1.2%). Every other Volusia CAMA
table controlled at zero. THE COUNTY FILTER IS LOAD-BEARING HERE AND THE CONTROL IS WHAT REVEALED IT.

### 12. E0 HAS TWO FORMS BECAUSE A JOIN HAS TWO FORMS - CC CAUGHT MY DEFINITION EXCLUDING PRODUCTION

`correction` | measured: 2026-08-16 | cc

I DEFINED E0 AS "contents read AND the join measured against a negative control" AND WROTE IT AS A KEY TEST.
CC MEASURED THE CONSEQUENCE: 513 OF 559 SPATIAL TABLES (91.8%) HAVE NO PARCEL-KEY COLUMN AT ALL. They answer by
CONTAINMENT. Among them fl_nwi_wetlands and nhd_flowline, WHICH SERVE IN PRODUCTION TODAY - and flood, zoning and
land_use are containment concepts by ruling 245.
A GRADE NO SERVED FLOOD LAYER CAN ATTAIN IS MEASURING THE RELATIONAL LANE AND CALLING IT THE STANDARD.
THE PRINCIPLE OF E0 WAS NEVER "A KEY WAS TESTED". It is THE JOIN THIS TABLE ACTUALLY USES WAS MEASURED AGAINST A
CONTROL THAT COULD HAVE FAILED. Containment IS a join.
  E0_key_verified_with_control          control = SAME KEY, WRONG COUNTY
  E0_containment_verified_with_control  control = SAME PARCEL INTERIOR POINTS, DISPLACED CLEAR OF THE COVERAGE
Same grade, two forms. Not a weaker grade and not a new tier.

### 13. A DISPLACED-POINT CONTROL MUST CLEAR THE COVERAGE AND MUST NOT FOLLOW THE GRADIENT

`test` | measured: 2026-08-16 | cc

CC BUILT THE SPATIAL CONTROL AND GOT IT WRONG FIRST, WHICH IS WHY IT IS WORTH RECORDING.
  fl_nwi_wetlands, 400 random parcel interior points, one sample throughout:
    in scope       17/400  (4.25%)
    +3 north       25/400  HIGHER THAN IN SCOPE - THE CONTROL INVERTED
    +9 north        0/400
    -12 west        0/400
FLORIDA IS 6.6 DEGREES TALL AND MOST PARCELS ARE SOUTHERN, so +3 moves a Miami parcel to CENTRAL FLORIDA - still
inside the layer, AND INTO WETTER GROUND. The displacement was too small AND it ran along a gradient of the very
attribute under test.
TWO REQUIREMENTS, BOTH NECESSARY: CLEAR THE ACTUAL COVERAGE, and MOVE PERPENDICULAR TO THE THING YOU ARE TESTING or
far enough that no gradient survives.
AND THE SAME CHECK CORRECTED CC OWN EARLIER NUMBER: 491 wetlands rows outside Florida was measured by BBOX OVERLAP;
BY INTERIOR POINT IT IS 518, reaching lat 35.31. Still 0.065%, still not a defect - but the looser test was the one
originally reported.

### 14. state_par_id IS A 1:1 SUBSTITUTE FOR THE (co_no, parcel_id) COMPOSITE - PROVED

`measurement` | measured: 2026-08-16 | claude

CC ran the cardinality and the structure; the distinct-triple proof timed out three times and they said so rather
than claiming it. I completed it by SAMPLING, which the full-table aggregate could not do.
MEASURED, TABLESAMPLE 0.3% OF parcels_staging, 32,433 ROWS:
  DISTINCT state_par_id                      32,299
  DISTINCT (co_no, parcel_id)                32,299
  DISTINCT (state_par_id, co_no, parcel_id)  32,299   <- ALL THREE EQUAL. THAT IS THE PROOF.
  rows failing the ^C<co_no>- prefix              0
Full-table, CC measured DISTINCT state_par_id = DISTINCT composite = 10,511,205, and 5,295 of 5,295 sampled rows
carry the embedded county matching co_no.
EQUAL CARDINALITY ALONE PROVES NOTHING - two different groupings can tie. THE TRIPLE COUNT IS WHAT PROVES THE
GROUPINGS ARE THE SAME. If the triple exceeded the pair, one state_par_id would span two parcels or vice versa.
CONSEQUENCE: a single statewide key exists in the spine and NOTHING USES IT. It is what nparno is in the GeoPlan
product. It does not remove the county from a join to a COUNTY table - those carry only their own local key - but it
removes the composite anywhere the spine is joined to itself or to another statewide table.
THE 228,676 ROW-VERSUS-DISTINCT GAP IS THE KNOWN FRAGMENT DEFECT and appears identically on both keys, which is
further evidence they are the same grouping.

### 15. THE EARHART FAILURE HAS THREE SHAPES AND WE HOLD ALL THREE

`test` | measured: 2026-08-16 | claude

ONE PROPERTY, TWO OWNERS. THE COUNTY CAN EXPRESS THAT THREE WAYS AND EACH BREAKS A DIFFERENT READER:
  TWO ROWS      volusia_cama_owner OWNSEQ 0 and 1. Reading one dropped IRIS MCNEELY from the PIR.
  TWO COLUMNS   pasco_cama_owners owner_mail_name1 + name2 - BUT THAT IS ONE NAME CONTINUED, not two people.
                "SOUTHWEST FLORIDA WATER" + "MANAGEMENT DISTRICT". 19.2% of rows.
  ONE STRING    parcel_deed_chain grantee "HAMIL COURTNEY F; HAMIL RUSSELL J" - SEMICOLON SEPARATED.
                MEASURED: 51,573 OF 108,864 ROWS (47.4%).
THE SHAPE DOES NOT TELL YOU THE MULTIPLICITY. Two rows meant two people; two columns meant one name; one string
meant two people. YOU HAVE TO READ WHAT THE SECOND SLOT MEANS.
AND A FOURTH TRAP IN THE SAME SAMPLE: grantor held "BOUDREAU HAWKINS MICHELE; BOUDREAU JUSTIN K; HAWKINS MICHELE
BOUDREAU" - THE FIRST AND THIRD ARE THE SAME PERSON UNDER TWO NAME FORMS. A naive split reports three grantors
where there are two people. NAME COUNTING IS NOT PARTY COUNTING.

### 16. FIVE COUNTIES PUBLISH THE CONDO RELATION FIVE WAYS AND ISO HAS ONE CLASS FOR IT

`mapping` | authority: ISO 19152-4 VM_CondominiumUnit | measured: 2026-08-16 | claude

  Miami-Dade  parent_folio ON EACH UNIT ROW
  Collier     a contiguous parcel-id RANGE with a header parcel - NOT DENSE, 5 parcels across an 81-id span
  Lee         parcel value SPLIT ACROSS BUILDINGS AND UNITS, 359,256 buildings over 324,138 parcels
  Volusia     A COMPLEX CODE - CNDCMPLX, MEASURED AT 338 COMPLEXES ACROSS 23,184 UNITS, ~69 units each
  Sarasota    NOTHING - which is where the defect was found, 58,000 parcels
ALL FIVE ARE VM_CondominiumUnit. THE STANDARD IS WHAT MAKES THEM THE SAME FACT, and it is the argument for the
model in one line: without it these are five county quirks; with it they are one class with five encodings.
AND VOLUSIA CARRIES TWO VALUATION DRIVERS NO PAYLOAD HOLDS: CONDOLVL is the FLOOR and CONDOVW a VIEW CODE. A
fifth-floor north-facing unit is a different asset from a ground-floor unit of identical area, and the roll knows
it.

### 17. ONE WRONG COLUMN LED TO A SWEEP THAT FOUND A WORSE CLASS

`test` | measured: 2026-08-16 | claude

clay_flood_zones had its zone column mapped to fld_zone, WHICH HOLDS 1000/1001/2000/4002 - internal FEMA area
identifiers. The real codes are in clay_flood_zone, a column named after the county. 748 OF 1,239 POLYGONS ARE SFHA
and every one would have rendered not_available. THE ST PETERSBURG FAILURE IN A SECOND COUNTY AND A SECOND FORM:
there the layer was absent, here it is present and the map points at the wrong column.
THE FAMILY WAS RIGHT AND THE MEMBER WAS NOT - it was E1, inherited from an exemplar that used fld_zone correctly.
THEN I SWEPT ALL 67 VALUE DOMAINS, WHICH THE DEFECT REMEDIATION DEMANDED, AND FOUND SOMETHING BIGGER:
DUVAL HOLDS COMMA-SEPARATED MULTI-ZONE STRINGS ON 22,606 OF 65,827 PARCELS (34.3%), 22,587 CONTAINING AN SFHA ZONE.
  "AE,VE" | "AE,AO" | "AE,OPEN WATER" | "0.2 PCT ANNUAL CHANCE FLOOD HAZARD,AE,VE"
The layer is PARCEL-JOINED, so a row is a parcel and A PARCEL GENUINELY SPANS MORE THAN ONE ZONE. THE MULTI-VALUE IS
CORRECT DATA IN A SINGLE-VALUE COLUMN.
AND THE ORDERING IS THE TRAP: "0.2 PCT ANNUAL CHANCE FLOOD HAZARD,AE" LEADS WITH THE NON-SFHA VALUE. Anything
reading the first token reports a 0.2% parcel that is actually Zone AE.
THE ZONE TEST MUST BE SET MEMBERSHIP OVER SPLIT TOKENS. Never equality, never prefix, never the first token.
in_sfha is TRUE if ANY token is an SFHA zone.
AND "OPEN WATER" INSIDE A ZONE STRING IS THE SENTINEL CLASS AGAIN - the same shape as Estuarine and Marine
Deepwater inside the wetlands layer.

### 18. SEVEN SPELLINGS OF ONE FLOOD ZONE, AND ONE OF THEM MEANS THE OPPOSITE

`measurement` | authority: FEMA NFHL zone definitions; 67 county layers read | measured: 2026-08-16 | claude

ALL 67 FLOOD LAYERS READ. 62 use fld_zone with a clean domain. THE FIVE THAT DO NOT INCLUDE DUVAL, LEE AND
LAKELAND - and the exceptions are where the population is.
THE 0.2% ANNUAL CHANCE ZONE IS SPELLED SEVEN WAYS:
  "0.2 PCT ANNUAL CHANCE FLOOD HAZARD" | same + " (X)" | X500 | "X (shaded)" | X5 | "X 2PCT"
AND boyntonbeach WRITES "X (unshaded)" - WHICH IS MINIMAL HAZARD, THE OPPOSITE FINDING, ONE WORD APART.
THREE VALUES THAT ARE NOT ZONES AT ALL:
  ZONE D  84 in Hardee, 5 in Orange. UNDETERMINED RISK - NO FLOOD ANALYSIS HAS BEEN CONDUCTED. Not SFHA and NOT
    non-SFHA. Lenders may still require insurance. RENDERING D AS X IS A FALSE CLEARANCE - it is the
    three-coverage-state problem compressed into a single value.
  "AREA NOT INCLUDED"  1 polygon, Santa Rosa. A COVERAGE GAP WEARING A ZONE CODE. not_available with a polygon
    drawn around it.
  "OPEN WATER"  22 polygons across SIX counties. The sentinel class again.
AND CAZ - COASTAL A ZONE, 224 polygons in Lee. INSIDE the SFHA, rated A, with V-zone wave exposure. Not a standard
NFHL value and absent from every IN-list anyone would write.
THE RULE: A CODE COLUMN SHARED ACROSS 67 PUBLISHERS DOES NOT SHARE A DOMAIN. Build a crosswalk from the OBSERVED
values, re-run the sweep after every pull, and never write an IN-list from the FEMA specification alone.

### 19. A NUMERIC CODE COLUMN IS THREE DIFFERENT DEFECTS AND THEY NEED DIFFERENT FIXES

`test` | measured: 2026-08-16 | claude

Sweeping every zoning and FLU code column for a leading-numeric signature found six, AND NO TWO WERE THE SAME
PROBLEM. The signature found them; only reading the values distinguished them.
  alachua_zoning "0103SF"     A JURISDICTION PREFIX + DISTRICT. Eleven prefixes in one county layer, corroborated
    by a juris column. THE SAME DISTRICT IN TWO MUNICIPALITIES CARRIES TWO CODES - 0100A and 0101A are both A -
    so any grouping on the raw code fragments silently. FIX: use zonedistrict, the bare-district column.
  lake_future_land_use "460"  A PURELY NUMERIC CLASSIFICATION with NO LOOKUP HELD. FIX: use label/fluseries.
  broward_future_land_use     Same shape - 1, 5, 28, 100, 222.
  pasco_land_use_land_cover   FLUCCS, AND THE CLASS WAS ALREADY RIGHT. It is REMOTE-SENSING LAND COVER, not a
    plan. A table named land_use_land_cover IS NOT A SPATIAL PLAN. Serving cover as plan would tell a buyer their
    vacant lot is residential because an aerial pass classified the neighbour house.
  volusia_zoning "999"        REAL CODES PLUS A SENTINEL - 929 of 5,246 rows (17.7%). Same class as
    "999 INCORPORATED". It means the county holds no zoning there: NOT_AVAILABLE, never a district.
THE LESSON: A SINGLE STRUCTURAL SIGNATURE FOUND ALL SIX AND WOULD HAVE PRESCRIBED THE WRONG FIX FOR FIVE OF THEM.
Detection generalises; remediation does not.
AND ONE MORE FROM VOLUSIA: THE SUFFIX GRAMMAR IS MEANING, NOT NOISE. A = annexed, C = conditional, W = waterfront,
bracketed digits = ordinance conditions. B-4C(5)A IS NOT A SPELLING VARIANT OF B-4. Never strip to normalise.

### 20. TABLESAMPLE SYSTEM SAMPLES PAGES, NOT ROWS. WITH LIMIT IT IS A GEOGRAPHIC CLUSTER, AND THAT IS THE THIRD FORM OF THE SAME ERROR.

`test` | measured: 2026-08-16 | cc

THREE FORMS, EACH SUBTLER, AND I WROTE THE THIRD INTO THE INSTRUMENT BUILT TO CATCH THE FIRST TWO:
  1 LIMIT with no ORDER BY               arbitrary rows
  2 ORDER BY ctid LIMIT n                a head slice of the heap - overstated two key rates by up to 2.3 points
  3 TABLESAMPLE SYSTEM (r) ... LIMIT n   SYSTEM selects whole 8kB PAGES; LIMIT then takes the FIRST PAGES SAMPLED
parcels_staging was loaded county by county, so a PAGE IS A GEOGRAPHIC CLUSTER and the first pages of a sample are
one area. "TABLESAMPLE" reads as a guarantee of randomness and is not one at row level.

WHAT IT COST, MEASURED. sarasota_building_footprints probed with SYSTEM+LIMIT: 0 OF 250 parcels intersected a
footprint - IN BOTH DIRECTIONS, point-in-polygon and polygon-intersects-polygon. 231,915 footprints in one county
and not one hit. I had it as my first quarantine candidate.
DRAWN BY co_no INSTEAD: 220 OF 250, 88%. The layer was never the problem.
The draw from the layer bbox was 79% Sarasota by count, so the bias was NOT in which rows qualified - it was that
LIMIT took the first-sampled pages, which happened to be Charlotte.
FIX: oversample by block, then ORDER BY random() over the pool before taking n. After it: 45.6% in scope, both
displaced controls 0, PASS. (45.6 rather than 88 because the bbox legitimately spans three counties.)

AND THE SAME PROBE FOUND THE JOIN TYPE MATTERS AS MUCH AS THE SAMPLE. Containment is not one test:
  SPARSE POLYGON   parcel interior point in polygon      fl_nwi_wetlands 6% - discriminates, the normal case
  TILING COVERAGE  every parcel is inside one            charlotte_existing_land_use 100% - NOT a defect. A land
                   use layer tiles its county. The containment test cannot validate it; THE ANSWER IS THE
                   ATTRIBUTE, so the evidence must be the value distribution plus displaced controls proving the
                   layer is where it claims to be.
  REVERSE          the layer sits INSIDE the parcel      building footprints
  LINE             a parcel polygon crosses a line       nhd_flowline - a parcel interior point NEVER lands on a
                   zero-width line, so containment returns 0 and means nothing.
AND LAYER-SIDE AND PARCEL-SIDE RATES ARE DIFFERENT QUESTIONS. nhd_flowline: take 25 flowlines and ask whether a
parcel touches them, 23/25. Take 200 parcels and ask whether a flowline crosses them, 0/200. BOTH ARE TRUE. The
first says the layer reaches parcels; the second is the one that matters for serving a parcel report.

### 21. FIVE SPELLINGS OF "NOT MY JURISDICTION" AND ALL FIVE LOOK LIKE DISTRICTS

`test` | measured: 2026-08-16 | claude

MEASURED ACROSS THE ZONING DOMAINS:
  calhoun_zoning  INC and ROAD on 2,287 OF 11,922 ROWS - 19.2%
  volusia_zoning  999 on 929 of 5,246 - 17.7%, plus ROW on 8
  charlotte       CITY (zoning) and "City" (FLU)
  clay            MUNI
  punta_gorda     ONE BLANK of 153
ALL FIVE MEAN THE SAME THING: THE COUNTY HOLDS NO ZONING HERE BECAUSE THE PARCEL IS INSIDE A MUNICIPALITY. THAT IS
not_available. NOT ONE MAY RENDER AS A DISTRICT, AND NEARLY A FIFTH OF TWO COUNTY LAYERS IS AFFECTED.
IT ALSO EXPLAINS SOMETHING STRUCTURAL: those parcels ARE zoned - BY THE CITY - and the municipal layer is where the
answer lives. A report reading only the county layer would say "zoned INC" where the truthful answer is "zoned by
Cape Coral, see the municipal layer". THAT IS THE CONTAINMENT ARCHITECTURE EARNING ITS KEEP, and it is a third
independent argument for ruling 245.
AND ONE MORE SENTINEL: clearwater FLU carries WATER on 223 rows. Open water is not a land use. Same class as OPEN
WATER in the flood domain and Estuarine Deepwater in wetlands - THREE LAYERS, THREE DOMAINS, ONE PATTERN.
PLUS DUPLICATE SPELLINGS INSIDE ONE LAYER: capecoral carries "Neighborhood Commercial" AND "Neighborhood Commercial
(NC)", "Single Family Residential (R1)" AND "Single-Family Residential (R1)" - A HYPHEN APART - and two DIFFERENT
districts sharing the abbreviation RML. Grouping on that column double-counts districts.

### 22. I NEARLY FILED A DEFECT AGAINST MY OWN DISPLAY PATH

`test` | measured: 2026-08-16 | claude

charlotte_future_land_use appeared to hold HTML entities - "Parks &amp; Recreation", "Public Lands &amp; Facilities".
I MEASURED BEFORE FILING: ZERO ROWS CONTAIN THEM. The entity was introduced by the query_to_xml sampling path I use
to read rows, NOT BY THE DATA.
VERIFY AN ENCODING DEFECT AGAINST THE STORED VALUE, NEVER AGAINST A RENDERED SAMPLE. My own instrument corrupted the
evidence in exactly the way I was about to accuse the county of.
Same class as a limit 1 inside a probe built to enforce reading contents: THE TOOL IS NOT EXEMPT FROM THE
DISCIPLINE, and its failures are harder to see because it looks like the authority.

### 23. A FALSE CLEARANCE HAS FOUR LAYERS AND FIXING THE PREDICATE FIXES ONE OF THEM.

`test` | measured: 2026-08-17 | cc

ZONE D MEANS FEMA PERFORMED NO ANALYSIS. It is neither inside nor outside the SFHA, so false is a clearance we
are not entitled to give. MEASURED across all 54 distinct SERVED flood layers, 559,289 polygons:
  ZONE D   110 polygons in SIX served layers - hardee 84, nfhl_flood_zones 13, orange 5, broward 4,
           miamidade 2, palmbeach 2. Reported to me as 84 Hardee + 5 Orange; it is in four more.
  CAZ      225 in lee_flood_zones_firm, the SERVED Lee layer. Coastal A Zone is INSIDE the SFHA and was in
           no IN-list. A live false clearance, not a latent one.
  MULTI    0 across every served layer - but duval_flood_zones (65,827 rows) carries them and IS NOT
           REGISTERED. Duval serves the generic nfhl_flood_zones (10,207) instead of its own county layer.
           The defect is latent and goes live the moment that layer is selected.

I FIXED THE PREDICATE AND THE CLEARANCE SURVIVED IN THREE MORE PLACES. Each had to be found by reading the
NEXT CONSUMER, not the thing I had just changed:
 1 THE ROLLUP. bool_or() IGNORES NULLS, so a parcel touching one Zone D polygon and one Zone X polygon rolled
   up to false. The aggregate manufactured a clearance out of two honest per-polygon answers.
 2 THE BLOCK BUILDER. get_parcel_flood_block branched on status IN ('present','none_intersecting'); the new
   'undetermined' fell to the ELSE, which says "no county FEMA NFHL layer is held for this county". THAT IS
   FALSE - we hold the layer and queried it. I had traded a false CLEARANCE for a false REASON.
 3 THE RENDER, TWICE. renderFloodBlock tested only field_status==='not_established', so undetermined printed
   "Not in a Special Flood Hazard Area" - the St Pete failure, in the function carrying a comment warning
   against it. And the zone list used `z.in_sfha ? ' · SFHA' : ''`, where NULL RENDERS EXACTLY LIKE FALSE.
   Then the panel border: a two-way colour test painted undetermined in the same calm sage as a real
   clearance. THE WORDS WERE HONEST AND THE COLOUR WAS NOT.
A THREE-STATE FACT MUST BE CHECKED AT EVERY HOP: predicate, aggregate, assembler, text, and styling. A truthy
test is a two-state test, and every `x ? a : b` on a nullable boolean is a silent collapse.

AND UNDETERMINED IS NOT THE SAME AS not_established. not_established says the gap is in OUR data. Zone D says
we hold complete data and THE AUTHORITY declined to determine. Collapsing them would have been honest about
the value and wrong about who to chase.

### 24. A CONTROL DRAWN BY ARITHMETIC INSTEAD OF FROM THE DATA CANNOT FAIL FOR THE COUNTIES AT THE END OF THE RANGE.

`test` | measured: 2026-08-17 | cc

verify_key_e0 chose its wrong-county control as (p_co % 67) + 1. DOR co_no RUNS 11..77, NOT 1..67. So
  67->1  68->2  69->3  70->4  71->5  72->6  73->7  74->8  75->9  76->10
every one of which holds ZERO parcels. The control counted a join against an empty set and returned 0 WHETHER
THE KEY WAS RIGHT OR WRONG. 27 recorded runs used those counties and 25 carried verdict E0.
THOSE WERE ASSERTIONS WITH A CONTROL COLUMN NEXT TO THEM. And it hit the counties carrying most of the
relational CAMA work - VOLUSIA 74, SEMINOLE 69, SUWANNEE 71, SARASOTA, SUMTER, TAYLOR, UNION, WAKULLA, WALTON.
RE-RUN AGAINST A CONTROL DRAWN FROM co_no VALUES THAT EXIST: 26 of 27 HOLD. The keys were genuinely good, so
the damage was nil - BUT THAT WAS LUCK, NOT EVIDENCE, and it was unmeasured until re-run. The 27th,
volusia_cama_exemptions, read 0 on transform='none' and is 2,087/3,000 control 0 on 'altkey' - A TRANSFORM THE
HARNESS ALREADY CARRIED.
THE RULE: DERIVE A CONTROL FROM THE POPULATION, NEVER FROM ARITHMETIC ON AN IDENTIFIER. Identifier spaces have
holes and edges; a modulus assumes a dense range starting at 1. And a control that returns 0 because it
matched NOTHING AT ALL is indistinguishable from one that returns 0 because the key is specific - so a harness
must fail loudly when it cannot find a real control, which this one now does.

AND THE SAME SHAPE ONE LAYER UP. The ruling-252 enumeration wrote UNREAD/E5_none across all 718 undeclared
tables. In the spatial lane that flattened 288 TABLES THAT ALREADY CARRIED A CLASS AND A GRADE in nr_final -
E3 name-plus-second-read, E1 family exemplar, E2 own-content-read - down to "not read". 21 of them are
REG_flood at E1: SERVED FLOOD LAYERS RECORDED AS NEVER HAVING BEEN READ. Only 243 of the 551 were genuinely
unclassified.
"AN INSERT CARRYING A HIGHER EVIDENCE GRADE MUST UPSERT, NOT SKIP" HAS A TWIN THAT WAS NEVER STATED:
AN INSERT CARRYING A LOWER GRADE MUST NOT OVERWRITE A HIGHER ONE. An enumeration that makes a gap visible is
worth doing; one that overwrites what was already known makes the gap LOOK bigger and the record worse.
It is recoverable - nr_final still holds both, and ladm_declaration.legacy_class already carries the
old-to-new vocabulary crosswalk - but restoring means re-classifying through a derived mapping on top of a
grade that was already inherited, and several legacy classes map to more than one new class.

### 25. A COLUMN SCREEN OPTIMISES FOR LOOKING LIKE AN ANSWER. IT HAS NO IDEA WHAT THE TABLE IS FOR. 46.7% WRONG.

`test` | measured: 2026-08-17 | cc

MACHINE-PROPOSED COLUMN MAPS, 30 HAND-CHECKED BEFORE SCALING: 14 WRONG. The gate was 1 in 5; it is nearly
1 in 2. At 283 tables that is ~130 wrong maps, which is worse than none because a wrong map is served.
THE FAILURE MODES, WORTH MORE THAN THE RATE:
 OUR OWN INGEST METADATA SCORES PERFECTLY. sjrwmd_wells -> retrieved_at: 5 distinct, 0 nulls. A load
   timestamp is a flawless "classification" by every numeric test.
 EDITOR PROVENANCE TOO. pinellas_municipal_boundary -> int_created_user (EGIS | misspf0 | MISSPE8).
 A ROUNDED COORDINATE IS A LOW-CARDINALITY COLUMN. lee_bus_stops -> stop_lat (26.6 | 26.7 | 26.5). A
   LATITUDE proposed as the answer to what a bus stop is.
 SENTINELS PASS THE TEST BEST OF ALL, AND THIS ONE IS DANGEROUS. marion_transitional_flood_prone ->
   flood_elevation, values -99999 | -9999. Two distinct, zero nulls, name matches "elevation" on a
   flood-prone layer. 100% NULL-AS-VALUE, and it would have been mapped as a flood elevation. That is a
   FABRICATION SURFACE, not a bad map. The blank-not-null rule has a numeric twin and the screen is blind
   to both.
 AND THE ONE NO TUNING FIXES: "MOST CLASSIFICATION-LIKE" IS NOT "ANSWERS THE QUESTION".
   palmbeach_daycares -> user_facility_size when a daycare's answer is its NAME.
   stlucie_address_master -> status (Current|Retired) when an address register's answer is THE ADDRESS.
   The scorer ranks columns by shape. WHAT A TABLE IS FOR IS NOT IN ITS STATISTICS.
WHAT IT GOT RIGHT tells you the safe subset: every correct proposal was a case where a COLUMN NAME SHARES A
STEM WITH THE TABLE NAME and the values are a closed vocabulary - zoning->zone_code (AG&S|R-1|B-1),
listings->restype (building|site|structure|district|object), waterbodies->code, traffic_signals->signaltype.
THE STEM MATCH IS DOING THE WORK, NOT THE CARDINALITY. Restrict any future screen to that and gate it again.

AND THE GATE IS THE POINT. This cost one query to propose and one careful read to reject. Scaling first and
sampling afterwards would have put 130 wrong maps into a registry that other agents READ AS ESTABLISHED.
A HEURISTIC WITHOUT A MEASURED ERROR RATE IS A GUESS WITH A SCHEMA.

### 26. STATISTICAL POWER IS SCOPE BEFORE IT IS SIZE. A STATEWIDE SAMPLE CANNOT MEASURE A COUNTY LAYER AT ANY n.

`test` | measured: 2026-08-17 | cc

A STRATIFIED STATEWIDE POINT SET SPREADS ITS POWER ACROSS 67 COUNTIES. A COUNTY-SCOPED LAYER ONLY EVER SEES
THE POINTS THAT FALL IN ITS OWN COUNTY, SO 66/67 OF THE SAMPLE IS SPENT WHERE THE LAYER CANNOT POSSIBLY HIT.
MEASURED. highlands_flood_zones, a SERVED county NFHL layer, was filed PASS_LOW_POWER on 1 hit of 335.
Probed against HIGHLANDS parcels instead: 12 of 200 = 6.0%. The layer is healthy.
  335 statewide points   -> ~5 in county  -> EXPECTED HITS 0.3
  1,340 statewide points -> ~20 in county -> EXPECTED HITS 1.2
A 4x INCREASE IN n MOVED THE EXPECTATION FROM 0.3 TO 1.2 AND LEFT IT BELOW THE 5-HIT LOAD-BEARING LINE. To
put 335 points inside ONE county a statewide draw needs ~22,000. THE SIZE KNOB CANNOT REACH IT.
THE FIX IS TO DRAW WHERE THE LAYER IS: ST_Extent, then ORDER BY random() inside that bbox. Same instrument,
150 points, and lee_yard_waste_areas reads 56.67% while volusia_traffic_signals reads 63.33%.

AND THE FAILURE IS INVISIBLE BECAUSE IT LOOKS LIKE THE THING IT IS NOT. A low hit count from a
wrong-scope draw is INDISTINGUISHABLE from a genuinely sparse layer - both read "1 of 335, controls clean".
146 passes were downgraded and 69 declared "genuinely underlie almost no parcels" on that number. The
statewide draw was right for the statewide layers in the same sweep, which is what made it look sound.
A SAMPLE IS ONLY POWERFUL WITHIN THE POPULATION IT WAS DRAWN FROM, AND A LAYER'S POPULATION IS ITS EXTENT.
RECORD WHICH DRAW WAS USED ON EVERY ROW - a hit count means opposite things under an in-extent and a
statewide draw, and neither the rate nor the count carries that on its face.

THE COROLLARY THAT MAKES A SPARSE FINDING CREDIBLE: it should agree with an INDEPENDENT PRIOR.
alachua_flood_zones and brevard_flood_zones also read 1 hit - and both had been DE-SELECTED months earlier
under item 80 for holding "~0 polygons inside the county". THAT agreement is what distinguishes a real zero
from an artefact of the draw. A sparse verdict with no corroborating prior is a hypothesis, not a finding.

## 17-unsolvable

### 1. A KEY IS NOT UNSOLVABLE UNTIL THE COLUMN LIST IS READ AND THE COUNTY NUMBER IS LOOKED UP

`rule` | measured: 2026-08-16 | murphy

I RECORDED SIX KEYS AS UNRESOLVED TODAY. ALL SIX WERE SOLVABLE, AND NOT ONE NEEDED A CLEVER TRANSFORM.
CAUSE ONE - THE ANSWER WAS IN THE SAME TABLE AND I NEVER LISTED ITS COLUMNS:
  clay_parcels   I used pin "009796-000-00". THE ANSWER IS pin_dsp "29-05-25-009796-000-00". 4,000 OF 4,000,
                 control 0. pin is the same number with the section-township-range prefix STRIPPED.
  citrus_parcels I used altkey "2222948" and wrote "A DIFFERENT KEY SPACE, and no transform will fix it".
                 THE ANSWER IS alt_id "18E20S130020  02460 0210". 3,961 of 4,000, control 0.
  hillsborough_address_points  I used folio, a DECIMAL map-book reference. THE ANSWER IS strap, same table.
CAUSE TWO - I HAND-WROTE COUNTY NUMBERS AGAINST A STANDING RULE THAT FORBIDS IT:
  Hillsborough is 39, I used 29 (FRANKLIN). Seminole is 69, I used 59. Flagler is 28, I used 18.
  SEMINOLE AND FLAGLER NEEDED NO TRANSFORM AT ALL - 3,950 and 3,977 of 4,000, controls 0. THE KEYS WERE ALWAYS
  CORRECT. I DECLARED THEM INCOMPATIBLE AFTER COMPARING THEM TO A DIFFERENT COUNTY PARCELS.
  Fifth, sixth and seventh hand-written co_no error today. CC flagged the same 29-versus-39 mistake hours earlier.
THE PROCEDURE, IN THIS ORDER, AND TWO OF THE THREE STEPS ARE FREE:
  1 LIST EVERY COLUMN of the table and try each plausible one
  2 CONFIRM co_no FROM geo_reference BY NAME
  3 ONLY THEN consider a transform
"UNSOLVABLE" WAS ALWAYS A STATEMENT ABOUT MY QUERY, NOT ABOUT THE DATA - which is the verification-null rule from
the spec, applied to myself and ignored.

### 2. THE PINELLAS STRAP MISMATCH WAS SOLVED BY READING THE PUBLISHER OWN LAYER DESCRIPTION

`correction` | authority: Pinellas County Property Appraiser GIS layer metadata | measured: 2026-08-16 | murphy

OPEN AS A BLOCKING ITEM FOR WEEKS. THE ANSWER WAS PUBLISHED BY THE COUNTY, IN PLAIN TEXT, ON THE LAYER ITSELF:
  "Matching DOR Mapping data use the field PARCELNO. Matching DOR Tabular data use PARCEL_ID.
   Matching Property Appraiser download files use STRAP. Matching Property Appraiser Web Site use PARCELID."
FOUR IDENTIFIERS FOR ONE PARCEL, EACH FOR A DIFFERENT AUDIENCE. Our spine holds the 23-char DOR form; the CAMA
download holds the 18-char STRAP. THEY ARE THE SAME NUMBER WITH SPACES REMOVED.
  strap    152711048790000030
  parcelno 15 27 11 04879 000 0030
  parcelid 112715048790000030      <- RANGE-TOWNSHIP-SECTION, THE REVERSE ORDER. Using it matches nothing.
TRANSFORM: split at 2,2,2,5,3,4 - SEC TWP RNG SUB BLK LOT - and insert five spaces. 18 + 5 = 23.
MEASURED: 3,969 OF 4,000 against co_no 62, WRONG-COUNTY CONTROL 0. THIRTEEN PINELLAS CAMA TABLES UNBLOCKED IN ONE
MOVE - property info, building, sales, sales history, permits, owners, land, exemptions, extra features,
structural elements, sub areas, legal, site addresses.
AND pinellas_septic HELD ALL FOUR FORMS IN ONE ROW THE WHOLE TIME. The rule I wrote earlier today - LOOK FOR THE
TABLE THAT HOLDS BOTH FORMS - would have found it without the web search. I wrote the rule and did not run it.

## 18-score

### 1. SESSION SCORE 2026-08-16 - REPORT THE GRADE, NEVER THE COUNT

`measurement` | measured: 2026-08-16 | claude

                              START      NOW
  populated tables            2,113      2,114
  LADM declared                  51      1,396
  E0 SERVABLE                     0        195     <- THE ONLY NUMBER THAT MATTERS
  E2 own content read             0        118
  E1 family exemplar              -        317
  E3 name + second read           -        223
  E4 name only                    -        485
  E5 honestly unclassified        -         59
  data_source_registry          557      1,368
  layer_column_map rows         436      3,617+
  tables with a column map     ~180      1,311+
  lens                            0         88 live (16 CC)
  ladm_class_vocabulary           0         25, FK-enforced
  active defects                119        141   (73 blocking)
  bus                           373        398   rulings 239-250
195 OF 2,114 ARE SERVABLE - 9.2%. EVERY OTHER NUMBER ABOVE IS REACHABILITY, NOT SERVING.
ARTEFACTS THAT DID NOT EXIST THIS MORNING: the lens table (append-and-supersede, both agents write), 
ladm_class_vocabulary (21 ISO classes with source clauses + 4 declared local extensions, FK-enforced so a class
cannot be invented in an INSERT), and evidence_grade (adopted from the July nr_final pass, with E0 added above it in
two forms).
WHAT THE READING BOUGHT: Iris McNeely restored to a PIR. polk_sales - 3M rows - rescued from an ELSE branch that
filed it as an amenity. Thirteen Pinellas CAMA tables unblocked. Clay, Citrus, Hillsborough, Seminole and Flagler
keys recovered. Six flood layers with wrong or non-standard zone columns. Zone D exposed as a false clearance.
Duval 22,606 multi-zone parcels where the non-SFHA value comes first in the string.
BLOCKING DEFECTS ROSE 119 -> 141 BECAUSE THE READING FOUND THEM, NOT BECAUSE ANYTHING BROKE.

## 19-scale

### 1. FAMILY DECLARATIONS BECOME LEGITIMATELY E0 BY MEASURING EVERY MEMBER, NOT ONE EXEMPLAR

`rule` | measured: 2026-08-16 | murphy

195 OF 2,114 IS NOT A SUCCESS AND THE BOTTLENECK WAS METHOD, NOT EFFORT. I was verifying 4-10 tables a turn by
hand while 317 sat at E1 - a class inherited from ONE member.
BUILT verify_key_e0(table, key, co_no, transform) AND key_verification_run.
The function measures a declared key against parcels_staging AND against a deliberately wrong county, RETURNS -1 ON
ERROR INSTEAD OF RAISING so a batch sweep completes, and every result is written to key_verification_run.
A GRADE WITH NO ROW IN key_verification_run IS AN ASSERTION, NOT A MEASUREMENT.
FIRST SWEEP - 61 DOR NAL TABLES, EACH AGAINST ITS OWN COUNTY: 60 PASS E0 (minimum 2,400 of 3,000, every control 0).
AND THE ONE THAT DID NOT IS THE ARGUMENT FOR DOING IT THIS WAY:
  bay_nal_dor_source  3,060 matched AND CONTROL 1,542 - A 50% FALSE-POSITIVE RATE.
CAUSE, MEASURED: Bay parcel ids are 11-DIGIT ZERO-PADDED NUMERICS ("00001000000") ON ALL 129,598 ROWS, ONE LENGTH
VARIANT, AND CALHOUN USES THE SAME SCHEME on 13,588 parcels. THE JOIN IS CORRECT; THE CONTROL CANNOT DISCRIMINATE.
That is the LOW-ENTROPY TRAP from the verification protocol appearing in the CONTROL rather than in the anchor -
graded E0_low_entropy_control_uninformative so the weakness is on the record rather than hidden inside a pass.
AN EXEMPLAR READ WOULD HAVE GIVEN ALL 67 THE SAME GRADE AND NEVER SURFACED BAY.

### 2. THE HARNESS: verify_key_e0 AND key_verification_run - A GRADE WITHOUT AN EVIDENCE ROW IS AN ASSERTION

`rule` | measured: 2026-08-16 | claude

BUILT 2026-08-16 BECAUSE 195 OF 2,114 WAS NOT A SUCCESS AND HAND-VERIFYING 4-10 TABLES A TURN NEVER WOULD BE.
  verify_key_e0(table, key, co_no, transform) - measures the declared key against parcels_staging AND against a
    DELIBERATELY WRONG COUNTY. Returns -1,-1 ON ERROR RATHER THAN RAISING, so a batch sweep completes instead of
    dying on the first bad column.
  key_verification_run - one row per (table, key, transform) with matched, control, sampled and match_rate.
    A GRADE WITH NO ROW HERE IS AN ASSERTION, NOT A MEASUREMENT. 154 E0 evidence rows now exist.
  Transforms supported: none | lpad11 | nodash | strap23 | altkey - each one earned by a specific county today.
FOUR THINGS THE SWEEP FOUND THAT AN EXEMPLAR READ COULD NOT:
1. bay_nal_dor_source AND bay_sdf_dor_source - MATCHED 3,060 AND 3,008, CONTROLS 1,542 AND 628. Bay parcel ids are
   11-DIGIT ZERO-PADDED NUMERICS on all 129,598 rows, ONE LENGTH VARIANT, AND CALHOUN USES THE SAME SCHEME on
   13,588 parcels. THE JOIN IS CORRECT AND THE CONTROL CANNOT DISCRIMINATE - the low-entropy trap appearing in the
   CONTROL rather than the anchor. Graded E0_low_entropy_control_uninformative so the weakness is ON THE RECORD
   rather than hidden inside a pass.
2. MY FIRST THRESHOLD WAS AN ABSOLUTE COUNT (matched > 1500) AND IT FAILED THREE SMALL COUNTIES. Liberty holds 599
   rows in total and matched 597 - a 99.7% rate scored as "review". SAME CLASS OF ERROR AS THE LOW-ENTROPY CONTROL:
   the number was right and the test was wrong. Rate against ROWS SAMPLED, never an absolute count.
3. MY SWEEP ONLY TESTED transform=none, SO 25 TABLES CAME BACK zero_match THAT I HAD ALREADY SOLVED BY HAND HOURS
   EARLIER. Re-run with the right transform: ALL 13 PINELLAS CAMA TABLES PASS ON strap23 (minimum 2,953 of 3,000),
   3 Volusia CAMA on altkey, Collier sales on lpad11. A HARNESS THAT DOES NOT CARRY THE KNOWN TRANSFORMS
   MANUFACTURES ITS OWN ZEROS.
4. lake_tax_parcels STILL ZERO ON nodash - a genuine open item, not a harness artefact, and now distinguishable
   from the 24 that were.
THE DISCIPLINE THIS ENFORCES: EVERY FAMILY MEMBER IS MEASURED, NOT ONE. That is what turns an E1 family declaration
into 60-odd legitimate E0s, and it is the only route from 195 to 2,000.

### 3. READING FIRST FOUND FOUR THINGS THE HARNESS WOULD HAVE KEYED PAST

`rule` | measured: 2026-08-16 | murphy

The harness measures keys. IT CANNOT TELL YOU WHAT A COLUMN MEANS, and four tables in one batch proved why reading
comes first.
1. volusia_cama_situs.OWNSEQ IS NOT OWNER SEQUENCE - IT IS ADDRESS SEQUENCE, AND THE NAME LIES.
   PARID 2000155: OWNSEQ 1 = 2130 NELSON AVE, OWNSEQ 2 = 2120 NELSON AVE. TWO STREET NUMBERS, ONE PARCEL.
   MEASURED: 368,083 rows / 344,861 parcels. 1,590 parcels carry MORE THAN ONE situs address AND ONE CARRIES 897.
   A limit 1 read serves one of several REAL addresses, and a search on the other FAILS TO FIND THE PARCEL.
   Fourth shape of the Earhart failure - and the first where the column NAME actively misdirects.
2. volusia_cama_legal EMBEDS PLAT AND DEED REFERENCES IN FREE TEXT, AT SCALE.
   "LOT 5 BRADDOCK PARK DAYTONA BEACH MB 5 PG 183 ... PER OR 5210 PG 0942 PER OR 8124 PG 1634"
   MEASURED: 237,633 OF 313,619 (75.8%) CARRY A MAP BOOK REFERENCE. 299,208 (95.4%) CARRY AN OFFICIAL RECORD
   REFERENCE. THE JURIDICAL REGISTER IS THE IDENTIFIED PRODUCT GAP AND 95% OF ONE COUNTY CARRIES ITS OWN INSTRUMENT
   POINTERS IN A FIELD WE TREATED AS PROSE.
   YR_ANNEX on 6,769 rows DATES ANNEXATIONS - and our municipal boundaries are 2021 vintage, so this column answers
   the staleness problem for the parcels that moved.
3. volusia_cama_parcel CARRIES FOUR TAXABLE VALUES FOR ONE PARCEL - STXBL, NSTXBL, CITXBL, COTXBL, by taxing
   authority, because exemptions differ per authority. ISO 19152-4 3.1.14 says a property can have more than one
   value; this is that, four times over. AND CRA - COMMUNITY REDEVELOPMENT AREA, Ch.163 Part III, ON 15,710
   PARCELS. Tax increment capture and design controls. Nothing serves it.
4. volusia_cama_land.SOIL IS POPULATED ON 9,367 ROWS - a soils reference inside a CAMA table, independent of SSURGO,
   which the spec lists as a pending statewide pull. AGFLG is the greenbelt flag, one character wide, and a use
   change triggers ROLLBACK TAXES. INFLU records WHY land is worth less - access, shape, easement.
THE ORDER MATTERS: READ, THEN KEY. The keys on all four verified at 2,959-2,971 of 3,000 with zero controls, and
every one of those facts would have been invisible to a run that only measured the join.

### 4. A CONSTRAINT THAT FORBIDS AN HONEST STATE FORCES A DISHONEST ONE

`correction` | measured: 2026-08-16 | cc

CC REPORTED 243 SPATIAL TABLES BLOCKED: declared_class IS NOT NULL WITH AN FK TO ladm_class_vocabulary, AND NO
MEMBER MEANT "NOT READ". The only options were to INVENT A CLASS or LEAVE THE TABLE ABSENT. They left them absent,
which was right, and said so.
THAT WAS MY SCHEMA FAILING, NOT THEIRS. The FK was correct to block invention and WRONG TO HAVE NO NULL OPTION.
E5_none was already the honest GRADE and had no CLASS to pair with.
ADDED class UNREAD - explicitly is_standard=false, always paired with evidence_grade E5_none, carrying NO claim about
contents. 718 tables enumerated with it.
EVERY POPULATED TABLE IN THE DATABASE IS NOW ENUMERATED: 2,115 declared of 2,114 populated, ZERO ABSENT. That is not
2,114 catalogued - 718 are UNREAD and say so. THE DIFFERENCE BETWEEN ENUMERATED AND CATALOGUED IS NOW VISIBLE IN THE
DATA INSTEAD OF BEING A GAP NOBODY COULD COUNT.

## 20-clearance

### 1. FIXING THE PREDICATE FIXED ONE LAYER OF FOUR - AND THE COLOUR LIED AFTER THE WORDS WERE FIXED

`principle` | measured: 2026-08-16 | cc

CC CORRECTED A LIVE FALSE CLEARANCE AND HAD TO FIND EACH SURVIVOR BY READING THE NEXT CONSUMER, NOT BY RE-READING
WHAT HAD JUST BEEN CHANGED.
 1 THE PREDICATE  Equality on the whole string: zone IN (A,AE,AH,AO,AR,A99,V,VE). CAZ absent -> false. A comma-joined
   "0.2 PCT...,AE" matches nothing -> false. D -> false when it means UNDETERMINED.
 2 THE ROLLUP  bool_or() IGNORES NULLS. One Zone D polygon plus one Zone X polygon rolled up to FALSE.
   THE AGGREGATE MANUFACTURED A CLEARANCE FROM TWO HONEST ANSWERS.
 3 THE BLOCK BUILDER  undetermined fell to an ELSE and emitted "no county FEMA NFHL layer is held for this county".
   WE HOLD THE LAYER. FEMA HAS NOT DONE THE ANALYSIS. A FALSE CLEARANCE TRADED FOR A FALSE REASON - which points the
   reader at the wrong party to chase.
 4 THE RENDER, TWICE  renderFloodBlock printed "Not in a Special Flood Hazard Area" - the St Petersburg failure,
   inside the function whose own comment warns against it. AND z.in_sfha ? ... : '' RENDERS NULL IDENTICALLY TO
   FALSE. Then the border painted undetermined in the same calm sage as a real clearance.
   THE WORDS WERE FIXED AND THE COLOUR STILL LIED.
THE RULE: A THREE-STATE VALUE MUST BE HONOURED AT EVERY LAYER IT PASSES THROUGH - predicate, aggregate, builder,
words AND COLOUR. A null that renders as false is not a null. Every ternary on a nullable boolean is a two-state
collapse, and CSS is a rendering path like any other.
AND THE PROOF NEEDED HUNTING: CC first two test parcels also touched AE, so in_sfha was correctly true and PROVED
NOTHING. It took a Zone-D-ONLY parcel - Hardee 35/0333230000100200000 - to show false -> NULL. A TEST THAT CANNOT
FAIL IS NOT A TEST, applied to the fixture rather than the guard.

### 2. MY ZONE D COUNT WAS LOW AND MY MULTI-ZONE FINDING WAS OFF THE SERVED PATH

`correction` | measured: 2026-08-16 | cc

CC MEASURED ACROSS ALL 54 DISTINCT SERVED LAYERS - 67 resolution rows COLLAPSE TO 54 TABLES because de-selected
counties share nfhl_flood_zones - over 559,289 polygons.
 ZONE D IS IN SIX LAYERS, NOT TWO. hardee 84, nfhl_flood_zones 13, orange 5, broward 4, miamidade 2, palmbeach 2 =
   110, not the 89 I reported. AND THE NFHL 13 REACH EVERY COUNTY THAT DE-SELECTED ITS OWN LAYER, so the exposure is
   far wider than the row count suggests. MY SWEEP SAMPLED 800 ROWS PER LAYER AND MISSED THE RARE VALUES - the
   distinct-value sweep found the CLASS and undercounted the INSTANCES.
 CAZ 225 IN LEE, AND LEE SERVES ITS OWN LAYER - so that was a LIVE false clearance, not a latent one.
 MULTI-ZONE: ZERO IN ANY SERVED LAYER. duval_flood_zones carries 22,606 of them and IS NOT REGISTERED. Duval serves
   the generic statewide layer instead of its own parcel-joined one. THE DEFECT WAS REAL AND LATENT, and CC fixed the
   predicate BEFORE I ruled on registering the layer - the right order.
THE LESSON ON MY OWN METHOD: A LIMIT ON A DISTINCT-VALUE SWEEP FINDS THE VOCABULARY AND UNDERSTATES THE COUNT. Use
it to discover the class, then count the class WITHOUT a limit.

## 21-reading

### 1. 428,228 BUILDING FOOTPRINTS WERE SITTING IN A TEXT COLUMN CALLED traverse

`measurement` | measured: 2026-08-16 | claude

pinellas_cama_rp_building.traverse, POPULATED ON 428,228 OF 428,229 ROWS:
  "BAS:40,0:=W40S20E16S4E24N24$OPF:0,20:=S4E16N4W16$."
IT IS THE BUILDING SKETCH AS DIRECTIONS AND DISTANCES. BAS = base area, starting at offset 40,0, then West 40,
South 20, East 16, South 4, East 24, North 24, closing with $. Then OPF - open porch finished - as a SECOND CLOSED
SECTION from 0,20. A polygon per section, WITH THE SECTION CODE NAMING WHAT EACH ONE IS.
THAT IS 428,228 BUILDING FOOTPRINTS IN A COUNTY WHERE WE HOLD NO BUILDING GEOMETRY.
AND IT IS INDEPENDENTLY CHECKABLE: the enclosed area of each section must equal the corresponding figure in
pinellas_cama_rp_sub_areas. TWO INDEPENDENT DERIVATIONS OF ONE FACT - which is the corroboration standard, available
without a second source.
DO NOT SERVE THE RAW STRING. Derive area and shape, and disclose it as an ASSESSOR SKETCH, NOT A SURVEY - the same
caveat as parcel geometry.
NO SCHEMA WOULD HAVE REVEALED THIS. A text column named traverse in a table of 40 columns, and the value is the
building.

### 2. A TABLE HOLDING BOTH THE PROHIBITED THING AND THE REQUIRED THING

`correction` | authority: PIR_REPORT_SPEC_v5 Part 0.2 | measured: 2026-08-16 | claude

data_confidence_scores, 427,682 rows.
PIR_REPORT_SPEC_v5 PART 0.2 IS EXPLICIT: "NO CONFIDENCE SCORE. Show source count, tiers, independence and dates. A
0-100 NUMBER IS THE NEXT FABRICATION."
THIS TABLE HAS confidence_score POPULATED ON 427,682 ROWS. MEASURED VALUES: 0.05, 0.40, 0.90, 0.98 - FOUR DISCRETE
LEVELS DRESSED AS A CONTINUOUS SCORE. confidence_tier is green/red. AND verified_by_staff_id IS POPULATED ON ZERO
ROWS, SO "VERIFIED" MEANS AN ALGORITHM AGREED WITH ITSELF.
BUT THE SAME TABLE HOLDS EXACTLY WHAT THE SPEC DOES WANT: sources_agree, 309,104 AGREE AND 4,474 DISAGREE, across
vcpa_cama versus dor_nal, on a NAMED FIELD. That is pairwise source agreement - the honest form.
SERVE sources_agree, source_a, source_b, verification_method. NEVER SERVE confidence_score OR confidence_tier.
AND THE SCOPE IS NARROW: TWO FIELDS ONLY - dor_parcel_id and lat_lng - AND ONE SOURCE PAIR. It is not a general
agreement ledger and must not be described as one.
THE LESSON: A SPEC PROHIBITION IS NOT SELF-ENFORCING. The forbidden column was built, populated on 427,682 rows, and
nothing stopped it - because the prohibition lives in a markdown document and the column lives in the database.

### 3. THE AGENT ROSTER IS 494,953 ROWS AND THE PLAN COUNTS 312,291 - THE DIFFERENCE IS rank

`measurement` | authority: DBPR licence roster | measured: 2026-08-16 | claude

agent_license_roster carries EIGHT ranks and only some are people who sell property:
  SL Sales Associate | BK Broker | BL Broker Sales | BO RE Branch Offic   <- practitioners
  CQ RE Corp. | PR RE Partnership                                          <- ENTITIES, NOT PEOPLE
  ZH Add Sch Loc | ZH RE Instructor                                        <- SCHOOLS AND INSTRUCTORS
COUNTING ROWS AS AGENTS OVERSTATES THE ADDRESSABLE MARKET BY ROUGHLY 180,000. Every saturation figure in the business
plan - 1% saturation = 3,123 agents, 3% = 9,369 - MUST BE COMPUTED ON PRACTITIONER RANKS ONLY.
AND ZH IS TWO DIFFERENT THINGS UNDER ONE PREFIX: "Add Sch Loc" is a school location, "RE Instructor" is a person.
Same code, different entities.
SEPARATELY, agent_license_status CARRIES TWO STATUS FIELDS THAT DIFFER ON 493,320 OF 493,556 ROWS:
  PRIMARY IS WHETHER THE LICENCE EXISTS. SECONDARY IS WHETHER IT MAY BE USED.
  "Current/Inactive" IS A LICENCE THAT EXISTS AND CANNOT PRACTISE. "Probation/Active" IS A DISCIPLINED LICENSEE
  STILL WORKING. "Invol Inactive" IS A REGULATORY ACTION, NOT A LAPSE.
READING primary_status ALONE REPORTS ALL THREE AS FINE. And snapshot_date makes every status a DATED OBSERVATION,
not a current fact.

### 4. nr_content IS THE ACCELERATOR I HAVE BEEN RECOMPUTING BY HAND ALL DAY

`rule` | measured: 2026-08-16 | claude

nr_content HOLDS top_values PER COLUMN FOR 1,183 TABLES. nr_keys HOLDS KEY-ROLE PROFILES FOR 1,226.
IT HAD ALREADY FLAGGED clay_parcels.pin_dsp AND citrus_parcels.alt_id - THE TWO KEYS I HUNTED FOR HOURS LATER.
ONE QUERY AGAINST nr_content GIVES THE VALUE DOMAIN OF EVERY COLUMN OF A TABLE WITHOUT TOUCHING THE TABLE. That is
step 1 and step 3 of the reading method, precomputed, for 56% of the database.
BUT IT IS A CANDIDATE GENERATOR, NOT AN ANSWER. nr_keys flags ogc_fid, globalid AND objectid as OWN_KEY_unique -
the exact defect behind seven bad column-map entries. Built view key_candidates to strip row-id and measure-like
names: 782 tables, 8.2 candidates each. THE HARNESS DECIDES; THE PROFILE ONLY NARROWS.
AND TWO FAILURES OF MY OWN IN USING IT:
  MY BATCH TIMED OUT MID-RUN and committed almost nothing. Smaller batches.
  I HARDCODED sampled=3000 IN THE INSERT, so union_sdf_dor_source - 1,451 rows total, 1,434 matched - reported a
  47.8% rate. THE SAME ABSOLUTE-VERSUS-RATE ERROR I HAD ALREADY MADE AND RECORDED HOURS EARLIER. Fixed; 28 rows now
  correctly exceed 100%, which is many-sales-per-parcel behaving as designed.

### 5. BROWARD HOLDS THREE FLOOD MAPS OF THREE VINTAGES AND THE SERVED CHOICE IS RIGHT

`measurement` | authority: FEMA FIRM vintages | measured: 2026-08-16 | claude

  broward_fema_sfha_2024        17,366 polygons  REGISTERED AND SERVED
  broward_fema_preliminary_2019 88,596 polygons  unregistered
  broward_flood_zones_2014      10,309 polygons  unregistered
THE CHOICE IS CORRECT AND WORTH STATING WHY: A PRELIMINARY MAP IS NOT AN EFFECTIVE MAP. It is a proposed revision,
not adopted, and serving it would state a hazard FEMA has not adopted. The 2014 map is simply superseded.
BUT THE PRELIMINARY CARRIES FACTS THE EFFECTIVE MAP DOES NOT, ON FIVE TIMES AS MANY POLYGONS:
  ins_req Yes/No AND 54,183 SAY YES - AN EXPLICIT FEMA INSURANCE-REQUIREMENT FLAG, where we currently DERIVE the
    mandate from a zone code.
  bfe_calc AND new_bfe - the PROPOSED base flood elevation against the current. A buyer whose BFE is about to rise
    has a decision to make NOW. That is forward-looking and nothing else we hold is.
  chhachg AND fldwychg - change flags for the Coastal High Hazard Area and the floodway (Z/D/I).
  case_no 15-04-4157S - the FEMA revision case, the authority reference for the change.
*** eff_date = 9999-09-09 ON 88,563 OF 88,596 ROWS - A SENTINEL DATE MEANING NOT YET EFFECTIVE. *** Never parse it;
anything sorting on eff_date puts these in the year 9999.
AND THE 2014 MAP GIVES SPELLINGS EIGHT AND NINE OF THE 0.2% ZONE:
  "X - Above the 500 year flood plain" = MINIMAL HAZARD
  "X - Below 500 year flood plain"     = THE 0.2% ZONE
ONE WORD APART, OPPOSITE FINDINGS - the second such pair after boyntonbeach "X (unshaded)". Plus "AREA NOT INCLUDED",
the second county after Santa Rosa.
THE SUPERSEDED MAP HAS ONE UNIQUE USE: it is the only way to answer WAS THIS PARCEL IN A DIFFERENT ZONE BEFORE 2024 -
which bears directly on grandfathered insurance rates. Serve as history, never as current.

## 22-controls

### 1. MY CONTROL COULD NOT FAIL FOR TEN COUNTIES AND I WROTE THE RULE THAT FORBIDS IT

`test` | measured: 2026-08-16 | cc

verify_key_e0 DREW ITS CONTROL COUNTY AS (p_co % 67) + 1. co_no RUNS 11..77, SO 67->1, 68->2 ... 76->10 - COUNTIES
THAT HOLD ZERO PARCELS. THE CONTROL JOINED AN EMPTY SET AND RETURNED 0 NO MATTER WHAT THE KEY DID.
TEN OF SIXTY-SEVEN COUNTIES, INCLUDING VOLUSIA 74, SEMINOLE 69 AND SUWANNEE 71 - the richest CAMA county we hold.
25 E0 VERDICTS RESTED ON IT. CC re-ran all 27 against real controls: 26 HELD. DAMAGE NIL - BY LUCK, NOT BY EVIDENCE.
"A CHECK THAT CANNOT FAIL IS NOT A CHECK" IS A RULE I RECORDED THIS MORNING AND THEN BUILT A VIOLATION OF, INSIDE THE
INSTRUMENT WHOSE ENTIRE PURPOSE IS THE CONTROL. Same class as CC putting limit 1 inside the probe built to enforce
reading contents: THE TOOL IS NOT EXEMPT, and its failures hide because it looks like the authority.
FIXED: the control is now drawn from co_no values that EXIST and hold more than 1,000 parcels, nearest to the subject
county, and the function RAISES if none is available rather than returning a comfortable zero. It returns control_co
so the choice is auditable in every row.
AND THE 27TH TABLE WAS NEVER UNRESOLVED: volusia_cama_exemptions read 0 on transform none and 2,087/0 on altkey - A
TRANSFORM THE HARNESS ALREADY CARRIED, just not the one recorded. Third instance today of the three-step procedure
paying off.

### 2. AN INSERT CARRYING A LOWER GRADE MUST NOT OVERWRITE A HIGHER ONE - THE UNSTATED TWIN OF MY OWN RULE

`correction` | measured: 2026-08-16 | cc

RULING 249 SAID: an insert carrying a HIGHER evidence grade must UPSERT rather than skip. CC STATED THE TWIN I HAD
NOT: AN INSERT CARRYING A LOWER GRADE MUST NOT OVERWRITE A HIGHER ONE.
MY UNREAD ENUMERATION VIOLATED IT IMMEDIATELY. I inserted UNREAD/E5_none for every table absent from
ladm_declaration - and 288 OF THOSE CARRIED A REAL CLASS AND GRADE IN nr_final. Only 243 were genuinely
unclassified. TWENTY-ONE WERE REG_flood AT E1: SERVED FLOOD LAYERS RECORDED AS NEVER READ.
CC tried to restore and was CORRECTLY BLOCKED - nr_final holds July classes and the FK now points at the 26-member
LADM-proper set. They did not guess, and said the vocabulary call was mine.
RESTORED THROUGH THE legacy_class CROSSWALK MY OWN MIGRATION LEFT BEHIND. MEASURED: 28 OF 30 LEGACY CLASSES MAP TO
EXACTLY ONE TARGET. Two do not and were LEFT AS UNREAD:
  PART4_valuationunit -> NINE targets (VM_ValuationUnit 118, LA_Party 3, VM_Building 3, VM_TransactionPrice 2, ...)
  PART2_rrr           -> LA_RRR 2 and LA_AdministrativeSource 1
257 RESTORED. UNREAD 705 -> 448, classified 1,405 -> 1,667.
EVERY RESTORED ROW SAYS IN ITS RATIONALE THAT THE GRADE IS INHERITED AND NOT A READ - E1 means one family exemplar,
E3 a name plus a read elsewhere, BOTH PROVEN UNSAFE TODAY. Restoring the record is not the same as reading the table.

## 23-shelving

### 1. THE CATALOGUE MEASURED AS A CATALOGUE - AND THE SHELF FALLS OFF A CLIFF AT THE JOIN

`measurement` | measured: 2026-08-16 | murphy

Murphy asked why we are grading tables when the job is cataloguing and shelving. Correct - the grade became the
activity. THE CATALOGUE MEASURED AS A CATALOGUE:
  2,115  tables in the library
  1,667  know what it is                79%
  1,321  + a column map                 62%
  1,215  + a refreshable source         57%
    154  + THE JOIN PROVED               7%
1,061 TABLES ARE CATALOGUED AND NOT SHELVED. Classed, mapped, sourced, join unproven - and the join is the only step
left for nearly all of them.
AND THE 7% UNDERSTATES IT FOR TWO THIRDS OF THE LIBRARY. Most of those 1,215 are amenity, hazard and boundary layers
that JOIN SPATIALLY, NOT BY KEY. They do not need a parcel key; they need a verified containment join. My grade
scoreboard was measuring the wrong axis for them.
SHELVED IS FOUR FACTS: known what it is, column map, refreshable source, AND THE JOIN IT ACTUALLY USES PROVED - by
key OR by containment. Report that, not a grade distribution.

### 2. THE ANSWER WAS ONE COLUMN AWAY FOR THE THIRD TIME TODAY

`test` | measured: 2026-08-16 | claude

polk_buildings: my candidate filter picked "parcel" - VALUE "000920", SIX DIGITS - AND IT MATCHED ZERO.
It is a COMPONENT, not a key. The row also carries township 28, range 26, section 25, sub 590000. I composed them and
got ZERO TOO.
parcel_id WAS IN THE SAME TABLE AND MATCHED 2,977 OF 3,000, CONTROL 0.
THIRD TIME TODAY, AFTER clay_parcels.pin -> pin_dsp AND citrus_parcels.altkey -> alt_id. STEP 1 OF THE PROCEDURE -
LIST EVERY COLUMN - IS THE ONE THAT KEEPS PAYING, and my key_candidates view scored "parcel" above "parcel_id"
because it ranked on uniqueness rather than on being a WHOLE identifier.
THE HEURISTIC LESSON: A COMPONENT OF A KEY CAN BE NEAR-UNIQUE AND STILL JOIN NOTHING. Uniqueness does not imply
completeness. Prefer the LONGEST plausible identifier, then test.
AND polk_buildings IS THE SECOND COUNTY CARRYING A traverse SKETCH VECTOR after Pinellas - together 751,557 BUILDING
FOOTPRINTS IN TEXT FORM, in counties where we hold no building geometry.
It also ships EVERY CODE WITH A PAIRED DESCRIPTION - extwall/exwalldesc, class/class_desc, frame/frmdesc, fltydesc -
so NO CROSSWALK IS NEEDED. But bldshapedesc MIXES SHAPES WITH A ROOF MATERIAL: RECTANGLE, SQUARE, IRREGULAR AND
"TILE ROOF" in one domain. The sentinel class in a description field.

### 3. A TABLE THAT DECLARES ITS OWN PROVENANCE, AND A PARTIAL HOMESTEAD

`test` | measured: 2026-08-16 | claude

property_transaction_history CARRIES import_batch = "DOR_SDF_SDF74F202502VAB". County 74, 2025 file, POST-VAB.
THE TABLE NAMES ITS OWN SOURCE IN A COLUMN. It is DERIVED FROM volusia_sdf_dor_source, which we already hold, reshaped
onto our internal ids. SO IT MUST NEVER CORROBORATE THE SDF - that is the lineage trap the spec names, one fact
wearing two hats, and the import_batch column is what makes it detectable.
It also carries expand_num_1/2 and expand_text_1/2 - UNTYPED PASSTHROUGH COLUMNS holding 1702, 09, 06, almost
certainly book/page or a qualification detail, WITH NO NAME TO SAY WHICH. Never serve an unnamed column.
And use_in_avm=false on the sampled row - the table carries its own fitness flag, which must be honoured.
SEPARATELY, pasco_cama_parcel: hstsqft IS HOMESTEAD SQUARE FOOTAGE AND IT READS 616 OF 1,176 TOTAL ON A ROW WHERE
hmstd IS "NO". A PARTIAL HOMESTEAD - the exemption applies to part of the structure. 171,796 of 324,735 rows (52.9%)
are hmstd YES, so nearly half are not, AND READING hmstd ALONE LOSES THE PARTIAL CASE ENTIRELY.
Its prop_use_desc also carries "Grzgsoil Class1" and "Class4" - GRAZING SOIL CAPABILITY CLASSES, an agricultural
productivity rating hiding inside a use code.

### 4. THE SAME 18-CHARACTER KEY SHAPE CARRIES TWO DIFFERENT COMPONENT ORDERS INSIDE ONE COUNTY

`test` | authority: Pinellas County Property Appraiser GIS metadata | measured: 2026-08-16 | claude

pinellas_address_points.pin_num IS 18 CHARACTERS, EXACTLY LIKE strap, AND THE strap TRANSFORM FAILS ON IT.
MEASURED ON 3,000 ROWS:
  SEC-TWP-RNG (the strap order)     22
  RANGE-TWP-SEC                  2,960
The Pinellas Property Appraiser metadata WARNED OF EXACTLY THIS FOR PARCELID - "Matching Property Appraiser Web Site
use PARCELID" against "download files use STRAP" - AND IT RECURS IN THE ADDRESS LAYER, which is a different
publisher inside the same county government.
A LENGTH MATCH IS NOT A FORMAT MATCH. Two 18-character strings can be the same six fields in a different order, and
the difference is invisible until you test a permutation. Added transform rts23.
AND 22 OF 3,000 MATCHED ON THE WRONG ORDER - not zero. A SMALL NON-ZERO MATCH IS THE MOST DANGEROUS READING: it
looks like a broken key rather than a wrong order, and 0.7% is exactly the range a careless eye calls noise and
moves on from.

### 5. PALM BEACH MASKS THE OFFICIAL RECORD BOOK, NOT JUST THE NAME

`principle` | authority: s.119.071(4)(d) F.S.; Palm Beach County PA | measured: 2026-08-16 | claude

palmbeach_property_info: book = "****" ON 4,636 ROWS. confid_flg = Y ON 4,628.
THE COUNTY REDACTS THE OFFICIAL RECORD BOOK FOR A PROTECTED OWNER, BECAUSE A BOOK AND PAGE LEADS STRAIGHT TO THE
INSTRUMENT AND THE INSTRUMENT NAMES THE OWNER. THE COUNTY THOUGHT ABOUT THE INDIRECT PATH AND WE HAD NOT.
s.119.071(4)(d) protects the HOME ADDRESS of police, judges, prosecutors and firefighters. Our own scrub logic
withholds NAMES. IT DOES NOT WITHHOLD A BOOK AND PAGE THAT RESOLVES TO THE SAME NAME - and Palm Beach demonstrates
that the county considers that a leak.
"****" IS A FIFTH SPELLING OF ABSENCE, after 999, -9999, blank-not-null and OPEN WATER. It must never parse as a
book number and must never render.
AUDIT EVERY PATH THAT LEADS FROM A PROTECTED PARCEL TO AN IDENTITY, NOT JUST THE NAME FIELD. Book/page, instrument
number, deed chain, and the situs address itself are all such paths, and we serve several of them.

### 6. pctown IS A FRACTION IN POLK AND A PERCENTAGE IN VOLUSIA

`test` | authority: ISO 19152-1 fraction constraint | measured: 2026-08-16 | claude

polk_owners.pctown MEASURED: values 0.5, 1, 0.25, 0.3333, 0.3334 - AND ZERO ROWS ABOVE 1. It is a FRACTION.
volusia_cama_owner.PCTOWN: 447,845 of 483,754 rows carry 100. It is a PERCENTAGE.
SAME COLUMN NAME, SAME CONCEPT, DIFFERENT SCALE, TWO COUNTIES. Any code summing or comparing pctown across counties
is out by a factor of 100.
AND 38,134 OF 676,232 POLK OWNER ROWS CARRY pctown = 0. A named owner holding zero percent - which is either a
lienholder, a life-estate remainderman, a trustee, or a data defect, AND THE COLUMN CANNOT SAY WHICH. Never render 0%
as an ownership share.
ALSO 265,325 ROWS AT EXACTLY 1 AGAINST 676,232 TOTAL - so most parcels have a single 100% owner and the fractions are
the minority, which is why a naive read of the first row looks clean.
THE POLK FRACTIONS ARE ISO-CONFORMANT (numerator <= denominator) AND THE VOLUSIA PERCENTAGES ARE NOT - which is the
LA_GroupParty case, already ruled: both are held unchanged, the model differs per tenancy code.

## 24-containment

### 1. ST_PointOnSurface, NEVER ST_Centroid - 68 OF 4,000 CENTROIDS FALL OUTSIDE THEIR OWN PARCEL

`test` | authority: PostGIS ST_PointOnSurface; Paul Ramsey, PostGIS Overlays | measured: 2026-08-16 | claude

MEASURED ON parcels_staging, 4,000 random rows:
  multipart geometries                       46
  CENTROID FALLS OUTSIDE ITS OWN PARCEL      68   (1.7%)
  ST_PointOnSurface falls outside             0
THE CENTROID FAILURE COUNT EXCEEDS THE MULTIPART COUNT, so it is not only fragmented parcels - A CONCAVE LOT DOES IT
TOO. An L-shaped parcel has its centroid in the notch, which may belong to a neighbour.
WITH 97,380 FRAGMENTED PARCELS STATEWIDE, A CENTROID PROBE SILENTLY TESTS THE WRONG PLACE ON EXACTLY THE PARCELS MOST
LIKELY TO BE INTERESTING - the stacked condos, the split lots, the odd-shaped waterfront.
ST_PointOnSurface IS GUARANTEED INSIDE THE POLYGON. Paul Ramsey uses it for overlay counting for this reason. It costs
nothing extra and removes a 1.7% silent error from every containment test.
AND THE ERROR IS SILENT IN THE WORST DIRECTION: a centroid landing in a neighbour parcel returns a REAL INTERSECTION
with a REAL layer - a flood zone, a wetland - for the WRONG PARCEL. Not a null, a confident wrong answer.

### 2. A SPARSE LAYER NEEDS THE PROBE INVERTED, AND CC MEASURED THAT BEFORE I THOUGHT OF IT

`test` | measured: 2026-08-16 | cc

fl_erp_conservation_easements IS 687 POLYGONS STATEWIDE. CC drew 200 random parcels and got 0.00% - AND CORRECTLY
CALLED IT UNDERPOWERED RATHER THAN A FAILURE. 687 polygons across 10.7M parcels: the expected hit rate on a
200-parcel draw is effectively zero, so the test had no power to detect anything.
THEY INVERTED IT - DRAW FROM THE LAYER, TEST AGAINST PARCELS - and got 149 of 150. Verdict PASS_LAYER_SIDE, which
records WHICH DIRECTION WAS USED.
THE RULE: WHEN THE LAYER IS SPARSE RELATIVE TO THE PARCEL POPULATION, PROBE FROM THE LAYER. A zero from an
underpowered draw is indistinguishable from a zero from a broken join, and only the direction of the draw tells you
which you are looking at.
AND TILING_COVERAGE IS THE OPPOSITE PROBLEM: fgs_sinkhole_types contains EVERY parcel probed. Not a defect - a
susceptibility classification tiles the state by design - BUT THE LAYER CANNOT DISCRIMINATE, so the displaced control
is the only evidence the join works at all. Recorded as its own verdict rather than passed silently.

### 3. ONE SHARED PROBE SET, STRATIFIED - AND TWO OF MY OWN DESIGNS FAILED FIRST

`test` | measured: 2026-08-16 | claude

THE CONTAINMENT SWEEP TIMED OUT EVERY BATCH BECAUSE IT REDREW PARCELS PER LAYER. Fixed by materialising ONE probe
set: probe_points, 335 points, 5 per county across ALL 67, with both displaced controls precomputed.
TWO FAILURES ON THE WAY, BOTH MINE:
 1. TABLESAMPLE 0.01% DREW 300 POINTS FROM ONLY TEN COUNTIES. TABLESAMPLE IS NOT GEOGRAPHICALLY REPRESENTATIVE, and
    on a table clustered by county it is badly so. A statewide layer would have been graded on a tenth of the state
    and a REGIONAL layer could score 0% purely because no probe landed in its region.
 2. row_number() OVER (PARTITION BY co_no) over 10.7M rows TIMED OUT. Replaced with a per-county loop of indexed
    LIMIT 5 reads.
RESULT: 335 points, all 67 counties, one index scan per layer. 79 layers proved in three batches where single-layer
runs had been timing out.
AND THE SWEEP CONFIRMED CC UNDERPOWERED FINDING AT SCALE: 52 LAYERS RETURNED 0 OF 335 PARCEL-SIDE AND ALL BUT TWO
CAME BACK PASS_LAYER_SIDE AT 61.7% OR BETTER. FIFTY OF FIFTY-TWO ZEROS WERE UNDERPOWERED, NOT BROKEN. A zero from a
sparse layer is the normal case, not the exception.
TRADE-OFF RECORDED: a fixed set cannot detect a layer that misses these 335 parcels but covers others. Re-draw
periodically, and never call a layer empty on the parcel-side test alone.

### 4. A POINT LAYER IS A PROXIMITY LAYER AND ST_Intersects IS THE WRONG PREDICATE

`test` | measured: 2026-08-16 | claude

TWO LAYERS RETURNED ZERO IN BOTH DIRECTIONS: bay_sinkhole_incidents AND brevard_sinkhole_incidents.
BOTH ARE ST_MultiPoint, WITH 2 AND 4 ROWS. A POINT INTERSECTS A PARCEL ONLY IF IT LANDS EXACTLY INSIDE ONE, so the
containment test was asking a question the geometry cannot answer - AND NEITHER ZERO WAS A FAILURE.
RE-TESTED WITH ST_DWithin: BAY 2 OF 2 AND BREVARD 4 OF 4 RESOLVE TO A PARCEL WITHIN ROUGHLY A KILOMETRE. Verdict
PASS_PROXIMITY.
THE PREDICATE MUST MATCH THE GEOMETRY TYPE. Polygon layers answer containment. POINT LAYERS ANSWER DISTANCE. Line
layers answer perpendicular distance and adjacency - which the NHD findings already said in a different context:
"collapsing all three into nearest water rebuilds the existing defect in a bigger layer".
CHECK ST_GeometryType BEFORE CHOOSING THE PREDICATE. I ran 79 layers through a polygon test without once asking what
shape they were, and it only surfaced because two of them were small enough that the answer was obviously wrong.

### 5. CONFIRMED TO CC - A PROXIMITY PASS IS NOT A CONTAINMENT JOIN AND THE RADIUS MUST BE STORED

`rule` | measured: 2026-08-16 | cc

CC ASKED BEFORE RUNNING 830 BATCHES, WHICH WAS RIGHT. THEIR OBJECTION: "a fire station within 0.3 mi" is a DIFFERENT
FACT from "this parcel is inside a fire district", so if point layers pass by distance the radius must be recorded and
the verdict must read PASS_PROXIMITY - otherwise the shelf claims a containment join that does not exist.
CONFIRMED, AND IT IS ALREADY BUILT THAT WAY: probe_layer_typed reads ST_GeometryType, points and lines get ST_DWithin,
polygons get ST_Intersects, and the verdict is PASS_PROXIMITY not PASS. Added radius_deg so the distance is on the row
rather than in the function body.
AND THE DISTINCTION CC IS PROTECTING GOES FURTHER THAN THE VERDICT NAME: 0.02 DEGREES IS A VERIFICATION RADIUS, NOT A
REPORTING RADIUS. It exists to prove the layer and the parcel are in the same place. IT SAYS NOTHING ABOUT WHAT
DISTANCE IS MATERIAL TO A BUYER, and a served proximity finding must carry its own measured per-parcel distance.
36 PASS_PROXIMITY rows now carry radius_deg 0.02.

### 6. A VERIFICATION RADIUS MUST SCALE WITH LAYER SPARSITY - FOUR MORE ZEROS WERE THE RADIUS, NOT THE DATA

`test` | measured: 2026-08-16 | claude

FOUR LAYERS RETURNED ZERO IN BOTH DIRECTIONS AT 0.02 DEGREES (~2.2km): charlotte_sinkhole_incidents (5 rows),
gadsden_brownfield_areas (1 row), franklin_sinkhole_incidents (1), hendry_sinkhole_incidents (1).
ALL FOUR RESOLVE AT 0.05 DEGREES (~5.5km). MEASURED PARCELS WITHIN THAT RADIUS:
  charlotte_sinkhole   178,618 parcels near FIVE POINTS
  gadsden_brownfield     7,740 near a SINGLE 3,963-ACRE DESIGNATED AREA
  hendry_sinkhole        3,448      franklin_sinkhole  2,141
A LAYER OF ONE FEATURE CANNOT BE FOUND BY 335 PROBE POINTS AT 2 KM, AND THAT SAYS NOTHING ABOUT THE DATA. The zero was
a property of my radius.
THIS IS THE UNDERPOWERED PATTERN A THIRD TIME, IN A THIRD FORM: first the parcel-side draw against a sparse layer,
then the predicate wrong for the geometry type, now THE RADIUS TOO TIGHT FOR THE FEATURE COUNT.
ALL THREE HAD THE SAME SIGNATURE - A CLEAN ZERO - AND THREE DIFFERENT CAUSES. A zero is never self-explaining.
gadsden_brownfield_areas IS THE ONE THAT MATTERS: A SINGLE POLYGON OF 3,963 ACRES WITH 7,740 PARCELS WITHIN 5KM. One
row is not a small finding; it is a large designated area recorded once.

## 25-fanout

### 1. MY HARNESS COUNTED JOIN ROWS, NOT MATCHED KEYS - A FAN-OUT WAS INDISTINGUISHABLE FROM A GOOD KEY

`correction` | measured: 2026-08-16 | cc

CC FOUND IT: miamidade_geoaddress RETURNED 3,079 FROM A 3,000-ROW SAMPLE. Over 100%, which is what made it visible.
THE SAME FAN-OUT AT 60% WOULD HAVE READ AS 75% AND PASSED SILENTLY.
MEASURED AFTER THE FIX, polk_sales:
  OLD READING   3,836 of 3,000
  TRUE READING  434 MATCHED OF 440 DISTINCT KEYS, 2,977 JOIN ROWS - A 6.8x FAN-OUT
The rate was right by accident (98.6% versus 98.7%) and the DENOMINATOR WAS A FICTION. On a table where the fan-out
correlated with match failure the two errors would not have cancelled.
FIXED: matched is now count(DISTINCT source key), and the function returns distinct_keys AND fanout_rows so the
FAN-OUT IS VISIBLE RATHER THAN FOLDED INTO THE RATE.
RE-MEASURED 40 OF THE E0 VERDICTS: 38 HOLD at 87.5% or better with max fan-out 1.1x - the NAL and SDF families are
genuinely near-unique, so the damage is small. ONE returns a NON-ZERO CONTROL and one is 80% (E0_partial). The
remaining 133 are marked superseded=true and await re-measure - THEY ARE NOT E0 UNTIL THEY CARRY A v2 ROW.
THIS IS THE THIRD DEFECT CC HAS FOUND IN MY OWN HARNESS TODAY - after the control that could not fail and the
transform list that manufactured its own zeros. ALL THREE WERE IN THE INSTRUMENT, NOT THE DATA, AND ALL THREE WERE
INVISIBLE FROM INSIDE IT.
AND THE PATTERN IS NOW UNDENIABLE: I BUILT THE MEASURING DEVICE AND CHECKED THE DATA WITH IT INSTEAD OF CHECKING IT.

### 2. CC CLIFF IS THE COLUMN MAP, NOT THE KEY - AND MY OWN RESTORE CAUSED IT

`measurement` | measured: 2026-08-16 | cc

CC MEASURED THEIR 559 SPATIAL TABLES AS A SHELF:
  known what it is   263  47.0%
  + column map        12   2.1%   <- THE CLIFF
  + source            12   2.1%
  + join proved       10   1.8%
MINE DROPS AT THE KEY BECAUSE MY LANE HAS KEYS. THEIRS DROPS A STEP EARLIER, AND THE REASON IS MY RESTORE: 257 OF
THEIR 263 "KNOWN" ARE CLASSES I RESTORED FROM nr_final. A RESTORED CLASS TELLS YOU WHAT A TABLE IS AND NOTHING ABOUT
WHICH COLUMN ANSWERS WHAT.
So the restore moved 257 tables from UNREAD to known WITHOUT MOVING THEM ONE STEP CLOSER TO SERVABLE. That is real
progress on the catalogue and ZERO progress on the shelf, and reporting "known" without "mapped" would have hidden it.
AND CC SPLIT STEP 3, WHICH I HAD COLLAPSED: REGISTERED IS NOT REFRESHABLE. 5 of their 12 carry
source_url=NOT_ESTABLISHED. A row in data_source_registry with no usable URL is a TRACKED GAP, not a source. They
named it rather than inventing a URL from a pattern, which is the right call and the one I was tempted by on the 147
municipal layers.
SHELVED IS FOUR FACTS AND THE THIRD HAS TWO PARTS: known | mapped | REGISTERED AND REFRESHABLE | join proved.

### 3. CC FOURTH CORRECTION - A FAN-OUT FROM AN ARBITRARY SLICE IS A PROPERTY OF THE SLICE

`correction` | measured: 2026-08-16 | cc

lee_building_footprints: 1,127 DISTINCT KEYS FROM A 3,000-ROW DRAW - A 2.70x FAN-OUT - WHEN THE POPULATION FIGURE IS
1.11 BUILDINGS PER PARCEL.
THE HARNESS STILL USES limit 3000 WITH NO ORDER BY, SO THE SLICE LANDED ON CONDO COMPLEXES. The fan-out column
working is the fix; the DRAW is still arbitrary.
AND CC SAID THE CAVEAT APPLIES TO MY 80 RE-RUNS TOO. IT DOES. Every fan-out figure I recorded is slice-dependent, and
a slice that happens to land on a condo block reports a fan-out the table does not have - or misses one it does.
FOURTH CORRECTION CC HAS MADE TO THIS HARNESS TODAY: the vacuous control, the transform list that manufactured zeros,
the join-row count, and now the arbitrary slice. THE MATCH RATE IS SOUND BECAUSE IT IS A RATIO WITHIN THE SLICE. THE
FAN-OUT IS NOT, BECAUSE IT IS A PROPERTY OF THE POPULATION.
FIX: compute fan-out from the table, not the slice - count(*) / count(distinct key) over the whole table where it is
affordable, and label it as a slice figure where it is not.
AND CC KILLED THEIR OWN HYPOTHESIS BEFORE SPENDING A BATCH ON IT: they were going to argue presence-only layers need
no attribute map, MEASURED IT AT 2 OF 559, AND REPORTED THE FAILURE. That is the most valuable habit either of us has
shown today.

## 26-denominator

### 1. THE GOAL WAS MEASURED AGAINST THE WRONG DENOMINATOR - 1,655 SERVING CANDIDATES, NOT 2,115

`measurement` | measured: 2026-08-16 | cc

CC CHALLENGED THE ARITHMETIC RATHER THAN SPENDING A SESSION ON A ROUTE THEY THOUGHT WAS WRONG, AND THEY WERE RIGHT
TO. MEASURED:
  2,115  populated tables
     21  SYSTEM - our own registries, harnesses, snapshot tables
     41  SCRATCH AND PROFILING - nr_*, rr_*, ladm_map/three/tokens/ngrams, table_column_signature, daily_table_rowcounts
      1  quarantined by rename
  1,655  SERVING CANDIDATES
THE 41 SCRATCH TABLES ARE THE ABANDONED CLASSIFICATION ATTEMPTS AND THE PROFILE TABLES. THEY ARE INSTRUMENTS, NOT
DATA. Shelving them would mean proving a parcel join on a table of table names.
SO THE TARGET IS A FRACTION OF 1,655, AND ANY NUMBER QUOTED AGAINST 2,115 UNDERSTATES PROGRESS BY 22% WHILE ALSO
IMPLYING WE MUST SHELVE OUR OWN TOOLING.
AND CC IS RIGHT THAT READING EACH TABLE WILL NOT GET THERE: 468 of their 559 are SINGLETONS across 495 distinct
signatures. FDEP-17 was not a template, it was the LARGEST FAMILY THEY HAVE - the next is six.

### 2. RULING ON CC THREE PROPOSALS - ONE REJECTED AS UNNECESSARY, TWO ACCEPTED WITH CONDITIONS

`rule` | measured: 2026-08-16 | claude

(a) LOWER THE BAR FOR EXT_Context - REJECTED, AND NOT BECAUSE IT IS DISHONEST. BECAUSE IT IS UNNECESSARY.
MEASURED, AVERAGE COLUMN-MAP ROLES WHERE MAPPED:
  EXT_Context     702 tables, 534 MAPPED, 1.5 ROLES AVERAGE
  EXT_Regulatory  329 tables, 281 mapped, 1.4
  SP_PlanUnit     211 tables, 170 mapped, 1.4
  VM_ValuationUnit 119 tables, 109 mapped, 7.4
THE BAR IS ALREADY ONE-OR-TWO ATTRIBUTES FOR EVERY CONTEXT AND REGULATORY CLASS, AND 534 OF 702 EXT_Context ARE
ALREADY MAPPED. There is nothing to lower. A school still needs its NAME - "something 0.3 miles away" serves nothing -
and a name is one role, which is why the average is 1.5 and not 7.4.
(b) DERIVE MAPS FROM nr_content - ACCEPTED, WITH ONE CONDITION THAT IS NOT NEGOTIABLE.
The seven reading tests ARE mechanisable from top_values: n_distinct=1 is a sentinel, =row count is an identifier,
2-50 distinct text is a classification, a leading-numeric domain is a composite. That is a genuine CONTENT read
because top_values IS the value domain.
CONDITION: HAND-CHECK A SAMPLE AND MEASURE THE ERROR RATE BEFORE APPLYING IT AT SCALE. Take 30 tables the machine
proposes, read them properly, and report how many it got right. If the machine is wrong 1 in 5 that is 300 wrong
maps and worse than none. WE HAVE NO IDEA WHAT THE RATE IS AND EVERY OTHER HEURISTIC TODAY MISSED SOMETHING -
nr_keys flagged ogc_fid, my filter picked "parcel" over "parcel_id" on polk_buildings.
Mark every one machine_proposed. E2 CEILING. Never E0.
(c) ACCEPT THAT SOME TABLES SHOULD NOT BE SHELVED - ACCEPTED. That is the 62 above and CC 243 in neither registry
averaging 405 rows. A table nothing will ever serve does not need a proved join; it needs a disposition.

## 27-versioning

### 1. I BROKE MY OWN TRACEABILITY RULE ON MY OWN REGISTRY, ALL DAY, AND THE STANDARD NAMES IT

`correction` | authority: ISO 19152-1:2024 clause 6, VersionedObject | measured: 2026-08-16 | claude

ISO 19152-1 VersionedObject: beginLifespanVersion, endLifespanVersion [0..1], quality, source (CI_ResponsibleParty).
EVERY LA_ AND VM_ AND SP_ CLASS INHERITS FROM IT. The standard, clause 6: "VERSIONING REQUIRES THAT INSERTED AND
SUPERSEDED DATA BE GIVEN A TIMESTAMP. IN THIS WAY THE CONTENTS OF THE DATABASE CAN BE RECONSTRUCTED AS THEY WERE AT
ANY HISTORICAL MOMENT." And: "TIMESTAMPS ARE LINKED TO ALL CONTENTS VIA LA_VersionedObject ... ALL DATA ARE KEPT,
ALSO AFTER DELETION."
MEASURED: ladm_declaration HAD ZERO VERSIONING COLUMNS. I ran DOZENS OF UPDATE STATEMENTS AGAINST IT TODAY -
reclassifying polk_sales out of amenity, correcting volusia_cama_permits to SP_Permit, restoring 257 rows through
legacy_class, promoting grades - AND EVERY PRIOR STATE IS GONE.
legacy_class PRESERVED THE OLD CLASS AND NOTHING ELSE. Not the old rationale, not the old grade, not when it changed,
not who changed it.
I WROTE "HOLD DATA COMPLETE AND UNCHANGED - THE SNAPSHOT IS THE LIABILITY PROTECTION" AND APPLIED IT ONLY TO SOURCE
DATA. MY OWN REGISTRY IS THE AUDIT TRAIL AND I OVERWROTE IT ALL DAY.
FIXED: begin_lifespan_version, end_lifespan_version, begin_real_world_version, source_responsible_party added to
ladm_declaration; begin/end added to lens and END BACKFILLED FROM superseded_by - the lens had a supersession POINTER
but no TIMESTAMP, so it could say WHAT replaced a rule and never WHEN.
STANDING RULE: A CORRECTION ENDS THE OLD VERSION AND INSERTS A NEW ONE. IT NEVER UPDATES IN PLACE.
That is the fifth instrument defect of the day and the first one I found myself.

### 2. THE 2024 EDITION IS BI-TEMPORAL AND THE SPEC as_of FIELD IS TWO FIELDS

`correction` | authority: ISO 19152-1:2024 bi-temporal VersionedObject | measured: 2026-08-16 | claude

ISO 19152-1:2024 ADDED A SECOND SET OF TEMPORAL ATTRIBUTES TO VersionedObject AND TO LA_Source:
  beginLifespanVersion / endLifespanVersion        SYSTEM TIME - when the record entered our database
  beginRealWorldLifespanVersion / end..., acceptance  REAL-WORLD TIME - when the fact became true
WITH CONSTRAINTS REQUIRING THE TWO TO CORRESPOND. And beginLifespanVersion multiplicity changed from mandatory [1] to
optional [0..1] with initial value "realWorldTime".
THAT IS EXACTLY THE PROBLEM PIR_REPORT_SPEC_v5 PART D DESCRIBES AND COLLAPSES INTO ONE FIELD. The DOR roll is a
1 JANUARY snapshot - real-world time - that we LOADED IN JULY - system time. The spec says "as_of is the winning
branch date, per field" and treats it as ONE value. THE STANDARD SAYS IT IS TWO, AND THE DISTINCTION IS THE WHOLE
STALENESS ARGUMENT: a value 19 months stale in the real world may have been loaded yesterday.
CONSEQUENCE FOR THE REPORT: "Owner of record - Florida DOR 2025 certified roll, as of January 1, 2025" IS THE
REAL-WORLD DATE AND IS CORRECT. But a reader asking "how fresh is your data" is asking the SYSTEM date, and we
currently cannot answer both from one field.
ADDED begin_real_world_version TO ladm_declaration. THE SAME SPLIT IS NEEDED IN data_source_registry AND IN THE FACT
INDEX, AND THAT IS A SPEC CHANGE, NOT A REGISTRY ONE - flagged, not made.

## 28-sweep

### 1. THE PREDICATE MUST MATCH THE GEOMETRY TYPE, AND 12 LAYERS PROVED IT IN ONE BATCH

`test` | measured: 2026-08-16 | claude

probe_layer_typed NOW READS ST_GeometryType BEFORE CHOOSING THE PREDICATE. Points and lines get ST_DWithin; polygons
get ST_Intersects. Records gtype and predicate on every row so the choice is auditable.
IN THE FIRST BATCH AFTER THE FIX: 12 LAYERS CAME BACK PASS_PROXIMITY - layers the polygon test would have recorded as
failures. A POINT INTERSECTS A PARCEL ONLY IF IT LANDS EXACTLY INSIDE ONE, so ST_Intersects asks point and line
geometry a question it cannot answer.
I HAD ALREADY RUN 79 LAYERS THROUGH A POLYGON TEST WITHOUT ONCE ASKING WHAT SHAPE THEY WERE. It surfaced only because
two of them held 2 and 4 rows and the answer was obviously wrong.
AND THE UNDERPOWERED PATTERN HELD AGAIN: of 28 parcel-side zeros across two batches, 27 CAME BACK PASS_LAYER_SIDE.
ONE REMAINS ZERO IN BOTH DIRECTIONS and is a genuine finding rather than a method artefact.

### 2. THE PARCEL-SIDE ZERO IS EVIDENCE AND MUST SURVIVE THE INVERSION

`rule` | authority: ISO 19152-1 VersionedObject | measured: 2026-08-16 | claude

I HAD BEEN UPDATING THE ZERO ROW TO PASS_LAYER_SIDE IN PLACE. That destroys the finding that the layer IS SPARSE -
which is a real property of the data and the reason the inversion was needed.
NOW, PER THE LADM VersionedObject RULE I RULED ONE TURN AGO: the layer-side result is INSERTED as its own row, and the
parcel-side row gets end_lifespan_version SET AND verdict SUPERSEDED_BY_LAYER_SIDE. BOTH SURVIVE.
28 SUPERSEDED ROWS NOW RETAINED. Before this, each inversion silently erased the measurement that justified it.
THE GENERAL FORM: WHEN A SECOND METHOD SUCCEEDS WHERE A FIRST FAILED, THE FIRST RESULT IS NOT AN ERROR TO OVERWRITE -
IT IS THE EVIDENCE THAT THE SECOND METHOD WAS NECESSARY. That applies to the flood column corrections, the key
transforms, and every reclassification made today.

### 3. THE UNDERPOWERED RATE IS THE FINDING, NOT THE EXCEPTION - 72 OF 73 PARCEL-SIDE ZEROS RECOVERED

`measurement` | measured: 2026-08-16 | claude

THREE BATCHES OF THE TYPED SWEEP, RUNNING AT 45 LAYERS EACH:
  PASS (polygon, parcel-side)          plus
  PASS_PROXIMITY (point/line, DWithin)       36
  PASS_LAYER_SIDE (inverted after a zero)
  SUPERSEDED_BY_LAYER_SIDE retained          72
  ZERO_BOTH_DIRECTIONS                        1
SEVENTY-TWO OF SEVENTY-THREE PARCEL-SIDE ZEROS RECOVERED ON INVERSION. ONE DID NOT.
THAT RATIO IS THE FINDING. A PARCEL-SIDE ZERO IS NOT WEAK EVIDENCE OF A BROKEN LAYER - IT IS STRONG EVIDENCE THAT THE
LAYER IS SPARSE, and the base rate is 99%. Any process that reads a parcel-side zero as a failure would have
quarantined 72 working layers.
CC ESTABLISHED THIS ON ONE TABLE - fl_erp_conservation_easements, 687 polygons statewide, 0.00% parcel-side, 149 of 150
layer-side. THE SWEEP CONFIRMS IT AS A GENERAL PROPERTY OF THE LIBRARY, not a property of that table.
AND THE ONE THAT STAYED ZERO IS NOW WORTH INVESTIGATING PRECISELY BECAUSE THE BASE RATE IS SO HIGH.
36 PASS_PROXIMITY IS THE OTHER HALF OF THE SAME LESSON: those are point and line layers that the polygon predicate
would have recorded as failures, and they are 12% of everything swept so far.

### 4. SHELF STATE AGAINST THE CORRECTED DENOMINATOR

`measurement` | measured: 2026-08-16 | claude

  1,656  SERVING CANDIDATES  (2,115 populated less 21 SYSTEM, 41 scratch/profiling, 1 quarantined)
  1,320  + column map                                       79.7%
    995  + REFRESHABLE source (not merely registered)       60.1%
    242  SHELVED - join proved                              14.6%
    331  joins proved on any table
THE REFRESHABLE STEP LOSES 325 TABLES AND THAT IS CC DISTINCTION, NOT A NEW ONE: a registry row carrying
NOT_ESTABLISHED or UNCONFIRMED is a TRACKED GAP, NOT A SOURCE. Those 325 are catalogued, joinable, and cannot be
refreshed - which for a monthly-refresh product is a real disqualification and not a bookkeeping detail.
THE GAP TO THE GOAL IS THEREFORE TWO GAPS, NOT ONE:
  753 tables mapped and refreshable, JOIN NOT YET PROVED   <- the sweep is closing this at ~45 a batch
  325 tables mapped, SOURCE NOT REFRESHABLE                <- needs endpoint recovery, not verification
  336 tables not yet mapped
THE SWEEP CANNOT FIX THE 325. That is the 31-county DCAT enumeration and the Pinellas/Polk download URLs - Murphy WSL
work, already on the open list, and it is now the second-largest single blocker after the unmapped 336.

## 29-datacenter

### 1. THREE REGISTERS INDEPENDENTLY CONFIRM THE PROJECT TANGO SITE - AND THIS IS THE MOAT WORKING, NOT A COINCIDENCE

`measurement` | authority: DOR NAL roll; FDEP MMP_MANNON layer 15; floridadatacenters.org (tier 4 lead only) | measured: 2026-08-16 | claude

floridadatacenters.org SAYS: Project Tango, 202 acres, developer PBA Holdings, denied 5-1 on 15 July 2026 WITHOUT
PREJUDICE, on former Palm Beach Aggregates land, adjacent to FPL West County Energy Center.
THAT SITE IS A TIER 4 SOURCE - internet, advocacy, sells t-shirts and $9.99 letters. Per PIR_REPORT_SPEC_v5 Part 0.2
IT MAY NEVER BE A RECORD FACT AND NEVER A CORROBORATOR. It is a LEAD.
SO I CHECKED THE LEAD AGAINST TWO REGISTERS WE HOLD:
 FISCAL REGISTER (DOR roll, parcels_staging co_no 60):
   own_name PBA HOLDINGS INC - 20 PARCELS, 321.2 ACRES, six addresses on STATE ROAD 80 including 20125
   SIX PARCELS AT dor_uc 092. Verified from pasco_cama_parcel: 092 = "Ming/Pet/Gaslnd" - MINING, PETROLEUM, GAS LANDS.
   One at 095 Rivers/Lakes - the mine pit water. Two at 010 Vacant Comm. One at 000 Vacant.
 REGULATORY REGISTER (FDEP MMP_MANNON layer 15, non-phosphate released mines 2024):
   15 OF 20 PARCELS INTERSECT IT. Attributes: MINE_NAME "Palm Beach Aggregates Mine", MINE_OPERATOR "Palm Beach
   Aggregates Inc.", RELEASE_DATE 01/01/2004, GIS_ACREAGE 3172, PARTIAL_RELEASE 2, SITE_ID 142832.
THREE SOURCES, THREE LINEAGES, ONE FACT. The advocacy site said "former Palm Beach Aggregates land"; the tax roll says
mining use code; FDEP names the operator and dates the release. NONE OF THE THREE DERIVES FROM THE OTHERS.
AND THE ADVOCACY SITE IS WRONG ON ONE MEASURABLE POINT, WHICH IS WHY THE CHECK MATTERS: THE APPLICATION WAS 202 ACRES
AND THE ASSEMBLED HOLDING IS 321.2. The parcel recorded in my own memory as "the Project Tango parcel" is 10.8 ACRES -
ONE OF TWENTY. Reading it alone would have described a tenth of the site.
RELEASE_DATE 2004 MEANS THE RECLAMATION OBLIGATION WAS DISCHARGED, NOT THAT IT NEVER EXISTED. Per the established
rule: released is a HISTORY fact, not a live restriction. The honest finding is "this land was a mine and FDEP
released it in 2004", never "this land is subject to reclamation".

### 2. A DATA CENTER PROPOSAL IS A PROXIMITY RESTRICTION WE CAN ALREADY ANSWER, AND ONE WE CANNOT

`open` | authority: SB 484 Ch.2026-65; SB 180; floridadatacenters.org as lead | measured: 2026-08-16 | claude

WHAT THE SITE TRACKS, ALL OF IT CHECKABLE AGAINST PRIMARY RECORDS:
  8 counties with active or proposed hyperscale projects | 38M sq ft proposed | $20B+ announced
  19 FLORIDA JURISDICTIONS WITH A MORATORIUM OR BAN - 16 temporary, 3 permanent
  SB 484, Chapter 2026-65, signed 7 May 2026, EFFECTIVE 1 JULY 2026 - bars utilities shifting data centre
    infrastructure cost to residential ratepayers, PRESERVES LOCAL ZONING AUTHORITY, and ALLOWS STATE AGENCY NDAs
    FOR UP TO 12 MONTHS
  SB 180, the post-hurricane recovery law, BARS NEW DEVELOPMENT MORATORIUMS UNTIL 1 OCTOBER 2027 - which is why
    Hillsborough could not pass one after directing staff to draft it on 5 August 2026
WHAT WE CAN ALREADY ANSWER FROM OUR OWN DATA: the parcel, the owner, the assembled acreage, the mining history, the
FDEP release date, the adjacency to an FPL generating site, and the use codes. That is a proximity finding a buyer
in Arden - 2,300 homes and a new elementary school - would want and cannot get anywhere else.
WHAT WE CANNOT ANSWER AND MUST NOT PRETEND TO: THE MORATORIUM STATUS OF A COUNTY. Nineteen jurisdictions, every one an
ordinance with an EXPIRATION DATE, and three permanent. WE HOLD NO MORATORIUM TABLE - zero tables match
moratorium/datacenter. A moratorium is a live LA_RRR on development rights and its absence from our registry is a
coverage gap, not a negative.
AND SB 180 IS THE FINDING NOBODY WOULD LOOK FOR: A STORM-RECOVERY STATUTE PRE-EMPTING LOCAL DEVELOPMENT MORATORIUMS
UNTIL OCTOBER 2027. That is a state-law restriction on a county power, and it changes what a county CAN do rather than
what a parcel IS - a class of fact restriction_authority does not currently model.

### 3. EVERY ONE OF THE FOUR DATA CENTRE SITES I COULD LOCATE CARRIES RESTRICTION DATA - AND THE STATEWIDE FLOOD LAYER SAID ZERO ON ALL FOUR

`measurement` | authority: DOR NAL roll; county NFHL layers; FDEP; floridadatacenters.org as lead only | measured: 2026-08-16 | claude

MURPHY ASKED HOW MANY OF THE TRACKED SITES HAVE RESTRICTION LAYERS. FOUR LOCATED BY OWNER NAME IN OUR OWN ROLL, AND
ALL FOUR CARRY AT LEAST ONE:
  PALM BEACH / Project Tango   PBA HOLDINGS INC, 20 parcels, 321.2 ac
    wetlands 5 | conservation 6 | MINE RELEASED 15 | sinkhole class 20 | FLOOD AE, AO, X
  MARTIN / Tesoro Groves       FLORIDA POWER & LIGHT COMPANY, 62 parcels, 22,361 ac
    wetlands 20 | conservation 14 | sinkhole class 62 | FLOOD AE, X
  OKEECHOBEE / Okee-One        INDIAN RIVER STATE COLLEGE TRU, 1 parcel, 206 ac (reported 205)
    wetlands 1 | DRASTIC aquifer 1 | sinkhole class 1 | FLOOD A, AE, X
  ST LUCIE / Sentinel Grove    Epic Estates 68 LLC, 3 parcels, 1,218 ac - EXACTLY THE REPORTED FIGURE
    wetlands 1 | sinkhole class 3 | flood X only
*** AND HERE IS THE FAILURE THAT MATTERS MORE THAN THE FINDING ***
I FIRST TESTED FLOOD AGAINST nfhl_flood_zones, THE STATEWIDE LAYER. IT RETURNED ZERO INTERSECTIONS ON ALL FOUR SITES -
NOT ZERO SFHA, ZERO CONTACT WITH ANY ZONE AT ALL, INCLUDING X.
HAD I READ THAT AS "not in a flood zone" I WOULD HAVE CLEARED FOUR SITES, THREE OF WHICH TOUCH AE, AO OR A. THAT IS
THE ST PETERSBURG FAILURE EXACTLY, WITH ME AS THE ONE MAKING IT, ON THE HIGHEST-PROFILE PARCELS IN THE STATE.
ALL FOUR COUNTIES HOLD THEIR OWN LAYER - palmbeach_flood_zones 31,305 rows, martin 3,289, okeechobee 615,
stlucie_flood_zones_2020 2,895 - AND AGAINST THE CORRECT LAYER EVERY PARCEL OF ALL FOUR SITES IS COVERED, 86 OF 86.
RULING 245 SAID FLOOD IS A CONTAINMENT CONCEPT RESOLVED PER COUNTY. I WROTE IT AND THEN QUERIED THE STATEWIDE LAYER
DIRECTLY BECAUSE IT WAS ONE TABLE INSTEAD OF FOUR. THE RESOLVER EXISTS TO STOP EXACTLY THAT.
NEVER QUERY A STATEWIDE LAYER DIRECTLY WHEN A PER-COUNTY RESOLVER EXISTS. Zero from the wrong layer is
indistinguishable from zero from the right one.

### 4. THE OWNER NAME IS THE HANDLE, AND FOUR OF EIGHT SITES DID NOT RESOLVE

`measurement` | measured: 2026-08-16 | claude

FOUND BY OWNER NAME IN parcels_staging: PBA HOLDINGS INC | Epic Estates 68 LLC (1,218 ac, EXACT MATCH TO THE REPORTED
FIGURE) | INDIAN RIVER STATE COLLEGE TRU (206 ac against 205 reported) | FLORIDA POWER & LIGHT COMPANY.
NOT FOUND: Stonebridge (Fort Meade) - only HOAs of that name in Polk | NextNRG (Nassau) | Atlas Compute (St Lucie) |
Deltona Corp resolves to 2,675 parcels and 3,522 acres, which is a LAND-BANKING PORTFOLIO, not the ~1,400-acre
application - the application parcels cannot be isolated by owner alone.
WHY THE MISSES ARE STRUCTURAL AND NOT A DATA FAULT: THE DOR ROLL IS A 1 JANUARY SNAPSHOT. A 2026 assemblage does not
appear until the following roll, and a developer under contract is not the owner of record. Atlas Compute has
"obtained zoning verification" and filed no application - THERE MAY BE NOTHING TO OWN YET.
THAT IS THE 19-MONTH STALENESS ARGUMENT WITH A CONSEQUENCE: THE FISCAL REGISTER CANNOT SEE A SITE ASSEMBLY IN
PROGRESS, WHICH IS EXACTLY WHEN A NEIGHBOUR WOULD WANT TO KNOW. The juridical register can - a deed is recorded within
days - and we hold it for one county.
AND I MADE TWO MORE HAND-WRITTEN co_no ERRORS FINDING THESE: ST LUCIE IS 66 AND I USED 56; OKEECHOBEE IS 57 AND I USED
47. Both returned empty and both looked like "no such site". NINTH AND TENTH INSTANCE TODAY.

## 30-heuristic

### 1. THE nr_content HEURISTIC FAILED THE GATE AT 46.7% AND THE FAILURE CLASSES ARE THE VALUE

`test` | measured: 2026-08-16 | cc

I APPROVED MECHANISED COLUMN MAPS SUBJECT TO ONE CONDITION: HAND-CHECK 30 AND REPORT THE ERROR RATE. CC DID. 14 OF 30
WRONG - 46.7% AGAINST A 1-IN-5 BAR. AT 283 TABLES THAT IS ~130 WRONG MAPS. NOT SCALED.
FOUR FAILURE CLASSES, EACH A STANDING WARNING:
 1 OUR OWN INGEST METADATA SCORES PERFECTLY. sjrwmd_wells -> retrieved_at: a LOAD TIMESTAMP, 5 distinct, 0 nulls, a
   flawless classification by every numeric test. WE BUILT THAT COLUMN AND THE HEURISTIC CANNOT TELL IT FROM DATA.
 2 EDITOR PROVENANCE TOO. pinellas_municipal_boundary -> int_created_user, values EGIS and misspf0.
 3 A ROUNDED COORDINATE IS LOW-CARDINALITY. lee_bus_stops -> stop_lat (26.6 | 26.7 | 26.5). A LATITUDE proposed as
   what a bus stop IS.
 4 AND THE DANGEROUS ONE: marion_transitional_flood_prone -> flood_elevation, values -99999 and -9999. TWO DISTINCT,
   ZERO NULLS, AND THE NAME MATCHES "elevation" ON A FLOOD-PRONE LAYER. 100% SENTINEL. IT WOULD HAVE BEEN MAPPED AS A
   FLOOD ELEVATION - A FABRICATION SURFACE, NOT A BAD MAP, and the same shape as the elevation figure the spec records
   as fabricated seven times with escalating false precision.
THE RULING CC ARRIVED AT: WHAT A TABLE IS FOR IS NOT IN ITS STATISTICS. palmbeach_daycares -> user_facility_size when
a daycare answer is its NAME; stlucie_address_master -> status when an address register answer is the ADDRESS. NO
TUNING FIXES THAT, because purpose is not a distribution.
THE ONE SALVAGEABLE SIGNAL: EVERY CORRECT PROPOSAL SHARED A STEM BETWEEN COLUMN AND TABLE NAME - zoning to zone_code,
listings to restype, waterbodies to code. THE STEM MATCH WAS DOING THE WORK, NOT THE CARDINALITY. Restricting to that
subset and gating again is the only route, and a second reject would be the right outcome.
AND THE PROCESS POINT MATTERS AS MUCH AS THE RATE: CC TESTED 30 BEFORE 283 AND REPORTED A FAILURE THAT COST THEM A
BATCH. That is the second time today they killed their own proposal with a measurement.

### 2. A ZERO IS NEVER SELF-EXPLAINING - THREE CAUSES, ONE SIGNATURE

`principle` | measured: 2026-08-16 | claude

THE UNDERPOWERED ZERO HAS NOW APPEARED IN THREE FORMS AND EVERY ONE PRODUCES AN IDENTICAL CLEAN ZERO:
 1 SPARSE LAYER, PARCEL-SIDE DRAW. CC found it on fl_erp_conservation_easements - 687 polygons statewide, 0.00% from
   200 parcels, 149 of 150 layer-side. MEASURED AT SCALE: 108 OF 112 PARCEL-SIDE ZEROS RECOVERED ON INVERSION.
 2 WRONG PREDICATE FOR THE GEOMETRY TYPE. ST_MultiPoint against ST_Intersects - a point intersects a parcel only if it
   lands exactly inside one. 73 layers recovered with ST_DWithin.
 3 RADIUS TOO TIGHT FOR THE FEATURE COUNT - new this turn. Four layers zero at 0.02 deg, ALL FOUR RESOLVE AT 0.05:
     charlotte_sinkhole   5 rows -> 178,618 parcels within 5km
     gadsden_brownfield   1 ROW  ->   7,740 parcels, AND IT IS A 3,963-ACRE DESIGNATED AREA
     hendry_sinkhole      1      ->   3,448
     franklin_sinkhole    1      ->   2,141
   A LAYER OF ONE FEATURE CANNOT BE FOUND BY 335 PROBE POINTS AT 2KM AND THAT SAYS NOTHING ABOUT THE DATA.
185 OF 189 ZEROS ACROSS THE THREE FORMS WERE METHOD, NOT DATA. THE BASE RATE OF A ZERO BEING REAL IS ABOUT 2%.
SCALE THE RADIUS WITH SPARSITY, MATCH THE PREDICATE TO THE GEOMETRY, AND INVERT THE DRAW BEFORE RECORDING ANY ZERO.
AND gadsden_brownfield_areas IS THE FINDING INSIDE THE METHOD LESSON: ONE ROW IS NOT A SMALL FACT. It is a 3,963-acre
designated brownfield area recorded once, with 7,740 parcels near it.

### 3. 701 VERIFICATION RUNS, 529 PASSES, AND NOT ONE SURVIVING ZERO

`measurement` | measured: 2026-08-16 | claude

THE SWEEP IS NOW STABLE AT ~60 LAYERS A BATCH. MEASURED ACROSS 701 RUNS:
  PASS (polygon, parcel-side)        136
  PASS_LAYER_SIDE (inverted)         168+
  PASS_PROXIMITY (point/line)        105+
  SUPERSEDED_BY_LAYER_SIDE retained  121+
  TILING_COVERAGE                      2
  ZERO_ALL_METHODS                     0
NOT ONE ZERO SURVIVED ALL THREE CORRECTIONS. Every zero encountered was one of:
  a parcel-side draw against a sparse layer
  a polygon predicate against point or line geometry
  a 2km radius against a layer of one to five features
THE BASE RATE OF A REAL ZERO IN THIS LIBRARY IS NOT 2% - SO FAR IT IS ZERO OF 189. That is a claim about our METHOD,
not about the data being clean: it says the three failure modes account for every zero we have seen, and any future
zero should be assumed to be a fourth method error until three corrections have been tried.
THE OPERATIONAL RULE, IN ORDER: MATCH THE PREDICATE TO THE GEOMETRY TYPE, INVERT THE DRAW, SCALE THE RADIUS. Only then
record a zero, and record it as a finding rather than a failure.

## 31-source

### 1. SIXTEEN TABLES KNEW THEIR OWN SOURCE WHILE THE REGISTRY SAID UNCONFIRMED

`correction` | measured: 2026-08-16 | claude

THE SOURCE-BLOCKED SET IS NOT ONE PROBLEM. MEASURED ACROSS 162 TABLES WITH A PROVED JOIN AND NO REFRESHABLE SOURCE:
  80  UNCONFIRMED - municipal or county publisher, endpoint not recorded at pull time
  63  NO REGISTRY ROW AT ALL   <- not an endpoint problem, a MISSING ROW
  32  UNCONFIRMED - endpoint not recorded (FDEP, FGS and county layers)
   9  UNCONFIRMED - county NFHL/FIRM publisher
   2  NOT_ESTABLISHED
AND THE FDEP/FGS FAMILY WRITES ITS ENDPOINT INTO EVERY ROW AT PULL TIME. 29 tables carry a per-row source_url, 26 hold
a real http URL, AND 16 OF THOSE HAD A REGISTRY ROW SAYING UNCONFIRMED OR NO ROW AT ALL.
THE PROVENANCE WAS NEVER LOST. THE REGISTRY COPY WENT STALE WHILE THE DATA HELD THE TRUTH.
RECOVERED, NOT GUESSED - the value the loader recorded at pull time, read back out of the column it was written to.
That took data_source_registry from 464 to 480 real URLs.
THE LESSON IS THE ONE THAT KEEPS RECURRING IN A NEW COSTUME: SEARCH FOR THE ARTEFACT BEFORE DESCRIBING THE GAP. I
called 162 tables "blocked on endpoint recovery, WSL work" one turn ago. Sixteen were blocked on a SELECT.
AND IT IS AN ARGUMENT FOR THE PATTERN ITSELF: the FDEP family carrying source_url and layer_note PER ROW is the reason
its provenance survived a stale registry. Every loader should write the endpoint into the row.

## 32-power

### 1. CC CAUGHT A PASS THAT FLIPPED ON A COIN TOSS - 146 OF 603 RESTED ON TWO HITS OR FEWER

`test` | authority: Poisson; CC objection | measured: 2026-08-16 | cc

CC OBJECTION, AND IT IS MATHEMATICAL RATHER THAN A JUDGEMENT CALL: lee_waterbodies PASSED AT 2.00% WITH BOTH CONTROLS
ZERO, AND THAT IS INDISTINGUISHABLE FROM AN UNDERPOWERED DRAW BY THE NUMBER ALONE. The easements are UNDERPOWERED at
0.00% for the same structural reason. THE ONLY SEPARATOR IS WHETHER ANY HIT LANDED - WHICH IS NOT EVIDENCE.
MEASURED ACROSS MY 603 PASSES:
  20+ hits   144      5-19 hits   228      3-4 hits    85      TWO OR FEWER  146      EXACTLY ONE  89
POISSON MAKES IT PRECISE: at an expected 1 hit, P(zero) is 37%. At 2, 14%. At 20, effectively nil. SO 146 PASSES AND
THE UNDERPOWERED ZEROS BESIDE THEM WERE THE SAME DRAW WITH A DIFFERENT COIN RESULT.
FIXED IN TWO STEPS:
 1 ALL 146 DOWNGRADED to *_LOW_POWER and their tables dropped from E0 to E2. The controls held, so this is NOT
   evidence of a broken join - IT IS INSUFFICIENT EVIDENCE OF A WORKING ONE.
 2 REBUILT probe_points AT 20 PER COUNTY - 1,340 POINTS, ALL 67, FOUR TIMES THE POWER. Re-probed all 146:
     77 RECOVERED with 3 to 18 hits and are now genuine passes
     69 STILL AT TWO OR FEWER despite an expected ~13 hits for a 1% layer
THE 69 ARE NOT A POWER PROBLEM ANY MORE. THEY GENUINELY UNDERLIE ALMOST NO PARCELS, and that is now MEASURED rather
than assumed. Serve them by proximity or not at all, and do not re-probe higher - the answer will not change and the
cost will.
THE GENERAL RULE: A PASS IS ONLY LOAD-BEARING ABOVE ROUGHLY FIVE HITS. Record the hit COUNT, not just the rate, and
gate the verdict on it. A rate hides its own sample size.

### 2. THE FULL CORRECTION LADDER, AND WHAT SURVIVES IT IS A FINDING

`principle` | measured: 2026-08-16 | claude

THE SWEEP NOW EXHAUSTS FOUR CORRECTIONS BEFORE IT MAY RECORD ANYTHING AS ABSENT, IN THIS ORDER:
  1 MATCH THE PREDICATE TO THE GEOMETRY TYPE - ST_GeometryType decides; points and lines get ST_DWithin, polygons
    ST_Intersects. 105+ layers recovered here.
  2 RAISE THE POWER - n=1340, 20 parcels per county across all 67. 77 of 146 low-power passes recovered here.
  3 INVERT THE DRAW - probe from the layer against parcels when the layer is sparse. 121+ recovered here.
  4 SCALE THE RADIUS - 0.02 to 0.05 degrees for a layer of a handful of features. 17 recovered here.
MEASURED AFTER ALL FOUR: 1,106 RUNS, 639 SOLID PASSES ON MORE THAN TWO HITS, AND A HANDFUL OF MEASURED_SPARSE.
WHAT SURVIVES THE LADDER IS NOT A FAILURE, IT IS A MEASUREMENT: the layer genuinely underlies almost no parcels. That
is a servable fact - proximity, or not at all - and it is now distinguishable from every method artefact that produces
the identical clean zero.
THE COUNT THAT MATTERS: OF ROUGHLY 200 ZEROS AND LOW-POWER RESULTS ENCOUNTERED ACROSS THE WHOLE SWEEP, FEWER THAN 20
SURVIVED ALL FOUR CORRECTIONS. NINETY PERCENT OF APPARENT ABSENCE WAS METHOD.
AND EVERY SUPERSEDED STEP IS RETAINED WITH end_lifespan_version SET, so the ladder is auditable: for any table you can
read which corrections were tried, in order, and what each returned.

## 33-scope

### 1. SCOPE, NOT SIZE - MY STATEWIDE DRAW CANNOT MEASURE A COUNTY LAYER AND NO AMOUNT OF POWER FIXES IT

`correction` | measured: 2026-08-16 | cc

CC STOPPED AT highlands_flood_zones - A SERVED LAYER FILED PASS_LOW_POWER ON ONE HIT OF 335. A county NFHL layer
covering 1-in-335 is impossible, and that impossibility is what exposed the design error.
PROBED AGAINST HIGHLANDS PARCELS: 12 OF 200 = 6.0% (I reproduced it at 13 of 200 = 6.5%). THE LAYER WAS ALWAYS HEALTHY.
THE ARITHMETIC CC PUT ON IT:
  draw 335   -> ~5 points in the county   -> EXPECTED HITS 0.3
  draw 1,340 -> ~20 points                -> EXPECTED HITS 1.2
MY 4x POWER INCREASE MOVED THE EXPECTATION FROM 0.3 TO 1.2 - STILL BELOW MY OWN 5-HIT BAR, FOR A WORKING LAYER. To
land 335 points in one county a statewide draw needs ~22,000. THE SIZE KNOB CANNOT REACH IT.
SCALE OF THE ERROR, MEASURED: 857 OF 1,106 RUNS ARE COUNTY-SCOPED LAYERS GRADED ON A STATEWIDE DRAW. 423 PASSES SAT ON
THAT INSTRUMENT.
FIXED: probe_in_extent resolves the county from the table prefix via geo_reference and draws parcels FROM THAT COUNTY
ONLY. Controls unchanged and still required to return zero.
RE-PROBED ALL 223 COUNTY-SCOPED LOW-POWER ROWS: 158 RECOVERED, RATES UP TO 88%. 65 remain sparse IN THEIR OWN EXTENT,
which is the first time that claim has been measured with the right instrument.
AND IT RETRACTS TWO THINGS I RULED LAST TURN. "They genuinely underlie almost no parcels" and "do not re-probe higher"
WERE BOTH WRONG FOR EVERY COUNTY-SCOPED LAYER IN THAT SET. Re-probing higher STATEWIDE would not have changed them;
re-probing IN-EXTENT did.
WHY THE ERROR HID: THE STATEWIDE DRAW IS CORRECT FOR fl_nwi_wetlands, nhd_flowline AND THE DRASTIC SET - the statewide
layers I validated it on. IT WORKED WHERE I TESTED IT AND FAILED WHERE I DID NOT.

### 2. AGREEMENT WITH AN INDEPENDENT PRIOR IS WHAT SEPARATES A REAL ZERO FROM AN ARTEFACT

`principle` | measured: 2026-08-16 | cc

CC KEPT TWO SUSPECTS OUT OF THE RECOVERY AND THE REASON IS THE BEST TEST IN THIS SESSION:
alachua_flood_zones AND brevard_flood_zones ALSO READ 1 HIT - AND BOTH WERE DE-SELECTED MONTHS AGO UNDER ITEM 80 FOR
HOLDING ~0 POLYGONS INSIDE THEIR OWN COUNTY.
A ZERO THAT AGREES WITH AN INDEPENDENT EARLIER FINDING IS EVIDENCE. THE SAME ZERO WITH NOTHING BEHIND IT IS A COIN
TOSS. That is the four-test protocol applied to a verdict rather than a join, and it is how you tell the two apart
when the number is identical.
AND CC WITHHELD SIGN-OFF ON lee_easements - AN LA_RRR, A RESTRICTION THAT RUNS WITH THE LAND - UNTIL IT IS RE-PROBED IN
LEE. Correct: a weak join on a context layer wastes a query; a weak join on a recorded restriction tells a buyer there
is no easement on land that has one.
TRIAGE BY CONSEQUENCE, NOT BY COUNT. CC reviewed 226 low-power rows starting with the 18 that are EXT_Regulatory or
LA_RRR, and that ordering is what found the flood error - because a served regulatory layer is where an impossible
number is recognisable as impossible.

### 3. THE SCOPE ERROR RECURRED ONE LEVEL DOWN - A CITY PREFIX RESOLVED TO NO COUNTY AND FELL BACK TO STATEWIDE

`correction` | measured: 2026-08-16 | claude

I BUILT probe_in_extent ON CC FINDING, RAN CC WORKLIST, AND BATCH TWO FILED 42 OF 60 AS MEASURED_SPARSE. I CHECKED
INSTEAD OF CONTINUING, AND MOST OF THE 42 WERE daytonabeach_city_*.
CAUSE: probe_in_extent RESOLVED THE PREFIX AGAINST geo_reference admin_level 2 ONLY - COUNTIES. A CITY PREFIX RESOLVED
TO NULL AND THE FUNCTION FELL BACK TO A STATEWIDE DRAW, WHICH IS WORSE FOR A CITY THAN FOR A COUNTY BY THE RATIO OF
CITY AREA TO COUNTY AREA. THE EXACT ERROR CC HAD JUST CAUGHT, ONE ADMINISTRATIVE LEVEL DOWN.
THE FIX WAS ALREADY IN THE DATABASE: geo_reference HOLDS 412 MUNICIPALITIES AT admin_level 3 AND EVERY ONE CARRIES ITS
PARENT dor_co_no. Built resolve_scope_co to try county names then municipal names.
  daytonabeach_city_streets  0 OF 200  ->  48 OF 200 (24%)
  Across the 42: 20 RECOVERED, max rate 100%, and 21 remain sparse in their parent county.
  445 of 536 worklist rows are now scopable, up from 356.
WHAT THIS DOES NOT FIX, AND I AM RECORDING IT RATHER THAN CLAIMING IT: RESOLVING A CITY TO ITS PARENT COUNTY REMOVES 66
OF 67 COUNTIES FROM THE DRAW BUT DOES NOT CONFINE IT TO THE CITY LIMITS. A city layer probed against county parcels
still has most of its probes outside the city. A TRUE MUNICIPAL DRAW NEEDS THE CITY BOUNDARY POLYGON, AND OUR MUNICIPAL
BOUNDARIES ARE 2021 VINTAGE - so county-of-the-city is both cheaper and less stale, and the residual understatement is
real.
THE PATTERN WORTH KEEPING: THE SAME ERROR EXISTS AT EVERY LEVEL OF A HIERARCHY AND FIXING IT AT ONE LEVEL DOES NOT FIX
IT AT THE NEXT. Statewide draw for a county layer, county draw for a city layer, and presumably county draw for a
subdivision layer if we ever hold one.

## 34-harness

### 1. A BLANKET EXCEPTION HANDLER RETURNING A SENTINEL HIDES ITS OWN CAUSE

`correction` | measured: 2026-08-16 | claude

A BATCH FILED 14 ROWS AS verdict=error. Every one existed, had a valid geom column, and had its geometry_type
correctly detected - so the first statement inside the function worked and the second did not.
CAUSE: I interpolated the scope column as a BARE NULL for statewide tables. PostgreSQL types an untyped NULL as TEXT,
the function declares scope_co int, and RETURN QUERY EXECUTE raised "structure of query does not match function result
type". Fixed with %s::int.
IT FAILED ONLY FOR STATEWIDE TABLES. Every county and municipal layer passed, because those interpolate a real integer.
THAT IS WHY 14 ERRORS APPEARED IN ONE BATCH AND NONE IN THE FIVE BEFORE IT - the batch was the first dominated by
fdep_, fgs_, fl_, fuds_, gwca_, hifld_ and hydrology_ prefixes.
AND THE HANDLER MADE IT HARDER, NOT EASIER: EXCEPTION WHEN others THEN RETURN -1 turned ONE DIAGNOSABLE ERROR INTO
FOURTEEN UNEXPLAINED ONES. I built the handler so a batch would not die on a bad column - which is right - but it
discards SQLERRM, so the harness could report THAT something failed and never WHAT.
THE FIX FOR NEXT TIME: CAPTURE SQLERRM INTO THE ROW. A sentinel that carries its own error message is a diagnosis; one
that does not is a mystery that has to be reproduced by hand.
THIS IS THE SAME CLASS AS "A GUARD THAT ERRORS IS NOT A GUARD THAT FAILS" - recorded this morning about
run_defect_detections dropping error_text. I recorded the lesson and then built the same defect into a new instrument.
RETRIED ALL 14: 7 PASS (to 100%), 7 measured sparse. The error rows are retained with end_lifespan_version set.

## 35-control

### 1. THE THIRD VACUOUS CONTROL IN ONE DAY - A DISPLACEMENT LARGER THAN THE LAYER CANNOT FAIL

`correction` | authority: CC question | measured: 2026-08-16 | cc

CC ASKED WHETHER probe_in_extent NARROWS THE CONTROL AS WELL AS THE SAMPLE. IT DOES NOT, AND THAT IS WORSE THAN
NARROWING IT.
THE DISPLACED CONTROLS MOVE A PROBE POINT 9 DEGREES NORTH OR 12 WEST. MEASURED: highlands_flood_zones SPANS 0.61
DEGREES TALL AND 1.12 WIDE.
ANY DISPLACEMENT LARGER THAN THE LAYER OWN EXTENT GUARANTEES A MISS. A zero control therefore proved only that a county
flood layer does not reach 9 degrees north - WHICH IS A FACT ABOUT FLORIDA GEOGRAPHY, NOT ABOUT THE JOIN. And Florida
itself is 6.6 degrees tall, so the 9-degree control was vacuous for EVERY LAYER WE HOLD, statewide ones included.
THIRD TIME TODAY, THE SAME SHAPE:
  1 (p_co % 67)+1 mapped county 67..76 onto 1..10 - counties with ZERO parcels, so the key control joined an empty set.
  2 the sweep graded county layers on a statewide draw, so a healthy 6% layer had an expected 0.3 hits.
  3 a displacement of 9 degrees against layers 0.6 degrees tall.
EVERY ONE WAS A CONTROL OR SAMPLE THAT COULD NOT PRODUCE A FAILING RESULT, AND I BUILT ALL THREE.
THE FIX - THE SPATIAL ANALOGUE OF "SAME KEY, WRONG COUNTY": draw parcels from the NEAREST OTHER COUNTY with more than
5,000 parcels and test them against this county layer. A correctly scoped layer MISSES them. A MIS-GEOREFERENCED OR
WRONGLY-SCOPED LAYER HITS THEM. That control can fail, and it is the one the key harness has used all along - I simply
never carried it across to the spatial side.
MEASURED SO FAR: 70 county-scoped passes re-checked, 70 CLEAN, ZERO LEAKED. The passes hold - but they now hold on
evidence rather than on a tautology, and control_wrong_county IS NULL on the remainder marks exactly which ones still
rest on the vacuous control.
AND A PROCESS NOTE: MY FIRST ATTEMPT AT THIS UPDATE ROLLED BACK ON TIMEOUT AND LOST THE COLUMN ADDS WITH IT - CC
FINDING ABOUT DO BLOCKS AND SINGLE TRANSACTIONS, HITTING ME IN A PLAIN UPDATE. Batches of 20-30 commit; 90 does not.

### 2. THE WRONG-COUNTY CONTROL HAS ONE ACCEPTABLE FAILURE MODE - AND MATERIALISING THE SAMPLE MADE IT 32x FASTER

`measurement` | measured: 2026-08-18 | claude

*** PERFORMANCE FIRST, BECAUSE IT DECIDED WHETHER THE DEBT COULD BE CLOSED AT ALL. ***
probe_control_wrong_county MEASURED AT 3,600 ms PER CALL. 1,031 remaining calls was OVER AN HOUR OF PURE COMPUTE at 25
per commit - about 41 round trips.
THE COST WAS THE PARCEL DRAW, NOT THE SPATIAL TEST, AND THE DRAW IS IDENTICAL FOR EVERY LAYER IN A COUNTY. It was being
recomputed once per layer for no reason.
MATERIALISED IT ONCE AS control_points - 14,600 POINTS, 200 PER COUNTY, ALL 67 COUNTIES, ONE GiST INDEX.
  3,600 ms -> 114 ms. THIRTY-TWO TIMES. Batch size 25 -> 450.
THAT IS "REPAIR GEOMETRY ONCE AT INGEST, NEVER PER CALL" APPLIED TO A SAMPLE INSTEAD OF A GEOMETRY - the same rule that
took a Marion report from 27.7 s to 4.98 s. SECOND FORM OF ONE LESSON.
*** THE RESULT: 1,080 PASSES RE-CHECKED, 1,079 CLEAN, ONE LEAK. ***
washington_flood_zones hit 2 Walton control points against 34 of its own. INVESTIGATED RATHER THAN ASSUMED:
  the two Walton points are at longitude -85.9061 and -85.9036, AGAINST WALTON EASTERN EDGE AT -85.8922 - ON THE SHARED
  COUNTY LINE - and ~26 MILES WEST of the nearest Washington control point
  AND 5 OF 5,900 POLYGONS (0.08%) EXTEND WEST OF THAT EDGE
A FEMA FIRM PANEL IS DRAWN ON HYDROLOGY, NOT ON POLITICAL BOUNDARIES. A floodplain crossing a county line is CORRECTLY
MAPPED CROSSING IT.
*** SO THE CONTROL HAS A KNOWN ACCEPTABLE FAILURE MODE: ADJACENT COUNTIES SHARING A REAL FEATURE. A NON-ZERO CONTROL IS
A QUESTION, NOT A VERDICT - AND THE QUESTION IS ANSWERED BY WHERE THE HITS FALL, NOT HOW MANY. 0.08% at the edge is a
straddle; a spill would put whole panels in the wrong county. ***
AND TWO PROCESS FINDINGS FROM BUILDING IT:
  co_no RUNS 11 TO 77, NOT 1 TO 67. My first fill used BETWEEN 1 AND 8 and RETURNED ZERO ROWS WITH NO ERROR - outside
  the domain entirely. Abort-on-zero caught it.
  A CONNECTOR TIMEOUT IS NOT A ROLLBACK. Counties 11-16 ended with 400 points because a batch I had recorded as failed
  HAD ACTUALLY COMMITTED and I inserted over it. "The connector is not responding" tells you NOTHING about whether the
  transaction landed - re-measure before re-running.

### 3. CONTROL DEBT CLOSED - AND THE LAST 50 NEEDED THE CONTROL DECLARED INAPPLICABLE RATHER THAN RUN

`measurement` | measured: 2026-08-18 | claude

FINAL STATE OF THE WRONG-COUNTY CONTROL ACROSS EVERY LIVE PASS:
  1,096  RAN AND RETURNED ZERO - evidenced
     50  NOT APPLICABLE, recorded as -2
      1  LEAKED - washington_flood_zones, investigated and resolved as a boundary straddle
      0  UNCHECKED
*** THE 50 ARE THE FINDING. *** They are fdep, hifld, nhd, nrhp, fema, nfhl, fl_, census, hydrology and fgs - STATEWIDE
AND FEDERAL LAYERS. A statewide layer COVERS EVERY COUNTY BY DESIGN, so parcels from a neighbouring county ARE SUPPOSED
TO HIT IT. A non-zero result would be CORRECT BEHAVIOUR.
WHICH MEANS THE CONTROL CANNOT FAIL - THE EXACT DEFECT IT WAS BUILT TO REPLACE, IN A NEW GUISE. Running it would have
produced 50 more clean results and 50 more false assurances, and the number would have looked better.
*** A CONTROL THAT CANNOT FAIL MUST BE RECORDED AS INAPPLICABLE, NOT RUN AND PASSED. ***
AND THE TWO CONTROLS ARE COMPLEMENTARY RATHER THAN ONE SUPERSEDING THE OTHER, WHICH I HAD NOT SEEN UNTIL NOW:
  COUNTY LAYER      the 9-degree displacement is LARGER than the layer, so it cannot fail -> USE WRONG-COUNTY
  STATEWIDE LAYER   the neighbouring county is INSIDE the layer, so wrong-county cannot fail -> USE DISPLACEMENT
THE OLD CONTROL IS VALID EXACTLY WHERE THE NEW ONE IS NOT. I spent a day treating the displaced control as simply
broken; IT IS BROKEN FOR COUNTY LAYERS AND CORRECT FOR STATEWIDE ONES, and those 50 rows already carry it.
AND -2 RATHER THAN NULL IS THE THREE-COVERAGE-STATE RULE TURNED ON OUR OWN EVIDENCE: NULL MEANS NOT YET CHECKED, -2
MEANS CHECKED AND NOT APPLICABLE. Leaving them NULL would have left 50 rows indistinguishable from work not done.
*** AND THE ENABLER WAS A RESOLVER FIX. *** 181 passes could not be control-checked FOR WANT OF A SCOPE, and CC
independently hit 21 unresolvable rows in layer_resolution - THE SAME DEFECT FOUND TWICE FROM TWO DIRECTIONS.
FOUR CLASSES: HYPHEN (miamidade vs "Miami-Dade"), PERIOD (stjohns vs "St. Johns"), ABBREVIATION (sjc), and
MUNICIPALITY-NOT-IN-geo_reference (portstlucie, pembrokepines, westpalmbeach, titusville, pinellaspark).
STRIPPING PUNCTUATION FIXES THE FIRST TWO. NOTHING FIXES sjc BUT A LOOKUP - AN ABBREVIATION IS NOT A NORMALISATION.
AND I GOT THE ALIAS TABLE WRONG ON THE FIRST ATTEMPT by comparing an unnormalised alias to a normalised name - the
normalisation has to be applied to BOTH SIDES, which is the same shape as the four spellings of Miami-Dade.

## 36-state

### 1. THE JOIN GAP IS CLOSING AND THE SOURCE GAP IS NOW THE WHOLE PROBLEM

`measurement` | measured: 2026-08-16 | claude

MEASURED THIS TURN:
  1,656  serving candidates
  1,320  mapped
    999  mapped AND REFRESHABLE
    607  SHELVED - all four facts
  1,078  JOINS PROVED
  1,652  verification runs
    220  of CC 536 worklist remaining
THE ARITHMETIC THAT MATTERS: 1,078 JOINS PROVED AGAINST 607 SHELVED. THE 471-ROW GAP IS ENTIRELY SOURCE
REFRESHABILITY - tables that are known, mapped, and whose join is measured against a control that can fail, and which
cannot be refreshed because no endpoint was recorded at pull time.
NO AMOUNT OF PROBING TOUCHES THAT NUMBER. It grows every time the sweep proves another join.
THE THREE REMAINING GAPS, IN SIZE ORDER:
  471  join proved, SOURCE NOT REFRESHABLE   <- the 31-county DCAT enumeration. WSL work.
  336  not mapped                            <- CC judgement lane
  220  CC worklist not yet probed            <- my runner, ~4 more batches
AND THE 471 IS NOT UNIFORM. 16 of the earlier 162 turned out to be blocked on a SELECT rather than a pull - the
FDEP/FGS family writes its endpoint into EVERY ROW and the registry copy had gone stale while the data held the truth.
BEFORE ANY PULL IS SCHEDULED, CHECK WHETHER THE TABLE ALREADY KNOWS ITS OWN SOURCE.
WHAT THE SWEEP HAS ESTABLISHED BEYOND THE COUNT: NINETY PERCENT OF APPARENT ABSENCE WAS METHOD. Four corrections -
predicate to geometry type, draw in the layer scope, invert the draw, scale the radius - and a fifth on the control
itself. Every one was found by measuring rather than by reasoning, and three of the five were found by CC.

## 37-endpoints

### 1. ANSWER TO CC: THE COUNTY ENDPOINTS ARE IN THE DATABASE, IN THREE PLACES, AND NONE OF THEM IS data_source_registry

`measurement` | measured: 2026-08-16 | cc

CC ASKED WHERE THE COUNTY PULL CONFIGS LIVE - registry, harness config, or WSL only. THEY ARE IN THE DATABASE. I
searched every table with a url-shaped column rather than guessing.
  cadence_sweep_request   5,816 ROWS, REAL ENDPOINTS. gis.polk-county.net Map_Property_Appraiser/FeatureServer/3,
    gisweb.miamidade.gov LandManagement/MD_Zoning/MapServer/1 and /2, services2.arcgis.com Lee_County_Parcels.
    BUT keyed on source_id, and NONE of the six tables CC named has a sweep row.
  county_export_survey    67 ROWS, ONE PER COUNTY, and it is the real find:
      gis_url 29 | pa_url 3 | rest_endpoint 42 | export_url 45 | reachable 46 | 20 DISTINCT VENDOR FINGERPRINTS
      plus oid_field, max_record_count, supports_pagination, paths_tried, export_evidence
    THAT IS A PULL CONFIGURATION AND IT IS 67 ROWS DEEP. Lee resolves:
      services2.arcgis.com/LvWGAAhHwbCJ2GMP/arcgis/rest/services/Lee_County_Parcels/FeatureServer/0
    Miami-Dade and Polk have NULL rest_endpoint - genuinely not surveyed, not merely uncopied.
  county_layer_registry   1,584 ROWS with table_name, county, concept, key_column, bridge_key, key_transform, srid.
    HAS ALL FOUR TABLES CC NAMED AND NO URL COLUMN AT ALL. And key_column is NULL on all four - CC HAS NOW PROVED
    THOSE KEYS AT 98.8 TO 99.8%, SO THIS REGISTRY IS BEHIND THE EVIDENCE.
SO THE ANSWER IS: NOT WSL-ONLY. A per-county survey exists with 42 REST endpoints and 20 vendor fingerprints, and
data_source_registry - THE TABLE WE HAVE BEEN TREATING AS THE SOURCE OF TRUTH FOR PROVENANCE - DOES NOT REFERENCE IT.
FOUR REGISTRIES HOLDING OVERLAPPING PROVENANCE, EACH INCOMPLETE IN A DIFFERENT WAY. That is the same fragmentation
layer_resolution was built to end for the five legacy registry tables, recurring on the provenance side.
THE RECOVERABLE PATH FOR CC THREE: Lee is a SELECT away. Miami-Dade and Polk are a survey away, and county_export_survey
records exactly which paths were tried - so the WSL work is scoped, not open-ended.

### 2. I RE-QUEUED WORK CC HAD ALREADY POSTED, BECAUSE I WROTE A PROMPT WITHOUT READING THE BUS

`correction` | measured: 2026-08-16 | cc

I gave CC items 3 and 4 - fdep_institutional_controls and county_land_interests - AS NEW WORK. BOTH WERE DONE THE TURN
BEFORE AND POSTED AT HANDOFF 412: fdep_institutional_controls 119/120 layer-side, county_land_interests 109/120,
lee_easements 118/120, all controls 0/0 with the displacement clearing Florida.
I WROTE THE PROMPT FROM MY OWN NOTES INSTEAD OF READING to_agent=claude AND status=unread FIRST. That is the inbox rule
I restored in ruling 222 and then broke.
IT IS ALSO THE THIRD TIME TODAY I HAVE DESCRIBED SOMETHING AS OUTSTANDING THAT WAS ALREADY DONE - after nr_final, after
table_column_signature, and after the 16 tables holding their own source_url.
THE PATTERN IS NOT CARELESSNESS ABOUT THE BUS. IT IS THAT I TRUST MY OWN MODEL OF THE STATE OVER THE RECORD OF IT, and
the record is the only thing that is current. READ THE INBOX BEFORE WRITING THE WORK ORDER, EVERY TIME.

### 3. THE PULL PROVENANCE HAS BEEN IN A TABLE SINCE JULY AND I NEVER OPENED IT - 130 SOURCES RECOVERED BY ONE UPDATE

`correction` | authority: county_coverage_status; conversation history July 6-8 | measured: 2026-08-16 | murphy

MURPHY: RESEARCH THE PAST CHAT HISTORY, THE PULL HISTORY WOULD BE IN THERE AND YOU KNOW THIS. HE WAS RIGHT.
county_coverage_status - 71 ROWS, 32 HUB URLS, 15 DISTINCT PULL TECHNIQUES, per-county notes naming every layer loaded
and the exact obstacles hit. IT HAS EXISTED SINCE JULY AND IS THE FIFTH REGISTRY HOLDING PROVENANCE.
THE THREE CC COULD NOT SHELVE, ALL THREE RECORDED:
  Lee          maps-leegis.hub.arcgis.com | dcat_feed | "73/73 layers. building_footprints 359,256 EXACT MATCH,
               confirmed via chunked_resume after repeated connection drops"
  Miami-Dade   gisweb.miamidade.gov/arcgis/rest/services | direct_arcgis_server_folder_crawl | "45 layers from
               LandManagement + CommunityServices folders: PAParcel, GeoAddress, Condo and Property Boundaries"
  Polk         ftp.polkflpa.gov (formerly ftp.polkpa.org, domain retiring) | ftp_shapefile_and_csv |
               "MICROSOFT IIS FTP, REQUIRES TLS 1.2 EXPLICITLY - TLS 1.3 HANDSHAKE FAILS. polk_parcels_gis 437,259
               via native ogr2ogr shapefile import, fixed numeric overflow with -lco PRECISION=NO"
POLK IS THE ONE THAT PROVES THE POINT: NO URL PATTERN, NO DCAT FEED AND NO AMOUNT OF ARCGIS ENUMERATION WOULD EVER HAVE
FOUND AN FTP SERVER THAT FAILS ON TLS 1.3. That is irreplaceable operational knowledge and it was recorded at the time.
RECOVERED: 130 SOURCES. UNREFRESHABLE 237 -> 107.
FIVE REGISTRIES NOW COUNTED, EACH INCOMPLETE DIFFERENTLY:
  data_source_registry   1,379 rows - the one we call the source of truth. Had the gap.
  county_coverage_status    71 - THE HUB URLS AND TECHNIQUES. Never consulted until now.
  county_export_survey      67 - 42 REST endpoints, 20 vendor fingerprints, oid_field, pagination support.
  cadence_sweep_request  5,816 - real endpoints, keyed on source_id, sparse coverage of what we need.
  county_layer_registry  1,584 - table_name and concept, NO URL, and key_column NULL where CC has proved the key.
I HAVE SAID "NO ENDPOINT WAS RECORDED AT PULL TIME" REPEATEDLY TODAY AND IT WAS FALSE. The endpoint was recorded; I was
reading the wrong table and never searched for a better one. FOURTH TIME TODAY, AND THE COSTLIEST - it made 237 tables
look like WSL work when 130 were a single UPDATE.
STANDING: BEFORE DECLARING A PROVENANCE GAP, ENUMERATE EVERY TABLE WITH A URL-SHAPED OR TECHNIQUE-SHAPED COLUMN, AND
SEARCH THE CONVERSATION HISTORY FOR THE PULL. The operational detail that makes a source reachable is often not a URL.

## 38-third-join

### 1. THERE ARE THREE JOIN TYPES, NOT TWO - AND I SPENT THE DAY ASSUMING EVERY TABLE JOINS TO A PARCEL

`principle` | authority: FEMA disaster declarations; EPA FRS | measured: 2026-08-16 | murphy

THE 199 RELATIONAL TABLES LEFT WOULD NOT MOVE. I read what they were instead of hunting for keys, AND NONE OF THEM HAS
A PARCEL KEY BECAUSE NONE OF THEM SHOULD.
  alachua_disaster_declarations   designatedArea "Alachua (County)", fipsCountyCode 001, fipsStateCode 12,
    disasterNumber 3561, incidentType "Severe Storm", 35 rows. A FEMA DISASTER DECLARATION COVERS A WHOLE COUNTY.
  alachua_superfund_facilities    county_name ALACHUA, registry_id 110069082771, pgm_sys_id FLD000823393, 11 rows.
  alachua_burn_detection_history  county-wide burn counts by year.
MEASURED: 123 OF THE 199 CARRY jurisdiction PLUS EVENT OR RESTRICTION ROLES AND NO KEY ROLE AT ALL. Zero of 199 had a
mapped key column - which I had been reading as "unmapped" when it meant "not parcel-keyed".
*** THE THIRD JOIN TYPE: JURISDICTION-TO-geo_reference ***
  E0_key_verified_with_control          key-to-parcel.   Control: SAME KEY, WRONG COUNTY.
  E0_containment_verified_with_control  spatial.         Control: parcels from the NEAREST OTHER COUNTY.
  E0_jurisdiction_verified_with_control county-wide fact. Control: the table names ITS OWN county, NOT the neighbour.
alachua_disaster_declarations: 35 OF 35 NAME ALACHUA, ZERO NAME THE NEAREST NEIGHBOUR. A control that could fail.
RESULT: 139 TABLES PASSED AT 100% WITH EVERY CONTROL AT ZERO. SHELVED 896 -> 1,088 IN ONE PASS.
*** WHY THIS MATTERS BEYOND THE COUNT ***
FORCING A PARCEL KEY ONTO THESE WOULD BE THE LOT-VERSUS-INTEREST ERROR AT THE JURISDICTION LEVEL - attributing a
county-wide fact to one parcel as though it were a property of that parcel. A DISASTER DECLARATION IS NOT A FACT ABOUT
YOUR LOT. Nor is a county Superfund count, nor a burn-detection total.
AND I HAD BEEN COUNTING THEM AS FAILURES ALL DAY. 199 tables sat in the "join not proved" column because the harness
could only ask two questions and they answer a third.
MURPHY SAID DOING THE WORK MAY ANSWER THE UNKNOWNS. IT DID - the blocked set was not blocked, it was mis-asked.
THE CHECK CONSTRAINT REFUSED THE NEW GRADE UNTIL I ADDED IT TO THE VOCABULARY, WHICH IS THE FK DISCIPLINE WORKING: a
new evidence form has to be declared before it can be used, exactly as a new class does.

## 39-run-close

### 1. RUN CLOSE 2026-08-16 - SHELVED 51 -> 1,088 OF 1,660, AND THE FULL INSTRUMENT LIST

`measurement` | measured: 2026-08-16 | claude

START OF RUN: 51 declared, 0 shelved, 0 verification runs, no lens.
END OF RUN:
  2,115  populated tables            1,660  serving candidates (less 21 SYSTEM, 41 scratch, 1 quarantined)
  2,115  ENUMERATED, ZERO ABSENT     1,677  classified (438 UNREAD, honestly marked)
  1,329  column-mapped               1,127  refreshable through provenance_all
  1,088  SHELVED - known, mapped, refreshable, JOIN PROVED AGAINST A CONTROL THAT COULD FAIL
  1,331  joins proved  |  1,839 containment runs  |  173 key runs  |  231 jurisdiction runs
    150  lens entries  |  142 active defects  |  bus to 414  |  rulings 239-262
REMAINING, HONESTLY: 51 joins (one pass) | 194 need a source | 327 need a column map.
*** INSTRUMENTS BUILT THIS RUN, ALL WITH THEIR OWN FAILURE HISTORY IN THE COMMENT ***
  lens                        the standard as a table, append-and-supersede, both agents write
  ladm_class_vocabulary       21 ISO classes with source clauses + 4 declared local extensions, FK-enforced
  evidence_grade              adopted from CC July pass, with THREE E0 forms above it
  verify_key_e0               corrected FOUR times by CC: vacuous control, missing transforms, join-row count,
                              arbitrary slice
  probe_in_extent             scope-aware, county then MUNICIPAL, after the statewide draw was found to be
                              unable to measure a county layer
  probe_layer_side_r          inverted draw with a sparsity-scaled radius
  probe_control_wrong_county  THE SPATIAL CONTROL THAT CAN FAIL
  verify_jurisdiction_join    THE THIRD JOIN TYPE, found by reading 199 tables that would not move
  provenance_all              ONE VIEW OVER FIVE REGISTRIES, 1,277 tables resolve a source
  before_you_declare_a_gap    SEVEN SEARCHES IN ONE CALL, built because a rule was not enough
*** THE FIVE THINGS THAT ACTUALLY MATTERED ***
 1 IRIS MCNEELY was restored to a PIR. Two rows, two people, one house, and a limit 1 read had dropped her.
 2 NINETY PERCENT OF APPARENT ABSENCE WAS METHOD. Four corrections plus one on the control itself; fewer than 20 of
   ~200 zeros survived all of them.
 3 EVERY VACUOUS CONTROL WAS MINE AND CC FOUND THEM. (p_co % 67)+1 onto empty counties; a statewide draw against a
   county layer; a 9-degree displacement against layers 0.6 degrees tall.
 4 SEVEN ARTEFACTS I DESCRIBED AS ABSENT ALREADY EXISTED - nr_final, nr_keys, nr_content, table_column_signature,
   county_coverage_status, per-row source_url, and CC own posted work. ONE FAILURE MODE: I TRUST MY MODEL OF THE
   STATE OVER THE RECORD OF IT.
 5 THE 46.7% MACHINE-SCREEN REJECT. marion_transitional_flood_prone -> flood_elevation with every value -99999 WOULD
   HAVE BEEN SERVED AS A FLOOD ELEVATION. A wrong column map is a fabrication surface, which is why the 327 stay
   unmapped rather than guessed.
*** THE ONE-LINE LESSON *** READ THE TABLE. Every real defect this run came from reading contents - the traverse
sketch vectors, OWNSEQ meaning address sequence, pctown being a fraction in Polk and a percentage in Volusia, "****"
masking a book number, and the third join type. NONE was visible from a schema, a name, or a statistic.

## 40-grade-vs-class

### 1. E0 IS A FACT ABOUT THE JOIN, NOT ABOUT THE TABLE - 114 ROWS SAID BOTH "VERIFIED" AND "WE DO NOT KNOW WHAT THIS IS"

`correction` | authority: CC measurement | measured: 2026-08-16 | cc

CC MEASURED IT: 114 rows carried evidence_grade E0 with declared_class STILL UNREAD. My sweep proved the join and set
the grade; nobody had read the contents.
THAT ROW ASSERTS TWO INCOMPATIBLE THINGS - verified to the highest standard, and unidentified. And it is exactly the
shape of every error this run corrected: polk_sales JOINED PERFECTLY and was filed as an amenity; volusia_cama_misc
JOINED PERFECTLY and was the improvement register carrying the entire cross-examination moat. A CLEAN JOIN SAYS NOTHING
ABOUT WHAT THE TABLE IS.
CC FRAMING IS THE RULING: E0 IS A FACT ABOUT THE JOIN, NOT ABOUT THE TABLE.
FIXED STRUCTURALLY, NOT BY RULE - I have broken my own upsert rules twice today:
  CHECK CONSTRAINT ladm_no_e0_without_class: an UNREAD table CANNOT carry an E0 grade.
  105 grades revoked to E5_none, WHICH IS THE HONEST PAIRING FOR UNREAD.
  THE PROOF IS NOT LOST. It stands in the three verification run tables with its control. Read the contents, declare
  the class, and the grade returns WITHOUT RE-PROBING.
  VIEW join_proved_awaiting_read carries the queue with nr_content value domains and the July nr_final class attached,
  so the read starts from evidence rather than a blank table.
*** AND THE VIEW EXPOSED A SECOND FAULT IN MY SWEEP ***
ALL 106 ARE UNMAPPED AND ONLY 3 ARE REFRESHABLE. My sweep was probing tables with NO COLUMN MAP AT ALL - it was not
restricted to the mapped set the way I described it. So a large part of the 1,331 "joins proved" was work on tables
that cannot be shelved for two other reasons.
THE JOINS ARE REAL AND THE EVIDENCE STANDS. But I reported throughput on a denominator I had not checked, which is the
same denominator error that started this whole run - measuring the three-part test only over the set that had already
passed it.
HONEST E0 AFTER THE REVOCATION: 1,358, EVERY ONE ON A TABLE WE CAN NAME.

### 2. GUARD THE FACT YOU ARE WRITING - CC UPSERT GUARD AND MY WHERE NOT EXISTS ARE THE SAME BUG

`rule` | measured: 2026-08-16 | cc

CC WROTE ON CONFLICT DO UPDATE ... WHERE evidence_grade IS DISTINCT FROM 'E0_...' TO HONOUR MY OWN
NEVER-LET-A-WEAKER-ROW-WIN RULE. It saw E0, concluded the row was strong, and REFUSED TO WRITE THE CLASS - so a row
that HAD been read lost to one that had not.
THAT IS THE SAME BUG AS MY WHERE NOT EXISTS KEEPING THE WEAKER SP_Permit ON volusia_cama_permits: A GUARD AIMED ONE
COLUMN OFF TARGET.
THE RULE: GUARD THE FACT YOU ARE WRITING. If you are writing the CLASS, compare the CLASS. Grade and class are separate
facts and neither is evidence about the other - which is the same distinction as the constraint above, arrived at from
the opposite direction.
AND CC RULING ON county_layer_registry IS THE OTHER HALF OF READING BEFORE ACTING: 8 OF 1,584 ROWS CARRIED A key_column,
SO IT LOOKED ABANDONED - AND IT IS READ BY discover_county_layers, A LIVE ROZ TOOL, PLUS daily_ops_report AND A VIEW.
A TABLE CAN BE 99.5% EMPTY ON ITS MOST IMPORTANT COLUMN AND STILL BE LOAD-BEARING. Retiring it would have broken the
assistant. Fed instead: 8 to 86, and 82 tables with passing runs at MORE THAN ONE TRANSFORM were LEFT NULL rather than
auto-filled, because a near-tie means the key is not settled.

## 41-owners

### 1. IT IS NOT TWO OWNERS. ONE PARCEL HAS TWENTY-SEVEN, AND THE PATTERN IS HEIRS PROPERTY.

`principle` | authority: ISO 19152 LA_RRR fraction; Fla. tenancy in common | measured: 2026-08-16 | murphy

MURPHY: "two rows, two people, one house - THERE MAY BE MORE THAN 2." Correct, and I had been saying "both owners"
all day as though two were the ceiling.
MEASURED ACROSS volusia_cama_owner, 343,841 PARCELS:
  1 owner   214,718      2 owners  121,835      3 owners  5,165      4 owners  1,574
  5 to 9      502        TEN OR MORE   47       MORE THAN TWO  7,288       MAXIMUM  27
*** THE 27-OWNER PARCEL IS HEIRS PROPERTY AND THE SHARES PROVE IT ***
219 GRAHAM ST. All 27 OWNTYPE1 = TIC, Tenancy in Common. FIVE DISTINCT SHARE TIERS:
  16.67 = 1/6      5.555 = 1/18      2.38 = 1/42      1.515 = 1/66      0.595 = 1/168
  AND THEY SUM TO EXACTLY 100.000.
THAT IS A GENERATIONAL SPLIT: an intestate estate divided among six children, then a deceased child share divided
among their own heirs, and again. THE DENOMINATORS ARE THE FAMILY TREE. PARRIS GLORIA BELL and HALL PATRICIA BELL both
hold 1/6 and share a surname stem - siblings. The 1/168 holders are great-grandchildren.
*** WHY THIS MATTERS AND NOT AS A CURIOSITY ***
HEIRS PROPERTY IS THE MOST FRAGILE TENURE IN AMERICAN LAND LAW. No single owner can convey clear title; any one of 27
can force a partition sale; it cannot be mortgaged, cannot be insured against loss by most carriers, and is the
best-documented mechanism of Black land loss in the South. Florida has NOT adopted the Uniform Partition of Heirs
Property Act.
A PIR ON THIS PARCEL THAT NAMES ONE OWNER IS NOT MERELY INCOMPLETE - IT CONCEALS THE SINGLE MOST CONSEQUENTIAL FACT
ABOUT THE PROPERTY. And 1,797 TIC PARCELS IN VOLUSIA CARRY MORE THAN TWO OWNERS, 13,236 CARRY TIC AT ALL.
*** WHAT THIS CORRECTS IN MY OWN RULING ***
Lens 16-evidence/5.1 said BOTH OWNERS ARE NAMED and used Earhart as the case. The rule is right and the WORDING WAS
WRONG - it should be EVERY OWNER IS NAMED, HOWEVER MANY, AND THE TENANCY IS STATED.
AND THE TENANCY CODE DECIDES THE MODEL PER PARCEL, WHICH NOW MATTERS MORE:
  TE  two spouses at 100 each      -> ONE right, LA_GroupParty, survivorship, creditor of one cannot reach it
  TIC n owners with REAL FRACTIONS -> n SEPARATE RIGHTS, each severable and each partitionable
EARHART IS THE TE CASE. 219 GRAHAM ST IS THE TIC CASE. Reading one row loses a spouse in the first and TWENTY-SIX
CO-HEIRS IN THE SECOND.

### 2. THE SERVING PATH IS CORRECT AND I VERIFIED IT ON THE HARDEST CASE INSTEAD OF ASSUMING

`test` | measured: 2026-08-16 | claude

get_parcel_owner_facts CONTAINS A limit 1, WHICH IS WHY I TESTED IT RATHER THAN READ IT.
219 GRAHAM ST (74/533998000100), THE 27-OWNER HEIRS-PROPERTY PARCEL:
  owners emitted        27 OF 27
  owner_count fact      27, as its own fact
  shares sum            100.000
  tenancy               {"form":"Tenancy in Common", note explaining shares are NOT normalized}
  per owner             value, pct_own, ownseq in the subject, ownership_type, source_tier
                        county_assessor_record, as_of "2026 roll (CAMA - live county file)"
1778 EARHART CT (74/633001001890): MCNEELY GENE and MCNEELY IRIS BOTH PRESENT, both 100, both
"Tenancy in the Entirety".
THE limit 1 IS NOT ON THE OWNER SET. The function is correct and the tenancy note already says the percentages can
total more than 100 BY DESIGN and are not normalized - which is Part B of the spec, implemented.
*** AND I NEARLY REPORTED A FALSE FAILURE ***
MY FIRST TWO CALLS RETURNED not_established WITH ZERO OWNERS, AND I ALMOST WROTE THAT THE FUNCTION WAS BROKEN. The
signature is (p_co_no, p_parcel_id) AND I PASSED AN alt_key. 3671058 is the CAMA PARID, which joins on ALT_KEY, not
parcel_id - a distinction I had ruled on and recorded four times today and then walked into.
THE FUNCTION RETURNED THE CORRECT ANSWER TO THE QUESTION I ASKED: no owner is established for a parcel_id that does not
exist. AND ITS coverage_note SAID SO EXPLICITLY - "a gap in our coverage, not a statement about the parcel". THE
THREE-STATE DISCIPLINE CAUGHT MY OWN BAD INPUT AND TOLD ME WHICH KIND OF NOTHING IT WAS.
THAT IS THE STRONGEST EVIDENCE THIS RUN THAT THE COVERAGE-STATE RULE EARNS ITS COST: a two-state function would have
returned false and I would have filed a defect against working code.

### 3. THE OWNER PATH IS HARDCODED TO ONE COUNTY AND PINELLAS HAS FIFTEEN TIMES THE EXPOSURE

`test` | measured: 2026-08-16 | cc

CC WENT TO VERIFY THE RENDER AND FOUND SOMETHING LARGER. Line 12 of get_parcel_owner_facts IS LITERALLY IF p_co_no = 74.
MEASURED, PARCELS WITH MORE THAN ONE OWNER ROW:
  PINELLAS 210,064 of 437,566 | MORE THAN TWO 27,319 | MAXIMUM 79 OWNERS ON ONE PARCEL
  Volusia  129,123 of 343,841 | more than two  7,288 | maximum 27
  Pasco    0 of 321,781, MAX 1 ROW - a different shape
EVERY PINELLAS PARCEL FALLS TO THE NAL SINGLE-STRING FALLBACK AND REPORTS owner_count = 1. All three counties are
ALREADY REGISTERED under cama_owners; the function never asks the resolver.
A PARCEL WITH 79 TENANTS IN COMMON SERVED AS ONE OWNER CONCEALS THAT NO SINGLE HOLDER CAN CONVEY CLEAR TITLE AND ANY ONE
OF 79 CAN FORCE A PARTITION SALE. That is the "both" concealment one level up - NOT A WRONG OWNER, A WRONG COUNT.
AND CC CHECKED BOTH ENDS BEFORE CONCLUDING: the RPC emits 27 of 27 with tenancy, and renderOwnersBlock has NO .slice()
and NO limit. THE DEFECT IS NOT IN THE RPC OR THE RENDER - IT IS IN WHICH COUNTIES REACH THE PER-OWNER BRANCH.
A GREEN RPC WOULD NOT HAVE PROVED IT, WHICH IS WHY CHECKING THE NEXT CONSUMER IS A STANDING RULE.
*** AND PASCO MUST NOT GET THE SAME BRANCH ***
pasco_cama_owners is ONE ROW PER PARCEL with owner_mail_name1 + name2 - the CONTINUATION form. Routing it per-owner
reports one owner where two NAME PARTS sit in two columns. RESOLVE THE SHAPE FROM THE DATA, NEVER FROM A COUNTY LIST.

### 4. shareCheck IS NOT A ROUNDING FLAG - 457 TIC PARCELS HAVE UNALLOCATED INTEREST AND ONE IS 90% MISSING

`measurement` | authority: ISO 19152-1 LA_RRR.shareCheck; LA_BAUnit sum constraint | measured: 2026-08-16 | cc

CC PROPOSED POPULATING LA_RRR.shareCheck AND SAID THE NEAR-MISSES ARE A FINDING ABOUT THE COUNTY RECORD RATHER THAN A
ROUNDING NUISANCE. MEASURED ON 11,448 MULTI-OWNER TIC PARCELS IN VOLUSIA:
  9,971  SUM TO EXACTLY 100          shareCheck TRUE
  1,003  sum 99.5 to 99.999          rounding of repeating fractions - 1/3 recorded as 33.33
    457  SUM WELL UNDER 100, LOWEST 10.000
     17  EXCEED 100, HIGHEST 300.000
THE 457 ARE THE FINDING. A TIC SET SUMMING TO 10% MEANS 90% OF THE OWNERSHIP INTEREST IS UNALLOCATED IN THE COUNTY
RECORD - an unrecorded heir, a lost deed, an incomplete probate, or an interest conveyed and never indexed. FOR A BUYER
THAT IS THE DIFFERENCE BETWEEN BUYING A PROPERTY AND BUYING A LAWSUIT.
THE 17 OVER 100 ARE THE TE DOUBLE-COUNT LEAKING INTO A TIC SET - a tenancy code that contradicts the shares.
THE LA_BAUnit CONSTRAINT sum(RRR.share)=1 IS THEREFORE NOT SOMETHING WE SATISFY - IT IS SOMETHING WE MEASURE AND
REPORT. shareCheck FALSE is a servable due-diligence finding: "the county record allocates only 10% of the ownership
interest in this parcel; the remainder is unaccounted for."
THAT IS THE STANDARD OWN MECHANISM DOING PRODUCT WORK, and it is the third time today ISO 19152 has named a defect we
found independently.

### 5. FOUR COUNTIES, FOUR SHAPES, AND POLK IS BIGGER THAN PINELLAS WITH 844 OWNERS ON ONE PARCEL

`measurement` | measured: 2026-08-16 | claude

CC SAID THREE COUNTIES HOLD PER-OWNER CAMA TABLES. I READ layer_resolution concept=cama_owners AND THERE ARE FOUR -
POLK IS REGISTERED AND WAS MISSED, AND IT IS THE LARGEST EXPOSURE OF ALL.
MEASURED, PARCELS WITH MORE THAN ONE OWNER ROW:
  POLK      186,256 of 436,127 | MORE THAN TWO 29,852 | MAXIMUM 844 OWNERS ON ONE PARCEL
  Pinellas  210,064 of 437,566 | more than two 27,319 | maximum  79
  Volusia   129,123 of 343,841 | more than two  7,288 | maximum  27
  Pasco           0 of 321,781 | MAX 1 ROW - the two-column continuation form
*** FOUR SHAPES, AND THE SCALE DIFFERS TOO ***
  Volusia  PARID on ALT_KEY,          PCTOWN a PERCENTAGE (100 each under TE)
  Pinellas strap via cama_key(),      owner_number ordinal, "SURNAME, FORENAME" with a comma
  POLK     parcel_id direct,          pctown a FRACTION (0.25, 0.0001) - OUT BY 100x FROM VOLUSIA
  Pasco    parcel_num direct,         ONE ROW, name1 + name2 CONCATENATE
*** THE 844-OWNER PARCEL IS NOT HEIRS PROPERTY AND READING IT IS WHAT SHOWED THAT ***
All 844 in DADE CITY, largest share 0.25, then 0.1609, then HUNDREDS AT 0.0001 EACH. SUM: EXACTLY 1.000000.
That is not a family tree - 0.0001 is one ten-thousandth and the names are unrelated. IT IS A SUBDIVIDED-INTEREST
INVESTMENT SCHEME, the pattern behind Florida swamp-lot and fractional-timeshare sales. A DIFFERENT FINDING ENTIRELY
FROM 219 GRAHAM ST, WITH AN IDENTICAL SIGNATURE IN A COUNT.
AND POLK IS CLEAN WHERE VOLUSIA IS NOT: ALL 186,256 MULTI-OWNER PARCELS SUM TO 1, ZERO UNDER-ALLOCATED. Volusia has 457
TIC parcels summing well under 100. SO shareCheck IS A COUNTY-QUALITY MEASURE AS WELL AS A PARCEL FINDING.
THE RULE: A MULTI-OWNER COUNT IS NOT A FINDING UNTIL THE SHARES ARE READ. 27 at 1/6-to-1/168 is heirs property; 844 at
0.0001 is a fractional-interest scheme; 2 at 100 each is a married couple. THE COUNT IS THE SAME SHAPE AND THE THREE
FACTS ARE UNRELATED.

### 6. shareCheck MUST BE TENANCY-AWARE OR IT CRIES WOLF ON A THIRD OF THE COUNTY - AND THERE ARE SIX TENANCY CODES, NOT THREE

`correction` | authority: ISO 19152-1 LA_BAUnit constraint "sum(RRR.share)=1 per type" | measured: 2026-08-16 | claude

CC BUILT shareCheck AND IT IS CORRECT. I THEN MEASURED WHAT IT WOULD SAY ACROSS THE WHOLE COUNTY BEFORE RULING ON THE
RENDER, AND THE ANSWER STOPPED THE RENDER.
  VOLUSIA: 115,767 OF 343,841 PARCELS SUM OVER 100. Polk: 1 of 436,127.
A NAIVE shareCheck WOULD RENDER FALSE ON A THIRD OF VOLUSIA.
BY TENANCY CODE, PARCELS WHERE EVERY OWNER IS RECORDED AT 100 EACH:
  FS  Fee Simple                142,352 parcels | 142,351 at 100 each | 67 over
  TE  Tenancy by the Entirety    82,341 | 82,116 at 100 each | 82,155 OVER 100
  TR  Trust                      24,945 | 24,039 at 100 each |  8,398 over
  LE  Life Estate                19,128 | 19,036 at 100 each |  7,055 over
  JT  Joint Tenancy              15,016 | 15,000 at 100 each | 14,952 OVER 100
  TIC Tenancy in Common          11,011 |     18 at 100 each |      8 over, 11 UNDER
*** SIX CODES, NOT THREE. I HAD RULED ON FS, TE AND TIC AND THERE ARE ALSO TR, LE AND JT. ***
  JT - JOINT TENANCY WITH RIGHT OF SURVIVORSHIP. Like TE it is ONE undivided right, so 100 each is CORRECT and the
    LADM form is LA_GroupParty. 14,952 of 15,016 over 100 BY DESIGN.
  TR - TRUST. The trustee holds legal title at 100%; the beneficiaries are NOT in this table. 100 each is correct and
    the LA_Party is the TRUST, not a person.
  LE - LIFE ESTATE. TWO SIMULTANEOUS INTERESTS: the life tenant and the remainderman, EACH AT 100 of their own estate.
    They are not fractions of one whole. LADM: two LA_Rights of DIFFERENT TYPE over one BAUnit - which is why the
    BAUnit constraint reads "sum(RRR.share)=1 PER TYPE".
*** THAT PHRASE IN THE STANDARD IS NOW LOAD-BEARING AND I HAD READ PAST IT. *** sum(RRR.share)=1 PER TYPE means a life
estate and a remainder each sum to 1 SEPARATELY. shareCheck must group by RRR TYPE, not over all rights on the parcel.
THE RULING: shareCheck IS ONLY MEANINGFUL FOR TIC, AND TIC IS THE ONLY CODE WHERE THE SHARES ARE REAL FRACTIONS OF ONE
WHOLE. For FS, TE, JT, TR and LE the shares are NOT fractions and the sum carries no information - shareCheck must be
NULL with reason not_applicable_tenancy, NOT false.
MEASURED CONSEQUENCE: THE HONEST FALSE POPULATION IN VOLUSIA IS 11 TIC PARCELS UNDER-ALLOCATED, NOT 115,767. CC 457
figure came from a >1-owner filter across all codes; restricted to single-tenancy TIC it is 11 under and 8 over.
A FINDING THAT FIRES ON A THIRD OF A COUNTY IS NOT A FINDING, IT IS NOISE, AND IT WOULD HAVE TRAINED EVERY READER TO
IGNORE THE ONE CASE THAT MATTERS.

### 7. RULED AGAINST CC PROPOSAL - A FRACTION SCALE IS NOT SELF-DESCRIBING, AND POLK PROVES IT WITH 38,134 ZERO SHARES

`correction` | measured: 2026-08-16 | claude

CC PROPOSED: for fraction scale, the sum test is meaningful WITHOUT the tenancy label, because entirety records each
holder at the full share, which on a fraction scale is 1.0 each summing to n. Return TRUE with reason
complete_allocation_tenancy_unknown rather than discarding 186,256 verified Polk allocations.
THE ARGUMENT IS SOUND AND I TESTED IT BEFORE RULING. IT FAILS, AND THE WAY IT FAILS IS THE FINDING.
FIRST TEST - DOES POLK RECORD ENTIRETY AT FULL SHARE? MEASURED, PARCELS BY OWNER COUNT:
  2 owners  156,404 parcels | ALL SUM TO 1.0000 | ZERO SUM TO 2 | min 1.0000 max 1.0000
  3 owners   18,807         | all sum to 1.0000 | zero sum to 3
  4 owners    7,323         | all sum to 1.0000 | zero sum to 4
NO PARCEL ANYWHERE SUMS TO n. On CC reasoning that means Polk has no entirety-style recording and the sum test is safe.
BUT THAT UNIFORMITY IS ITSELF SUSPICIOUS - min and max BOTH exactly 1.0000 across 182,534 parcels is too clean for a
county record. SO I READ THE SHARE DISTRIBUTION ON TWO-OWNER PARCELS:
  0.5000  7,448 rows      <- genuine halves
  1.0000    245 rows  AND  0.0000  245 rows   <- ONE HOLDER AT FULL, ONE AT ZERO
  0.6667 / 0.3333, 0.7500 / 0.2500  <- genuine fractions
*** THAT IS THE ENTIRETY PATTERN RECORDED A THIRD WAY: 1.0 PLUS 0.0. IT SUMS TO 1 AND CONCEALS ITSELF. ***
SCALE, MEASURED ACROSS ALL OF POLK:
  38,134 OWNER ROWS HOLD A ZERO SHARE
  26,151 PARCELS HAVE AT LEAST ONE ZERO-SHARE HOLDER
  15,455 PARCELS HAVE EVERY OWNER BUT ONE AT ZERO
Named holders include "MOSS NAN K REVOCABLE TRUST AGREEMENT", "HINKSON LISA C A", "HOYTE JANICE P" - real parties with
NO RECORDED INTEREST, on a parcel whose shares sum to exactly 1.
THE RULING: NULL, tenancy_not_recorded, AS ORIGINALLY RULED. NOT TRUE.
A sum of 1.0000 on a Polk parcel does NOT mean the allocation is complete - it can mean ONE HOLDER HAS EVERYTHING AND
THE OTHERS ARE NAMED WITH NOTHING. Returning TRUE would assert a verified allocation on 15,455 parcels where the
allocation is the opposite of what the sum implies.
AND A ZERO SHARE IS ITS OWN FINDING, LARGER THAN shareCheck: a named owner at 0% is a lienholder, a life-estate
remainderman, a trustee, a released spouse, or a defect - AND THE COLUMN CANNOT SAY WHICH. Never render 0% as an
ownership share. That is now a separate defect, not a shareCheck case.
CC WAS RIGHT THAT THE COST OF THE GATE IS REAL. The answer is not to loosen the gate; it is that POLK NEEDS ITS TENANCY
FROM ANOTHER SOURCE - polk_parcels_cama or the deed - before shareCheck can speak on 186,256 parcels.

### 8. THE GATE IS A WHITELIST BECAUSE THERE ARE TWELVE-PLUS TENANCY CODES AND 33,182 BLANKS

`rule` | measured: 2026-08-16 | cc

I RULED SIX CODES. CC MEASURED OWNTYPE1_DESC BEFORE BRANCHING AND FOUND TWELVE-PLUS: my six (FS, TE, TIC, TR, LE, JT)
PLUS County, Municipal, Estate, State of Florida TIITF, State Owned - AND 33,182 PARCELS WITH NO TENANCY RECORDED AT ALL.
SO THE GATE IS A WHITELIST: COMPUTE shareCheck FOR TIC AND NOTHING ELSE. Enumerating exclusions breaks on the
thirteenth code, AND A THIRTEENTH ALREADY EXISTS. That is the ELSE-branch rule applied to a whitelist instead of a
classifier - and it is the correct direction here because the SAFE default is silence.
"Estate" IS WORTH ITS OWN NOTE: a decedent estate is a pending transfer, not a stable tenure. "State of Florida TIITF" is
the Trustees of the Internal Improvement Trust Fund - sovereign submerged land, which is the pasco_cama_legal Gulf
campsite finding in an ownership column.

### 9. MY ELEVEN WAS SIX, AND MATERIALLY-UNDER-ALLOCATED IS ZERO - BANDED BEFORE BELIEVED

`measurement` | measured: 2026-08-16 | cc

I RULED THE HONEST FALSE POPULATION AT 11 UNDER AND 8 OVER. CC APPLIED THE GATE, STILL SAW 312 READING "UNDER", AND
BANDED THEM BEFORE BELIEVING EITHER NUMBER:
  exactly 100          10,684   TRUE
  99.00 - 99.99           312   ROUNDING - THREE OWNERS AT 33 EACH. NOT A FINDING.
  100.01 - 101              7   rounding over
  MATERIALLY UNDER 99       0
  materially over 101       6   116.6 to 300
THE HONEST FALSE POPULATION IS SIX, ALL OVER-ALLOCATED. AND THERE IS NO MATERIALLY UNDER-ALLOCATED TIC PARCEL IN
VOLUSIA AT ALL.
THREE FIGURES DISSOLVED IN SEQUENCE: my first "457 well under, lowest 10.000" was counting across all tenancy codes; my
"11 under" was counting without a rounding tolerance; CC own 312 was the same. EACH WAS MEASURED AND EACH WAS WRONG
BECAUSE THE POPULATION WAS WRONG.
±1 POINT TOLERANCE ON PERCENT SCALE IS WHAT SEPARATES 1/3 RECORDED AS 33 FROM AN ACTUAL GAP. Without it the shipped
check would have called 312 rounding cases a finding - THE SAME NOISE PROBLEM ONE ORDER DOWN FROM THE 115,767.
THE LESSON: A COUNT IS NOT A FINDING UNTIL THE POPULATION IS RIGHT AND THE TOLERANCE IS DECLARED. I gave CC a number
three times and it was wrong three times, each time for a different reason.

### 10. min() ACROSS OWNERS PICKED A TENANCY ALPHABETICALLY AND HID THE MIX ON 4,476 PARCELS

`rule` | measured: 2026-08-16 | cc

CC FOUND THIS BUILDING THE RENDER: tenancy.form WAS min(OWNTYPE1_DESC) ACROSS THE OWNER SET. On a parcel with two
tenancy forms recorded, min() RETURNS THE ALPHABETICALLY FIRST AND DISCARDS THE OTHER - silently, on 4,476 VOLUSIA
PARCELS.
A MIXED-TENANCY PARCEL IS NOT A DATA ERROR. It is a life estate beside a remainder, or a TIC share held in trust - TWO
RIGHTS OF DIFFERENT TYPE OVER ONE BAUnit, which is exactly what the LADM constraint sum(RRR.share)=1 PER TYPE exists to
model.
FIXED: tenancy.form IS NULL WHEN MIXED, with forms_recorded beside it listing all of them. And shareCheck returns NULL
reason mixed_tenancy - because you cannot test a sum against one whole when there are two.
THAT IS THE THIRD AGGREGATE THIS RUN THAT MANUFACTURED A SINGLE ANSWER FROM MULTIPLE FACTS: bool_or ignoring NULLs and
turning Zone D plus Zone X into false; count(join rows) inflating a match rate; AND NOW min() ON A CATEGORICAL COLUMN.
AN AGGREGATE OVER A CATEGORICAL COLUMN IS ALWAYS A DEFECT. min, max and first on a code column pick by sort order,
which carries no meaning at all. If the set has more than one value, THE ANSWER IS THE SET OR IT IS NULL.

### 11. THE OWNER PATH SHIPPED END TO END - AND A TEST THAT ASSERTS THE ABSENCE OF AN OBJECT

`measurement` | measured: 2026-08-16 | cc

SHIPPED IN 75bbd76, tsc clean, 32 render controls. THE FULL CHAIN, ALL FOUR SHAPES:
  Volusia  74/533998000100  27 owners  multi_row  percent   100.000  shareCheck TRUE
  Polk     63/2226150000...  844       multi_row  fraction  1.0000   shareCheck NULL tenancy_not_recorded
  Pinellas 52/14 30 01 ...     4       multi_row  none      -        shareCheck NULL not_computed
  Pasco    51/01-24-16-...      1  one_row_continuation     -        NULL
  TE, sum 200                                               shareCheck NULL not_applicable_tenancy
POLK WENT FROM 1 TO 844. PINELLAS FROM 1 TO 4. IF p_co_no = 74 IS GONE.
shareCheck FALSE gets its own bordered line ABOVE the owner list. NULL RENDERS NOTHING - not a dash, not "unknown".
*** AND THE SECOND TEST ASSERTS THAT A not_applicable_tenancy NULL PRODUCES NO shareCheck OBJECT AT ALL. ***
THAT IS A TEST ON AN ABSENCE, AND IT IS THE RIGHT SHAPE. Rendering a null as a dash later WILL FAIL THE SUITE. Every
null-as-value defect this run - 999, -9999, "****", "Does Not Exist", bool_or, the sage border on Zone D - would have
been caught by a test that asserted the absence rather than the presence.
CC ALSO HIT AND FIXED A JSX PARSE FAILURE: a {...} comment in expression position after ? ( parses as an OBJECT LITERAL,
not a comment. Recorded because it cost a build and the error message does not say so.

### 12. ZERO-SHARE OWNERS ARE IN VOLUSIA TOO, ACROSS SEVEN TENANCY FORMS, AND FOUR PARCELS HAVE EVERY OWNER AT ZERO

`measurement` | measured: 2026-08-16 | cc

CC MEASURED VOLUSIA AFTER THE POLK RULING:
  PCTOWN = 0                      57 rows, 46 parcels
  every owner but one at zero     32 parcels
  EVERY OWNER AT ZERO              4 PARCELS
Against Polk 38,134 rows / 26,151 parcels - THREE ORDERS OF MAGNITUDE APART, SAME DEFECT.
*** FOUR PARCELS WHERE EVERY OWNER HOLDS ZERO PERCENT. *** The county names the parties and allocates none of the
interest to any of them. That is not a rounding artefact and not a tenancy convention - it is a record with owners and
no ownership.
AND IT SPANS SEVEN TENANCY FORMS, INCLUDING TWO MORE CODES BEYOND THE TWELVE: "Lease Hold" and "Purchase Under
Contract". SO A ZERO SHARE IS NOT A PROPERTY OF ONE TENANCY, which is what would have made it explainable. Fourteen-plus
codes now, and the whitelist is vindicated a third time.
"Purchase Under Contract" IS ITSELF A FINDING: an equitable interest under a contract for deed, recorded as an owner at
0%. The buyer under such a contract has a real interest and no legal title - and 0% is arguably the county recording
that correctly.
SHIPPED: share_status = recorded | zero_recorded | not_recorded. pctOwn SUPPRESSED for zero so it can never print "0% as
recorded". THE PARTY IS STILL NAMED - suppressing them would be worse than mis-stating the share. The note infers
nothing about why.
AND THE TEST IS THE RIGHT SHAPE: it asserts the party IS PRESENT AND pctOwn IS NULL. Assert-the-absence, aimed at the
thing that must not render.

## 42-explicit-negatives

### 1. AN EXPLICIT NEGATIVE STORED AS A VALUE IS A THIRD FORM OF SENTINEL, AND FOUR TABLES IN ONE BATCH CARRY ONE

`principle` | measured: 2026-08-16 | claude

READING 14 JOIN-PROVED TABLES FOUND THE SAME SHAPE FOUR TIMES: A LAYER WHOSE MEMBERSHIP DOES NOT MEAN WHAT ITS NAME
IMPLIES, BECAUSE THE STORED VALUE SAYS OTHERWISE.
  hillsborough_historic_resources  type = "NOT A LANDMARK" alongside "Historic Landmark". Presence in a historic
    resources layer therefore does NOT mean landmark status - it holds surveyed resources of which some were assessed
    and DECLINED. Serving presence would assert a designation the county explicitly refused.
  broward_ev_charging  add_type = "DOES NOT EXIST" and "Planned" alongside PUBLIC, on a layer 81.5% of probes hit. A
    charger that does not exist, served as an amenity.
  collier_planned_unit_developments  status = "SUNSET" - AN EXPIRED ENTITLEMENT. Serving it as live zoning would tell a
    buyer they hold development rights that have LAPSED. That is the inverse of a false clearance: AN AFFIRMATIVE FALSE
    PERMISSION, and it is the more dangerous direction.
  hifld_fuds_sites  eligibility = "Eligible" MEANS ELIGIBLE FOR THE CLEANUP PROGRAMME, SO ELIGIBLE IS THE WORSE
    FINDING. "Categorical Exclusion" means excluded from the programme, NOT that the land is clean. And status
    "Properties without projects" means A HAZARD IDENTIFIED AND UNADDRESSED - a finding, not an absence.
THE FIRST TWO SENTINEL FORMS WERE ABSENCE-AS-VALUE (999, -9999, blank-not-null, "****") AND WRONG-CATEGORY-IN-COLUMN
(Estuarine Deepwater in wetlands, OPEN WATER in flood, TILE ROOF in bldshape). THIS IS THE THIRD: A VALUE THAT
CORRECTLY RECORDS A NEGATIVE, IN A LAYER WHOSE PRESENCE IS BEING READ AS A POSITIVE.
IT IS THE MOST DANGEROUS OF THE THREE BECAUSE THE DATA IS CORRECT. Nothing is malformed, nothing is missing, no
crosswalk is needed - the only error is treating membership as the answer. NEVER SERVE PRESENCE-IN-LAYER WHERE THE
LAYER CARRIES A STATUS COLUMN.

### 2. THE EXPIRED-ENTITLEMENT CLASS NOW HAS THREE MEMBERS AND TWO CARRY NO DATE AT ALL

`principle` | authority: s.161.053 F.S.; s.290.001-290.016 F.S. sunset 2015 | measured: 2026-08-16 | claude

READING 14 MORE JOIN-PROVED TABLES FOUND THE SUNSET PUD PATTERN TWICE MORE, AND THE WORST CASE HAS NOTHING IN THE TABLE
TO WARN YOU:
  collier_planned_unit_developments  status = "SUNSET" - the table SAYS SO. Filterable.
  charlotte_cccl                     year = 1985. A COASTAL CONSTRUCTION CONTROL LINE FORTY-ONE YEARS OLD. Seaward of
    the CCCL, s.161.053 F.S. requires a STATE FDEP PERMIT for any construction, on a 100-year-storm standard. FDEP
    RE-ESTABLISHES THE LINE BY COUNTY AND CHARLOTTE HAS MOVED SINCE. Serving a 1985 line puts a parcel on the wrong
    side of a state permitting requirement IN EITHER DIRECTION. year is not metadata here - IT IS THE MOST IMPORTANT
    COLUMN IN THE TABLE.
  charlotte_enterprise_zone          NO DATE COLUMN, NO STATUS, NO EXPIRY. AND FLORIDA ENTERPRISE ZONES EXPIRED ON
    31 DECEMBER 2015 - s.290.001-290.016 sunset and were not renewed. THE INCENTIVES THIS BOUNDARY CONFERRED NO LONGER
    EXIST AND NOTHING IN THE TABLE SAYS SO. Classed EXT_Context, not EXT_Regulatory, BECAUSE IT REGULATES NOTHING ANY
    MORE.
THE PATTERN: AN AFFIRMATIVE FALSE PERMISSION. Not a false clearance - the inverse. Telling a reader they hold a right,
an incentive or a permitted use that has LAPSED.
AND IT IS THE HARDER FAILURE TO DETECT, BECAUSE THE THREE-COVERAGE-STATE RULE DOES NOT REACH IT. present /
none_recorded / not_available all assume the fact is either there or not. A SUNSET ENTITLEMENT IS PRESENT AND EXPIRED,
and only the statute tells you which.
REQUIRED: EVERY REGULATORY LAYER NEEDS ITS PROGRAMME STATUS ESTABLISHED EXTERNALLY, NOT READ FROM THE TABLE. Two of the
three above cannot be caught by any amount of reading the data.

### 3. A COUNTER-EXAMPLE - fl_city_limits CARRIES is_active AND THE LOAD ALREADY HONOURED IT

`test` | measured: 2026-08-16 | cc

CC FOUND is_active ON fl_city_limits - EXACTLY THE STATUS-COLUMN TRAP - AND THEN CHECKED WHETHER IT LEAKS INSTEAD OF
FILING A DEFECT.
  411 ACTIVE, ONE FALSE: WEEKI WACHEE, "DISINCORPORATED ON JUNE 9, 2020" IN ITS OWN notes COLUMN.
  geo_id NULL | ABSENT FROM geo_reference (which holds 412 municipalities) | ZERO LAYERS RESOLVE TO IT
THE LOAD HONOURED THE STATUS COLUMN. No parcel can resolve into a city that no longer exists.
THAT IS THE COUNTER-EXAMPLE TO THE FOUR NEGATIVE-VALUE TABLES - "Not a Landmark", "Does Not Exist", SUNSET, and
eligibility "Eligible". THE TRAP IS NOT THAT A STATUS COLUMN EXISTS; IT IS WHETHER ANYTHING READS IT.
SO THE CHECK IS TWO-PART AND CC RAN BOTH: does the layer carry a status value that contradicts its presence, AND DOES
THE SERVING PATH FILTER ON IT. One without the other is either a false alarm or a live defect, and only measuring tells
you which.
WEEKI WACHEE IS ALSO A GENUINE HISTORICAL FACT WORTH KEEPING: a Florida city that ceased to exist in 2020, and the
municipal boundary data is 2021 vintage - so it is correctly absent, and any pre-2020 document referencing it is not
wrong, just historical.

## 43-restrictions-hiding

### 1. FOUR TABLES I WOULD HAVE CALLED CONTEXT ARE LA_RRR, AND THE OBLIGATION TEST IS WHAT SEPARATES THEM

`principle` | authority: s.161.163, s.379.2431 F.S.; Ch.163 Pt III | measured: 2026-08-16 | claude

FROM ONE BATCH OF FOURTEEN:
  charlotte_sea_turtle_lighting_zones  I WOULD HAVE FILED THIS AS ENVIRONMENTAL CONTEXT. It is an ENFORCEABLE
    RESTRICTION ON EXTERIOR LIGHTING under s.161.163 and the Marine Turtle Protection Act s.379.2431 - shielded
    fixtures, amber wavelengths, seasonal limits 1 May to 31 October, WINDOW TINTING ON BEACHFRONT UNITS, and penalties.
    IT CHANGES WHAT AN OWNER MAY DO ON THEIR OWN LAND. LA_RRR.
  charlotte_impact_fee_zones (x2)      AN IMPACT FEE IS A REAL CHARGE LEVIED AT PERMIT. LA_RRR.
  charlotte_cras                       Ch.163 Part III - tax increment and design controls. LA_RRR. FOURTH COUNTY with
    CRA data after Volusia (flag), Collier (name + year), Palm Beach (numeric code, no lookup); CHARLOTTE GIVES THE NAME.
THE TEST, RESTATED BECAUSE IT KEEPS EARNING ITS PLACE: DOES CROSSING THIS BOUNDARY CHANGE WHAT THE OWNER OWES OR MAY DO?
A school does not. A turtle lighting zone does. THE SUBJECT MATTER SOUNDS ENVIRONMENTAL AND THE EFFECT IS REGULATORY,
which is exactly how the environmental_overlay error happened the first time.
AND TWO WITH NO CROSSWALK: turtlezone "Zone 15" and impact fee zone "103" ARE OPAQUE NUMBERS. The zone tells a reader
nothing; the ordinance section it maps to is the fact, AND WE DO NOT HOLD IT. Serve the presence and the authority,
never the bare zone number.

### 2. fdep_source_water_protection - HELD BACK, THEN READ, AND THE READING JUSTIFIED HOLDING IT

`test` | authority: F.A.C. 62-521 | measured: 2026-08-16 | cc

CC DECLINED TO DECLARE THIS TWO TURNS AGO RATHER THAN GUESS WHETHER A PROTECTION AREA IMPOSES AN OBLIGATION. Reading it:
  ATTRIBUTES: AQUIFER, PWS_ID, WELL_ID. NO RESTRICTION FIELD. NO STATUTORY CITATION.
It identifies WHICH WATER SYSTEM AND WHICH WELL - not what is prohibited near them.
Florida regulates wellhead protection under F.A.C. 62-521, BUT THE LAYER DOES NOT SAY WHETHER IT DELINEATES THAT
REGULATORY RADIUS OR THE WIDER ASSESSMENT AREA - AND THOSE ARE DIFFERENT OBLIGATIONS. One is a prohibition on siting; the
other is a study boundary.
DECLARED EXT_Context, NOT EXT_Regulatory. Serving it as a restriction would assert a prohibition whose radius we cannot
establish - the environmental_overlay error with a statute attached, which is worse than without one.
AND CC CAUGHT A PROVENANCE CONFUSION IN THE SAME TABLE: the note mentioning "metric-2 eligible" IS OUR OWN ANNOTATION
ABOUT A METRIC, NOT THE PUBLISHER CAVEAT. Our commentary had migrated into a field read as source metadata - the same
shape as restriction_class holding our own "LA_Restriction" literal, and the third time our own labels have been found
inside data we treat as external.

## 44-census

### 1. A POPULATION OF ONE CANNOT BE SAMPLED - THE FIFTH FORM OF THE UNDERPOWERED ZERO, AND THE FIRST WHERE THE ANSWER IS TO STOP SAMPLING

`principle` | measured: 2026-08-16 | claude

THE LAST 51 UNPROVED TABLES HAD ALL BEEN TRIED BOTH WAYS. I read WHY they failed instead of re-running the same probes,
AND 22 OF THEM ARE ONE-TO-TWO-ROW POINT LAYERS: ONE HOSPITAL OR ONE PRIVATE SCHOOL IN A RURAL COUNTY.
  gadsden_hospitals    2 ROWS, verdict MEASURED_SPARSE_IN_EXTENT on 1 hit of 200 probes
  holmes_private_schools, madison_private_schools, dixie_private_schools, gulf_hospitals   ONE ROW EACH
NO PROBE OF 200 OR 1,340 PARCELS CAN MAKE TWO POINTS DENSE. "MEASURED_SPARSE" on gadsden_hospitals was a statement
that GADSDEN COUNTY HAS TWO HOSPITALS - true, and not a fact about the join.
*** THE FIX IS A CENSUS, NOT A LARGER SAMPLE. *** verify_tiny_layer asks: DOES EVERY FEATURE RESOLVE TO A PARCEL, with n
= the row count. Controls unchanged and still required to return zero.
  gadsden_hospitals: 2 FEATURES, 2 RESOLVED, both controls 0.
  17 LAYERS RUN, 17 PASS_CENSUS AT 100%, features ranging from 1 to 412.
SAMPLE SIZE CANNOT FIX A POPULATION OF ONE. Every previous correction made the sample better - right predicate, right
scope, right direction, right radius, more points. THIS ONE ABANDONS SAMPLING BECAUSE THE POPULATION IS SMALLER THAN ANY
USEFUL SAMPLE.
FIVE FORMS NOW, ALL PRODUCING AN IDENTICAL CLEAN ZERO:
  1 sparse layer, parcel-side draw        -> invert the draw
  2 wrong predicate for the geometry      -> match predicate to ST_GeometryType
  3 radius too tight for the feature count -> scale the radius
  4 statewide draw against a county layer  -> draw in the layer scope
  5 POPULATION SMALLER THAN THE SAMPLE     -> CENSUS EVERY FEATURE
AND THE COST BOUNDARY IS MEASURED: the census runs cleanly up to ~500 rows in batches of 25, and rolls back on timeout
above ~3,000. So it is the right instrument for tiny layers and the WRONG one for large ones - which is exactly the
inverse of the sampling probe. TWO INSTRUMENTS, ONE ROW-COUNT THRESHOLD BETWEEN THEM.

## 45-join-not-data

### 1. THE 194 SOURCE GAP WAS MY JOIN. FOUR SPELLINGS OF ONE COUNTY, IN OUR OWN REGISTRY.

`correction` | authority: Murphy | measured: 2026-08-16 | murphy

MURPHY ASKED WHY 194 TABLES NEEDED A SOURCE WHEN I HAD BUILT provenance_all AND before_you_declare_a_gap. He was right
to. I BUILT THE INSTRUMENT AND THEN REPORTED THE GAP WITHOUT CHECKING WHETHER MY OWN JOIN WORKED.
*** data_source_registry HOLDS FOUR NAMES FOR ONE COUNTY: "Miami-Dade", "Miamidade", "Municipal", "Statewide". ***
provenance_all joined county_coverage_status ON county_name EQUALITY. NONE OF THE FOUR MATCHED "Miami-Dade". Thirteen
Miami-Dade tables read as source-less WHILE THE HUB URL SAT IN A ROW I HAD ALREADY READ AND QUOTED TO CC.
AND CITY ROWS NEEDED THEIR OWN PATH. county_coverage_status carries "St. Petersburg (city)", "Daytona Beach (city)",
"Tampa (city)" - A CITY PREFIX NEVER MATCHES A COUNTY NAME. daytonabeach_* resolved only after adding a city-prefix path
AND a parent-county path.
FIXED: RESOLVE ON co_no, NEVER ON A NAME. resolve_scope_co survives all four spellings.
MEASURED EFFECT OF FIXING ONE JOIN:
  provenance_all   1,277 -> 1,896 tables      refreshable  1,139 -> 1,295
  SHELVED          1,105 -> 1,223             need_source    194 -> 41
SIX HUNDRED AND NINETEEN TABLES RECOVERED. THE REGISTRIES WERE NEVER THE PROBLEM.
AND CC PLANNING NOTE WENT STALE IN THE SAME MINUTE: they measured that only 3 OF 78 join-proved-awaiting-read were
refreshable, so "one read each shelves them" held for 3. AFTER THE JOIN FIX IT IS 74 OF 74. Their analysis was correct
against the state they measured; MY BROKEN JOIN WAS THE BLOCKER THEY WERE MEASURING.
THE LESSON, TURNED ON US: NAMES LIE - INCLUDING OUR OWN COUNTY NAMES, IN OUR OWN REGISTRY. Four spellings of Miami-Dade,
written by us, in the table we call the source of truth. Every rule about county names lying applies to the names we
wrote ourselves.

## 46-endpoints-in-history

### 1. THE EXACT LAYER ENDPOINTS ARE IN THE CONVERSATION HISTORY, IN THE PULL SCRIPTS THAT LOADED THE TABLES

`correction` | authority: Murphy; conversation history 2026-07-20 | measured: 2026-08-16 | murphy

MURPHY: "I told you not to leave anything unfinished. FIND THE ENDPOINTS IN THE CHAT HISTORY." They are there, with the
layer index, in the ogr2ogr script that ran the load.
RECOVERED EXACT ENDPOINTS - 22 TABLES:
  putnam_parcels        pamap.putnam-fl.gov/server/rest/services/CadastralData/MapServer/2
                        COUNT VERIFIED AT PULL TIME: curl returnCountOnly = 97,815, AND OUR TABLE HOLDS 97,815.
  putnam subdivisions/lots/blocks/easements   same service, MapServer/0, /3, /4, /5
  putnam fire_stations/zoning/evac/flu        services1.arcgis.com/YZc1OyqL6jbIOeOv/...__new_hub/FeatureServer/0
  hernando 6 layers     services2.arcgis.com/x5zvhhxfUuRDntRe/.../Parcels|Subdivisions|Hospitals|Evacuation_*
  manatee 11 layers     services1.arcgis.com/t03WDvnSR7gSDOB2/.../GIS_PARCELS|ADDRESS_POINTS/FeatureServer/2|
                        ZONEOFFICIAL|SCHOOLS_ALL|PARKS|EVACUATION_LEVELS/FeatureServer/20
                        plus mymanatee.org/gisits/rest/services/opendata/utilities/FeatureServer/37|7|14
  lee_address_points    services2.arcgis.com/LvWGAAhHwbCJ2GMP/.../NG911_Address_Points/FeatureServer/0
  sarasota evac/hydrants ags3.scgov.net/server/rest/services/Hosted/...
THE PULL PATTERN IS ALSO IN THE RECORD AND IS NOW ON EVERY RECOVERED ROW:
  ogr2ogr -f PostgreSQL "${url}/query?where=1=1&outFields=*&returnGeometry=true&f=json"
    -oo FEATURE_SERVER_PAGING=YES -nlt PROMOTE_TO_MULTI -t_srs EPSG:4326 -lco GEOMETRY_NAME=geom
*** AND THE DISTINCTION IS RECORDED PER ROW, NOT GLOSSED *** access_technique is either
arcgis_rest_ogr2ogr_paging (AN EXACT LAYER ENDPOINT, refreshable as-is) or
arcgis_host_only_layer_path_unrecovered (A HOST, sufficient to find the service, NOT a verified endpoint). Twenty-two
are exact. The rest are hosts and say so.
FOUR THINGS I HAD CALLED UNRECOVERABLE AND FOUND IN ONE SEARCH:
  putnam_parcels endpoint AND its verified count | hernando_parcels, which the history shows FAILED 1 of 6 and was
  never completed | the manatee EVACUATION_LEVELS layer index 20 - NOT 0, which no pattern would guess | the
  mymanatee.org utilities service, a SECOND HOST for one county.
THE STANDING RULE: THE PULL SCRIPT IS PROVENANCE. It carries the host, the service, THE LAYER INDEX, the paging flag,
the SRID and the geometry column name - everything a registry row needs and more than county_coverage_status holds. The
conversation history is a source of record and searching it is not optional.

## 47-final-joins

### 1. THIRTY-NINE SPATIAL AND THIRTY-THREE RELATIONAL NEVER GOT A RUN - MY BATCHES STOPPED AT AN ALPHABETICAL BOUNDARY

`correction` | authority: Murphy | measured: 2026-08-17 | claude

MURPHY RULED: DO THE 72 JOINS FIRST, THE HARD ONES, AND THE REST MAY GET EASIER. He was right and the reason is that
reading WHY they had not joined answered a question the count could not.
MEASURED: OF THE 72, THIRTY-NINE SPATIAL AND THIRTY-THREE RELATIONAL HAD NO VERIFICATION RUN OF ANY KIND. They were not
failures. THE BATCHES STOPPED AT AN ALPHABETICAL BOUNDARY - every table from palmcoast to westpalmbeach, and every
santarosa/stjohns/stlucie/wakulla/walton/washington relational - AND I HAD BEEN REPORTING THEM AS "join not proved" AS
THOUGH THEY HAD BEEN TESTED AND LOST.
FOUR MORE ALREADY HELD A PASSING RUN AND HAD NEVER BEEN GRADED, INCLUDING TILING_COVERAGE, WHICH MY GRADING UPDATE DID
NOT LIST AS A PASS VERDICT.
AND FOUR VOLUSIA CAMA TABLES KEYED CLEANLY THE MOMENT THEY WERE ASKED:
  volusia_cama_comm_bldg            1,579 of 1,580 distinct = 99.94%, control 0
  volusia_cama_condo_misc           2,658 of 2,667 = 99.66%
  volusia_cama_agland               2,167 of 2,179 = 99.45%
  volusia_cama_comm_bldg_refinement 1,096 of 1,114 = 98.38%
ALL ON PARID JOINING ALT_KEY - THE TRANSFORM ALREADY PROVED ON SIX SIBLING TABLES. They sat in the unproved pile because
NOTHING HAD ASKED THEM THE KEY QUESTION, not because the answer was no.
THE LESSON: A COUNT OF "NOT PROVED" CONFLATES TESTED-AND-FAILED WITH NEVER-TESTED, AND I DID NOT SEPARATE THEM FOR
SEVERAL TURNS. Report attempted and unattempted separately, or the queue looks like a wall of failures when most of it
has never been touched.

## 48-fips-join

### 1. A FOURTH JOIN QUESTION - A STATEWIDE TABLE OF COUNTY-SCOPED FACTS JOINS ON A FIPS CODE, NOT A NAME

`open` | measured: 2026-08-17 | claude

THE LAST 22 UNPROVED TABLES ARE ONE SHAPE:
  7 *_disaster_declarations | 7 *_burn_detection_history | 6 *_superfund_facilities
  1 fl_historical_aqi_by_area | 1 clay_flood_zones
ALL RETURNED no_scope OR no_jurisdiction_column. TWO OF THEM - epa_superfund_facilities AND fema_disaster_declarations -
ARE STATEWIDE TABLES WITH NO COUNTY PREFIX AT ALL, so resolve_scope_co returns NULL and the jurisdiction probe cannot
even begin.
*** BUT alachua_disaster_declarations CARRIED fipsStateCode 12 AND fipsCountyCode 001. THE COUNTY IS IN THE ROW AS A
CODE, AND MY PROBE READS NAMES. ***
SO THE THIRD JOIN TYPE HAS A SECOND FORM: jurisdiction-by-NAME (designatedArea "Alachua (County)", county_name ALACHUA)
AND jurisdiction-by-FIPS (12 + 001). A statewide table of county-scoped facts uses the code because it must be
unambiguous across 3,143 US counties; a county-scoped extract uses the name because it only has one.
NOT BUILT, AND DELIBERATELY SO. I have added four join instruments today and each one taught me something the previous
one could not see. THE FIPS FORM IS A FIFTH AND IT NEEDS THE SAME DISCIPLINE: a control that can fail, which here means
THE ROW MUST CARRY ITS OWN COUNTY FIPS AND NOT THE NEIGHBOUR'S.
RECORDED AS AN OPEN QUESTION RATHER THAN COUNTED AS A FAILURE. Twenty-two tables are waiting on an instrument that does
not exist yet, which is a different state from twenty-two tables that failed a test.

### 2. THE FOURTH JOIN TYPE IS BUILT - AND THE FIPS BRIDGE WAS ALREADY IN THE TABLES

`measurement` | measured: 2026-08-18 | claude

I RECORDED THE FIPS JOIN AS AN OPEN QUESTION YESTERDAY AND DID NOT BUILD IT. Building it today, THE COLUMNS WERE
ALREADY THERE:
  derived_county_fips | std_county_fips | county_fips | fipsCountyCode | fips_code
*** SOMEONE BUILT THE FIPS BRIDGE AND THE JURISDICTION PROBE NEVER LOOKED FOR IT. *** It read NAMES only, so
epa_superfund_facilities returned no_scope (no county prefix to resolve) and stlucie_superfund_facilities returned
ZERO_NAME_MISMATCH - both while carrying derived_county_fips populated.
MEASURED WITH A CONTROL THAT CAN FAIL:
  epa_superfund_facilities      617 of 646 = 95.51%   control 0
  fema_disaster_declarations  2,705 of 2,794 = 96.81%  control 0
  stlucie_superfund_facilities    3 of 3 = 100.00%     control 0
  SEVEN TABLES PASS_JURISDICTION_FIPS, 95.51% TO 100.00%, EVERY CONTROL ZERO.
*** THE CONTROL DIFFERS BY SCOPE, WHICH IS THE LESSON FROM THE 50 INAPPLICABLE WRONG-COUNTY CONTROLS APPLIED FORWARD: ***
  COUNTY TABLE     control = the NEAREST OTHER COUNTY FIPS. It can fail.
  STATEWIDE TABLE  control = A NON-FLORIDA STATE FIPS (13 = Georgia). It can also fail - unlike the wrong-county
                   control, which is vacuous on a statewide layer because the neighbour is inside it.
FOUR JOIN TYPES NOW, EACH WITH ITS OWN CONTROL:
  key-to-parcel         same key, WRONG COUNTY
  containment           parcels from the NEAREST OTHER COUNTY (county layers) or a 9-degree displacement (statewide)
  jurisdiction by NAME  the table names ITS OWN county, not the neighbour
  JURISDICTION BY FIPS  the code is ITS OWN county, or a non-Florida state
AND THE CONVERSION IS THE TRAP I HIT EARLIER TODAY: geo_id IS THE FIPS AND dor_co_no IS NOT. VOLUSIA IS DOR 74 AND FIPS
127. verify_fips_join converts between them, and without that conversion every match would have been to the wrong county
- silently, because both are plausible three-digit numbers.

### 3. THE FIPS BRIDGE HAS FOUR COLUMN NAMES AND TWO LENGTHS - AND I ASSUMED THE LENGTH TWICE

`correction` | measured: 2026-08-19 | claude

EXTENDING verify_fips_join TO THE STATISTICAL TABLES FOUND THE BRIDGE UNDER FOUR MORE NAMES:
  area_fips     bls_qcew_county        2,260 of 2,260 = 100.00%, control 0
  geoid         alachua_census_boundaries  160 of 160 = 100.00%, control 0
  county        census_acs_data       13,388 of 13,388 = 100.00%, control 0
  county_fips   bls_laus_county          100.00%, control 0
*** AND census_acs_data BROKE THE FUNCTION IN A WAY THAT RETURNED ZERO RATHER THAN ERRORING. ITS county IS A BARE
THREE-DIGIT COUNTY FIPS - 001, 003, 005 - WITH NO STATE PREFIX. MY lpad TO FIVE TURNED 001 INTO 00001 AND MATCHED
NOTHING, SILENTLY. ***
A CLEAN ZERO FROM A 13,388-ROW TABLE, AND THE ONLY REASON I CAUGHT IT IS THE ABORT-ON-ZERO RULE. Had I accepted it the
verdict would have read ZERO_FIPS_MISMATCH - "this table names the wrong county" - WHICH IS A STATEMENT ABOUT THE DATA
WHEN THE FAULT WAS ENTIRELY MINE.
FIXED BY MEASURING THE LENGTH INSTEAD OF ASSUMING IT: max(length()) decides whether the value is a 5-digit state+county
code or a bare 3-digit county. THREE-DIGIT VALUES ALSO CANNOT SUPPORT THE STATEWIDE CONTROL - there is no state prefix
to make Georgia with - so that control is DECLARED INAPPLICABLE rather than faked.
*** THAT IS THE THIRD TIME TODAY A LENGTH OR A FORMAT ASSUMPTION PRODUCED A SILENT ZERO: the Pinellas 18-char STRAP in
two component orders, geo_id as FIPS against dor_co_no, and now a 3-digit versus 5-digit FIPS. A LENGTH MATCH IS NOT A
FORMAT MATCH AND A FORMAT ASSUMPTION FAILS QUIETLY. ***
AND bebr_county_estimates AND bebr_county_projections HAVE NO FIPS COLUMN AT ALL - THEY JOIN BY county_name, and one of
their rows is "Florida", A STATE TOTAL SITTING IN A COUNTY TABLE. Any per-county aggregate that does not exclude it
double-counts the entire state.

## 49-audit

### 1. I SAID EVERYTHING WAS LOGGED AND THE AUDIT SAID OTHERWISE ON SIX COUNTS

`correction` | authority: Murphy | measured: 2026-08-17 | claude

MURPHY ASKED "EVERYTHING LOGGED?" I CHECKED INSTEAD OF ANSWERING, AND THE ANSWER WAS NO:
  0      lens entries for that turn - the never-ran finding, four Volusia keys, the FIPS question, sjc_plat_index
  70     CLASSIFIED TABLES WITH NO RATIONALE over 40 characters
  34     E0_key GRADES WITH NO ROW IN key_verification_run
  1      E0_containment grade with no containment run
  88     key runs marked superseded and NEVER RE-MEASURED under the corrected distinct-key count
  1,166  LIVE PASSES RESTING ON THE VACUOUS DISPLACED CONTROL ALONE - only 95 were re-checked
*** THE TWO THAT MATTER ***
34 E0_key GRADES HAVE NO EVIDENCE ROW. My own ruling: a grade with no row in key_verification_run IS AN ASSERTION, NOT A
MEASUREMENT. They slipped in through rationale-only updates where I recorded the measurement IN PROSE and never wrote
the row. The prose is not the evidence; the row is.
1,166 PASSES REST ON A CONTROL I PROVED CANNOT FAIL. A 9-degree displacement against a layer 0.6 degrees tall guarantees
a miss. I measured that, re-checked 95 under the wrong-county control - ALL CLEAN - AND THEN KEPT COUNTING THE OTHER
1,166 AS SHELVED. Probably fine is not the standard I have spent the day enforcing on everything else.
*** AND IT IS THE SAME SHAPE AS EVERY OTHER FAILURE TODAY: I FIXED THE INSTRUMENT, VERIFIED A SAMPLE, AND STOPPED
BEFORE THE POPULATION. *** Identical to the 80-of-173 re-measure, the batches that stopped alphabetically, and the 619
tables hidden behind a broken join.
SO 1,299 IS THE COUNT UNDER THE CORRECTED DEFINITION AND THE FULLY-EVIDENCED NUMBER IS LOWER AND UNKNOWN. Both figures
are now on the record and the second is the one to close.

### 2. EVIDENCE DEBT CLOSED - AND ALL 32 UNGROUNDED GRADES TURNED OUT TO BE RIGHT, WHICH IS NOT THE SAME AS BEING EVIDENCED

`measurement` | authority: Murphy | measured: 2026-08-18 | claude

MURPHY ASKED "EVERYTHING LOGGED?" AND THE AUDIT SAID NO ON SIX COUNTS. ALL SIX ARE NOW CLOSED.
  1,166 -> 1,295 -> FULLY EVIDENCED AFTER THE BACKFILL
  63 SHELVED TABLES WITH NO RATIONALE -> ZERO
  32 E0 GRADES WITH NO EVIDENCE ROW -> ZERO
  181 UNCHECKED CONTROLS -> ZERO (1,096 evidenced, 50 declared inapplicable, 1 leak resolved)
  238 UNEVIDENCED topological CLAIMS -> RETRACTED
*** THE 32 WERE THE HIGHEST-VALUE TABLES WE HOLD AND THEY CARRIED A GRADE WITH NOTHING BEHIND IT: ***
volusia_cama_owner, volusia_cama_sales, volusia_cama_permits, polk_owners, polk_sales, ten DOR NAL/SDF sources, and
twelve county parcel spines. THE ENTIRE OWNERSHIP AND SALES BACKBONE.
RE-MEASURED RATHER THAN TRUSTED. EVERY ONE HELD:
  volusia_cama_owner   2,018 of 2,022 distinct = 99.80%, control 0
  polk_owners          1,758 of 1,762 = 99.77%
  volusia_cama_sales     655 of 747 = 87.68% - THE LOWEST, AND STILL PASSING
  nineteen key runs, 87.68% to 99.87%, EVERY CONTROL ZERO
  eight parcel spines at 100.00% containment
*** THEY WERE ALL RIGHT. THAT IS THE POINT AND NOT THE DEFENCE. *** A grade with no row is an assertion that happens to
be true, and there was no way to know which it was without re-running - which cost four queries and would have cost far
more if one had failed after being served.
AND TWO OF THE THIRTY-TWO ARE A FINDING IN THEMSELVES: palmbay_city_parcels AT 0.50% AND
pinellas_NON_RECOGNIZED_parcels AT 0.00% AGAINST THE PARCEL SPINE. *** BOTH ARE NAMED AS EXCEPTIONS TO THE SPINE -
"non-recognized" parcels are BY DEFINITION ONES THE COUNTY SPINE DOES NOT RECOGNISE - SO A LOW IN-EXTENT RATE IS THE
EXPECTED RESULT AND ARGUABLY THE POINT OF THE LAYER. *** Inverted: 120 of 120 both, controls zero. THE NAME PREDICTED
THE MEASUREMENT, which is the one case today where a name told the truth.

## 50-elevation-cert

### 1. CHARLOTTE PUBLISHES THE ELEVATION CERTIFICATE PDF PER PROPERTY - THE DOCUMENT WE RULED WE COULD NOT COMPUTE

`measurement` | authority: PIR_REPORT_SPEC_v5 Part 0.2; NGVD29/NAVD88 | measured: 2026-08-17 | claude

charlotte_certificate_elevation.link:
  data.charlottecountyfl.gov/CCGIS/PDFs/Elevation_Certificates/2006080795.pdf
PIR_REPORT_SPEC_v5 RULES THAT NO BFE DIFFERENCE MAY BE COMPUTED FROM A DEM SAMPLE - "A DEM SAMPLE IS NOT A LOWEST-FLOOR
ELEVATION AND THE VALUE WOULD BE INDISTINGUISHABLE FROM FREEBOARD". That ruling followed the incident where an elevation
figure was fabricated seven times with escalating false precision.
*** AN ELEVATION CERTIFICATE IS THE SURVEYED LOWEST FLOOR, SIGNED BY A LICENSED SURVEYOR. IT IS THE DOCUMENT THAT
ANSWERS THE QUESTION WE RULED WE COULD NOT ANSWER - AND THE COUNTY PUBLISHES IT, LINKED PER PROPERTY. ***
WE DO NOT COMPUTE IT. WE LINK IT. That is the correct form: the fact stays in a signed instrument and we route the
reader to it, which is what "who can answer" was always for.
*** AND THE DATUM TRAP IS SEVERE. *** datum = "NGVD 1929". FEMA FIRM PANELS ARE NAVD88. THE OFFSET IN FLORIDA IS ROUGHLY
1.0 TO 1.5 FEET AND VARIES BY LOCATION. SUBTRACTING AN NGVD29 CERTIFICATE FROM AN NAVD88 BFE PRODUCES A NUMBER THAT
LOOKS EXACTLY LIKE A FREEBOARD FIGURE AND IS WRONG BY MORE THAN MOST FREEBOARD REQUIREMENTS. NEVER SUBTRACT ACROSS
DATUMS - read the datum column first, and if the two differ, say so rather than converting silently.
THIS IS THE SEVENTH TIME TODAY A COUNTY HAS ALREADY SOLVED SOMETHING WE RECORDED AS UNSOLVABLE.

### 2. CHARLOTTE FLOOD CARRIES THREE INDEPENDENT FLAGS AND A ZONE CODE WITH A DEPTH GLUED TO IT

`measurement` | authority: Coastal Barrier Resources Act 16 U.S.C. 3501 | measured: 2026-08-17 | claude

charlotte_flood_zones_2022: fzone = "8AE". NOT "AE". A ZONE CODE WITH THE BFE OR DEPTH PREFIXED. ANY IN-LIST ON
STANDARD FEMA CODES MISSES IT ENTIRELY - and that is now the tenth distinct flood-domain shape after the seven
spellings of the 0.2% zone, Duval comma-joined multi-zones, and Lee CAZ.
AND THE TABLE CARRIES THREE SEPARATE FLAGS THE ZONE STRING DOES NOT:
  sfha = "IN"          AN EXPLICIT COUNTY-PUBLISHED SFHA FLAG - stronger than deriving it from a code we have to parse
  floodway = "OUT"     a separate regulatory floodway flag
  cobra = "COBRA OUT"  *** THE COASTAL BARRIER RESOURCES ACT. COBRA IN MEANS FEDERAL FLOOD INSURANCE IS UNAVAILABLE. ***
COBRA IS A HARDER FINDING THAN THE FLOOD ZONE. A parcel inside a CBRS unit cannot obtain an NFIP policy at all - not
expensive, UNAVAILABLE - and no federal financial assistance may be used for development there. We hold that flag and
have never served it.
AND charlotte_flood_zones_pre2003 SPELLS THE SAME FLAG "COBRA_OUT" WITH AN UNDERSCORE. Same county, same concept, two
vintages, two spellings - which is the four-spellings-of-Miami-Dade lesson inside a single county.

## 51-authority-links

### 1. FIVE COUNTIES LINK THE PRIMARY INSTRUMENT PER FEATURE AND WE HAVE NEVER SERVED ONE

`principle` | authority: PIR_REPORT_SPEC_v5 Part H, Part A6 | measured: 2026-08-17 | claude

READING MAP-ONLY TABLES TO SHELVE THEM TURNED UP A CLASS OF COLUMN MORE VALUABLE THAN THE LAYER IT SITS IN:
  collier_zoning_links.zoning_url      apps4.collier.gov/.../zoning/482930.pdf keyed on tss "48-29-30" - THE
                                       AUTHORITATIVE ZONING MAP PDF FOR A PLSS SECTION
  stpete_city_zoning.pdfurl            library.municode.com - THE EXACT ORDINANCE SECTION, on 1,648 rows
  alachua_zoning.zonelink              the ordinance behind the district
  charlotte_punta_gorda_boundary.link  PG_Annexations/947-89.pdf WITH ordnum 947-89 AND approved 03-15-1989
  charlotte_certificate_elevation.link THE SIGNED ELEVATION CERTIFICATE per property
restriction_authority HOLDS 12 CITATIONS AT STATUTE LEVEL. THESE ARE THE INSTRUMENT ITSELF, PER FEATURE.
A statute citation says WHICH LAW. A per-feature link says WHICH DOCUMENT APPLIES TO THIS PARCEL - the ordinance that
created this district, the resolution that annexed this land, the certificate that surveyed this floor.
AND "NEVER NAME THE PORTAL" DOES NOT FORBID THEM. It forbids citing the portal AS THE SOURCE. A link to a recorded
ordinance PDF is a link to the PRIMARY INSTRUMENT - the highest source tier we have - and the portal is merely where the
county keeps it.
THE DISTINCTION: accountlink and datasheet link a PROPERTY RECORD PAGE, which is a portal view and must not be served.
These link A DOCUMENT. SERVE THE DOCUMENT, NEVER THE VIEW.

### 2. AN AIRPORT APPROACH SURFACE IS A HARD CEILING - AND AN EXPIRED EXCEPTION IS MARKED ONLY IN FREE TEXT

`principle` | authority: FAR Part 77; Ch.333 F.S. | measured: 2026-08-17 | claude

collier_apo: zone "Approach or Transitional Surface", airport "Naples Municipal Airport", minz 150 maxz 158.
FAR PART 77 IMAGINARY SURFACES ADOPTED INTO LOCAL AIRPORT ZONING UNDER Ch.333 F.S. THEY CAP THE HEIGHT OF ANYTHING
BUILT AND REQUIRE FAA FORM 7460-1 NOTICE. A parcel under an approach surface has A HARD CEILING IN FEET - the only
restriction found today that can STOP a build rather than make it costlier. It passes the obligation test cleanly.
AND collier_zoning_exception IS THE OPPOSITE - A LIVE-LOOKING ENTITLEMENT THAT IS DEAD:
  expnotes1 = "6/6/90 PU-90-7 90-294 (EXPIRED), 5-28-91 PU-90-7-EXT 91-431 (EXP)"
BOTH ENTRIES SAY EXPIRED, IN FREE TEXT, IN A NOTES COLUMN. NO STATUS COLUMN, NO DATE COLUMN, NOTHING FILTERABLE. The
only marker that this zoning exception is dead IS THE WORD "EXPIRED" INSIDE A STRING.
FOURTH EXPIRED-ENTITLEMENT INSTANCE - after the SUNSET PUD, the 1985 CCCL and the 2015 enterprise zone - AND THE FIRST
WHERE THE EXPIRY IS UNFILTERABLE. The other three had a status or a year in a column.
SO THE EXPIRED-ENTITLEMENT CHECK CANNOT BE MECHANISED. It needs a read per layer, and this one proves it.

### 3. THE PER-FEATURE DOCUMENT LINK IS LA_Source.extArchiveID - THE STANDARD HAS A DEDICATED ATTRIBUTE AND I READ PAST IT

`mapping` | authority: ISO 19152-1 LA_Source; ISO/DIS 19152:2010 clause 6.4.7 | measured: 2026-08-17 | murphy

MURPHY ASKED HOW THE FIVE PER-FEATURE INSTRUMENT LINKS ROUTE IN LADM. THE ANSWER IS AN ATTRIBUTE I HAD ALREADY SEEN IN
THE LA_Source SIGNATURE AND NOT RECOGNISED.
LA_Source (ISO 19152-1, abstract, parent of LA_AdministrativeSource and LA_SpatialSource):
  sID: Oid | acceptance: DateTime | availabilityStatus: LA_AvailabilityStatusType = documentAvailable
  *** extArchiveID: ExtArchive [0..1] *** | lifeSpanStamp | maintype: CI_PresentationFormCode
  quality: QualityElement | recordation: DateTime | source: CI_Responsibility | submission: DateTime
THE 2010 DIS DEFINES IT VERBATIM: "extArchiveID: THE IDENTIFIER OF A SOURCE IN AN EXTERNAL REGISTRATION (blueprint class
ExtArchive)". THAT IS EXACTLY A URL TO THE DOCUMENT IN THE COUNTY ARCHIVE.
SO THE FIVE MAP CLEANLY AND EACH IS AN LA_Source WITH extArchiveID SET:
  collier_zoning_links.zoning_url      LA_AdministrativeSource, the zoning map for a PLSS section
  stpete_city_zoning.pdfurl            LA_AdministrativeSource, the ordinance section
  alachua_zoning.zonelink              LA_AdministrativeSource, the ordinance
  charlotte_punta_gorda_boundary.link  LA_AdministrativeSource - AND IT ALSO CARRIES recordation (approved 03-15-1989)
                                       AND sID (ordnum 947-89). THREE OF THE ATTRIBUTES IN ONE ROW.
  charlotte_certificate_elevation.link LA_SPATIALSOURCE, NOT ADMINISTRATIVE - an elevation certificate is A SURVEY
                                       MEASUREMENT signed by a surveyor, not an instrument creating a right.
*** AND availabilityStatus IS THE THREE-STATE RULE AGAIN, IN THE STANDARD, FOR DOCUMENTS. *** Its default is
documentAvailable; the type also carries values for a document that is KNOWN TO EXIST AND NOT HELD. That is precisely
present / none_recorded / not_available applied to an instrument, and it is what lets a report say "an ordinance
created this district and we do not hold it" rather than staying silent.
maintype: CI_PresentationFormCode DISTINGUISHES A SCANNED IMAGE FROM A DIGITAL DOCUMENT - which bears on whether a link
resolves to something machine-readable or a photograph of paper.
WE HAVE BEEN TREATING THESE COLUMNS AS METADATA. THEY ARE A MODELLED CLASS WITH EIGHT ATTRIBUTES AND WE POPULATE ONE.

## 52-daytona

### 1. ONE CITY CODES ITS ROAD MAINTAINER AS A NUMBER IN ONE TABLE AND A WORD IN ANOTHER

`test` | measured: 2026-08-17 | claude

daytonabeach_city_streets.maintby = 1 AND ownedby = 1 - AN UNDOCUMENTED NUMERIC CODE WITH NO CROSSWALK HELD.
daytonabeach_city_traffic_network.maintby = "COUNTY", with owner and billto also COUNTY.
*** TWO TABLES FROM ONE CITY, THE SAME FACT, ONE AS AN INTEGER AND ONE AS A WORD - AND THE SECOND IS THE CROSSWALK FOR
THE FIRST. *** Who maintains a road is a real cost question for an adjacent owner: an unmaintained or private road is
the owners liability; a county road is not.
FOURTH INSTANCE OF THE PATTERN THAT KEEPS PAYING - WHEN A COLUMN IS AN OPAQUE CODE, LOOK FOR A SIBLING TABLE FROM THE
SAME PUBLISHER THAT SPELLS IT OUT. It found collier folio=lpad(parcelid,11), the Pinellas STRAP crosswalk inside
pinellas_septic, and the county hosts in registry siblings.
TWO MORE FROM THE SAME BATCH:
  year = 9999 ON 278 OF 3,441 HYDRANTS (8.1%) - a sentinel, not a year. Anything computing age gets 7,973 years.
  sidewalk_2015 AND sidewalk_budgeted HAVE IDENTICAL SCHEMAS AND AN IDENTICAL SAMPLED ROW - same street, same tom
  0.01900017. TWO TABLES, ONE LAYER, OR A BUDGETED SUBSET, AND THE NAME IMPLIES A SUBSET THE DATA DOES NOT CONFIRM.
AND THE HTML ENTITIES IN THE SAMPLE WERE MY OWN query_to_xml DISPLAY PATH AGAIN - MEASURED ZERO IN THE DATA. Second
time today I nearly filed a defect against my own instrument.

### 2. THREE FIRM TABLES, TWO NAMED FOR THE PULL YEAR AND ONE FOR THE MAP YEAR

`test` | measured: 2026-08-17 | claude

  daytonabeach_city_firm_panel_2014   eff_date 2014-02-19   NAME AGREES WITH THE DATA
  daytonabeach_city_firm_2017         eff_date 2014-02-19   NAME IS THE PULL YEAR, PANELS ARE 2014
  broward_fema_firm_2024              eff_date 2014-08-18   NAME IS THE PULL YEAR, PANELS ARE 2014
TWO OF THREE ARE NAMED FOR WHEN WE FETCHED THEM, NOT WHEN THE MAP TOOK EFFECT - AND A FLOOD MAP YEAR IS A REGULATORY
FACT. A 2024 name on a 2014 panel implies a currency the data does not have, and a reader asking "is this the current
FIRM" is told yes by the name and no by eff_date.
THE PANEL NUMBER IS THE CITATION - 12127C0194J, 12011C0025H - AND THE SUFFIX LETTER IS THE REVISION LEVEL. J is later
than H. That is the field a lender or surveyor asks for, and it is more precise than the table name or the date.
NEVER TRUST A YEAR IN A TABLE NAME. It records when we pulled; only eff_date records when the map became law.

## 53-stcm

### 1. 74,262 PETROLEUM CONTAMINATION SITES, WITH THE PARCEL ID IN A PROSE FIELD AND THE CLEANUP FILE LINKED

`measurement` | authority: FDEP STCM; floridadep.gov storage tank facility information | measured: 2026-08-17 | claude

fdep_stcm_tanks LOOKED LIKE FOUR COLUMNS - oid, county, retrieved_at, location_known - BECAUSE MY OWN SAMPLE STRIPPED
THE jsonb attributes COLUMN TO KEEP THE OUTPUT READABLE. I HAD TO FIX MY INSTRUMENT AGAIN BEFORE I COULD READ THE TABLE.
RESEARCHED AT floridadep.gov: STCM IS THE STORAGE TANK AND CONTAMINATION MONITORING DATABASE, tracking facilities "for
active storage tanks, storage tank history, OR PETROLEUM CLEANUP ACTIVITY", REFRESHED DAILY from FDEP Oracle production.
INSIDE THE JSONB:
  COL_PROG "TANKS-PETROLEUM CONTAMINATION" | STATUS "REVIEWED" | LOC_ID 65714 - THE FACILITY ID, the join key across
  every FDEP tank report | REL_FEAT "EXACT" | COORD_ACC 4 | ADDRESS1 4175 BUCKINGHAM RD
*** DIRECT = "PARCEL ID 05442600000160020" - A DIRECT PARCEL REFERENCE ON A CONTAMINATION SITE, IN A PROSE FIELD. ***
*** DOCUMENTS LINKS prodenv.dep.state.fl.us/DepNexus - THAT IS OCULUS, FDEP ELECTRONIC DOCUMENT MANAGEMENT SYSTEM, filed
under the seven-digit facility ID. AN LA_Source.extArchiveID POINTING AT THE CLEANUP FILE ITSELF. ***
SIXTH PER-FEATURE DOCUMENT LINK, AND THE FIRST ON A CONTAMINATION RECORD. The spec ranks contamination containment
ABOVE SFHA in the report lead, and we hold 74,262 of these with the file attached.
COL_DATE AND VER_DATE ARE EPOCH MILLISECONDS - 1302652800000 is 2011-04-13, not a number. COL_NAME "WILLIAMS_CA" is a
staff identifier and is never served.

### 2. A ZONING POLYGON CARRYING A BOOK AND PAGE - THE FIFTH JURIDICAL SOURCE AND THE FIRST ON A REZONING

`measurement` | authority: s.163.3191 F.S. | measured: 2026-08-17 | claude

flagler_bunnell_zoning: book_page "2489/1198", type "ORDINANCE", from_code "R-1 (F)" -> to_code "AG (B)",
zone_code AG, zone_desc AGRICULTURAL.
*** AN OFFICIAL RECORD BOOK AND PAGE ON A ZONING POLYGON. A RECORDED REZONING WITH ITS INSTRUMENT REFERENCE. ***
FIFTH INDEPENDENT BOOK-AND-PAGE SOURCE - after DOR SDF in 67 counties, volusia_cama_legal at 95.4%, county_land_interests
and sjc_plat_index - AND THE FIRST ATTACHED TO A ZONING CHANGE RATHER THAN A CONVEYANCE OR A PLAT.
AND IT IS THE PREVIOUS-VALUE TRAP IN ITS HONEST FORM: from_code and to_code are BOTH LABELLED, the current code sits in
its own column, and the ordinance is cited. Compare stlucie previouszo1-4 and polk pr_strap, where the previous value
wore the name of the current one.
flagler_bunnell_flu IS THE SAME SHAPE ON LAND USE: type ORDINANCE, notes "EAR UPDATES", MUH-F -> MU. EAR IS THE
EVALUATION AND APPRAISAL REPORT under s.163.3191 F.S., the periodic comprehensive plan review - SO THE LAYER RECORDS WHY
THE DESIGNATION CHANGED, not just that it did.
AND THE SAME COUNTY DIFFERS BY CITY: flagler_beach_flu HAS THE IDENTICAL SCHEMA WITH book_page, from_code, to_code AND
type ALL NULL. ONE SCHEMA, TWO CITIES, DIFFERENT COMPLETENESS - so a county-level assumption about a field being
populated is wrong at the city level.

### 3. TWO CITIES, ONE LAYER CONCEPT, AND ONLY ONE EXPOSES ITS OFFICERS

`test` | authority: Ch.190 F.S.; Ch.380 F.S. | measured: 2026-08-17 | claude

clearwater_city_neighborhood_assoc CARRIES contact "Monica Lueking", title President, a residential address, phone and
personal email.
fortlauderdale_city_neighborhood_assoc CARRIES officialname "Bay Colony Club Condominium" AND NOTHING ELSE - NO OFFICER,
NO ADDRESS, NO PHONE, NO EMAIL.
*** SAME LAYER CONCEPT, SAME STATE, TWO PUBLISHERS, AND ONE MADE A DIFFERENT DECISION ABOUT PII. ***
THAT IS WHY THE SWEEP HAS TO BE PER-TABLE AND CANNOT BE PER-CLASS. An EXT_Context amenity layer is not safe by class;
it is safe or not by publisher, and the only way to know is to read the columns.
BOTH ARE NOW MAPPED - Clearwater with pii_render_blocked, Fort Lauderdale without, because there is nothing to block.
LOAD COMPLETE, SCRUB AT RENDER, AND MAP BOTH SO THE DIFFERENCE IS ON THE RECORD.
AND TWO MORE Ch.190-CLASS FINDINGS IN THE SAME BATCH:
  hillsborough_cdd RECLASSED FROM EXT_Context TO LA_RRR. A COMMUNITY DEVELOPMENT DISTRICT LEVIES NON-AD-VALOREM
  ASSESSMENTS RUNNING WITH THE LAND FOR 20-30 YEARS AND A BUYER INHERITS THEM. Same obligation as
  volusia_cama_nonadvalorem, which carries the amount; this carries the boundary and the name.
  hillsborough_dri IS A Ch.380 DEVELOPMENT OF REGIONAL IMPACT - state review, a binding development order, and VESTED
  RIGHTS surviving later plan changes. Materially heavier than a PUD and must not be flattened into one.

## 54-capacity-fields

### 1. THREE HYDRANT LAYERS, THREE COUNTIES, AND THE FLOW RATE IS NULL IN ALL THREE

`principle` | authority: NFPA 291; ISO PPC | measured: 2026-08-17 | claude

  lake_fire_hydrants        gpmpre NULL, ports NULL, hydrantid NULL
  flagler_fire_hydrants     rated_capacity NULL, owner and system BLANK
  daytonabeach_city_hydrants class "Green" POPULATED - the NFPA 291 colour, which IS the flow band
*** FLOW RATE IS THE ONLY HYDRANT FIELD THAT MATTERS TO A PROPERTY. *** It drives the ISO Public Protection
Classification, which drives the fire insurance premium. A hydrant with no flow rate is a location, not a capability.
AND DAYTONA IS THE COUNTER-EXAMPLE THAT PROVES THE POINT: it does not publish gpm either, BUT IT PUBLISHES THE NFPA 291
COLOUR CLASS, AND GREEN MEANS 1,000+ GPM. THE FACT SURVIVED IN A DIFFERENT ENCODING.
THE PATTERN ACROSS THIS BATCH IS THE SAME EVERY TIME - THE CAPABILITY FIELD IS THE ONE THAT IS EMPTY:
  hydrants        flow rate            NULL
  lee_bridges     height and des_load  BLANK-NOT-NULL - clearance and posting, the two facts that govern use
  sidewalks       width                NULL - the only field that determines ADA compliance
  stormwater      invert elevations    NULL - no gradient, no capacity, no direction of flow
  bus routes      headway              NULL in Broward; IN A LINKED PDF in Lee
GEOMETRY AND IDENTIFIERS SURVIVE EVERY LOAD. CAPABILITY DOES NOT. That is not a load defect - it is what these
publishers choose to release - AND IT MEANS AN INFRASTRUCTURE LAYER IS A PRESENCE LAYER UNLESS PROVED OTHERWISE.
NEVER SERVE PROXIMITY TO INFRASTRUCTURE AS ACCESS TO ITS FUNCTION.

### 2. A ROUNDED COORDINATE IS AN ELEVEN-KILOMETRE ERROR, AND IT IS THE COLUMN THAT FOOLED THE MACHINE SCREEN

`test` | authority: GTFS | measured: 2026-08-17 | claude

lee_bus_stops: stop_lat 26.6, stop_lon -81.9. ROUNDED TO ONE DECIMAL PLACE. *** ONE DECIMAL OF LATITUDE IS ABOUT 11
KILOMETRES. *** These are not coordinates, they are a bounding region, and the geometry column is the only usable
position.
THIS IS THE EXACT COLUMN CC MACHINE SCREEN PROPOSED AS A CLASSIFICATION - lee_bus_stops -> stop_lat - because a rounded
latitude has LOW CARDINALITY AND NO NULLS, which is what every numeric heuristic rewards.
SO THE SAME COLUMN IS TWO TRAPS AT ONCE: it fools a statistical screen into calling it a category, AND it fools a reader
into calling it a location. The only defence against both is reading the values.
AND hillsborough_bus_stops IS THE CONTRAST: stop_lat 27.715913, SEVEN DECIMALS, and stop_id EQUALS stop_code. In Lee
they DIFFER - stop_id 1885, stop_code 10006 - SO TWO GTFS FEEDS FROM TWO AGENCIES USE THE SAME COLUMN NAMES WITH
DIFFERENT SEMANTICS AND DIFFERENT PRECISION.
GTFS IS A STANDARD AND ITS PUBLISHERS STILL DIVERGE. Never assume a named standard means a shared meaning - that is the
seven-spellings-of-the-0.2%-zone lesson applied to a specification rather than a domain.

## 55-datum

### 1. THE DATUM TRAP HAS A HORIZONTAL FORM, AND THE TWO DATUMS ARE STORED AS DIFFERENT TYPES IN ONE TABLE

`principle` | authority: NAD27/NAD83; NGVD29/NAVD88 | measured: 2026-08-17 | claude

lee_section_corners IS A BLM PLSS SURVEY MONUMENT RECORD - blm "T44SR24E440640", section "034424CENTER1/4" encoding
section-township-range plus corner position. THE HIGHEST-GRADE SPATIAL SOURCE WE HOLD after daytonabeach_city_control_points.
*** IT CARRIES BOTH DATUMS AND THEY HAVE DIFFERENT COLUMN TYPES: ***
  n83, e83  double precision
  n27, e27  CHARACTER VARYING - AND 1,654 OF 1,766 VALUES ARE NON-NUMERIC
A numeric column would have rejected those blanks at load. THE TYPE DIFFERENCE IS WHY THE NAD27 PAIR IS UNUSABLE, and it
is invisible unless you look at the schema rather than the values.
NAD27 TO NAD83 IS A REAL HORIZONTAL SHIFT OF HUNDREDS OF FEET IN FLORIDA. NEVER MIX THEM.
*** SO THE DATUM TRAP HAS TWO FORMS AND WE HAVE NOW FOUND BOTH IN ONE DAY: ***
  VERTICAL    charlotte_certificate_elevation datum "NGVD 1929" against FEMA NAVD88 BFEs - about 1.0 to 1.5 ft,
              and subtracting across them produces a number that looks exactly like freeboard
  HORIZONTAL  lee_section_corners NAD27 beside NAD83 - hundreds of feet
BOTH ARE SILENT. Neither produces an error, a null or an outlier - THEY PRODUCE A PLAUSIBLE WRONG NUMBER, which is the
hardest defect class there is. READ THE DATUM COLUMN BEFORE ANY ARITHMETIC ON A COORDINATE OR AN ELEVATION.

### 2. SSURGO IS ALREADY IN THE DATABASE FOR THE SECOND TIME, INSIDE A LAYER CALLED HISTORIC FLOWWAYS

`test` | authority: NRCS SSURGO; SFWMD | measured: 2026-08-17 | claude

lee_historic_flowways: musym 16, muid 71016, compname "PECKISH MUCKY FINE SAND", stssaid FL071, source SFWMD.
*** musym IS THE NRCS MAP UNIT SYMBOL AND muid THE MAP UNIT ID - THESE ARE SSURGO SOIL SURVEY KEYS. THE SPEC LISTS
SSURGO AS A PENDING STATEWIDE PULL. ***
SECOND INSTANCE - volusia_cama_land.SOIL is populated on 9,367 rows. TWO COUNTIES ALREADY CARRY SOIL DATA IN TABLES
NAMED FOR SOMETHING ELSE.
AND THE LAYER IS AN INFERENCE, WHICH IT DOES NOT SAY: "historic flowways" DERIVED FROM SOIL TYPE. Mucky fine sand
indicates historic standing water, so SFWMD RECONSTRUCTED PRE-DEVELOPMENT DRAINAGE FROM SOILS. reclass 5 and ecocomm 19
record the derivation.
IT IS site_hazard_installations ALL OVER AGAIN - a derived layer whose name states a conclusion. That table at least
had a column literally called inference_basis; THIS ONE HAS ONLY source "SFWMD" AND THE SOIL KEYS TO GIVE IT AWAY.
SERVE AS A MODELLED HISTORIC CONDITION, NEVER AS AN OBSERVED WATERCOURSE. A buyer told "a historic flowway crosses this
parcel" would reasonably think someone saw water there.

## 56-marion

### 1. ONE COUNTY, FIVE FIRM TABLES, FOUR ENCODINGS OF ONE BOOLEAN, AND THE RESOLVER USES A SIXTH

`measurement` | measured: 2026-08-17 | claude

  marion_fema_flood_1983         sfha "IN" | "OUT"     1,754 rows   FORTY-THREE YEARS OLD
  marion_fema_flood_2008         sfha "Yes" | "No"     5,808
  marion_fema_flood_zones_2017   sfha_tf "T"           4,514        ALL T
  marion_fema_flood_other_areas  sfha_tf "F"           5,134        ALL F
  marion_fema_firm_panel_2008    panel index
  AND layer_resolution REGISTERS marion_flood_zones_firm - A SIXTH TABLE, NONE OF THESE.
*** THE 2017 PAIR IS ONE FIRM PUBLISHED AS TWO TABLES. A PARCEL QUERIED AGAINST THE SFHA HALF ALONE EITHER HITS OR
RETURNS NOTHING - AND NOTHING LOOKS EXACTLY LIKE BEING OUTSIDE THE FLOOD ZONE. A FALSE CLEARANCE PRODUCED BY A TABLE
SPLIT RATHER THAN BY A NULL, WHICH IS A SHAPE NOT SEEN BEFORE TODAY. ***
AND THE NEWER LAYER CARRIES LESS ATTRIBUTION THAN THE OLDER ONE: the 2008 table has panel, quad, cobra and floodway ALL
NULL; the 1983 table populates every one. NEWER IS NOT RICHER.
FOUR ENCODINGS OF A BOOLEAN IN ONE COUNTY - IN/OUT, Yes/No, T, F - which is the seven-spellings-of-the-0.2%-zone lesson
compressed into a single jurisdiction. And Charlotte writes COBRA_OUT with an underscore in its pre-2003 table and
"COBRA OUT" with a space in its 2022 one, so the same drift happens WITHIN a county ACROSS vintages.
marion_flood_prone_areas IS A DIFFERENT INSTRUMENT AGAIN: notes "LEVEL-POOL" - a HYDROLOGIC MODEL METHOD, not a hazard
description. Level-pool routing assumes a flat water surface and no momentum: the simplest and least conservative model
there is. IT IS A COUNTY MODEL, NOT A FEMA FIRM, and its sibling transitional layer has flood_elevation -99999 on every
row - the column CC machine screen would have mapped as a flood elevation.

### 2. THREE HYDRANT LAYERS IN ONE COUNTY AND ONLY ONE IS FIRE PROTECTION

`test` | authority: ISO PPC; NFPA | measured: 2026-08-17 | claude

MANATEE PUBLISHES THREE HYDRANT LAYERS AND THE PULL SCRIPT IN CONVERSATION HISTORY RECORDS ALL THREE ENDPOINTS:
  potable            mymanatee.org/gisits/rest/services/opendata/utilities/FeatureServer/37
  reclaimed county   /14   asset_id prefix RHY
  reclaimed private  /7
*** A RECLAIMED-WATER HYDRANT IS NOT A FIRE HYDRANT. *** Reclaimed lines carry treated wastewater for irrigation at
lower pressure and are not rated for fire flow. MERGING THE THREE WOULD OVERSTATE FIRE COVERAGE ON A PARCEL, which
feeds the ISO Public Protection Classification and therefore the insurance premium.
THE ONLY MARKER IS THE asset_id PREFIX - RHY for reclaimed - AND THE LAYER NAME. There is no type column saying
"not for fire".
AND manatee_evacuation_levels CARRIES TWO ENCODINGS OF ONE FACT: evac_zone "A" AND zone_ 1. ONLY THE LETTER IS WHAT THE
COUNTY BROADCASTS IN AN EVACUATION ORDER - Zone A is ordered out first. Serve the letter.
That layer is also the one whose ArcGIS index is 20 RATHER THAN 0, recovered from the pull script - no pattern would
have guessed it.

## 57-map-complete

### 1. ALL 91 MAP-ONLY TABLES ARE MAPPED - AND SSURGO IS IN THE DATABASE FOR THE FOURTH TIME

`measurement` | authority: NRCS SSURGO | measured: 2026-08-17 | claude

THE map_only QUEUE IS ZERO. 1,428 SHELVED OF 1,691 - 84.4%.
*** SSURGO, LISTED IN THE SPEC AS A PENDING STATEWIDE PULL, IS ALREADY HELD IN FOUR PLACES: ***
  volusia_cama_land.SOIL           9,367 rows, inside a CAMA land table
  lee_historic_flowways            musym, muid, compname - inside a layer named for HYDROLOGY
  orange_soils                     mukey, musym, muname, comppct, texture, hydrgrp, corcon - the full extract
  orange_soil_hydric_rating        THE SAME EXTRACT FILTERED - identical sampled row
FOUR TABLES, THREE COUNTIES, AND NOT ONE OF THEM IS NAMED FOR SOIL EXCEPT THE TWO ORANGE ONES.
AND THE ORANGE PAIR CARRIES WHAT MATTERS TO A BUYER: hydrgrp "C" IS THE NRCS HYDROLOGIC SOIL GROUP - slow infiltration,
high runoff - which drives stormwater design AND SEPTIC SUITABILITY. corcon "HIGH" IS CONCRETE CORROSION POTENTIAL, a
foundation and buried-utility fact.
*** AND THE HONEST CAVEAT IS IN THE DATA: mukind "COMPLEX" MEANS TWO OR MORE SOILS ARE INTERMINGLED AND NOT SEPARATELY
MAPPABLE, AND comppct 53 SAYS THIS COMPONENT IS ONLY 53% OF THE UNIT. THE RATING IS A MAJORITY, NOT A CERTAINTY, AT ANY
GIVEN POINT. *** Serve it as such or not at all - it is the DEM-sample lesson in a different medium.
THREE MORE DUPLICATE PAIRS FOUND IN THE SAME PASS, ALL WITH IDENTICAL SAMPLED ROWS: orange_soils /
orange_soil_hydric_rating, orange_sheriff_sectors / orange_sheriff_zones, and daytonabeach sidewalk_2015 /
sidewalk_budgeted. MEASURE THE SET DIFFERENCE BEFORE SERVING EITHER OF A PAIR.

### 2. FOUR UTILITY LAYERS WITH GEOMETRY AND NOTHING ELSE, AND A BILLBOARD LAYER THAT IS AN EMPTY SHELL

`principle` | authority: Ch.479 F.S. | measured: 2026-08-17 | claude

orange_stormwater_major_control_structure: cs_id, cs_type, datum, pipes, diameter, material, accuracy, source AND
comment_ ALL NULL. *** A MAJOR CONTROL STRUCTURE GOVERNS DISCHARGE FROM A STORMWATER BASIN - THE SINGLE MOST
CONSEQUENTIAL ASSET IN A DRAINAGE NETWORK - AND THIS TABLE CANNOT SAY WHAT TYPE IT IS. ***
orange_billboards: height, face_type, structure, changeabl, lot, block, section, township, range ALL NULL, with dot_1
and dot_2 reading "None". A BILLBOARD IS A REAL LAND-USE RESTRICTION UNDER Ch.479 F.S. AND THIS LAYER CANNOT SUPPORT
ONE.
WITH THE THREE DAYTONA STORMWATER LAYERS AND THREE HYDRANT LAYERS, THAT IS EIGHT INFRASTRUCTURE LAYERS TODAY WHOSE
CAPABILITY FIELDS ARE EMPTY WHILE GEOMETRY AND IDENTIFIERS SURVIVED.
*** THE RULE STANDS AND IS NOW EVIDENCED EIGHT TIMES: AN INFRASTRUCTURE LAYER IS A PRESENCE LAYER UNLESS PROVED
OTHERWISE. NEVER SERVE PROXIMITY TO INFRASTRUCTURE AS ACCESS TO ITS FUNCTION. ***
AND TWO COUNTER-EXAMPLES WORTH KEEPING, BECAUSE THEY SHOW IT IS A PUBLISHER CHOICE AND NOT A LOAD DEFECT:
  orange_benchmarks_88_datum  elevation 94.9901 ft, description "ORANGE COUNTY BRASS DISC ON CURB INLET" - COMPLETE,
    AND THE TABLE NAME DECLARES THE DATUM, which is exactly what charlotte_certificate_elevation lacks.
  lee_neighborhoods  gated "N", parcels 14, buildings 12 - THREE REAL SERVABLE FACTS, and the parcel/building
    disagreement is itself a vacancy signal.

## 58-ladm-audit

### 1. LADM AUDIT: 67% OF CLASSIFIED TABLES SIT OUTSIDE THE STANDARD, AND EXT_Regulatory IS THE FAILURE

`correction` | authority: ISO 19152-1:2024 scope and external stereotype classes; ISO 19152-3:2024 | measured: 2026-08-18 | murphy

MEASURED ACROSS 2,115 DECLARATIONS:
  ISO CLASSES        560   33.0%
  LOCAL EXTENSIONS 1,136   67.0%   EXT_Context 724 | EXT_Regulatory 334 | EXT_Address 78
  bookkeeping        419           UNREAD 398 | SYSTEM 21
*** TWO THIRDS OF WHAT WE HAVE CLASSIFIED IS MODELLED OUTSIDE A STANDARD BUILT FOR EXACTLY THIS DOMAIN. ***
*** FINDING 1 - EXT_Regulatory IS NOT AN EXTENSION, IT IS A GAP IN MY READING. ***
ISO 19152-1:2024 RENAMED THE DOMAIN: "the land administration/GEOREGULATION domain. IT DEFINES A GENERAL SCHEMA THAT
PERMITS REGULATORY INFORMATION TO BE DESCRIBED." The 2024 edition INTRODUCED THE TERMS "georegulation" AND "regulation"
as new definitions, and Part 3 is MARINE GEOREGULATION - an entire part for regulatory overlays over water.
SO REGULATORY INFORMATION IS IN SCOPE, EXPLICITLY, AND I CREATED A LOCAL CLASS FOR 334 TABLES BECAUSE I READ THE 2012
SCOPE AND NOT THE 2024 ONE.
AND THE SUBTYPES SHOW WHAT THEY ACTUALLY ARE: flood, contamination, geohazard, hazard, historic, archaeological,
military_contamination, coastal_construction_line, wind_design, environment. EVERY ONE PASSES THE OBLIGATION TEST -
CROSSING THAT BOUNDARY CHANGES WHAT THE OWNER MAY DO. THEY ARE LA_RRR RESTRICTIONS, and I have already reclassed six by
hand - turtle lighting, impact fees, CRAs, the CDD, the BZA variance, county land interests - WITHOUT NOTICING THE
PATTERN APPLIED TO ALL 334.
LA_RRR CURRENTLY HOLDS 13 ROWS. IT SHOULD HOLD HUNDREDS.
*** FINDING 2 - EXT_Context AND EXT_Address ARE CORRECT, AND THE STANDARD SAYS SO. ***
"THE FOLLOWING ARE OUTSIDE THE SCOPE: construction of external databases with PARTY DATA, ADDRESS DATA, LAND COVER
DATA, PHYSICAL UTILITY NETWORK DATA, ARCHIVE DATA AND TAXATION DATA. HOWEVER, THE LADM PROVIDES STEREOTYPE CLASSES FOR
THESE DATA SETS TO INDICATE WHICH DATA SET ELEMENTS THE LADM EXPECTS FROM THESE EXTERNAL SOURCES."
THE BLUEPRINT CLASSES ARE ExtAddress, ExtLandCover, ExtPhysicalUtilityNetwork, ExtTaxation, ExtArchive, ExtParty.
SO OUR EXT_ PREFIX IS RIGHT IN PRINCIPLE AND WRONG IN NAMING - the standard names them Ext<Thing> and we invented
EXT_Context, a bucket the standard does not have. Roads, hydrants, stormwater and utilities are
ExtPhysicalUtilityNetwork. Soils, wetlands and land cover are ExtLandCover. Addresses are ExtAddress.
*** FINDING 3 - WHAT WE GOT RIGHT. *** The 560 ISO classes are correctly assigned: SP_PlanUnit 213 for zoning and FLU,
VM_ValuationUnit 120 for the fiscal roll, VM_TransactionPrice 73 for sales, LA_SpatialUnit 78, and the small precise
sets - VM_CondominiumUnit 2, LA_BAUnit 4, LA_AdministrativeSource 5. THE FK CONSTRAINT HELD ALL DAY: no class was ever
invented in an INSERT.
*** THE AUDIT VERDICT: THE VOCABULARY IS SOUND AND THE ASSIGNMENT IS NOT. *** 334 EXT_Regulatory tables are LA_RRR
restrictions or SP_ regulatory units, and 802 EXT_Context/EXT_Address should carry the standard external-class names.
THAT IS A RECLASSIFICATION PASS, NOT A REBUILD - every one already has a proved join, a column map and a source.

### 2. NAMING FIXED WHERE THE STANDARD HAS A CLASS - AND 543 TABLES GENUINELY HAVE NONE, WHICH IS THE POINT OF THE PRODUCT

`correction` | authority: ISO 19152-1:2024 external stereotype classes | measured: 2026-08-18 | murphy

RENAMED TO THE STANDARD BLUEPRINT CLASSES, 97 TABLES, NO CHANGE OF MEANING AND NO CHANGE OF EVIDENCE:
  EXT_Address              -> ExtAddress                  78
  EXT_Context/utility      -> ExtPhysicalUtilityNetwork    13  (with transport)
  EXT_Context/landcover    -> ExtLandCover                  6
legacy_class RETAINED ON EVERY ROW so the rename is reversible and auditable, per VersionedObject.
*** AND THE RENAME CARRIED A DISTINCTION THE OLD NAME HID: LADM HAS BOTH ExtPhysicalUtilityNetwork AND
LA_LegalSpaceUtilityNetwork. THE PIPE IS EXTERNAL CONTEXT. THE RIGHT TO RUN THE PIPE ACROSS SOMEONE LAND IS AN LA_RRR
OVER THE SERVIENT PARCEL. *** We hold thirteen physical networks and not one legal space - that is a coverage gap, and
the utility easement is exactly the kind of restriction a buyer discovers after closing.
*** WHAT DOES NOT RENAME, AND WHY IT MATTERS MORE THAN WHAT DOES ***
543 TABLES FIT NONE OF THE SIX BLUEPRINT CLASSES:
  amenity        348   schools, fire stations, boat ramps, hospitals, parks
  event          136   disaster declarations, burn detection history
  admin_boundary  59   school attendance zones, evacuation routes, commission districts
LADM MODELS RIGHTS, RESTRICTIONS AND RESPONSIBILITIES IN LAND. A SCHOOL NEAR YOUR HOUSE IS NONE OF THOSE. It holds no
interest in the parcel and imposes no obligation on the owner. Neither does a hurricane declaration over the county.
*** THE STANDARD IS NOT SILENT BY OVERSIGHT - IT IS SILENT BECAUSE THESE ARE NOT LAND ADMINISTRATION FACTS. THEY ARE
WHAT A BUYER WANTS AND WHAT A CADASTRE DOES NOT RECORD. THAT GAP IS THE ENTIRE REASON A PIR EXISTS. ***
So EXT_Context stays local, is_standard=false, and its comment now states the reasoning rather than just the fact.
TWO THINGS THE AUDIT LEFT OPEN AND I AM NOT GUESSING AT:
  155 EXT_Context ROWS HAVE NO SUBTYPE AT ALL and cannot be tested against the standard. Flagged
  unsubtyped_pending_read - A SUBTYPE IS WHAT MAKES A LOCAL EXTENSION AUDITABLE, and without one the row asserts "not in
  the standard" without saying what it is instead.
  THE admin_boundary SET MIXES TWO THINGS: a school attendance zone imposes nothing, BUT AN EVACUATION ZONE DOES - a
  mandatory evacuation order is an obligation on the occupant, which is an LA_RRR responsibility. Needs splitting.

### 3. AUDIT CLOSED - THE VOCABULARY IS SOUND, THE ASSIGNMENT IS NOT, AND FOUR ITEMS ARE ON THE BACKLOG

`measurement` | authority: ISO 19152-1:2024 | measured: 2026-08-18 | murphy

FULL AUDIT RESULT, 2,115 DECLARATIONS:
  BEFORE   ISO 560 (33.0%) | LOCAL 1,136 (67.0%) | bookkeeping 419
  AFTER    ISO 657 (38.7%) | LOCAL 1,039        | 97 renamed with legacy_class retained
WHAT WAS FIXED - NAMING ONLY, NO CHANGE OF MEANING OR EVIDENCE:
  EXT_Address           -> ExtAddress                  78
  EXT_Context/utility   -> ExtPhysicalUtilityNetwork   13 (with transport)
  EXT_Context/landcover -> ExtLandCover                 6
WHAT IS ON THE BACKLOG, WITH THE REASONING RECORDED SO NOBODY REPEATS THE ANALYSIS:
  334 EXT_Regulatory -> LA_RRR or SP_. THE 2024 EDITION PUTS REGULATORY INFORMATION IN SCOPE and I read the 2012 scope.
  155 EXT_Context with no subtype - unauditable until subtyped.
   59 admin_boundary - an evacuation ZONE is an obligation, an evacuation ROUTE is not.
   13 ExtPhysicalUtilityNetwork with ZERO LA_LegalSpaceUtilityNetwork counterparts - we hold the assets and none of the
      rights.
WHAT THE AUDIT CONFIRMED AS CORRECT: the 560 original ISO assignments. SP_PlanUnit 213 for zoning and FLU,
VM_ValuationUnit 120 for the roll, VM_TransactionPrice 73 for sales, LA_SpatialUnit 78, and the small precise sets -
VM_CondominiumUnit 2, LA_BAUnit 4, LA_AdministrativeSource 5. THE FK CONSTRAINT HELD ALL DAY AND NO CLASS WAS EVER
INVENTED IN AN INSERT.
*** AND THE FINDING WORTH KEEPING IS THE ONE ABOUT WHAT THE STANDARD DOES NOT COVER. ***
543 TABLES - amenity 348, event 136, admin_boundary 59 - FIT NONE OF THE SIX BLUEPRINT EXTERNAL CLASSES, AND THAT IS
NOT A GAP IN THE STANDARD. LADM models rights, restrictions and responsibilities IN LAND. A school near your house holds
no interest in your parcel and imposes no obligation on you. Neither does a hurricane declaration over your county.
THE STANDARD IS SILENT BECAUSE THESE ARE NOT LAND ADMINISTRATION FACTS. THEY ARE WHAT A BUYER WANTS AND WHAT A CADASTRE
DOES NOT RECORD - AND THAT GAP IS THE ENTIRE REASON A PIR EXISTS.
SO THE PRODUCT IS NOT A CADASTRE WITH EXTRAS. IT IS A CADASTRE PLUS 543 TABLES OF THINGS A CADASTRE DELIBERATELY
OMITS, AND THE AUDIT MADE THAT COUNTABLE FOR THE FIRST TIME.

### 4. THE RECLASSIFICATION WENT BOTH WAYS - THE BACKLOG ASSUMED ONE DIRECTION AND 114 TABLES MOVED THE OTHER

`correction` | authority: s.376.80, s.161.053, s.627.7073 F.S.; 42 U.S.C. 4012a; 44 CFR 60.3 | measured: 2026-08-18 | claude

I WROTE THE BACKLOG ITEM AS "RECLASS 334 EXT_Regulatory TO LA_RRR". APPLYING THE OBLIGATION TEST PER SUBTYPE INSTEAD OF
BATCHING PRODUCED MOVEMENT IN BOTH DIRECTIONS, AND THE REVERSE CASES ARE THE INTERESTING ONES.
*** MOVED OUT OF REGULATORY - 114 TABLES THAT IMPOSE NOTHING ***
  59 SINKHOLE INCIDENT TABLES -> EXT_Context/event. A REPORTED SUBSIDENCE IMPOSES NOTHING ON ANY OWNER. It is a
     historical event at a location - no restriction, no permit, no right. AND FGS PUBLISHES THEM UNVERIFIED, FROM THE
     PUBLIC, IN A LAYER LITERALLY NAMED "_raw".
  55 SUPERFUND FACILITY TABLES -> EXT_Context/contamination_site. A FACILITY IS A POINT AND THE OBLIGATION RUNS WITH THE
     CONTAMINATED SITE, NOT WITH THE NEIGHBOUR. For an adjacent parcel this is proximity, not restriction.
*** MOVED INTO LA_RRR - 161 TABLES THAT BIND THE LAND ***
  86 BROWNFIELD AREAS. A BSRA under s.376.80 F.S. carries INSTITUTIONAL CONTROLS AND RECORDED DEED RESTRICTIONS THAT
     SURVIVE CONVEYANCE. And fdep_institutional_controls holds the BOOK AND PAGE of those very restrictions at 58.1%.
  72 FLOOD ZONE LAYERS. Mandatory insurance under 42 U.S.C. 4012a as a condition of any federally-backed mortgage, and
     construction standards under 44 CFR 60.3 in the local ordinance. A FLOODWAY IS STRICTER: 60.3(d) PROHIBITS ANY RISE.
   3 SINGLES, each by a different route: the CCCL needs a STATE FDEP PERMIT (s.161.053); archaeological sensitivity
     TRIGGERS A SURVEY BEFORE GROUND DISTURBANCE - procedural, still an obligation; historic designation restricts
     ALTERATION AND DEMOLITION.
*** RESULT: LA_RRR 13 -> 174. EXT_Regulatory 334 -> 59. ***
*** THE TEST THAT DID THE WORK, AND IT SPLIT ONE SUBTYPE IN HALF: DOES THE INSTRUMENT ATTACH TO THE PARCEL? ***
contamination held BOTH ANSWERS - brownfield AREAS bind the land, superfund FACILITIES do not. Same subtype, 86 one way
and 55 the other. IF I HAD BATCHED THE SUBTYPE I WOULD HAVE BEEN WRONG ON WHICHEVER HALF I CHOSE.
AND THE COMMERCIAL POINT SURVIVES THE RECLASSIFICATION: A SINKHOLE INCIDENT IS STILL A MATERIAL DISCLOSURE UNDER
Johnson v. Davis AND s.627.7073 F.S. IT IS SIMPLY NOT A LAND ADMINISTRATION RESTRICTION. THE PIR MUST SERVE IT AND LADM
DOES NOT MODEL IT - WHICH IS THE 543-TABLE FINDING PROVED A SECOND TIME.

### 5. THE LAST REGULATORY TABLES READ - A NOMINATION RESTRICTS NOTHING AND A DAM BINDS ITS OWNER, NOT ITS NEIGHBOUR

`measurement` | authority: Ch.252 F.S.; Ch.190 F.S. | measured: 2026-08-18 | claude

READING THE 59 REMAINING EXT_Regulatory TABLES INDIVIDUALLY RATHER THAN BATCHING:
  41 UNSUBTYPED WERE FLOOD - FIRM panels, SFHA layers, floodways. -> LA_Restriction/flood_restriction.
  12 EVACUATION ZONES -> LA_Responsibility. See 02A-ladm/8.
  charlotte_fbc2010_wind_speeds -> LA_Restriction/construction_standard. It restricts the MANNER of construction rather
    than the use of the land, which is still a restriction. AND IT IS THE 2010 CODE against Florida current 2023 edition.
  hifld_frs_relevant AND hifld_fuds_sites -> EXT_Context/contamination_site. POINTS. The obligation runs with the
    facility, not the neighbour. AND FUDS eligibility IS INVERTED - "Eligible" MEANS ELIGIBLE FOR CLEANUP, so it is the
    WORSE finding, and "Ineligible" does not mean clean.
  hifld_dams -> EXT_Context/hazard. *** A DAM IMPOSES INSPECTION AND MAINTENANCE OBLIGATIONS ON ITS OWNER, NOT ON A
    DOWNSTREAM PARCEL. THE RESTRICTION WOULD BE THE INUNDATION ZONE, WHICH WE DO NOT HOLD. *** Serving dam proximity
    without the inundation area tells a buyer a dam is nearby and nothing about whether failure would reach them.
  lee_conservation_2020_nominations -> EXT_Context/conservation_proposal. *** THESE ARE NOMINATIONS. LAND PROPOSED FOR
    ACQUISITION AND NOT ACQUIRED - o_name, carteid AND folioid ARE ALL NULL, consistent with land the county does not
    own. A NOMINATION RESTRICTS NOTHING. *** Serving it as a conservation designation would be AN AFFIRMATIVE FALSE
    RESTRICTION - the mirror of the expired-entitlement error, and the first instance of that mirror found.
  collier_conservation_lands -> EXT_Context. PUBLICLY OWNED preserve. The restriction runs with the PUBLIC parcel; for a
    neighbour it is context, and valuable context - a preserve boundary will not be developed.
FINAL: LA_Restriction 192 | LA_Responsibility 14 | EXT_Regulatory 19 remaining | LA_RRR 3 abstract stragglers.
*** THE READ-EACH-ONE DISCIPLINE PAID FOR ITSELF THREE TIMES IN NINETEEN TABLES: a nomination that is not a
designation, a dam whose obligation is its owner, and an eligibility flag that means the opposite of what it reads. ***

## 59-loma-rl

### 1. TWO FLOOD FACTS WE HOLD AND HAVE NEVER SERVED - AND ONE OF THEM CANCELS THE FINDING WE DO SERVE

`measurement` | authority: 42 U.S.C. 4012a; 44 CFR 59.1 repetitive loss definitions | measured: 2026-08-18 | claude

*** daytonabeach_city_lomas_lomrs - A LOMA IS NOT A HAZARD LAYER. IT IS THE INSTRUMENT THAT REMOVES A PROPERTY FROM
THE HAZARD. ***
A Letter of Map Amendment or Revision is FEMA official determination that a structure or parcel sits above the base
flood elevation and is therefore OUT of the SFHA. IT VOIDS THE MANDATORY INSURANCE REQUIREMENT UNDER 42 U.S.C. 4012a.
80 ROWS, ALL 80 LINKING THEIR OWN PDF at gis.codb.us/ExternalAccess/loma/03-04-065P.pdf.
CLASS: LA_AdministrativeSource - A DOCUMENT THAT ALTERS AN LA_Restriction - with lomaurl1 as its
LA_Source.extArchiveID. TENTH PER-FEATURE DOCUMENT LINK FOUND TODAY.
*** AND IT IS THE MISSING PIECE OF EVERY FLOOD FINDING WE SERVE. A PARCEL CAN SIT INSIDE AN SFHA POLYGON AND HAVE A
LOMA REMOVING IT. SERVING THE ZONE WITHOUT CHECKING FOR AN AMENDMENT ASSERTS A RESTRICTION FEMA HAS ALREADY LIFTED. ***
charlotte_flood_zones_2022 CARRIES A lomc COLUMN, SO AT LEAST TWO COUNTIES MODEL THIS AND WE HAVE NEVER JOINED IT.
*** fema_nfip_multiple_loss_fl - 33,547 FLORIDA PROPERTIES, 31,801 REPETITIVE LOSS AND 5,402 SEVERE. ***
NFIP repetitive loss is two or more claims of $1,000+ in ten years; SEVERE is four claims over $5,000 or two exceeding
the building value. SRL properties face MANDATORY MITIGATION OR PREMIUM ESCALATION, are priority FEMA acquisition
targets, and a community must track them to remain in the NFIP.
*** THIS IS ACTUAL CLAIM HISTORY RATHER THAN A MODELLED ZONE - THE MOST PREDICTIVE FLOOD FACT AVAILABLE - AND IT IS
EXACTLY WHAT A SELLER HAS NO INCENTIVE TO DISCLOSE. ***
IT IS COUNTY-LEVEL BY LAW: privacy rules bar address-level release, so it joins by jurisdiction and MUST NEVER BE
IMPLIED TO BE ABOUT A SPECIFIC PARCEL. Four flags - nfiprl, nfipsrl, fmarl, fmasrl - two programmes, different
thresholds. Read all four.
TOGETHER THEY ARE THE TWO ENDS OF THE FLOOD PICTURE WE HAVE BEEN MISSING: ONE CANCELS A ZONE FINDING AND THE OTHER
PROVES A ZONE FINDING WITH MONEY ALREADY PAID OUT.

### 2. lee_easements IS THE COMPLETE LADM PICTURE IN ONE ROW - AND IT IS THE GAP I FLAGGED THIS MORNING, ALREADY HELD

`measurement` | authority: ISO 19152-1 Administrative and Party packages | measured: 2026-08-18 | claude

THIS MORNING I RECORDED "we hold 13 physical utility networks and ZERO legal space utility networks" AS A BACKLOG ITEM.
lee_easements: type1 "Road", type2 "UTILITY", grantor "Sunset Realty Corp.", grantee "Other",
orbkpg "O BK 736 / PG 244". 19,024 ROWS, 9,208 WITH A RECORDED BOOK AND PAGE - 48.4%.
*** IT IS THE COMPLETE LADM PICTURE IN A SINGLE ROW: ***
  AN LA_Restriction        the easement
  OVER AN LA_SpatialUnit   the servient parcel
  BETWEEN TWO LA_Party     grantor and grantee
  EVIDENCED BY AN LA_AdministrativeSource   the recorded instrument at book 736 page 244
NOTHING ELSE WE HOLD HAS ALL FOUR IN ONE PLACE. It is what the standard is FOR, and it was sitting in a table declared
against the abstract parent class.
SEVENTH INDEPENDENT BOOK-AND-PAGE SOURCE - after DOR SDF, volusia_cama_legal, county_land_interests, sjc_plat_index,
flagler_bunnell_zoning and hillsborough_right_of_way.
AND grantee "Other" IS A SENTINEL: THE ACTUAL HOLDER IS NOT RECORDED. We can say an easement exists and not who holds
it - present, and the party is not_available.
AND volusia_hoas IS THE MIRROR CASE: cor_name "PARKVIEW HEIGHTS HOMEOWNERS ASSOCIATION" IS AN LA_Party AND THE
COVENANTS - THE ACTUAL RESTRICTION - ARE ABSENT. An HOA existing as a corporation tells a buyer an association governs
the property; IT DOES NOT TELL THEM WHAT IT FORBIDS. That absence must render as not_available, never as "no covenants".

## 60-stale-evidence

### 1. ON CONFLICT DO NOTHING PROTECTED 21 STALE no_scope VERDICTS AFTER THE RESOLVER WAS FIXED

`correction` | measured: 2026-08-18 | claude

I FIXED resolve_scope_co, THEN RE-RAN THE JURISDICTION SWEEP, AND ONLY 3 OF 26 TABLES MOVED. I checked instead of
re-running and the cause was my own guard.
*** 21 TABLES ALREADY HELD A no_scope VERDICT WRITTEN BEFORE THE FIX. ON CONFLICT (table_name) DO NOTHING PROTECTED THE
STALE ROW, SO THE SWEEP INSERTED NOTHING AND REPORTED NOTHING WRONG. ***
THE GUARD IS CORRECT AND THE CONSEQUENCE IS NOT: it exists so a re-run cannot overwrite good evidence with worse. But
no_scope IS NOT EVIDENCE ABOUT THE TABLE - IT IS EVIDENCE ABOUT THE INSTRUMENT, and when the instrument is repaired,
every verdict that reported an instrument failure IS OBSOLETE BY CONSTRUCTION.
*** THE RULE: A VERDICT THAT DESCRIBES THE INSTRUMENT RATHER THAN THE DATA MUST BE INVALIDATED WHEN THE INSTRUMENT
CHANGES. *** no_scope, no_jurisdiction_column, error and control_failed are all in that class. PASS and
ZERO_NAME_MISMATCH are not - those are about the table.
RESULT AFTER RE-RUNNING THE 21: PASS_JURISDICTION 195 -> 216.
AND IT IS THE THIRD TIME TODAY THE SAME SHAPE HAS APPEARED: CC upsert guard refused to write a class because it saw a
strong GRADE; my WHERE NOT EXISTS kept a weaker SP_Permit; and now DO NOTHING kept a verdict that only recorded that the
tool was broken. THREE GUARDS, ALL CORRECT IN INTENT, ALL AIMED AT THE WRONG FACT.
GUARD THE FACT YOU ARE WRITING - AND KNOW WHETHER THE FACT IS ABOUT THE DATA OR ABOUT THE TOOL.

## 61-evacuation

### 1. FIVE COUNTIES, FIVE ENCODINGS OF AN EVACUATION ZONE - AND ONLY SARASOTA PUBLISHES THE MODEL BEHIND IT

`measurement` | authority: Ch.252 F.S.; NOAA SLOSH | measured: 2026-08-18 | claude

AN EVACUATION ZONE IS AN LA_Responsibility - Ch.252 F.S. creates AN OBLIGATION ON THE OCCUPANT TO LEAVE. Reading all
five holdings, THE ENCODINGS DO NOT AGREE AND ONE IS NOT A ZONE AT ALL:
  flagler   evac_zone = "Hurricane"   *** NOT A ZONE - THAT IS THE HAZARD TYPE. *** One polygon covering the whole
            county. A county-wide designation with NO TIERING. Serving it as "you are in an evacuation zone" is true
            and useless; serving it as a lettered zone would be false.
  palmbeach fname = "ZONE L"          *** LETTERS BEYOND A-F. ANY IN-LIST BUILT ON A THROUGH F SILENTLY DROPS IT. ***
  putnam    evlevel = "F"             plus id, qc, ezcat, island, mobilehome AND parcel_are ALL ZERO - six columns at
            zero is THE SENTINEL PATTERN, NOT SIX MEASUREMENTS. And island and mobilehome are the two that would matter
            most: MOBILE HOMES EVACUATE FIRST UNDER Ch.252 REGARDLESS OF ZONE.
  manatee   evac_zone "A" AND zone_ 1 - two encodings in one table; only the LETTER is broadcast in an order.
  hernando  "A/B" and a zone_new of "A" - a compound value and a previous-value column together.
*** AND SARASOTA IS THE ONE THAT MATTERS: surgeheight 26 FEET, windvelocity 131 MPH. THAT IS THE SLOSH MODEL OUTPUT
BEHIND THE ZONE LETTER, AND NO OTHER COUNTY PUBLISHES IT. ***
A 26-FOOT SURGE IS A FACT A BUYER CAN ACT ON. A ZONE LETTER IS AN INSTRUCTION TO OBEY. The letter tells you when to
leave; the surge height tells you what happens if you do not, and it is the difference between a compliance fact and a
risk fact.
lastupdate 2021-04-20 dates the model run - so the number is five years old and the layer says so, which is more than
most.
THE ROUTES ARE THE MIRROR IMAGE AND CONFIRM THE CLASS SPLIT: hillsborough, pasco, pinellas, putnam and manatee all
carry evacuation ROUTES, and putnam contraflow IS NULL - THE ONE FIELD THAT DISTINGUISHES AN EVACUATION ROUTE FROM A
ROAD. manatee has NO ATTRIBUTES AT ALL. A ROUTE IMPOSES NOTHING AND IS CORRECTLY EXT_Context; THE OBLIGATION IS IN THE
ZONE, THE ROUTE IS WHERE YOU GO.

### 2. THREE COUNTIES SAY "PART OF THIS BOUNDARY IS WATER" THREE DIFFERENT WAYS

`measurement` | measured: 2026-08-18 | claude

  collier_county_boundary    type  = "LAND"
  lee_county_boundary        type  = "Coastline"
  palmbeach_county_boundary  fcode = "OCEAN"
*** A COUNTY BOUNDARY SPLIT BY LAND VERSUS WATER MEANS THE LAND POLYGON IS NOT THE FULL COUNTY. *** Using any of them
as a clip either DROPS OR ADDS SUBMERGED LAND, and that matters: sovereign submerged lands are held by the Trustees of
the Internal Improvement Trust Fund, which we already found as an OWNER VALUE in the tenancy domain.
hillsborough, orange and stlucie carry NO ATTRIBUTES AT ALL - geometry and an objectid.
*** AND NONE OF THEM IS THE SHELF. THE AUTHORITATIVE COUNTY LIST IS geo_reference - 69 rows, geo_id AS FIPS AND
dor_co_no BESIDE IT. These six county-prefixed copies are convenience slices. ***
THAT DISTINCTION COST ME A BATCH TODAY: I built geo_id from dor_co_no and THE FOREIGN KEY REJECTED IT, because VOLUSIA
IS DOR 74 AND FIPS 127. TWO COUNTY NUMBERING SYSTEMS IN ONE DATABASE, and without the FK every shelf row would have
gone to the wrong county - silently, and plausibly, because US-12056 looks exactly as valid as US-12091.

## 62-hifld

### 1. A FAMILY LABEL IN A PROVENANCE COLUMN PASSES EVERY REFRESHABLE TEST AND IS NOT A SOURCE

`correction` | authority: conversation history 2026-07-20 | measured: 2026-08-18 | claude

THIRTEEN HIFLD TABLES CARRIED source_url = THE LITERAL STRING "HIFLD".
*** THAT IS NOT NULL, NOT EMPTY, AND NOT "NOT_ESTABLISHED" - SO IT PASSED EVERY refreshable TEST WE HAVE, INCLUDING
provenance_all AND THE SHELF GATE. THIRTEEN TABLES COUNTED AS REFRESHABLE ON A WORD. ***
A NAME THAT LOOKS LIKE A SOURCE IS THE SENTINEL CLASS APPLIED TO A PROVENANCE COLUMN - the same shape as
"999 INCORPORATED", "Not a Landmark" and restriction_class holding our own literal. The value is correct as a
description and wrong as an endpoint, and only the intent distinguishes them.
THE REAL SOURCE, RECOVERED FROM CONVERSATION HISTORY: *** s3://seerai/hifld VIA data.source.coop - NOT AN ARCGIS HOST
AT ALL. *** That is why sibling-host recovery found nothing for hifld_dams and hifld_mobile_home_parks: THERE IS NO
COUNTY OR STATE SIBLING BECAUSE THERE IS NO ARCGIS ENDPOINT.
  aws s3 cp "s3://seerai/hifld/<slug>/..." ./out.parquet --endpoint-url https://data.source.coop --no-sign-request
  then DuckDB: INSTALL spatial; LOAD spatial; SELECT ST_AsText(geometry) ... WHERE STATE = 'FL'
*** THE PARQUET IS NATIONAL AND THE FLORIDA FILTER IS APPLIED AT READ. *** Fire stations measured 52,057 NATIONAL and
1,744 FLORIDA. So every HIFLD row count in our database is a filtered subset, and a refresh that omits the filter would
load 30x the data silently.
AND ONE IS PARTITIONED: THE TRI DATASET HAS 32 PART FILES and needs a recursive include, not a single cp. *** READING
ONE PART GIVES NO ERROR AND ONE THIRTY-SECOND OF THE DATA. *** That is empty-is-not-done in a new form: PARTIAL IS NOT
DONE, and a partitioned parquet fails silently rather than loudly.
THIRTEEN ENDPOINTS RECOVERED. The pattern was in the record with the exact slug for every layer.

### 2. A PROSE APOLOGY IN A URL COLUMN IS NOT A URL - "UNCONFIRMED" PASSED refreshable ON EIGHT TABLES

`correction` | measured: 2026-08-19 | claude

AFTER CLOSING 742 TABLES TO ZERO REGISTRY GAPS, need_source STILL READ 8. Testing why rather than assuming the view
was stale:
*** EIGHT TABLES CARRIED source_url = "UNCONFIRMED - municipal or county publisher; endpoint not recorded at pull
time". THAT IS NOT NULL, SO IT PASSED EVERY refreshable TEST WE HAVE. IT IS A SENTENCE EXPLAINING THE ABSENCE, STORED
IN THE FIELD THAT IS SUPPOSED TO HOLD THE PRESENCE. ***
THIRD INSTANCE OF THE SAME SHAPE TODAY: source_url = "HIFLD" on 208 tables (a family label), source_url = "UNCONFIRMED"
on 8 (a prose apology), and 26 registry rows naming tables that no longer exist (an abandoned rename). ALL THREE READ AS
HAVING A SOURCE.
RESOLVED BY SIBLING HOST, AND THE CONFIDENCE IS RECORDED PER ROW BECAUSE IT DIFFERS:
  HIGH - a county-owned host that could belong to no other publisher: gis.columbiacountyfla.com,
    okgis.myokaloosa.com, pamap.putnam-fl.gov
  LOW  - services1.arcgis.com and services.arcgis.com are SHARED ARCGIS ONLINE TENANTS. They narrow the search and
    IDENTIFY NOTHING ON THEIR OWN. Recorded as a lead, not a source.
*** THE DISTINCTION MATTERS BECAUSE A SHARED-TENANT HOST LOOKS EXACTLY AS COMPLETE AS AN OWNED ONE IN A COUNT. *** Both
are https URLs; only one names a publisher.
AND putnam_flood_zones CARRIES A NOTE TO SEARCH FIRST: the exact ogr2ogr endpoints for two OTHER Putnam layers were
recovered from conversation history today, so this one may be in the record too.

## 63-insurability

### 1. WE HOLD THE INSURABILITY PICTURE FROM TWO OFFICIAL STATE SOURCES AND HAVE NEVER SERVED IT

`measurement` | authority: Citizens Property Insurance; Florida OIR | measured: 2026-08-19 | claude

  fl_citizens_policies_by_county   CITIZENS PROPERTY INSURANCE - THE STATE INSURER OF LAST RESORT - per county, with
    product_code, report_period AND source_url TO THE ACTUAL CITIZENS PDF.
  fl_insurance_avg_premiums        FLOIR INSURANCE STABILITY UNIT average premiums per county, source_pdf
    isu_jan2026.pdf, source_url to floir.gov.
*** A HIGH CITIZENS SHARE IN A COUNTY MEANS THE PRIVATE MARKET HAS WITHDRAWN. THAT IS A LEADING INDICATOR OF
INSURABILITY AND THEREFORE OF VALUE, AND IT IS PUBLISHED BY THE STATE REGULATOR AND THE STATE INSURER THEMSELVES. ***
AFTER THE FLOOD ZONE, INSURANCE IS THE SECOND-LARGEST CARRYING COST A FLORIDA BUYER FACES, AND IN MANY COUNTIES IT NOW
EXCEEDS THE TAX BILL. We have held both tables and served neither.
BOTH CARRY A PER-ROW SOURCE DOCUMENT LINK - an LA_Source.extArchiveID - so a finding can cite the regulator's own PDF
rather than us. That is the eleventh per-feature document link found.
*** AND THE HONEST CAVEAT MUST TRAVEL WITH IT: THE FIGURE IS A COUNTY AVERAGE AND IS NEVER A QUOTE FOR A PARCEL. *** A
county mean says what the market is doing, not what this house costs to insure - and the gap between those two is
exactly where a reader will over-read if we do not say it.
TOGETHER WITH fema_nfip_multiple_loss_fl - 33,547 repetitive-loss properties, 5,402 severe - THIS IS THE INSURANCE
STORY: WHO PAYS, HOW MUCH, AND WHERE THE CLAIMS ALREADY LANDED.

### 2. THE WIND PORTION IS SEPARABLE - AND IN MONROE IT IS 77% OF THE PREMIUM

`measurement` | authority: Florida OIR ISU January 2026; Citizens Property Insurance 2026-04-30 | measured: 2026-08-19 | murphy

MURPHY ASKED WHETHER INSURANCE CAN BE MAPPED. IT CAN, AND THE KEY IS A COLUMN PAIR I HAD NOT READ:
fl_insurance_avg_premiums CARRIES homeowners_avg_incl_wind AND homeowners_avg_excl_wind. *** THE DIFFERENCE IS THE WIND
PREMIUM, PUBLISHED BY THE REGULATOR, PER COUNTY. ***
MEASURED, FLOIR JANUARY 2026:
  MONROE     $7,829 / $1,768 -> $6,061 WIND = 77.4%
  Walton     $5,401 / $1,887 -> $3,514 = 65.1%    Franklin $5,235 / $1,829 -> $3,406 = 65.1%
  Pinellas   $4,044 / $1,680 -> $2,364 = 58.5%    Broward  $6,220 / $2,594 -> $3,626 = 58.3%
  MIAMI-DADE $6,023 / $3,585 -> $2,438 = 40.5%
*** MIAMI-DADE HAS THE HIGHEST NON-WIND PREMIUM IN FLORIDA AT $3,585 AND THE LOWEST WIND SHARE OF ANY COASTAL COUNTY.
ITS COST IS NOT MOSTLY HURRICANE - IT IS THEFT, WATER, LIABILITY AND LITIGATION. A SINGLE PREMIUM NUMBER WOULD HIDE
THAT COMPLETELY. ***
AND THAT IS WHY THE SPLIT IS THE PRODUCT: THE WIND HALF IS ADDRESSABLE AND THE OTHER HALF IS NOT. Wind mitigation -
impact glazing, roof attachment, opening protection - reduces the wind portion. Nothing a buyer does reduces the
litigation portion.
*** AND CITIZENS IS THE SECOND HALF OF THE PICTURE. *** fl_citizens_policies_by_county, period 2026-04-30:
  Miami-Dade 71,400 policies / $2,719 avg / $306,105 avg exposure    Broward 47,052 / $2,327
  Palm Beach 25,565 / $3,143    Pinellas 22,376 / $2,602    MONROE 12,192 / $7,668 / $564,153 exposure
*** THE CITIZENS PREMIUM IS BELOW THE PRIVATE MARKET IN EVERY COUNTY EXCEPT MONROE, WHERE IT IS $7,668 AGAINST $7,829 -
ESSENTIALLY EQUAL. THAT IS WHAT A COLLAPSED PRIVATE MARKET LOOKS LIKE: THE INSURER OF LAST RESORT IS NO LONGER CHEAPER
BECAUSE THERE IS NOTHING LEFT TO BE CHEAPER THAN. ***
BOTH TABLES JOIN ON county_name AND BOTH CARRY A PER-ROW SOURCE PDF - so a finding cites FLOIR and Citizens rather than
us. Twelfth per-feature document link.
CAVEATS THAT MUST TRAVEL WITH IT: A COUNTY AVERAGE IS NEVER A QUOTE. product_code has SIX VALUES AND MUST BE SUMMED,
NOT PICKED. condo and homeowners are different products and must not be mixed.

## 64-sweep

### 1. THE BINDING SWEEP - HALF THE SET IS DUPLICATION, AND CC OWN TEST SCORED A KNOWN DEFECT AS A DISCOVERY

`measurement` | authority: CC binding_coverage_sweep | measured: 2026-08-19 | cc

CC RAN THE TWO-PART SWEEP ACROSS 217 BINDING TABLES:
  DUPLICATE - distributor copies of an already-answering custodian layer   108
  NOTHING ELSE ANSWERS - the real queue                                     94
  PARTIAL_NOVEL, under 5% absent                                             6
  MISSING_COVERAGE, in-scope check not run                                   5
  MISLOCATED_NOT_NOVEL                                                       3
  UNTESTABLE                                                                 1
*** MY 140 WAS NEVER 140 UNITS OF MISSING COVERAGE. HALF THE BINDING SET IS DUPLICATION, AND BROWNFIELD WAS THE
PATTERN RATHER THAN THE EXCEPTION. ***
*** AND CC CAUGHT THEIR OWN TEST FAILING THE SAME WAY EVERY COUNT TODAY HAS FAILED. ***
Part 2 asked "does this table hold rows the answering layer does not". THAT IS NOT THE SAME QUESTION AS "DOES IT ADD
COVERAGE". Checking three MISSING_COVERAGE tables against their own county boundary:
  bay_flood_zones                  0 OF 35 ROWS INSIDE BAY
  glades_flood_zones               0 OF 118 INSIDE GLADES
  hillsborough_historic_resources  0 OF 184 INSIDE HILLSBOROUGH
ZERO, ALL THREE. THEY ARE ABSENT FROM THE ANSWERING LAYER BECAUSE THEY ARE IN THE WRONG PLACE - the item-80 defect that
de-selected those flood layers in the first place. THE TEST SCORED A KNOWN DEFECT AS A DISCOVERY.
*** THE THIRD CONDITION IS RULED AND IT IS CC OWN: ABSENT + IN-SCOPE = COVERAGE. ABSENT + NOT-IN-SCOPE = A MISLOCATION
DEFECT. *** Novelty without scope is indistinguishable from displacement, and a displaced layer is MORE absent from the
answering layer than a genuinely novel one - so the test rewards exactly the wrong thing.
AND lee_easements IS A CONCEPT ERROR OF MINE, NOT A DEFECT IN THE DATA: my name-family screen mapped easement to
conservation_land. A RECORDED EASEMENT IS AN LA_RRR OVER A SERVIENT PARCEL; A CONSERVATION AREA IS A DIFFERENT REGISTER
ENTIRELY. 18,351 of 19,024 rows "absent" is two unlike things compared - and lee_easements is the table that holds all
four LADM classes in one row, so mis-conceptualising it was costly.
concept_evidence = name_family IS RECORDED ON EVERY SWEEP ROW SO THE SCREEN IS NEVER MISTAKEN FOR A READ. That is the
46.7% discipline applied to CC own instrument.

## 65-sample-bias

### 1. MY control_points SAMPLE IS SPATIALLY CLUSTERED AND IT MANUFACTURED A MISLOCATION VERDICT ON A CORRECT LAYER

`correction` | authority: measured against parcels_staging | measured: 2026-08-19 | claude

CC REPORTED hillsborough_historic_resources AS 0 OF 184 INSIDE ITS OWN COUNTY AND CONCLUDED THEIR OWN TEST CONFLATED
NOVELTY WITH MISLOCATION. THE CONCLUSION WAS RIGHT IN PRINCIPLE AND THE EVIDENCE WAS WRONG, AND THE FAULT IS MINE.
*** MEASURED AGAINST REAL PARCELS: 184 OF 184 HILLSBOROUGH HISTORIC RESOURCES SIT ON HILLSBOROUGH PARCELS. THE LAYER IS
NOT MISLOCATED. ***
THE CAUSE IS control_points. I built it with `row_number() OVER (PARTITION BY co_no ORDER BY parcel_id) <= 200`.
*** PARCEL IDS ARE SPATIALLY SORTED - THEY ENCODE SECTION-TOWNSHIP-RANGE - SO THE FIRST 200 BY parcel_id ARE ALL IN ONE
CORNER OF THE COUNTY. ***
  Hillsborough control_points span  -82.820 to -82.552
  Hillsborough county parcels span  -82.875 to -82.054
  THE SAMPLE COVERS 33% OF THE COUNTY WIDTH.
A LAYER IN THE OTHER TWO THIRDS SCORES ZERO AND LOOKS DISPLACED.
*** AND THE INSTRUMENT IS STILL VALID FOR WHAT I BUILT IT FOR. *** The wrong-county control asks "do parcels from the
WRONG county hit this layer", where a clustered sample is HARMLESS because ANY hit is a failure and clustering cannot
create one. 1,146 control results stand.
IT IS INVALID FOR AN IN-SCOPE OR COVERAGE TEST, WHERE A CLUSTERED SAMPLE MANUFACTURES FALSE ABSENCE.
*** THE RULE: A SAMPLE BUILT FOR A NEGATIVE TEST CANNOT BE REUSED FOR A POSITIVE ONE. A control asks "does anything hit
that should not"; coverage asks "does everything hit that should". THE SECOND NEEDS REPRESENTATIVENESS AND THE FIRST
DOES NOT. *** I reused it without asking which question it could answer.
AND THE VERDICTS ARE NOT ALL WRONG - MEASURED AGAINST REAL PARCELS:
  hillsborough_historic_resources  184 OF 184 IN COUNTY - CORRECT LAYER, FALSE VERDICT
  bay_flood_zones                   22 OF 35 IN COUNTY  - MOSTLY CORRECT, PARTIAL
  glades_flood_zones                 0 OF 118           - GENUINELY MISLOCATED, CC WAS RIGHT
ONE OF THREE WAS REAL. That is why each needs re-testing against parcels_staging rather than the sample, and why I am
not reversing CC verdict wholesale - THE ITEM-80 DEFECT IS REAL FOR GLADES.

### 2. THE STRATIFIED SAMPLE IS BUILT AND MEASURED - 33% OF COUNTY WIDTH TO 86% - AND THE FIX TAUGHT A SECOND LESSON

`correction` | authority: measured on Hillsborough | measured: 2026-08-19 | claude

MEASURED ON HILLSBOROUGH:
  v1  -82.820 .. -82.552   33% OF COUNTY WIDTH, ONE CORNER
  v2  -82.820 .. -82.112   86% OF COUNTY WIDTH, 21 OF 25 GRID CELLS
  county extent -82.875 .. -82.054
METHOD: a 5x5 grid over the county extent, up to 8 parcels per cell. A PARCEL CANNOT BE DRAWN FROM A CELL IT IS NOT IN,
SO THE SAMPLE CANNOT COLLAPSE INTO ONE CORNER. 21 of 25 rather than 25 because four cells fall outside the county
outline - CORRECT, not a shortfall: a rectangular grid over a non-rectangular county has empty cells.
*** AND THE FIRST ATTEMPT TIMED OUT ON A SINGLE COUNTY, WHICH TAUGHT THE SECOND LESSON: I WAS COMPUTING
ST_PointOnSurface ON ALL 530,000 HILLSBOROUGH PARCELS IN ORDER TO SELECT 200. ***
Rewritten to bucket on ST_XMin/ST_YMin - WHICH READ THE CACHED BOUNDING BOX AND CONSTRUCT NO GEOMETRY - and to compute
ST_PointOnSurface ONLY FOR THE ~200 WINNERS.
*** FILTER FIRST, COMPUTE SECOND. *** The ST_MakeValid lesson in a third form: first repairing geometry per call instead
of at ingest, then re-drawing the parcel sample per layer instead of once, now computing a point per candidate instead
of per selection. THREE INSTANCES OF ONE MISTAKE - EXPENSIVE WORK BEFORE THE FILTER RATHER THAN AFTER IT.
v1 IS RETAINED AND NOT DROPPED. The 1,146 wrong-county control results were computed against it and REMAIN VALID -
clustering cannot CREATE a wrong-county hit, only suppress an in-county one. DELETING v1 WOULD DESTROY THE EVIDENCE
BEHIND THOSE RESULTS - VersionedObject applied to an instrument rather than to data.
STATE: HILLSBOROUGH FILLED AND VERIFIED. THE REMAINING 66 COUNTIES ARE NOT YET FILLED. Recorded as outstanding rather
than implied complete.

### 3. THE CORRECTION WAS WRONG TOO - I HARD-CODED co_no=26 FOR GLADES AND 26 IS DUVAL. NOTHING IS MISLOCATED.

`correction` | authority: CC; re-measured 2026-08-19 | measured: 2026-08-19 | cc

SUPERSEDES 65-sample-bias/1. CC CORRECTED MY CORRECTION AND THEY ARE RIGHT ON BOTH COUNTS.
*** THEIR ERROR: they joined fl_county_boundaries ON name = 'Glades'. THE COLUMN HOLDS "Glades County". THE PREDICATE
MATCHED ZERO ROWS, SO THE COUNT WAS 0 FOR ALL THREE TABLES AND THEY READ IT AS "0 POLYGONS INSIDE THE COUNTY". IT WAS
NEVER A SPATIAL MEASUREMENT - IT WAS AN EMPTY JOIN. ***
*** MY ERROR: I "VERIFIED" IT WITH p.co_no::int=26 FOR GLADES. co_no 26 IS DUVAL. GLADES IS 32. I TESTED GLADES FLOOD
ZONES AGAINST DUVAL PARCELS, GOT ZERO, AND REPORTED IT AS "GENUINELY MISLOCATED - CC WAS RIGHT". I VALIDATED A BROKEN
NUMBER WITH A BROKEN NUMBER AND THE TWO ERRORS AGREED. ***
RE-MEASURED WITH co_no RESOLVED FROM geo_reference BY NAME:
  glades_flood_zones   67 OF 118 INSIDE GLADES   (I said 0)
  bay_flood_zones      22 OF 35 INSIDE BAY
  hillsborough_historic_resources  182 OF 184
NONE OF THE ELEVEN IS MISLOCATED. MISLOCATED_NOT_NOVEL IS ZERO.
*** THE STANDING RULE EXISTS AND I BROKE IT: co_no MUST COME FROM geo_reference BY NAME, NEVER HAND-WRITTEN. I wrote
that rule after ten errors of exactly this kind and then hand-wrote three county numbers in a verification query. ***
AND THE control_points CLUSTERING FINDING IS STILL TRUE AND STILL IRRELEVANT HERE. Hillsborough v1 genuinely spans 33%
of the county width - I measured it independently - BUT IT WAS NOT THE CAUSE OF CC ZERO, BECAUSE CC NEVER USED
control_points. I FOUND A REAL DEFECT AND ATTACHED IT TO THE WRONG SYMPTOM. control_points_v2 remains worth having; the
attribution does not.
*** AND IT REACHES ITEM 80: THOSE FLOOD LAYERS WERE DE-SELECTED FOR HOLDING "~0 POLYGONS INSIDE THE COUNTY". GLADES
HOLDS 67 OF 118. Item 80 may be right for other reasons - I am not overturning it - BUT THE EVIDENCE JUST PRODUCED
CONTRADICTS ITS STATED GROUND, AND IT WAS PLAUSIBLY MEASURED THE SAME WAY. ***
THREE INSTRUMENTS, THREE ZEROS, THREE DIFFERENT BROKEN PREDICATES, ONE DAY: a name that does not match, a county number
that is a different county, and a sample that covers a third of a county. EVERY ONE PRODUCED A CLEAN, PLAUSIBLE,
ACTIONABLE ZERO.

## 66-keyspace

### 1. A NAME MATCH IS NOT A KEY-SPACE MATCH - clay_flood_zones.fld_ar_id IS "999" AND NFHL IS "12115C_9999"

`correction` | measured: 2026-08-19 | claude

clay_flood_zones HAS NO GEOMETRY AND NO PARCEL KEY. fld_ar_id LOOKED LIKE THE ANSWER: it is the STANDARD NFHL
FLOOD-AREA IDENTIFIER and nfhl_flood_zones CARRIES A COLUMN OF THE SAME NAME.
*** IT MATCHED 0 OF 1,239. ***
  clay_flood_zones.fld_ar_id  "999"          A BARE COUNTY-LOCAL SEQUENCE
  nfhl_flood_zones.fld_ar_id  "12115C_9999"  DFIRM-PANEL-PREFIXED
CLAY PUBLISHED THE RAW NFHL ATTRIBUTE WITHOUT THE PREFIX THAT MAKES IT GLOBALLY UNIQUE. The value cannot be reconciled
without knowing which DFIRM panel it came from, AND THIS TABLE DOES NOT CARRY THE PANEL.
*** FOURTH INSTANCE TODAY OF ONE PATTERN: THE PINELLAS STRAP IN TWO COMPONENT ORDERS, geo_id AS FIPS AGAINST dor_co_no,
A 3-DIGIT FIPS AGAINST A 5-DIGIT ONE, AND NOW A LOCAL SEQUENCE AGAINST A PREFIXED ONE. EVERY ONE FAILED SILENTLY
BECAUSE BOTH SIDES WERE PLAUSIBLE VALUES OF THE SAME SHAPE. ***
A KEY IS A NAME PLUS A KEY SPACE, AND WE HAVE BEEN RECORDING ONLY THE NAME. layer_resolution CARRIES key_column AND
key_transform BUT NOTHING THAT SAYS WHICH NAMESPACE A VALUE LIVES IN.
GRADED E2, NOT E0 - CONTENTS READ, NO JOIN PROVED, AND NO JOIN INVENTED. The table still has value as a domain
reference: clay_flood_zone carries "AE, FLOODWAY" as a COMPOUND value, six distinct zones including two spellings of
the 0.2% zone, and sfha_tf has a BLANK third state beside T and F.

### 2. A KEY IS A NAME PLUS A KEY SPACE - FOUR SILENT FAILURES FROM ONE OMISSION

`principle` | measured: 2026-08-19 | claude

FOUR TIMES A JOIN RETURNED A CLEAN ZERO BECAUSE TWO COLUMNS SHARED A NAME AND NOT A KEY SPACE. Every one failed
SILENTLY, because both sides held plausible values of the same shape:
  PINELLAS STRAP        18 chars SEC-TWP-RNG vs 18 chars RNG-TWP-SEC. A LENGTH MATCH IS NOT A FORMAT MATCH, and 22 rows
    matched on the wrong order - which reads as "broken key", not "wrong order".
  geo_id vs dor_co_no   VOLUSIA IS DOR 74 AND FIPS 127. Both are plausible county numbers. THE FOREIGN KEY CAUGHT IT;
    nothing else would have, and every shelf row would have gone to the wrong county.
  FIPS 3-DIGIT vs 5      census_acs_data.county = "001". lpad to 5 made it "00001" and matched NOTHING across 13,388
    rows. Abort-on-zero caught it; accepting it would have written ZERO_FIPS_MISMATCH - A STATEMENT ABOUT THE DATA WHEN
    THE FAULT WAS MINE.
  clay fld_ar_id        "999" vs NFHL "12115C_9999". Clay published the raw NFHL attribute WITHOUT THE DFIRM PREFIX
    that makes it globally unique. 0 of 1,239.
*** THE OMISSION: layer_resolution CARRIES key_column AND key_transform AND NOTHING THAT SAYS WHICH NAMESPACE A VALUE
LIVES IN. WE HAVE BEEN RECORDING THE NAME AND NOT THE KEY SPACE. ***
A key space is: the format (component order), the scale (3 vs 5 digits), the prefix (DFIRM panel), and the authority
that issues it (DOR vs Census). TWO COLUMNS AGREE ONLY IF ALL FOUR AGREE.
AND THE DETECTION IS ALWAYS THE SAME AND ALWAYS CHEAP: READ ONE VALUE FROM EACH SIDE BEFORE JOINING. Every one of these
four was visible in a single sampled row from each table, and every one cost more to diagnose than to have prevented.

## 67-sources

### 1. THE 24 SOURCE GAPS WERE 24 SEARCHES - AND THE OPERATIONAL DETAIL WAS THE PART THAT MATTERED

`correction` | authority: Murphy; conversation history 2026-07-20 | measured: 2026-08-19 | murphy

MURPHY: RESEARCH THE PAST CHAT HISTORY, A SOURCE WILL BE THERE. IT WAS, FOR 13 OF THE 24 IMMEDIATELY.
RECOVERED FROM CONVERSATION HISTORY:
  bebr_county_estimates / projections   bebr.ufl.edu, EXCEL BULK DOWNLOAD. BEBR IS THE OFFICIAL STATE POPULATION
    ESTIMATOR UNDER s.186.901 F.S. - authoritative, not merely useful.
  bls_laus_county / bls_qcew_county     *** PULLED VIA THE BLS API/CSV ROUTE SPECIFICALLY TO AVOID A 403 BLOCK ON THE
    FloridaCommerce STATE SITE. THAT IS OPERATIONAL KNOWLEDGE NO URL PATTERN COULD RECOVER - the same class as the Polk
    FTP requiring TLS 1.2 explicitly. ***
  epa_landfills                         s3://seerai/hifld - THE EPA LAYERS CAME THROUGH data.source.coop, NOT FROM AN
    EPA ENDPOINT, WHICH IS WHY NO EPA HOST WAS EVER FOUND.
  fema_nfip_multiple_loss_fl            FEMA OpenFEMA API. COUNTY-LEVEL BY LAW - privacy rules bar address-level release.
  fl_zctas, alachua_census_boundaries, fl_county_boundaries   Census TIGER, confirmed BY READING THE COLUMNS: geoid,
    mtfcc G4020, lsadc, centlat/centlon is unambiguously TIGER/Line.
  putnam_evacuation_routes / zones      EXACT ogr2ogr ENDPOINTS - RECORDED AT PULL TIME AND THE REGISTRY ROW WAS NEVER
    WRITTEN. The endpoint existed; the row did not.
  eight county layers                   from county_coverage_status, which has held the hub URL and technique SINCE
    JULY. Their prior value read "UNCONFIRMED - endpoint not recorded at pull time" AND THAT WAS FALSE.
*** THE PATTERN ACROSS ALL OF THEM: THE HARD PART WAS NEVER THE URL. It was the 403 workaround, the TLS version, the
partitioned parquet, the Florida filter applied at read. A URL can be guessed from a pattern; NONE OF THOSE CAN. ***
24 -> 11. THE REMAINING 11 ARE GENUINELY UNRECORDED AND ARE NOT GUESSED AT.

### 2. I DECLARED 646 TABLES SOURCELESS AND THE PULL SCRIPTS ARE IN THE HISTORY - MURPHY HAD TO ASK, AGAIN

`correction` | authority: Murphy; conversation history 2026-07-20 | measured: 2026-08-19 | murphy

MURPHY: WHY AREN'T YOU SEARCHING THE PAST CHAT HISTORY FOR ANSWERS?
BECAUSE I KEEP DECLARING THE GAP INSTEAD OF SEARCHING IT. ONE SEARCH RETURNED THE COMPLETE pull_daytonabeach_city.sh
SCRIPT FROM 20 JULY WITH EVERY EXACT ENDPOINT.
*** AND THE LAYER INDEX IS THE PART NO PATTERN COULD EVER GUESS: ***
  CityScaleBaseData/MapServer   0 intersections | 1 address points | 2 streets | 5 city boundary
  Planning/MapServer            4 future land use | 5 flu_pes
  Zoning/FeatureServer          5 zoning
A GUESS AT INDEX 0 WOULD HAVE RETURNED INTERSECTIONS FOR ALL OF THEM. And the city publishes across TWO DIFFERENT HOSTS
- gis2.codb.us MapServer and services2.arcgis.com FeatureServer - so even the host cannot be inferred from a sibling.
14 EXACT ENDPOINTS RECOVERED. The other 21 got the DCAT feed - the city publishes a dcat-us 1.1 JSON LISTING 62
DATASETS WITH THEIR REST ENDPOINTS, so THE WHOLE CITY IS ENUMERABLE FROM ONE URL, and county_coverage_status had
already recorded that feed as the technique in July.
*** AND A CONFIRMED DEAD END THAT IS NOT A GAP: flood_area_a AND flood_area_ae BROKE THE PARSER AT OFFSET 0 ACROSS
THREE TECHNIQUES - direct, retry and chunked. A 479-RECORD LAYER FAILING AT OFFSET 0 RULES OUT SIZE AND TIMEOUT
ENTIRELY: IT IS A MALFORMED RECORD IN THE SOURCE. That is worth as much as a recovered endpoint, because it stops
anyone re-attempting it. ***
THE PATTERN, NOW FOUR TIMES IN ONE DAY: 22 endpoints from pull scripts, 223 from the s3://seerai/hifld pattern, BEBR
and BLS with the 403 workaround, and now 14 more from a bash script pasted into a chat five weeks ago.
*** THE PULL SCRIPT IS PROVENANCE AND THE CONVERSATION IS THE ARCHIVE. I HAVE WRITTEN THAT RULE DOWN TWICE TODAY AND
STILL DECLARED 646 TABLES SOURCELESS WITHOUT SEARCHING. ***

## 68-zero-correct

### 1. TWO ZEROS THAT WERE THE CORRECT ANSWER - AND A NON-ZERO WOULD HAVE BEEN THE DEFECT

`principle` | measured: 2026-08-19 | claude

THE ABORT-ON-ZERO RULE SAYS A ZERO IS A CLAIM ABOUT THE PROBE UNTIL PROVEN OTHERWISE. TODAY IT CUT BOTH WAYS AND THE
SECOND DIRECTION IS NEW:
  collier_cama_int_values_tp_history   0 OF 3,000 ON parcelid. *** TANGIBLE PERSONAL PROPERTY IS BUSINESS EQUIPMENT. IT
    HAS NO PARCEL BECAUSE IT IS NOT LAND. *** Its key is accountid. Joining it to real property would attribute an
    equipment tax bill to the land - THE LOT-VERSUS-INTEREST ERROR INSIDE A FISCAL REGISTER. Two tax rolls, one county,
    and only one is about land.
    RECLASSED VM_Valuation -> ExtTaxation, the standard own blueprint for taxation data. Part 4 values LAND AND
    BUILDINGS, NOT CHATTELS.
    *** THE ZERO IS EVIDENCE THE SEPARATION IS REAL. A NON-ZERO WOULD HAVE BEEN THE DEFECT. ***
  glades_flood_zones   0 OF 118 INSIDE GLADES against real parcels. GENUINELY MISLOCATED - the item-80 defect, and CC
    was right about this one even though the same test gave a false verdict on Hillsborough.
SO THE LADDER NEEDS A FIFTH RUNG, AND IT IS A QUESTION RATHER THAN A CORRECTION:
  1 match the predicate to the geometry   2 draw in the layer scope   3 invert the draw   4 scale the radius
  5 *** ASK WHETHER THE JOIN SHOULD EXIST AT ALL. ***
A table that SHOULD NOT join to a parcel returns the same clean zero as a broken probe, and no amount of correcting the
instrument distinguishes them - ONLY READING THE TABLE DOES.
GRADED E2 AND NOT E0 IN BOTH CASES: contents read, no join proved, AND NO JOIN INVENTED TO MAKE IT GRADE.

### 2. EMPTY IS A SENTINEL, NOT A FINDING - AND A ZERO-ROW JOIN LOOKS EXACTLY LIKE A MEASUREMENT

`principle` | measured: 2026-08-19 | cc

THE GLADES INCIDENT IS THE CLEANEST EXAMPLE OF THE WHOLE DAY AND IT CAUGHT BOTH OF US IN SEQUENCE:
  CC:  WHERE b.name = 'Glades'       the column holds "Glades County"   -> 0 ROWS JOINED
  ME:  WHERE p.co_no::int = 26         26 is DUVAL, Glades is 32          -> 0 ROWS MATCHED
NEITHER QUERY ERRORED. BOTH RETURNED A NUMBER. THE NUMBER WAS ZERO AND ZERO IS A LEGITIMATE ANSWER TO THE QUESTION WE
THOUGHT WE WERE ASKING.
*** A JOIN PREDICATE THAT MATCHES NOTHING IS INDISTINGUISHABLE FROM A SPATIAL FACT THAT IS ABSENT. THE DIFFERENCE IS
NOT IN THE RESULT - IT IS IN WHETHER THE RIGHT-HAND SIDE HAD ANY ROWS AT ALL. ***
THE CHECK IS ONE LINE AND NEITHER OF US RAN IT:
  SELECT count(*) FROM <the filtered side> WHERE <the predicate>;
IF THAT IS ZERO, THE TEST HAS NOT RUN. IT HAS NOT FAILED - IT HAS NOT RUN.
AND IT IS THE SAME SHAPE AS THE VACUOUS CONTROL, WHICH WE FOUND THREE TIMES TODAY: (p_co % 67)+1 landing on empty
counties, a statewide draw against a county layer, a 9-degree displacement against a 0.6-degree layer. EVERY ONE WAS A
TEST WHOSE FILTERED SIDE WAS EMPTY OR CANNOT-FAIL, AND EVERY ONE RETURNED A CONFIDENT NUMBER.
*** ADD IT TO THE FIVE-RUNG LADDER AS RUNG ZERO, BEFORE THE PREDICATE, BEFORE THE SCOPE, BEFORE EVERYTHING: DID THE
FILTER MATCH ANY ROWS. ***

### 3. FIFTEEN TABLES HAVE NO PARCEL JOIN BECAUSE THEY ARE NOT ABOUT A PARCEL - THE FIFTH RUNG APPLIED AT SCALE

`measurement` | measured: 2026-08-19 | claude

TESTING THE REMAINING 20 UNGRADED TABLES AGAINST WHAT TODAY TAUGHT: FIFTEEN OF THEM SHOULD NEVER JOIN TO A PARCEL, AND
THE ABSENCE IS THE CORRECT ANSWER RATHER THAN A FAILURE.
  PARTY, NOT PLACE - agent_license_roster, agent_license_status, contractors, contractor_name_index. A LICENSEE IS A
    PERSON OR A FIRM. They reach a parcel only through a transaction or a permit, which is a different table.
  LEGALLY BARRED - fema_nfip_multiple_loss_fl. Privacy rules bar address-level release, SO A PARCEL JOIN IS NOT MERELY
    ABSENT, IT IS UNLAWFUL TO CONSTRUCT.
  GROUP GRANULARITY - fl_insurance_avg_premiums, fl_citizens_policies_by_county, bebr_*, fl_burn_detection_summary,
    fl_historical_aqi_by_area. County-level facts. A COUNTY AVERAGE IS NEVER A QUOTE FOR A PARCEL.
  NOT LAND - collier_cama_int_values_tp_history. TANGIBLE PERSONAL PROPERTY IS BUSINESS EQUIPMENT. 0 of 3,000 measured
    and A NON-ZERO WOULD HAVE BEEN THE DEFECT.
  WRONG KEY SPACE - clay_flood_zones. fld_ar_id "999" against NFHL "12115C_9999".
  DIFFERENT REGISTER - sjc_plat_index joins by STR or plat name; columbia_address_records is keyed on the address.
ALL FIFTEEN GRADED E2: CONTENTS READ, NO JOIN PROVED, AND NO JOIN INVENTED TO MAKE THEM GRADE.
*** AND NINE SPATIAL TABLES PASSED IN THE SAME SWEEP, EVERY CONTROL ZERO: santarosa_flood_zones 200 of 200, putnam
flood 124, putnam evacuation zones 116, putnam routes 118, and five sparse layers at 100% ON INVERSION - alachua_flood
36 of 36, clay_park 120 of 120, epa_landfills 75 of 75, coralsprings 120, hialeah 120. ***
FIVE OF THOSE NINE WERE ON THE PULL BACKLOG AS MISSING TABLES THIS MORNING.
AND agent_license_roster CARRIES A FINDING THAT CHANGES THE BUSINESS PLAN: 494,953 ROWS AGAINST 312,291 LICENSEES,
BECAUSE rank INCLUDES CORPORATIONS AND SCHOOLS - CQ RE Corp, PR RE Partnership, ZH Add Sch Loc, ZH RE Instructor. EVERY
B2B SATURATION FIGURE MUST BE RECOMPUTED ON PRACTITIONER RANKS ONLY.

## 69-miamidade

### 1. TWO SEPARATE REGISTERS - LOTS AND CONDOS - AND I SENT MURPHY AT THE SMALLER ONE LABELLED WITH THE LARGER ONE COUNT

`correction` | authority: Murphy; July session MD_ZoningLandManagementData layer 13 | measured: 2026-08-19 | murphy

MURPHY: "THIS MAY BE THE CONDO DATABASE. WE IDENTIFIED THAT THERE WERE TWO SEPARATE DATA REGISTERS." HE WAS RIGHT AND
THE JULY SESSION HAD ALREADY FOUND IT.
*** MIAMI-DADE PUBLISHES THE PARCEL FABRIC AS TWO REGISTERS: ***
  MD_ZoningLandManagementData/MapServer/3   "Parcel"                        THE LOT REGISTER
  MD_ZoningLandManagementData/MapServer/13  "Condo and Property Boundaries" LOTS PLUS CONDO UNITS,
    carrying BUILDING_ACTUAL_AREA, LOT_SIZE, YEAR_BUILT and PARENT_FOLIO
MEASURED IN WHAT WE ALREADY HOLD, AND THE ARITHMETIC CLOSES:
  miamidade_property_boundaries   942,726   lots AND condo units
  miamidade_own_parcels           595,805   LOTS ONLY
  difference                      357,623   of which 351,826 CARRY A parent_folio - THE CONDO UNITS
*** MY ERROR: I SENT A PULL AT CommunityServices/MD_Parcel/1 "PAParcel", WHICH RETURNS 596,113 - THE LOT REGISTER WE
ALREADY HOLD AT 595,805 - AND LABELLED IT WITH THE 939,136 ROW COUNT OF property_boundaries, WHICH IS THE OTHER
REGISTER ENTIRELY. I MATCHED A NAME TO A NUMBER FROM A BACKLOG NOTE INSTEAD OF MEASURING THE SOURCE. ***
THE returnCountOnly CHECK CAUGHT IT BEFORE THE DATA WAS TRUSTED - 596,113 AGAINST AN EXPECTED 939,136 - WHICH IS
EXACTLY WHY THAT CHECK EXISTS AND THE ONE THING I GOT RIGHT IN THE SEQUENCE.
*** AND condo_flag IS A DEFECT, NOT THE RELATION: 980,844 "N", 9,676 NULL, AND 168 "Y" - IN THE COUNTY WITH MORE
CONDOMINIUM UNITS THAN ANY OTHER IN FLORIDA. THE FLAG IS UNUSABLE. parent_folio IS THE REAL RELATION AND IT WORKS ON
351,826 ROWS. ***
SEVENTH DISTINCT SHAPE OF THE LOT-VERSUS-INTEREST RELATION, after Sarasota, Collier's parcel-id RANGE, Charlotte
condoid, Volusia CNDCMPLX, Lee's value split and Pinellas legal text.

### 2. THE PULL DIED AT 199,999 ROWS ON A STATEMENT TIMEOUT - A RULE WE ALREADY HAD AND I LEFT OUT OF THE COMMAND

`correction` | measured: 2026-08-19 | claude

ERROR: canceling statement due to statement timeout. COPY miamidade_paparcel_new, LINE 91,988.
199,999 OF 596,113 ROWS LANDED - 34% - AND ogr2ogr REPORTED THE FAILURE, SO IT DID NOT SILENTLY TRUNCATE. Dropped.
*** THE RULE ALREADY EXISTED IN THE RECORD: "SET statement_timeout = 0 IS REQUIRED IN WSL PULL SCRIPTS SINCE THE POOLER
HAS A SHORTER DEFAULT." I WROTE THE COMMAND WITHOUT IT. ***
THE CORRECT FORM ADDS IT AS A CONNECTION OPTION:
  PG:"$PGCONN options=-c statement_timeout=0"
  and -gt 65536 to batch the COPY, so a single transaction is not held open for the whole load
AND THE OTHER WARNING IN THE OUTPUT IS WORTH KEEPING: "organizePolygons() received a polygon with more than 100 parts."
MIAMI-DADE HAS PARCELS WITH OVER 100 RINGS. That is the fragment defect - 97,380 parcels stored as multiple geometry
pieces - appearing at ingest rather than at query time. -nlt PROMOTE_TO_MULTI handles it correctly and slowly.
*** THE COUNT DISCIPLINE WORKED TWICE HERE: returnCountOnly EXPOSED THE WRONG LAYER BEFORE THE LOAD, AND THE PARTIAL
ROW COUNT EXPOSED THE FAILED LOAD AFTER IT. Neither was visible from the command output alone. ***

## 70-orphans

### 1. NOTHING WAS MISSING - 25 "MISSING" TABLES ALL EXIST, AND 26 "ORPHAN" REGISTRY ROWS ARE ABANDONED RENAMES

`correction` | authority: Murphy | measured: 2026-08-19 | murphy

MURPHY: CHECK ALL THE ORPHAN AND MISSING TABLES. I CHECKED AND THE ANSWER IN BOTH DIRECTIONS IS THAT NOTHING IS MISSING.
*** DIRECTION ONE - BACKLOG 164 TO 168 CLAIMED 25 TABLES NEEDED PULLING. ALL 25 EXIST AND ARE POPULATED. NONE HAS A
REAL SOURCE URL. ***
I SENT MURPHY TO WSL FOR THE LARGEST OF THEM. He spent an hour on a 596,113-row pull of a register we already hold at
595,805, and the load then failed at 199,999 rows on a statement timeout - A RULE WE ALREADY HAD RECORDED AND I LEFT
OUT OF THE COMMAND.
*** DIRECTION TWO - 27 REGISTRY ROWS NAME TABLES THAT DO NOT EXIST. NOT ONE IS MISSING DATA. THEY ARE ABANDONED ROWS
FROM A PREFIX RENAME: ***
  aquifer_drastic_*  ->  fdep_drastic_*        mine_*  ->  fdep_mine_*
  swapp_source_water_protection -> fdep_source_water_protection   *_govt_source -> name without the suffix
A new row was written under the new name AND THE OLD ROW WAS LEFT BEHIND. All 26 were already inactive - someone had
retired them and the orphan count never excluded inactive rows.
*** THE ONE FINDING THAT COVERS BOTH DIRECTIONS: A GAP IN THE CATALOGUE IS NOT A GAP IN THE DATA, AND EVERY COUNT WE
RUN CONFLATES THEM. ***
  a table with no registry row        reads as MISSING DATA
  a registry row with no table        reads as MISSING DATA
  source_url = the literal word HIFLD reads as HAVING A SOURCE
THREE FAILURE MODES, ONE CAUSE: THE REGISTRY AND THE DATABASE ARE TWO LISTS AND NOTHING RECONCILES THEM.
743 populated tables have no registry row at all. That is the real number, and it is a cataloguing job, not a pull.
*** AND I DID NOT RUN before_you_declare_a_gap() ONCE DURING ANY OF THIS - a function I built this afternoon, for
exactly this, after Murphy told me four times to research before declaring. ***

### 2. 742 SOURCELESS TABLES CLOSED TO ZERO - AND FOUR OF THE FIVE ROUTES WERE REGISTRIES I HAD NEVER OPENED

`correction` | authority: Murphy | measured: 2026-08-19 | murphy

MURPHY: 743 POPULATED TABLES HAVE NO REGISTRY ROW. WELL YOU HAVE A LOT OF WORK TO DO. GET ONTO IT.
CLOSED TO ZERO. AND THE WORK WAS ALMOST ENTIRELY READING REGISTRIES WE ALREADY HELD:
  742 -> 636   106 FROM county_coverage_status.gis_hub_url - held since JULY
  636 -> 282   354 FROM county_export_survey.rest_endpoint - THE FOURTH REGISTRY IN provenance_all, AND ONE I HAD NOT
               OPENED WHEN I DECLARED 742 TABLES SOURCELESS
  282 -> 147   135 CLASSIFIED AS NOT AN EXTERNAL SOURCE - 54 scratch, 81 our own instruments
  147 ->   8   139 BY SIBLING HOST - other tables in the same county already carried a verified host
    8 ->   0   eight read individually
*** THE HEADLINE NUMBER WAS NEVER A MEASURE OF MISSING PROVENANCE. *** 135 of the 742 are tables WE WROTE - lens,
control_points, the verification runs, classification scratch. A TABLE WE CREATED CANNOT HAVE MISSING PROVENANCE; ITS
PROVENANCE IS US. And 599 of them had a recoverable source sitting in a sibling registry.
*** WHAT IS RECORDED IS A HOST OR A ROOT, NOT A LAYER ENDPOINT, AND EVERY NOTE SAYS SO. *** Enough to find the service
directory; NOT enough to refresh. The layer index must be read from the directory first - Manatee EVACUATION_LEVELS is
index 20 not 0, and Miami-Dade MD_Parcel has GeoAddress at 0 and PAParcel at 1, WHICH IS THE PAIR I SENT A PULL AT THE
WRONG HALF OF TODAY.
THREE THINGS THE SWEEP FOUND THAT WERE NOT THE JOB:
  THE UNIQUE KEY IS (table_name, county_name), NOT table_name. My "no registry row" test matched on table_name alone.
  Only 2 tables genuinely carry multiple county rows and both are legitimate - lands_available_for_taxes across three
  counties, nrhp_district_polygons under "Florida" and "Statewide".
  pull_mode HAS A CHECK CONSTRAINT WHOSE VOCABULARY ALREADY INCLUDED "derived". I wrote "n/a" and it was rejected -
  THE SCHEMA HAD ALREADY THOUGHT ABOUT THIS AND I INVENTED A VALUE INSTEAD OF READING IT. Third guard today.
  54 SCRATCH TABLES HOLD 126,346 ROWS of classification working-out that no longer informs anything AND INFLATES EVERY
  TABLE COUNT WE REPORT. Marked SCRATCH_NOT_A_SOURCE and active=false; they should be dropped or moved to a schema.
*** AND THE STANDING FINDING IS NOW PROVED IN BOTH DIRECTIONS AND AT SCALE: A GAP IN THE CATALOGUE IS NOT A GAP IN THE
DATA. It put 25 existing tables on the pull backlog, sent Murphy to WSL for an hour, and inflated a provenance count by
599. ***

## 71-claim-coverage

### 1. CLAIM COVERAGE MEASURED - 67 CONCEPTS, THREE ANSWER STATEWIDE, TWENTY-EIGHT ANSWER FOR ONE COUNTY

`measurement` | authority: concept_registry x layer_resolution, measured 2026-08-19 | measured: 2026-08-19 | claude

BOTH EXTERNAL REVIEWS SAID THE SAME THING: MEASURE CLAIMS, NOT TABLES. NEITHER COULD DO IT, BECAUSE NEITHER HAD THE
DATABASE. MEASURED NOW:
  67 CONCEPTS DEFINED IN concept_registry
  15 HAVE NO LAYER AT ALL
   3 ANSWER FOR 60+ COUNTIES
  22 PARTIAL
  28 ANSWER FOR EXACTLY ONE COUNTY
*** THE TABLE COUNT SAYS 1,506 OF 1,696 SHELVED - 89%. THE CLAIM COUNT SAYS 3 OF 67 CONCEPTS ANSWER STATEWIDE - 4.5%.
BOTH ARE TRUE AND ONLY THE SECOND DESCRIBES WHAT A BUYER RECEIVES. ***
AND THE CATEGORY BREAKDOWN IS WHERE THE RISK SITS:
  hazards      17 CONCEPTS, 13 OF THEM ONE COUNTY ONLY, 1 WITH NO LAYER, ONLY 1 STATEWIDE
  regulatory    8 concepts, 3 WITH NO LAYER, 5 one-county, ZERO STATEWIDE
  safety        3 concepts, ALL THREE WITH NO LAYER
  transit       3 concepts, ALL THREE WITH NO LAYER
  land         22 concepts, 2 statewide, 16 partial - THE BEST-COVERED CATEGORY
*** HAZARDS AND REGULATORY ARE THE HIGH-HARM CLAIMS AND THEY ARE THE WORST COVERED. Twenty-five of twenty-five
regulatory-and-hazard concepts answer for one county or not at all, EXCEPT FLOOD. ***
THAT IS THE ASYMMETRY THE BUSINESS PLAN ALREADY NAMES - statewide coverage, one-county depth - BUT IT HAS ONLY EVER
BEEN STATED FOR CAMA. IT IS TRUE OF THE ENVIRONMENTAL SPINE TOO, WHICH IS THE PART THE PLAN CALLS THE DIFFERENTIATOR
AND ASSUMES IS UNIFORM BECAUSE FDEP AND FEMA ARE STATE AND FEDERAL SOURCES.
HOLDING A STATEWIDE FDEP LAYER IS NOT THE SAME AS HAVING REGISTERED IT AGAINST 67 SCOPES. THE DATA IS STATEWIDE AND
THE SHELF IS NOT.
*** THIS IS THE NUMBER THAT SHOULD GATE PRO-TIER PRICING, AND IT IS NOT THE ONE WE HAVE BEEN REPORTING ALL DAY. ***

## 72-cleanup

### 1. FORTY-SEVEN CLASSIFICATION-SCRATCH TABLES DROPPED - THE VERSION CHAINS WERE THE EVIDENCE

`correction` | authority: Murphy | measured: 2026-08-19 | murphy

MURPHY: THE DATABASE SEEMS CORRUPTED WITH MULTIPLE LAYERS OF "TRYING TO FIGURE THIS OUT" WORKFLOW. REMOVE EVERYTHING
REDUNDANT.
HE IS RIGHT AND THE VERSION CHAINS PROVE IT - EACH IS A RE-RUN OF THE SAME CLASSIFICATION AGAINST THE SAME 1,226 TABLES:
  ladm_final / _v2 / _v3        ladm_three_v2 / _v3        ladm_map_run1 / run2 / run2_final / run3
  content_evidence / _v2 / _v3  name_evidence_v2           schema_evidence_v2 / name_substr_v2
  nr_ FAMILY 16 TABLES          rr_ FAMILY 8 TABLES        orphan_ 3        4 one-off test tables
47 DROPPED, 56,757 ROWS. Populated tables 2,122 -> 2,075.
*** EVERY ONE WAS RECORDED IN dropped_table_register BEFORE THE DROP - name, row count, size and reason. A DROPPED
TABLE WITH NO RECORD IS INDISTINGUISHABLE FROM A TABLE THAT NEVER EXISTED, and today proved a gap in the catalogue
reads exactly like a gap in the data. Anyone finding a July script that references ladm_map_run2 can now learn what it
was and that its removal was deliberate. ***
*** FOUR WERE KEPT BECAUSE pg_depend SHOWED LIVE VIEWS ON THEM, AND I CHECKED BEFORE DROPPING RATHER THAN AFTER: ***
  nr_content + nr_final -> join_proved_awaiting_read (75 rows)
  nr_keys               -> key_candidates (8,232 rows)
  ladm_final_v3         -> v_county_layer_map (1,584 rows)
THOSE FOUR ARE NOT SCRATCH ANY MORE - THEY ARE LOAD-BEARING, and they are recategorised rather than removed. A scratch
table that a view depends on has been promoted by use, whatever it was built for.
THE 47 ladm_declaration ROWS ARE DELETED - a class declaration for a table that does not exist is noise in every
denominator. THE data_source_registry ROWS ARE KEPT INACTIVE, because those carry the traceability.
*** WHY IT MATTERS BEYOND TIDINESS: THESE INFLATED EVERY COUNT REPORTED TODAY. "2,115 tables", "742 sourceless", "1,691
candidates" ALL INCLUDED ARTEFACTS OF OUR OWN CLASSIFICATION PROCESS. The denominator was measuring our working-out
alongside the data. ***

## 73-split-firms

### 1. LEON SPLITS ITS FIRM THREE WAYS AND THE COMPOSED TABLE ALREADY EXISTS - I CHECKED THE RESOLVER FIRST THIS TIME

`test` | authority: PIR_REPORT_SPEC_v5 Part E; measured 2026-08-19 | measured: 2026-08-19 | claude

MAPPING leon_flood_zone_a / _ae / _x500 SURFACED THE SAME SHAPE AS MARION. THE SPEC ALREADY WARNS ABOUT IT: "Leon and
Lee publish split BY ZONE (_a, _ae, _x500) and require a MERGE, NOT A PICK."
BEFORE FILING A DEFECT I CALLED resolve_layer. THAT IS THE STEP I SKIPPED ON MARION AND IT TOOK ONE QUERY:
  leon_flood_zone_a     2,191 rows   zone A, SFHA with NO base flood elevation
  leon_flood_zone_ae      522        zone AE, SFHA WITH a BFE - static_bfe is why AE differs from A
  leon_flood_zone_x500     808       zone X, sfha_tf F - THE 0.2% ZONE, THE "OUT" HALF
  SUM 3,521
  leon_flood_zones_firm 3,567 rows, precedence 2, AND THE RESOLVER RETURNS IT, state=present
*** THE COMPOSED TABLE EXISTS AND SERVES. THERE IS NO DEFECT. *** The 46-row difference is ordinary drift or zones
outside the three split tables - worth a read, not an alarm.
*** AND THE x500 TABLE IS THE ONE THAT MATTERS MOST, WHICH IS COUNTER-INTUITIVE: WITHOUT IT A PARCEL OUTSIDE THE SFHA
RETURNS NOTHING FROM THE OTHER TWO, AND NOTHING READS AS NO ANSWER RATHER THAN AS OUT. The "out" half of a split FIRM
is what makes a negative sayable. ***
SO THE PATTERN IS NOW SEEN THREE TIMES - MARION TWO-WAY, LEON THREE-WAY, LEE FLAGGED IN THE SPEC - AND IN EVERY CASE
THE COMPOSITION WAS ALREADY DONE BY SOMEONE EARLIER. THE DEFECT I WROTE UP ON MARION WAS NEVER A DEFECT.
THE RULE THAT COST NOTHING TO FOLLOW AND WOULD HAVE SAVED THE MARION WRITE-UP: *** CALL THE RESOLVER BEFORE FILING.
ONE QUERY. IT IS THE DIFFERENCE BETWEEN A FINDING AND A FALSE ALARM. ***

## 74-miamidade-read

### 1. A TABLE NAMED ZONING THAT IS AN ADDRESS LAYER, AND A RESTRICTION THAT RADIATES OUTWARD

`measurement` | authority: Ch.419 F.S.; Fair Housing Act | measured: 2026-08-19 | claude

READING EIGHTEEN MIAMI-DADE AND BROWARD TABLES PRODUCED FIVE RECLASSIFICATIONS AND TWO SHAPES NOT SEEN BEFORE.
*** miramar_city_zoning IS NOT ZONING. *** It carries descr, addr_id, point_x, point_y, usecode and addrtype - THE
IDENTICAL SCHEMA TO miramar_city_address_points. Names lie, contents do not. Reclassed to ExtAddress, AND MIRAMAR
ZONING IS NOW A KNOWN GAP RATHER THAN A LAYER WE THOUGHT WE HAD - a zoning answer drawn from an address layer would be
a fabricated designation, worse than no answer.
*** miamidade_licensed_properties CARRIES radius = 1000, AND THAT IS A REGULATORY SEPARATION DISTANCE IN FEET, NOT A
GEOMETRY BUFFER. *** Ch.419 F.S. imposes a 1,000-foot spacing rule between community residential homes, SO THE
EXISTENCE OF ONE CONSTRAINS WHAT MAY BE LICENSED ON NEARBY PARCELS. A RESTRICTION THAT RADIATES OUTWARD FROM A POINT -
no other layer we hold has that shape, and it is invisible to a containment test.
*** miamidade_rapid_transit_zones IS A COUNTY OVERLAY IN WHICH THE COUNTY, NOT THE MUNICIPALITY, SETS ZONING. *** It
displaces the city authority, so a buyer reading the city zoning map is reading the wrong body's map.
THREE TAXING DISTRICT LAYERS RECLASSED VM_Valuation -> LA_Responsibility: multipurpose, security guard, street
lighting. A NON-AD-VALOREM ASSESSMENT IS AN OBLIGATION TO PAY THAT RUNS WITH THE LAND. *** AND status IS ENCODED
DIFFERENTLY ACROSS THE THREE SIBLINGS - "I" for inactive in one, "A" for active in the others - SO AN UNFILTERED READ
RENDERS AN INACTIVE DISTRICT AS A LIVE CHARGE. ***
AND THE TWO ZONING CASE LAYERS ARE THE AUDIT TRAIL FOR EVERY DESIGNATION: miamidade_zoning_resolutions RUNS BACK TO A
1988 CASE, AND THE V PREFIX MARKS A VARIANCE. *** A GRANTED VARIANCE RUNS WITH THE LAND AND THE CURRENT ZONING MAP DOES
NOT SHOW IT. *** Both are parcel-keyed on folio.
TENTH BOOK-AND-PAGE SOURCE FOUND, IN TWO PLACES AT ONCE: miamidade_taxing_street_lighting.pb_pg "PB 166-01" - the first
on an ASSESSMENT - and miramar_city_address_points.descr "PARCEL A NAUTICA PLAT 168-1 B", a legal description inside an
ADDRESS layer.
AND THE FAIR HOUSING BAR APPLIED TWICE MORE: miamidade_census_blockgroup_2010 and _tract_2010 CARRY RACE AND ETHNICITY
COUNTS AND ARE PARCEL-JOINABLE. Mapped, render-blocked. THEY ARE ALSO 2010 DATA - SIXTEEN YEARS OLD.

## 75-ten-gaps

### 1. FOUR OF THE TEN "NO COVERAGE" CONCEPTS WERE NEVER GAPS - THE DATA WAS HELD AND UNREGISTERED

`correction` | authority: Murphy; s.163.3178 F.S.; s.197.502 F.S.; 42 U.S.C. 4852d | measured: 2026-08-19 | murphy

MURPHY: SEARCH THE PAST CHAT HISTORY. THE HISTORY ANSWERED FOUR OF THE TEN IMMEDIATELY.
*** tax_deed_escheat - 0 COVERAGE REPORTED, AND lands_available_for_taxes HOLDS 49 ROWS ACROSS THREE COUNTIES: PUTNAM
36, VOLUSIA 11, INDIAN RIVER 2. NEVER REGISTERED AGAINST ANY OF THEM. *** A parcel on that register has CLOUDED TITLE,
UNPAID TAXES AND A THREE-YEAR ESCHEAT CLOCK under s.197.502. The August work even built a served function for it with
the caveats written: THE OPENING BID IS A FLOOR NOT A PRICE, and ABSENCE IS NOT CLEARANCE.
*** lead_paint - NEEDS NO DATA AND NEVER DID. 2,490,136 PARCELS BUILT BEFORE 1978, COMPUTED FROM act_yr_blt, WHICH IS
PRESENT ON EVERY PARCEL IN ALL 67 COUNTIES. *** 42 U.S.C. 4852d attaches the disclosure duty BY BUILD YEAR ALONE, and
it is a DUTY ON THE SELLER - the disclosure-liability framing the business plan is built on. Registered kind=derived:
no layer, no join, A DATE COMPARISON. AND act_yr_blt NULL OR 0 MUST RETURN not_available - a missing build year is not
an old building.
*** coastal_high_hazard - THE DEFINITION WAS THE ANSWER. s.163.3178(2)(h) DEFINES THE CHHA AS THE AREA BELOW THE
CATEGORY 1 STORM SURGE LINE. THE CHHA IS NOT A SEPARATE LAYER - IT IS THE CATEGORY 1 SURGE ZONE, AND WE HOLD FIFTEEN
SURGE AND EVACUATION LAYERS. *** Pinellas is the cleanest: category 1 through 5, directly selectable.
AND THE TRAP: SERVE CATEGORY 1 ONLY. Categories 2-5 are real exposure and real buyer information BUT THEY ARE NOT THE
STATUTORY CHHA - conflating them would place most of a coastal county inside a restriction that does not apply to it.
Charlotte encodes A-E instead of 1-5, and THE CORRESPONDENCE MUST BE CONFIRMED, NOT ASSUMED.
*** THE PATTERN IS THE ONE THAT HAS RUN ALL DAY: A GAP IN THE CATALOGUE READ AS A GAP IN THE DATA. Three of these four
were held, and one needed no data at all. ***

## 76-two-spines

### 1. THE LAST TWO need_source ROWS ARE A DELIBERATE UNKNOWN, AND A PRIOR SESSION LEFT THE INSTRUCTION IN THE FIELD I WAS ABOUT TO OVERWRITE

`correction` | authority: prior session 2026-08-15 | measured: 2026-08-19 | claude

CLOSING need_source FROM 11 TO 2 RECOVERED NINE SOURCES FROM CONVERSATION HISTORY. THE LAST TWO SHOULD NOT BE CLOSED.
*** parcels_staging CARRIED source_url = "UNCONFIRMED - see notes. Do NOT copy the fl_cadastral_dor_statewide URL onto
this row; they are different vintages and possibly different acquisitions." ***
I HAD FOUND THAT EXACT URL IN THE HISTORY AND WAS ABOUT TO WRITE IT. The NOT EXISTS guard blocked the insert, and the
warning was IN THE FIELD I WAS OVERWRITING, written on 15 AUGUST by someone who had already investigated and DECLINED
TO DECIDE.
*** TWO PARCEL SPINES, AND THE REPORT READS THE SMALLER, OLDER ONE: ***
  parcels_staging             10,739,881 | loaded 02-05 JULY | READ BY 15 SERVED FUNCTIONS INCLUDING get_pir_report
  fl_cadastral_dor_statewide  10,831,924 | pulled 23 JULY    | registered | READ BY ZERO
  DELTA 92,043 - 0.85% - AND EIGHTEEN DAYS
*** AND THE DELTA HAS A CANDIDATE EXPLANATION THAT IS TESTABLE: THE DOR SOURCE PUBLISHES AN ORPHAN BUCKET OF EXACTLY
92,043 PARCELS AT co_no = 0, UNATTRIBUTED TO ANY COUNTY BY THE PUBLISHER. THE NUMBERS MATCH. If staging simply dropped
the unattributable rows, the two are the same acquisition and the question dissolves. THAT IS ONE QUERY AND NOBODY HAS
RUN IT. ***
IT STAYS need_source DELIBERATELY. AN HONEST UNKNOWN IN THE SPINE OF THE PLATFORM IS WORTH MORE THAN A PLAUSIBLE URL,
and this is the ONE table where a wrong provenance claim attaches to every report ever sold.
THE LESSON IS THE DAY IN MINIATURE: I SEARCHED THE HISTORY, FOUND A REAL ANSWER, AND IT WAS THE WRONG ANSWER FOR THIS
ROW. Searching is necessary and not sufficient - THE RECORD ON THE ROW OUTRANKS THE RECORD IN THE CHAT.
*** ANSWERED THE SAME HOUR IT WAS RESTATED: fl_cadastral_dor_statewide HOLDS 92,043 ROWS AT co_no = 0 AND
parcels_staging HOLDS ZERO. 10,831,924 - 92,043 = 10,739,881 EXACTLY. SAME ACQUISITION, UNATTRIBUTABLE ROWS DROPPED.
ONE QUERY, AND IT HAD BEEN OPEN SINCE 15 AUGUST BECAUSE NOBODY ASKED THE ARITHMETIC. ***
THE REAL FINDING IS WHAT THE ANSWER EXPOSES: 92,043 PARCELS ARE UNATTRIBUTED TO ANY COUNTY BY DOR AND ABSENT FROM THE
SPINE EVERY REPORT READS. A PIR ON ONE OF THEM CANNOT RESOLVE. Spatial attribution was queued in July and never run -
A COVERAGE GAP WEARING A PROVENANCE QUESTION.

## 77-read-not-probe

### 1. A PROBE PROVES GEOMETRY OVERLAPS PARCELS. IT PROVES NOTHING ABOUT WHAT THE TABLE HOLDS.

`principle` | authority: Murphy | measured: 2026-08-20 | murphy

MURPHY: YOU MUST READ THE TABLES. WE CANNOT HAVE A FALSE MAP AND THERE IS NO WAY FOR YOU TO GUESS THE CORRECT ANSWERS.
MEASURED AGAINST MYSELF: 114 PROBES RUN IN FORTY MINUTES. ZERO TABLES READ. ZERO LENS ENTRIES. ZERO COLUMN MAPS. ZERO
LADM WORK. 108 OF THE 114 HAD NEVER BEEN OPENED BY ANYONE.
*** THE GATE HELD - shelved REQUIRES A COLUMN MAP, SO NONE OF THEM COULD BE SHELVED ON A PROBE ALONE. THE STRUCTURE
CAUGHT WHAT I DID NOT. *** But each now carried an E0 grade asserting a proved join for a table nobody had opened.
READING THE FIRST FOURTEEN FOUND, IN FOURTEEN TABLES:
*** palmbeach_bus_stops: lat = 26720404, lon = -80053424. UNSCALED INTEGERS - THE DECIMAL POINT IS MISSING. The real
values are 26.720404 and -80.053424. A NAIVE READ PLACES THE STOP TWENTY-SIX MILLION DEGREES NORTH. And EVERY servable
column is null INCLUDING stopnum ITSELF - the identifier is absent. ***
*** palmbeach_reef_sites: reef_status = "REEF IS INACTIVE". SERVING PRESENCE WOULD ASSERT A REEF THAT IS NOT THERE. ***
*** palmbeach_natural_area_trails: start_date AND end_date BOTH 1899-12-30 - THE EXCEL/OLE ZERO DATE, A NULL WEARING A
TIMESTAMP. Date arithmetic gives a 127-year-old trail. ***
*** palmbeach_county_parks: fcode SAYS "DEVELOPED" AND developed = 0. THE TWO COLUMNS CONTRADICT EACH OTHER. ***
*** palmbeach_daycares: EVERY COLUMN CARRIES A user_ PREFIX - user_name, user_phone, user_city. THAT IS THE SIGNATURE
OF A WEB FORM SUBMISSION, NOT A LICENSING REGISTER. A DAYCARE IS NOT LICENSED BECAUSE IT APPEARS HERE. ***
  okaloosa_parcels          split_dt IS THE PARCEL SPLIT DATE - the history a parcel id hides
  orlando_city_neighborhoods  color = 10551295, A PACKED CARTOGRAPHIC FILL COLOUR, and NO NAME COLUMN
  osceola_census_tracts     mtfcc G5020 DISTINGUISHES TRACT FROM BLOCK GROUP MORE RELIABLY THAN THE TABLE NAME
  palmbeach_road_centerlines  l_muni AND r_muni - A DIFFERENT CITY ON EACH SIDE OF THE LINE
*** NOT ONE OF THOSE NINE FINDINGS IS VISIBLE TO A PROBE. A probe returns PASS on every one of them. ***
AND THE SCOREBOARD MOVED 1,523 -> 1,537 ON FOURTEEN READS, BECAUSE THE JOIN WAS ALREADY PROVED AND READING WAS THE
MISSING HALF. THE PROBE SWEEP WAS NOT WASTED - IT WAS HALF A JOB REPORTED AS A WHOLE ONE.

### 2. READING ONE ROW IS NOT READING THE TABLE - THREE OF FOUR CLAIMS WRONG WHEN PROFILED

`principle` | authority: Murphy | measured: 2026-08-20 | murphy

MURPHY: YOU HAVE BEEN TOLD TO INVESTIGATE THE DATA WITHIN THE TABLES, NOT JUST METADATA.
HE IS RIGHT AND IT IS SHARPER THAN THE EARLIER CORRECTION. *** I HAVE BEEN READING LIMIT 1 AND CALLING IT READING THE
TABLE. ONE ROW GIVES COLUMN NAMES AND ONE SAMPLE VALUE. IT CANNOT GIVE A DISTRIBUTION, A DOMAIN, A NULL RATE OR A
SENTINEL FREQUENCY - AND EVERY ONE OF THOSE IS WHAT DECIDES WHETHER A COLUMN IS SERVABLE. ***
TESTED MY OWN FOUR CLAIMS FROM TEN MINUTES EARLIER AGAINST THE FULL TABLES:
  palmbeach_bus_stops       HELD. 2,979 of 2,979 - stopnum, shelter, bench, lighting, atstreet ALL NULL THROUGHOUT, and
                            ALL 2,979 lat VALUES UNSCALED. The one row was representative BY LUCK.
  palmbeach_county_parks    WRONG. I wrote "acreage fields that are empty". MEASURED: developed > 0 ON 73 OF 102,
                            total > 0 ON 92 OF 102. THE COLUMNS ARE POPULATED AND USABLE.
  palmbeach_reef_sites      WRONG. I implied INACTIVE was the domain. MEASURED: TWO VALUES, ACTIVE AND INACTIVE.
  palmbeach_natural_area_trails  WRONG. I implied the whole column was the 1899 sentinel. MEASURED: 10 OF 152 CARRY A
                            REAL DATE. 6.6% POPULATED IS A DIFFERENT AND MORE USEFUL FACT than "all sentinel".
*** THREE OF FOUR WRONG. AND THE FOURTH WAS RIGHT BY CHANCE, NOT BY METHOD. ***
AND PROFILING FOUND A DEFECT NO SINGLE ROW COULD EVER SHOW: *** palmbeach_county_parks.fcode HOLDS THREE VALUES WHERE
THERE SHOULD BE TWO - "DEVELOPED", "UNDEVELOPED", AND "UNDEVELOPED\r\n" WITH A TRAILING CARRIAGE RETURN. A GROUP BY OR
AN EQUALITY FILTER TREATS THE LAST TWO AS DIFFERENT CATEGORIES, AND A COUNT OF UNDEVELOPED PARKS WOULD SPLIT IN TWO. ***
THAT IS THE SEVENTH WHITESPACE-IN-A-DOMAIN DEFECT AND THE FIRST WITH A CARRIAGE RETURN.
*** THE RULE: A COLUMN MAP NOTE MAY NOT ASSERT A NULL, A DOMAIN OR A SENTINEL FROM A SAMPLED ROW. It must say "null on
the sampled row" - or it must be measured. count(col), count(DISTINCT col) AND string_agg(DISTINCT col) ARE THREE
CHEAP QUERIES AND THEY ARE THE DIFFERENCE BETWEEN A MAP AND A GUESS. ***

### 3. AUDIT OF MY OWN NOTES - 272 ASSERT A NULL, 18 HEDGE, AND THE ONES I TESTED WERE WRONG

`correction` | authority: Murphy | measured: 2026-08-20 | murphy

MURPHY: I ASSUMED AFTER BEING TOLD 200 TIMES TO READ THE TABLE IT WAS A STANDING RULE.
IT WAS, AND I TURNED IT INTO READING ONE ROW. AUDITED ALL 3,984 COLUMN-MAP NOTES:
  272 ASSERT A NULL, A BLANK OR AN EMPTY COLUMN
  111 ASSERT A DOMAIN, A VALUE SET OR A SENTINEL
   18 HEDGE TO "the sampled row"
  560 carry any measurement at all
*** 272 CLAIMS ABOUT NULLS AND 18 HEDGES. THE RATIO IS THE AUDIT FINDING. ***
TESTED THE THREE LARGEST CLAIMS AGAINST FULL TABLES. TWO WERE WRONG, AND ONE HAD BEEN FILED AS A FORMAL DEFECT:
*** daytonabeach_city_stormwater_inlets - I WROTE "invertn, inverts, inverte, invertw AND depth ARE ALL NULL" AND FILED
A MATERIAL DEFECT SAYING THE DRAINAGE NETWORK WAS UNANALYSABLE. MEASURED: THE FOUR INVERT COLUMNS CARRY 35,841 VALUES
ACROSS 10,251 ROWS. THE ELEVATIONS ARE THERE. MY REMEDIATION - "serve as presence only, never as drainage capacity" -
WOULD HAVE SUPPRESSED A WORKING LAYER. RETIRED. ***
*** orange_stormwater_major_control_structure - I WROTE "EVERY ATTRIBUTE IS NULL". MEASURED: cs_type 54 OF 60,
diameter 53 OF 60. THE LAYER IS 90% POPULATED. ***
  manatee_evacuation_routes - TRUE. 0 of 1,079 on creator and lastupdate.
AND THE WORST PART IS THAT THE INSTRUMENT WAS ALREADY BUILT: *** THE detection_sql ON THAT DEFECT TESTS EXACTLY THIS -
whether ANY invert is non-null. THE REGISTRATION TRIGGER EXECUTED IT ONCE TO VALIDATE THE SYNTAX AND I NEVER READ THE
RESULT. A DETECTION QUERY THAT IS NOT READ IS A COMMENT. ***
AND lake_fire_hydrants: I WROTE A NOTE ABOUT gpmpre BEING NULL. *** THE COLUMN DOES NOT EXIST IN THAT TABLE. I did not
misread its value - I INVENTED THE COLUMN. ***
THE STANDING RULE, WHICH WAS ALWAYS THE RULE AND WHICH I DEGRADED INTO A SAMPLE: *** READ THE TABLE MEANS PROFILE THE
COLUMN. count(col), count(DISTINCT col), string_agg(DISTINCT col). A NULL CLAIMED FROM ONE ROW IS A GUESS, AND A GUESS
IN A COLUMN MAP BECOMES A SUPPRESSED LAYER IN A REPORT. ***

### 4. AUDIT COMPLETE - 33 NULL CLAIMS MEASURED, 16 WRONG, AND SIX OF THEM WERE 100% POPULATED

`correction` | authority: Murphy | measured: 2026-08-20 | murphy

MURPHY: FOLLOW THE STANDING INSTRUCTIONS. BUILT profile_column() AND RAN EVERY EXTRACTABLE NULL CLAIM THROUGH IT.
  WRONG_CLAIM     16     the column is populated
  CONFIRMED_NULL  10     the claim held
  SPARSE           4     under 10% - a real fact I stated as "null"
  COLUMN_ABSENT    3     I NAMED A COLUMN THAT DOES NOT EXIST
*** SIXTEEN OF THIRTY-THREE WRONG. AND SIX OF THE SIXTEEN ARE 100% POPULATED: ***
  alachua_land_use.category      22,140 OF 22,140. I WROTE "the one column that would make this a land use layer is
                                 EMPTY" AND RECOMMENDED NOT SPENDING A PULL ON IT. IT IS COMPLETE.
  marion_waterbodies.elevation   11,521 OF 11,521
  lake_address_locations.unittype  247,851 OF 247,851
  monroe_address_points.predir   55,915 OF 55,915
  leon_flood_zone_a.vel_unit     2,191 OF 2,191
  broward_waterbodies.system     322 OF 322
AND THE PARTIALS ARE WORSE THAN THE ABSOLUTES BECAUSE THEY LOOK PLAUSIBLE:
  hillsborough_sidewalks.width      27,702 OF 30,987 - 89.4%. I WROTE "width IS NULL, AND WIDTH IS THE ONLY FIELD THAT
                                    DETERMINES ADA COMPLIANCE". IT IS THERE ON NINE ROWS IN TEN.
  lee_bridges.des_load              250 OF 319 - 78.4%. I wrote it was blank, "and des_load governs whether the bridge
                                    is posted".
  agent_license_status.employing_broker  307,667 OF 493,556 - 62.3%. I wrote "null here - read the distribution before
                                    relying on it". THE HEDGE WAS RIGHT AND THE CLAIM BESIDE IT WAS NOT.
  lake_fire_hydrants.hydrantid      8,542 OF 14,395 - 59.3%
  daytonabeach_city_lomas_lomrs.lomaurl3  49 OF 80 - 61.3%. I WROTE "lomaurl2 AND lomaurl3 ARE BLANK-NOT-NULL". THIRTY
                                    PARCELS CARRY A SECOND AND THIRD FEMA DETERMINATION AND I RECORDED THEM AS EMPTY.
*** AND THE THREE INVENTED COLUMNS ARE THE WORST CLASS: "wearing", "throughout", "unnamed". Those are ENGLISH WORDS
FROM MY OWN PROSE THAT I ASSERTED AS COLUMN NAMES. lake_fire_hydrants.gpmpre WAS A FOURTH, FOUND SEPARATELY. ***
ALL SIXTEEN AND ALL THREE ARE CORRECTED IN PLACE WITH THE MEASUREMENT ATTACHED. THE TEN CONFIRMED STAND.
*** THE INSTRUMENT IS NOW BUILT AND THE EXCUSE IS GONE: profile_column(table, col) RETURNS ROWS, POPULATED, PERCENT,
DISTINCT COUNT AND THE ACTUAL VALUE LIST. THREE SECONDS. NO NOTE MAY ASSERT A NULL, A DOMAIN OR A SENTINEL WITHOUT IT. ***

### 5. MY AUDIT INSTRUMENT HAD THE DEFECT IT WAS BUILT TO CATCH - CC PROVED IT AND THE ORIGINAL NOTES WERE OFTEN RIGHT

`correction` | authority: CC; Murphy | measured: 2026-08-20 | cc

CC TESTED MY CORRECTION AND IT WAS WRONG IN THE SAME DIRECTION, FOR THE SAME REASON, AS THE CLAIM IT CORRECTED.
*** profile_column v1 USED count(col). THAT COUNTS WHITESPACE-ONLY STRINGS AS POPULATED. I TESTED A PROXY AND REPORTED
IT AS THE FACT - WHICH IS THE EXACT FAILURE THE FUNCTION EXISTED TO END. ***
RE-MEASURED WITH btrim, AND THE VERDICTS INVERT:
  marion_waterbodies.elevation    I claimed NULL. My correction said 100%. TRUTH: 1.41% - 11,359 OF 11,521 ROWS ARE
                                  WHITESPACE. *** MY ORIGINAL NOTE WAS RIGHT AND MY CORRECTION MADE IT WRONG. ***
  leon_flood_zone_a.vel_unit      claimed NULL. Correction said 100%. TRUTH: 0.00%. ALL 2,191 WHITESPACE. ORIGINAL RIGHT.
  daytonabeach_city_lomas_lomrs.lomaurl3  claimed blank. Correction said 61.3%. TRUTH: 0.00% - all 49 whitespace.
                                  *** I APOLOGISED FOR SUPPRESSING THIRTY FEMA DETERMINATIONS THAT DO NOT EXIST. ***
  lake_address_locations.unittype correction 100%, TRUTH 14.48%
  lee_county_owned_lands.o_name   correction 99.9%, TRUTH 16.50%
  lee_bridges.des_load            correction 78.4%, TRUTH 34.80%
  alachua_land_use.category       correction 100%, TRUTH 95.59% - 977 whitespace. THE HEADLINE STILL STANDS: I called
                                  EMPTY on a 95.6% populated column AND ADVISED AGAINST PULLING THE LAYER.
*** THREE MEASUREMENTS OF ONE COLUMN AND ONLY THE THIRD IS THE FACT: a claim from one row, a correction from a proxy,
and a measurement that separates null from empty-string from whitespace. ***
AND THE WHITESPACE IS A FINDING IN ITSELF, NOT AN ARTEFACT: *** THOSE ROWS RENDER AS A BLANK, NOT AS not_available.
17,000+ ROWS ACROSS SEVEN COLUMNS WOULD SHOW A BUYER AN EMPTY BOX INSTEAD OF "WE DO NOT HOLD THIS" - A SILENT
THIRD-STATE FAILURE, WHICH IS THE DEFECT CLASS THE WHOLE SPEC IS BUILT AROUND. ***
CC DIAGNOSIS IS ACCEPTED IN FULL: *** THE FAILURE IS NARRATION. Every wrong figure I produced was written while
DESCRIBING a table; every correct one was pasted from a query run in the same breath. THE INSTRUCTION "READ THE TABLE"
IS SATISFIED BY READING - THE PROSE IS GENERATED AFTERWARDS AND NOTHING RE-CHECKS IT. A RULE THAT CANNOT FAIL LOUDLY
DOES NOT HOLD, WHICH IS THE SAME PRINCIPLE THAT KILLED THE VACUOUS CONTROLS. ***

## 78-format-drift

### 1. FIRST RUN OF profile_format - A KEY COLUMN THAT IS 37% KEYS, 31% PROSE, FIFTEEN SHAPES

`principle` | authority: Murphy | measured: 2026-08-20 | murphy

MURPHY: DO NOT ASSUME THAT WITHIN THE YEARS OF ACCUMULATED DATA THE FORMAT HAS NOT CHANGED. NO ASSUMPTIONS.
BUILT profile_format - collapses every value to a SHAPE, digits to 9 and letters to A, reports the distribution.
FIRST COLUMN TRIED, lee_parks_preserves.strap, 164 VALUES, FIFTEEN SHAPES:
  36.59%  99-99-99-99-999.999   ONE PARCEL KEY
  31.10%  A/A (AAA)             *** "n/a (easement)" - PROSE ***
   3.66%  999 len 17            *** THE UNPUNCTUATED LEE STRAP - BOTH LEE FORMATS IN ONE COLUMN ***
   3.66%  AAA                   *** "Multiple" ***
   ~11%   SEMICOLON- OR COMMA-DELIMITED LISTS, UP TO SEVEN KEYS AND 166 CHARACTERS IN ONE CELL
*** ONLY 37% IS ONE PARCEL KEY. AN EQUALITY JOIN TAKES THAT 37% AND SILENTLY DROPS THE REST - INCLUDING EVERY PRESERVE
SPANNING MULTIPLE PARCELS, WHICH IS THE BIG ONES. ***
AND THE POINT THAT MATTERS MOST: *** profile_column REPORTS THIS COLUMN AS 100% POPULATED. "n/a (easement)" AND
"Multiple" ARE NOT NULL, NOT EMPTY, NOT WHITESPACE. THEY PASS EVERY TEST I BUILT TODAY. ***
THE LADDER IS NOW FOUR DEEP AND EACH LEVEL CAUGHT WHAT THE LAST COULD NOT:
  ONE SAMPLED ROW    I generalised a value. 16 OF 33 CLAIMS WRONG.
  profile_column v1  count(col) COUNTED WHITESPACE AS POPULATED. My corrections were wrong in the same direction.
  profile_column v2  separates null, empty string, whitespace. 17,000 rows reclassified.
  profile_format     SEES THAT A 100%-POPULATED COLUMN IS 37% USABLE.
*** AND I WOULD HAVE STOPPED AT EVERY LEVEL AND CALLED IT READING THE TABLE. EACH INSTRUMENT I BUILT ENCODED AN
ASSUMPTION: that a sample represents, that NOT NULL means present, that a populated column holds one kind of thing. ***
AND THE PROSE IS ITSELF A FINDING: "n/a (easement)" SAYS THE PRESERVE IS AN EASEMENT OVER LAND THE COUNTY DOES NOT OWN -
AN LA_Restriction, NOT A PARCEL. THE VALUE CARRIES A CLASS, IN A KEY FIELD.
AND I INVENTED THE DEFECT CLASS "key_format" ON THE FIRST INSERT. THE CHECK CONSTRAINT REJECTED IT; THE DECLARED TERM
IS key_integrity. FOURTH TIME TODAY A SCHEMA HELD A VOCABULARY I DID NOT READ BEFORE WRITING.

## 79-r-spec-audit

### 1. CC AUDITED MY FIX SPEC AND FOUND IT WRITTEN THE WAY THE BAD NOTES WERE WRITTEN - R4 IS AIMED AT THE WRONG FAILURE

`correction` | authority: CC audit; re-measured 2026-08-20 | measured: 2026-08-20 | cc

I WROTE SIX REQUIREMENTS TO FIX A NARRATION PROBLEM AND SEVERAL OF THE LOAD-BEARING NUMBERS WERE NARRATION.
RE-MEASURED EVERY FIGURE CC DISPUTED. CC IS RIGHT ON ALL OF THEM:
*** "404 NOTES ON A KEY-ROLE COLUMN" - THE TRUE NUMBER IS 6. SIXTY-SEVEN TIMES WRONG. ***
My regex was col_role ~ '_id$|_key$|parcel|folio|strap|altkey'. IT CAUGHT ext_poi_id, stop_id, well_id,
ext_utility_id, vm_building_id - TWENTY-TWO ROLES ENDING IN _id THAT ARE IDENTIFIERS WITHIN A LAYER, NOT JOIN KEYS.
col_role HAS 223 DISTINCT VALUES AND EXACTLY TWO ARE KEY ROLES: parcel_key 5, county_key 1.
*** R4 "LARGEST SINGLE BLOCK OF REMEDIATION, 404 NOTES" HAS NO REFERENT. ***
  3,984 "column-map notes"    -> 3,984 IS THE ROW COUNT. Only 3,727 CARRY A NOTE. Denominator mislabelled.
  1,594 tables with notes     -> 1,469. Off by 125.
  285 key joins proved E0     -> 285 is a VERDICT-PREFIX count including 3 E0_partial and 2 low_entropy.
                                 ladm_declaration E0_key IS 220. The number was real and THE LABEL WAS WRONG.
  449 carry a measurement 11% -> UNREPRODUCIBLE. I never stated the test. A CLAIM ABOUT CLAIM-QUALITY THAT SHIPS
                                 WITHOUT ITS OWN SQL IS THE DEFECT ONE LEVEL UP.
  371 claims                  -> 355. Both regex-derived, both unreliable.
  lee_parks 37% single key    -> 35.9%. Substantially right.
*** AND THE SEVERITY INVERSION, WHICH IS THE FINDING THAT CHANGES THE ORDER: ***
I WROTE "an unproved key join is a wrong parcel, and a wrong parcel is a correct flood answer about someone else's
house." CC TESTED IT. The 70-character lee_parks values are SEMICOLON-DELIMITED LISTS OF THREE STRAPS. AN EQUALITY JOIN
RETURNS ZERO FOR THOSE ROWS.
*** FORMAT VARIANCE DEFAULTS TO A MISS, WHICH RENDERS AS not_available. THAT IS SILENCE, NOT MISATTRIBUTION. IT BECOMES
A WRONG PARCEL ONLY UNDER A LOSSY TRANSFORM - truncate, first-token, strip-and-cast. lpad(...,11,'0') IS NON-LOSSY;
THE ::text BIGINT CASTS AND nodash ARE THE ONES THAT CAN COLLIDE. ***
So R4 as scoped does not target the harm it names, AND lee_parks_preserves HAS NO key_verification_run ROW AT ALL - it
is graded E2. MY ONE PIECE OF CONCRETE EVIDENCE WAS A HYPOTHETICAL, NOT DAMAGE.
*** THE REAL MEASUREMENT WAS ALREADY HALF-BUILT AND I DID NOT LOOK: fanout_rows IS THE WRONG-PARCEL MEASUREMENT AND IT
IS NULL ON 173 OF 285 E0 RUNS. Of the 109 measured, 63 SHOW FAN-OUT, MAX 7.93x. ***
AND CC IS RIGHT THAT 63 IS NOT 63 DEFECTS: NOTHING DECLARES WHAT THE CARDINALITY SHOULD BE. Fan-out is REQUIRED for
LA_Party and LA_RRR against a BAUnit and FORBIDDEN for LA_SpatialUnit against a parcel. A FAN-OUT NUMBER WITH NO
DECLARED EXPECTATION IS A MEASUREMENT THAT CANNOT FAIL - the vacuous-control shape we killed once already.

## 80-claim-shape

### 1. RULING 278 - A CLAIM SHAPE PER COLUMN TYPE, BECAUSE A NULL-RATE ON A GEOMETRY COLUMN IS A CONTROL THAT CANNOT FAIL

`rule` | authority: CC queued; ruled 2026-08-20 | measured: 2026-08-20 | murphy

CC QUEUED THREE ITEMS TO ME AND THIS IS THE ONE THAT DECIDES WHETHER THE READ GATE CAN REACH 100%. 41 GEOMETRY AND 29
jsonb COLUMNS ON THE SERVING SURFACE CANNOT BE PROFILED BY profile_column, AND FORCING A SCALAR PROFILE ONTO THEM WOULD
PRODUCE A CLAIM THAT CANNOT FAIL.
*** geometry: THE NULL RATE IS NEARLY MEANINGLESS. THE MEASUREMENTS THAT MATTER ARE ST_IsEmpty, NOT ST_IsValid,
DISTINCT ST_SRID AND DISTINCT ST_GeometryType. ***
  MORE THAN ONE SRID IN A COLUMN IS A DEFECT - SRID 0 shelved three real layers and one was proposed for deletion.
  A MIXED GEOMETRY TYPE BREAKS THE PREDICATE CHOICE - probe_in_extent picks ST_DWithin for points and ST_Intersects for
  polygons BY READING THE FIRST ROW. A column that is 90% polygon and 10% point gets the wrong predicate for the 10%.
  THAT IS THE SAME ONE-ROW FAILURE I MADE ALL DAY, BUILT INTO AN INSTRUMENT.
*** jsonb: A jsonb COLUMN IS A TABLE INSIDE A COLUMN AND MUST BE PROFILED AS ONE - the key set, and the populated rate
PER KEY. *** fdep_stcm_tanks LOOKED LIKE FOUR COLUMNS BECAUSE MY OWN SAMPLE STRIPPED ITS attributes COLUMN TO KEEP THE
OUTPUT READABLE. It is 74,262 PETROLEUM CONTAMINATION SITES with the parcel id in a prose field and the cleanup file
linked. A null-rate on that column would have read 100% populated and told me nothing.
  derived: NO COLUMN EXISTS. lead_paint is act_yr_blt < 1978. THE CLAIM IS THE RULE PLUS THE POPULATION IT SELECTS.
AND THE PRINCIPLE UNDER IT IS THE ONE THAT HAS RUN ALL DAY: *** A MEASUREMENT MUST BE ABLE TO FAIL IN THE WAY THE THING
ACTUALLY BREAKS. A null-rate on geometry cannot detect a mixed SRID, an invalid polygon or a mixed type - the three
ways geometry actually breaks. It would return 100% and mean nothing. ***

## 81-cardinality

### 1. RULING 279 - EXPECTED CARDINALITY DECLARED FROM THE LADM CLASS, AND IT CAUGHT MY OWN CLASSIFICATION ON ITS FIRST RUN

`rule` | authority: CC queued; ruled and measured 2026-08-20 | measured: 2026-08-20 | murphy

CC MEASURED FAN-OUT ON 109 OF 285 E0 RUNS AND FOUND 63 EXCEEDING distinct_keys, MAX 7.93x - AND WAS RIGHT THAT THAT IS
NOT 63 DEFECTS. *** NOTHING DECLARED WHAT THE CARDINALITY SHOULD BE, SO THE NUMBER COULD NOT FAIL IN EITHER DIRECTION.
THAT IS THE VACUOUS-CONTROL SHAPE, IN A NEW PLACE. ***
DECLARED expected_cardinality ON 624 OF 668 SHELF ROWS, FROM THE LADM CLASS AND BEFORE ANY MEASUREMENT:
  LA_Party, LA_Restriction, LA_Responsibility, LA_Right, LA_AdministrativeSource  ONE_TO_MANY - FAN-OUT REQUIRED.
    One parcel, many owners - 41.5% of Volusia, one Polk parcel with 844. COLLAPSING IS THE DEFECT, NOT THE FAN-OUT.
  LA_SpatialUnit, VM_ValuationUnit  ONE_TO_ONE - fan-out forbidden, the Sarasota lot-versus-interest error.
    EXCEPT GEOMETRY FRAGMENTS: 26.7% duplicate parcel_id in St Johns, 100% one owner one address across 3,443 groups.
    AGGREGATE, NEVER DEDUPE - one parcel had 1,215 fragments and reading one gave a 1,580x error.
  Ext*  MANY_TO_MANY. Proximity, and neither side is a key.
*** AND THE INSTRUMENT CAUGHT MY OWN CLASSIFICATION ON ITS FIRST RUN. Thirteen one_to_one violations, and ALL THIRTEEN
ARE CAMA SUB-TABLES I HAD DECLARED VM_ValuationUnit: res_area 4.18x, sales 3.69x, comm_bldg 1.90x, agland, condo_misc,
collier land. A PARCEL HAS MANY SUB-AREAS, MANY SALES, MANY BUILDINGS, MANY LAND LINES. THE FAN-OUT IS THE SCHEMA
WORKING AND THE CLASS WAS WRONG. ***
A TABLE THAT REFERENCES A VALUATION UNIT IS NOT A VALUATION UNIT. Collapsing volusia_cama_sales to one row per parcel
would discard the sale history - the same shape as the one-owner defect that lost 41.5% of Volusia ownership.
*** THE CONTROL DISCRIMINATES: 9 one_to_many RUNS WITH FAN-OUT PASSED, 13 one_to_one RUNS FLAGGED. Before the
expectation existed, all 22 were an undifferentiated "63 of 109 show fan-out" - a number nobody could act on. THE
EXPECTATION MUST PRECEDE THE MEASUREMENT OR THE MEASUREMENT RATIFIES WHATEVER IT FINDS. ***

## 82-overload

### 1. RULING 280 - A COLUMN MAP THAT CARRIES A VALUE INSTEAD OF A COLUMN NAME, AND THE VALUE DECIDES A VERDICT

`rule` | authority: CC queued; ruled 2026-08-20 | measured: 2026-08-20 | murphy

CC QUEUED THIS RATHER THAN HANDING IT BACK, AND IT IS A SCHEMA CALL SO I AM MAKING IT.
FOUR ROWS IN layer_column_map CARRY col_role = share_scale AND column_name = "percent", "fraction", "none", "none".
*** THOSE ARE NOT COLUMN NAMES. THEY ARE VALUES. THE ROW RECORDS A PROPERTY OF THE TABLE, NOT A MAPPING OF A COLUMN. ***
CC NEARLY FILED FOUR STALE-MAPPING DEFECTS AGAINST THEM - the phantom-column detector found four columns that do not
exist and was right about the facts and wrong about the meaning.
AND IT WAS ABOUT TO BREAK SOMETHING REAL: R7 PHASE 2 DEMANDS A column_claim FOR EVERY MAPPING ON A SERVED LAYER, AND
YOU CANNOT PROFILE A COLUMN THAT DOES NOT EXIST. Volusia and Polk owners ARE served. The gate would have blocked the
next legitimate mapping on those tables.
RULED: layer_column_map.is_property boolean, DEFAULT FALSE. TRUE MEANS column_name CARRIES A VALUE AND EVERY CHECK THAT
ASSUMES A COLUMN MUST SKIP THE ROW. The R7 trigger now returns early on it, and its HINT names the escape.
*** WHY NOT A SEPARATE TABLE: THE FACT IS GENUINELY PER-TABLE-PER-ROLE AND BELONGS BESIDE THE COLUMN MAP THAT READS IT.
provenance_all ALREADY CARRIES FIVE REGISTRIES AND ITS OWN COMMENT SAYS DO NOT ADD A SIXTH. ***
*** WHY NOT LEAVE IT OVERLOADED: AN OVERLOAD IS INVISIBLE. IT PASSED EVERY STRUCTURAL TEST WE HAVE, AND THE ONLY REASON
IT SURFACED IS THAT A DETECTOR PRODUCED FOUR FALSE POSITIVES. THE NEXT DETECTOR WILL NOT BE SO LUCKY - it will produce
four defects instead. ***
AND THE VALUE IS LOAD-BEARING RATHER THAN DESCRIPTIVE: *** share_scale DECIDES WHETHER A SUM OF 200 ACROSS TWO OWNERS
IS CORRECT OR A DEFECT. Volusia records percent and unity is 100 - under tenancy by the entirety EACH SPOUSE HOLDS 100%
AND n*100 IS BY DESIGN. Polk records fraction and unity is 1, where the same sum would be a 200x over-allocation.
READING THE WRONG SCALE INVERTS THE VERDICT ON 41.5% OF VOLUSIA PARCELS. ***
Pasco and Pinellas record "none" - NO SHARE COLUMN EXISTS, so shareCheck is NOT COMPUTED rather than false. THAT IS THE
THREE-STATE RULE INSIDE A METADATA FIELD, and it is why "none" had to be storable at all.

## 83-hundred-percent-empty

### 1. RULING 281 - A COLUMN EMPTY ON 100% OF ROWS IS not_available, NEVER none_recorded, AND THE REASON IS THE DISCRIMINATING TEST

`rule` | authority: CC measured; ruled 2026-08-20 | measured: 2026-08-20 | murphy

CC MEASURED fl_cadastral_dor_statewide.fidu_name AND HANDED ME THE THREE-STATE CALL. VERIFIED:
  10,831,924 ROWS. 0 NULL. 10,831,924 WHITESPACE. ZERO POPULATED. ONE DISTINCT VALUE AFTER btrim.
*** RULING: not_available. NOT none_recorded. ***
THE THREE STATES ARE NOT THREE DEGREES OF EMPTINESS - THEY ARE THREE DIFFERENT CLAIMS ABOUT WHAT WE DID:
  present        we queried and found something
  none_recorded  WE QUERIED AND THE ANSWER WAS NO. THIS IS A REAL NEGATIVE AND IT ASSERTS SOMETHING.
  not_available  WE CANNOT ANSWER.
*** THE DISCRIMINATING TEST: COULD THIS COLUMN EVER SAY YES? IF SOME ROWS WERE POPULATED, A BLANK ROW WOULD MEAN "NO
FIDUCIARY IS RECORDED FOR THIS PARCEL" - a real negative, because the field demonstrably CAN carry a name. AT 100%
BLANK THERE IS NO EVIDENCE THE FIELD IS EVER POPULATED BY ANYONE, SO A BLANK CANNOT DISTINGUISH "THIS PARCEL HAS NO
FIDUCIARY" FROM "DOR DOES NOT COLLECT THIS". ***
A COLUMN THAT IS EMPTY ON EVERY ROW CARRIES NO INFORMATION. IT CANNOT SUPPORT A NEGATIVE, BECAUSE A NEGATIVE REQUIRES
THAT A POSITIVE WAS POSSIBLE.
AND IT IS THE VACUOUS-CONTROL PRINCIPLE APPLIED TO A DATA COLUMN RATHER THAN TO A TEST: *** A FIELD THAT CANNOT SAY YES
IS NOT SAYING NO. IT IS NOT SAYING ANYTHING. ***
CONSEQUENCE, AND IT IS STATEWIDE: A FIDUCIARY - trustee, executor, guardian, conservator - IS EXACTLY THE PARTY A BUYER
NEEDS TO KNOW ABOUT, BECAUSE THEY SIGN INSTEAD OF THE OWNER AND THEIR AUTHORITY IS LIMITED BY THE INSTRUMENT THAT
APPOINTED THEM. "No fiduciary" ON 10.8 MILLION PARCELS WOULD BE A CONFIDENT FALSE NEGATIVE ON EVERY ESTATE, TRUST AND
GUARDIANSHIP SALE IN FLORIDA.
THE RIGHT SENTENCE IS "we do not hold fiduciary information; the Clerk of Court probate and the recorded deed carry
it" - WHICH IS THE COVERAGE-GAP-AS-SERVICE PATTERN, NOT AN APOLOGY.
AND THE GENERAL RULE: *** ANY COLUMN MEASURING 0% POPULATED ACROSS ITS FULL CENSUS IS not_available BY CONSTRUCTION,
AND MUST NOT BE WIRED TO A CONCEPT THAT CAN RENDER A NEGATIVE. A SAMPLED ZERO IS NOT THE SAME THING - it supports
"effectively empty" and never "empty", which is CC own distinction and it is the right one. ***

## 84-reltuples

### 1. reltuples = -1 IS A SENTINEL MEANING NEVER MEASURED, AND I READ IT AS ZERO IN MY OWN DENOMINATOR

`correction` | authority: CC measured; verified 2026-08-21 | measured: 2026-08-21 | cc

I DECLARED "ZERO UNDECLARED TABLES" AND CC MEASURED 107. THE MECHANISM IS THE ONE I HAVE CORRECTED FIVE TIMES TODAY,
COMMITTED IN THE INSTRUMENT I USED TO AUDIT THE OTHERS.
*** MY FILTER WAS reltuples > 0. POSTGRES USES reltuples = -1 TO MEAN "ANALYZE HAS NEVER RUN ON THIS TABLE" - IT IS NOT
A ROW COUNT, IT IS THE ABSENCE OF ONE. A GREATER-THAN-ZERO TEST EXCLUDES IT SILENTLY. ***
COUNTED FOR REAL: 48 OF THE 107 CARRY -1, AND 44 OF THOSE HOLD ROWS - 35,973 OF THEM.
  seminole_hydrants 15,786 | seminole_wetlands 10,524 | seminole_soils 4,237
  hifld_transmission_lines 3,739 | hifld_gas_pipelines 317 | an entire seminole_* layer family
  AND THE GOVERNANCE TABLES: golden_parcel, statewide_metrics, restriction_authority, dropped_table_register,
  AND ladm_class_vocabulary ITSELF - THE TABLE HOLDING THE EVIDENCE-GRADE TERM I TRIPPED OVER AN HOUR EARLIER.
*** SO THE THING THAT DEFINES OUR VOCABULARY WAS INVISIBLE TO THE COUNT THAT MEASURES OUR COVERAGE. ***
IT IS EXACTLY null_as_value, IN pg_class: a value that means absence, in a numeric column, passing every arithmetic
test. THE SAME SHAPE AS -9999 BFE, 9999 HYDRANT YEAR, 999 INCORPORATED, parcel_id = " ", AND phy_addr2 AT 97.3%
WHITESPACE. I have written that defect class into the record six times today and then built a denominator on it.
*** AND IT IS WORSE THAN THE OTHERS BECAUSE IT IS OUR OWN INSTRUMENT RATHER THAN A COUNTY EXTRACT. Every "populated
tables" figure quoted this session - 2,115, 2,075, 2,080 - RESTS ON reltuples AND IS THEREFORE A LOWER BOUND, NOT A
COUNT. ***
THE FIX IS ONE CHARACTER OF LOGIC: reltuples <> 0, OR AN EXACT count(*) WHERE IT MATTERS. THE LESSON IS NOT THE FIX -
IT IS THAT I AUDITED FIVE INSTRUMENTS TODAY FOR THIS EXACT DEFECT AND DID NOT AUDIT THE ONE I WAS AUDITING WITH.

## 85-geom-vocab

### 1. RULING 282 - THE GEOMETRY ROLE TERM IS DERIVED FROM THE CLASS, NOT CHOSEN PER TABLE

`rule` | authority: CC queued; ruled from usage 2026-08-21 | measured: 2026-08-21 | murphy

CC MAPPED 10 GEOMETRY COLUMNS WHERE A TERM ALREADY EXISTED AND STOPPED ON 79 WHERE NONE DID, RATHER THAN INVENT ONE.
THAT IS CORRECT AND IT IS THE THIRD TIME TODAY SOMEONE HAS BEEN CAUGHT INVENTING A VOCABULARY - E2_own_content_read,
key_integrity, pull_mode derived.
THE TWO TERMS IN USE ARE NOT ARBITRARY. THEY FOLLOW ONE PATTERN:
  ext_poi_geom          271 uses   ExtAmenity, ExtAdministrativeBoundary
  la_spatialunit_geom    42 uses   LA_SpatialUnit, VM_ValuationUnit
*** BOTH ARE <lowercased class stem>_geom. THE TERM IS NOT A CHOICE - IT IS DERIVED FROM THE DECLARED CLASS, AND THE
CLASS IS ALREADY EVIDENCED. So the seven classes without a precedent do not need a new decision; THEY NEED THE EXISTING
RULE APPLIED. ***
RULED, ONE TERM PER CLASS:
  EXT_Context                 -> ext_context_geom      46
  SP_PlanUnit                 -> sp_planunit_geom      18
  ExtAddress                  -> ext_address_geom       6
  LA_Restriction              -> la_restriction_geom    4
  LA_SpatialSource            -> la_spatialsource_geom  3
  ExtPhysicalUtilityNetwork   -> ext_utility_geom       1
  VM_Valuation                -> vm_valuation_geom      1
AND THE EXISTING TWO STAND UNCHANGED - ext_poi_geom AND la_spatialunit_geom KEEP THEIR 313 USES. A ruling that renamed
them would be tidiness bought with a migration, and the pattern is what matters, not the exact stem.
*** WHY THE CLASS AND NOT THE GEOMETRY TYPE: A COLUMN IS NOT ext_poi_geom BECAUSE IT HOLDS POINTS. seminole_property_
details MIXES ST_MultiPolygon AND ST_Polygon IN ONE COLUMN, AND SEVERAL AMENITY LAYERS ARE POLYGONS. The role says what
the geometry IS FOR - a POI location, a spatial unit boundary, a plan unit extent - and that is a question the LADM
class already answers. TYPING THE ROLE OFF ST_GeometryType WOULD MAKE THE ROLE CHANGE WHEN A PUBLISHER SWITCHES FROM
POLYGON TO MULTIPOLYGON. ***
AND THE CLASS IS THE EVIDENCED THING: every one of the 91 was read this session, and the geometry claim carries
ST_GeometryType, the SRID list and the invalid count as a shape_profile the CHECK constraint demanded.

### 2. RULING 282 OVERTURNED - I DERIVED THE RULE FROM THE ONE CASE THAT FIT. THE TWO TERMS ENCODE A SEMANTIC SPLIT, NOT A CLASS STEM.

`correction` | authority: CC disproof; verified 2026-08-21 | measured: 2026-08-21 | cc

SUPERSEDES 85-geom-vocab/1. CC TESTED THE PREMISE BEFORE MAPPING 79 TABLES AND IT FAILED. VERIFIED INDEPENDENTLY:
  ext_poi_geom        <- ExtAmenity 269   *** STEM WOULD BE ext_amenity ***          FAILS
  ext_poi_geom        <- ExtAdministrativeBoundary 2                                 FAILS
  la_spatialunit_geom <- VM_ValuationUnit 3   *** STEM WOULD BE vm_valuationunit *** FAILS
  la_spatialunit_geom <- LA_SpatialUnit 39                                           fits
*** ONE OF FOUR FITS, AND IT IS THE SMALLEST BY A FACTOR OF SEVEN. I LOOKED AT TWO TERM NAMES, SAW A PATTERN IN ONE OF
THEM, AND RULED. THAT IS THE LOW-ENTROPY-ANCHOR ERROR - high agreement on a sample of one is not evidence - COMMITTED
IN A VOCABULARY RULING RATHER THAN A JOIN TEST. ***
AND THE CONSEQUENCE WOULD HAVE BEEN PERMANENT: SEVEN NEW TERMS MINTED, VOCABULARY 2 -> 9, ON 79 TABLES. CC CAUGHT IT BY
DOING THE ONE THING I DID NOT - TESTING THE RULE AGAINST THE FULL POPULATION BEFORE APPLYING IT.
*** THE ACTUAL PATTERN IS THE OPPOSITE OF PER-CLASS: TWO TERMS, EACH DELIBERATELY SHARED BY TWO CLASSES, COVERING 313
TABLES. AND WHAT THEY ENCODE IS A SEMANTIC SPLIT THAT IS BETTER THAN A CLASS STEM: ***
  la_spatialunit_geom  THE GEOMETRY IS THE PROPERTY. LA_SpatialUnit and VM_ValuationUnit are both the parcel itself.
  ext_poi_geom         THE GEOMETRY IS SOMETHING THE PROPERTY SITS NEAR OR INSIDE.
THAT DISTINCTION IS THE ONE THE REPORT ACTUALLY MAKES - "this parcel" versus "what is around this parcel" - and it is
the same line as containment versus proximity in the resolver. A CLASS STEM WOULD HAVE ENCODED OUR TAXONOMY; THIS
ENCODES THE QUESTION.
CC CLASSIFICATION ACCEPTED: EXT_Context 46, SP_PlanUnit 18, ExtAddress 6, LA_Restriction 4,
ExtPhysicalUtilityNetwork 1 -> ext_poi_geom (75 tables). All are things the parcel relates to rather than is.
AND THE FOUR FLAGGED RATHER THAN GUESSED ARE CORRECTLY FLAGGED - LA_SpatialSource 3 and VM_Valuation 1 ARE GENUINELY
AMBIGUOUS: a survey monument or a control point IS a located thing, not a parcel and not an amenity. THOSE FOUR NEED A
READ, NOT A RULE.

## 86-timeshare

### 1. TIMESHARE - FLORIDA IS THE LARGEST MARKET IN THE WORLD AND THERE IS NO DOR USE CODE FOR IT

`measurement` | authority: Murphy; Ch.721 F.S.; measured 2026-08-21 | measured: 2026-08-21 | murphy

MURPHY RAISED IT AND WE HAVE NEVER MENTIONED IT IN ANY SPEC, PLAN OR REGISTRY. MEASURED:
*** THE DOR USE CODE LIST HAS NO TIMESHARE CODE. 000 vacant, 001 single family, 002 mobile home, 003 multifamily 10+,
004 CONDOMINIUM, 005 cooperative, 006 retirement, 007 misc residential, 008 multifamily under 10, 009 COMMON ELEMENT,
039 HOTEL/MOTEL. A TIMESHARE HAS NOWHERE TO SIT. ***
ORANGE COUNTY - THE TIMESHARE CAPITAL OF THE WORLD - MEASURED:
  039 hotel/motel   4,111 parcels, AVERAGE JUST VALUE $8,432,829
  004 condominium  52,522 parcels, average $215,178
*** AN $8.4M AVERAGE ON 4,111 PARCELS IS WHOLE RESORTS ASSESSED AS SINGLE PARCELS. The timeshare INTERESTS inside them
are not parcels. ***
THE STRUCTURE, AND IT IS THE LOT-VERSUS-INTEREST PROBLEM IN ITS MOST EXTREME FORM:
  Ch.721 F.S. governs Florida vacation and timeshare plans. A TIMESHARE ESTATE IS A RECORDED REAL PROPERTY INTEREST -
  a deeded fractional, typically one week - AND ONE UNIT CAN CARRY UP TO 52 SEPARATE OWNERS EACH WITH A RECORDED DEED.
  SARASOTA WAS 489 PARCELS ON ONE FOOTPRINT. A TIMESHARE RESORT IS ONE PARCEL WITH THOUSANDS OF RECORDED INTERESTS.
*** SO A PIR ON A TIMESHARE ADDRESS RETURNS THE RESORT, NOT THE INTEREST. The buyer of week 27 in unit 412 gets a
report about an $8.4M hotel parcel they own a 1/52nd share of, and nothing about their own interest. ***
*** AND THIS IS WHY THE OFFICIAL RECORDS WORK MATTERS MORE THAN WE HAVE BEEN SAYING: THE TIMESHARE INTEREST EXISTS ONLY
IN THE CLERK REGISTER. IT IS A DEED, NOT A PARCEL. The 3.5M Volusia and 1.8M Landmark rows are the ONLY place a
timeshare estate is visible to us. ***
NOT REGISTERED AS A CONCEPT, NOT SERVED, NOT PREVIOUSLY NAMED. Recorded here so it is not discovered a third time.
AND THE COMMERCIAL NOTE: timeshare resale is a market with a documented history of predatory practice, and a buyer
asking what they actually own is EXACTLY the PIR question. It is also where an unsatisfied lien is most likely -
maintenance-fee liens against individual weeks are routine and are recorded against the interest, not the parcel.

## 87-cast-defeats-index

### 1. A CAST ON THE COLUMN SIDE DEFEATS THE INDEX - MY DETECTION WAS 30% OF THE ENTIRE BATCH FROM ONE ::int

`principle` | authority: CC measured; verified 2026-08-22 | measured: 2026-08-22 | cc

CC PROFILED THE 365-SECOND DETECTION BATCH PER PREDICATE. THE WORST WAS MINE, WRITTEN YESTERDAY:
  109,135 ms - 30% OF THE WHOLE RUN - FROM select count(*) ... where co_no::int = 0
*** co_no IS double precision AND CARRIES A BTREE INDEX. CASTING THE COLUMN MAKES THAT INDEX UNUSABLE AND FORCES A SCAN
OF 10,739,881 ROWS. The cast has to be evaluated per row, so the planner cannot match it to the index. ***
REWRITTEN AS not exists (... where co_no = 0 ...): SAME ANSWER, 105,466 ms -> 28,642 ms, AND EXPLAIN NOW SHOWS
fl_cadastral_dor_statewide_cono_idx INSTEAD OF A SEQ SCAN. 3.7x FROM DELETING FOUR CHARACTERS.
*** AND I HAVE WRITTEN co_no::int IN EVERY QUERY THIS SESSION. It is a habit formed because co_no is double precision
and comparisons read oddly - I made it readable and made it unindexable. ***
THE RULE, AND IT IS THE ::geography LESSON IN A SECOND FORM: PUT THE CAST ON THE LITERAL, NEVER ON THE COLUMN.
  co_no::int = 0        SCAN     co_no = 0        INDEX
  parcel_id::text = x   SCAN     parcel_id = x::numeric   INDEX
THE FIRST INSTANCE COST 5-12 SECONDS PER REPORT STATEWIDE AND WAS DIAGNOSED AS MISSING PARCEL-ID INDEXES. IT WAS THE
::geography CAST DEFEATING GiST. SAME MECHANISM, DIFFERENT INDEX TYPE, AND I DID NOT RECOGNISE IT.
AND count(*) WHERE EXISTENCE WOULD DO IS THE SECOND HALF: count(*) MUST VISIT EVERY MATCHING ROW; not exists STOPS AT
THE FIRST. On a predicate that is expected to return zero, THE DIFFERENCE IS THE WHOLE TABLE VERSUS ONE PAGE.
*** AND CC OWN DIAGNOSIS WAS WRONG IN A USEFUL WAY: IT FIRST BLAMED ONE SLOW PREDICATE. run_defect_detections() RUNS
ALL 153 INSIDE ONE STATEMENT, SO THE POOLER TWO-MINUTE CAP APPLIES TO THE SUM - 365.3s MEASURED. NO SINGLE DETECTION
COULD HAVE BEEN THE CULPRIT, AND THE FIX WAS A SESSION WITH statement_timeout = 0, NOT A FASTER PREDICATE. ***

## 88-declared-type

### 1. A GEOMETRY COLUMN DECLARED "GEOMETRY" IS INVISIBLE TO ANY TOOL THAT RESOLVES DIMENSION FROM THE DECLARATION

`principle` | authority: CC repaired; verified 2026-08-22 | measured: 2026-08-22 | cc

CC REPAIRED ALL 729 INVALID GEOMETRIES AT REST USING THE EXISTING repair_geometry_once FROM THE JULY RULING - it did
not write a new one. 25 of 26 tables went through cleanly. VERIFIED INDEPENDENTLY: seminole_property_details IS NOW 0
INVALID.
*** THE ONE REFUSAL IS THE FINDING. repair_geometry_once FAILED WITH "could not resolve geometry dimension" ON
seminole_property_details BECAUSE ITS geometry_columns.type IS "GEOMETRY" - UNTYPED - WHERE EVERY OTHER TABLE DECLARES
MULTIPOLYGON. THE FUNCTION READ THE DECLARED TYPE AND REFUSED RATHER THAN GUESSED. ***
AND TWO INSTRUMENTS FOUND THE SAME TABLE INDEPENDENTLY: the column read flagged it for holding BOTH ST_MultiPolygon
AND ST_Polygon in one column; the repair function flagged it from the declaration. CONTENTS AND DECLARATION AGREEING
FROM OPPOSITE DIRECTIONS IS THE STRONGEST EVIDENCE SHAPE WE HAVE - and it is the independent-evidence-path the external
reviewers said we lacked, arrived at by accident.
*** THE RULE: DECLARED TYPE IS A NAME. ST_GeometryType IS CONTENTS. A column declared GEOMETRY is invisible to any tool
that resolves dimension from the declaration - AND A TOOL THAT FAILED QUIETLY WOULD HAVE SKIPPED THE TABLE AND REPORTED
SUCCESS. repair_geometry_once FAILED LOUDLY, WHICH IS WHY THE TABLE WAS FOUND AT ALL. ***
AND CC WAS RIGHT NOT TO COERCE IT TO ST_Multi. The column is untyped, so forcing Multi would change data to suit a
convention rather than a requirement. THE MIXED TYPING STANDS AS A RECORDED OBSERVATION, NOT A SILENT NORMALISATION -
and it matters, because probe_in_extent PICKS ITS PREDICATE BY READING THE FIRST ROW.
CLAIM HYGIENE: 35 column_claim ROWS STILL CARRIED THE PRE-REPAIR INVALID COUNTS. Moved to invalid_at_claim_time rather
than overwritten - A CLAIM RECORDS WHAT WAS MEASURED, AND A REPAIR IS A LATER EVENT, NOT A CORRECTION OF THE
MEASUREMENT. VersionedObject applied to a measurement.

### 2. RULING 283 - probe_in_extent READS THE TYPE SET, NOT THE FIRST ROW. AND I INVENTED TWO TABLE NAMES TO DISPUTE CC WORK.

`rule` | authority: CC queued; ruled 2026-08-22 | measured: 2026-08-22 | murphy

*** FIRST, MY ERROR, BECAUSE IT IS THE WORSE ONE. I WROTE "two of the table names CC cited do not exist" AND NAMED
pinellas_annexations AND pasco_zoning. NEITHER EXISTS. NEITHER WAS EVER CITED BY CC. I TYPED THEM FROM MEMORY AS
PLAUSIBLE EXAMPLES AND THEN REPORTED THEIR ABSENCE AS A FINDING ABOUT SOMEONE ELSE WORK. ***
THE REAL NAMES ARE pasco_zoning_area AND pinellas_annexation_historic. I GOT THE STEM RIGHT AND INVENTED THE SUFFIX -
WHICH IS EXACTLY WHY IT LOOKED RIGHT TO ME.
FIFTH INVENTED IDENTIFIER THIS WEEK, AFTER gpmpre, wearing, throughout AND unnamed. THE FIRST FOUR WERE INVENTED
COLUMNS IN MY OWN NOTES. *** THESE TWO WERE INVENTED IN AN ACCUSATION, WHICH IS A DIFFERENT AND WORSE THING: CC HAD TO
SPEND A ROUND TRIP DISPROVING A CLAIM I HAD NO BASIS FOR, AND IT NEARLY REPORTED MY REAL AND CORRECT RENAME AS
"DID NOT HAPPEN" WHILE DOING SO. ***
THE RULE, AND IT IS NOT A NEW ONE: A TABLE NAME IS AN IDENTIFIER, NOT A DESCRIPTION. IT COMES FROM A QUERY OR IT IS NOT
WRITTEN. I have the to_regclass check and I did not run it.
*** SECOND, THE RULING CC CORRECTLY REFUSED TO MAKE. probe_in_extent PICKS ITS PREDICATE - ST_DWithin FOR POINTS AND
LINES, ST_Intersects FOR POLYGONS - BY READING ST_GeometryType OF ONE ROW. A MIXED-TYPE COLUMN GETS THE WRONG PREDICATE
FOR WHICHEVER TYPE IS NOT FIRST, AND WHICH ROW IS FIRST IS AN ARTEFACT OF PHYSICAL ORDER. ***
MEASURED SCOPE BEFORE RULING: *** EXACTLY ONE OF 132 GEOMETRY CLAIMS IS MIXED-TYPE - seminole_property_details, HOLDING
ST_MultiPolygon AND ST_Polygon. ***
RULED: probe_in_extent MUST READ THE TYPE SET, NOT THE FIRST ROW. Three reasons and the third is the one that matters:
  1. THE FIX IS THE SAME EITHER WAY HERE - both types are polygonal, so ST_Intersects is correct for both, and the
     current behaviour happens to be right on this table by luck.
  2. LUCK IS NOT A CONTROL. A future load mixing ST_Point into a polygon layer gets ST_Intersects and returns
     essentially nothing - A CLEAN ZERO FROM A WORKING LAYER, which is the failure mode we have chased all week.
  3. *** THE INSTRUMENT COMMITS THE EXACT ERROR THE WHOLE SESSION HAS BEEN ABOUT: IT GENERALISES FROM ONE SAMPLED ROW.
     I CANNOT WRITE "READ THE TABLE, NOT ONE ROW" INTO THE RECORD FIFTEEN TIMES AND LEAVE A PROBE THAT READS ONE ROW. ***
IMPLEMENTATION: read DISTINCT ST_GeometryType over the column. One type -> as now. MIXED AND ALL POLYGONAL ->
ST_Intersects. MIXED AND ALL POINT OR LINE -> ST_DWithin. *** MIXED ACROSS DIMENSIONS -> REFUSE AND RECORD, THE WAY
repair_geometry_once REFUSED. A probe that cannot choose a correct predicate must not choose a plausible one. ***
DO NOT TYPE THE COLUMN. CC was right: forcing ST_Multi changes data to suit a convention rather than a requirement, and
the mixed typing is a true recorded observation about what Seminole publishes.

## 89-sop-read-audit

### 1. BEFORE YOU BUILD AN INSTRUMENT, LOOK FOR THE ONE THAT EXISTS

`rule` | authority: Murphy; measured 2026-08-22 | measured: 2026-08-22 | cc

Query information_schema for the concept first. On 2026-08-22 a search for audit-shaped tables returned SEVENTEEN (attestation_register, column_profile_audit, containment_verification_run, data_audit_findings/runs/summary, dataset_audit, dataset_content_audit(_latest), jurisdiction_verification_run, key_verification_run, layer_verify_staging, null_claim_audit, paging_audit_prong2, permit_intake_audit_log, zoning_verify_staging, hazard_verification_prompts). None authoritative, none complete, and that is exactly WHY nobody could name which 5 tables two scoreboards disagreed on.
CC then built table_audit_stamp anyway, while catalogue_worklist - a well-designed reading journal with extent_state, join_state, outcome, note, read_at, batch - had been used SIX times and abandoned on 2026-08-16, and geometry_repair_log had not been written since 2026-08-11 despite 26 repairs that day.
THE RULE: an eighteenth instrument is only justified if it INDEXES the others rather than measuring again. Everything else extends what is there.

### 2. HOW TO READ A TABLE - the procedure, and the evidence each step must leave

`rule` | authority: Murphy; measured 2026-08-22 | measured: 2026-08-22 | cc

You cannot define a table without knowing its contents (Murphy, 2026-08-22). Reading is not sampling one row and it is not reading the column names.
PER COLUMN, measure and record:
  1. rows_total, rows_populated
  2. THE THREE ABSENCE STATES SEPARATELY - rows_null, rows_empty_string, rows_whitespace_only. Never one "empty" number. Whitespace passes count(), passes IS NOT NULL, and passes a human reading a sample. Found this way on 2026-08-22: six parcels_staging fidu_* columns 100% whitespace over 10,739,881 rows (count() returns 10.7M for each), alt_key 60.3% whitespace, phy_addr2 97.3%.
  3. distinct_count and up to 10-12 REAL distinct sample values. The samples are the evidence a later reader uses to argue a role.
  4. For geometry: the actual ST_GeometryType SET, the SRID SET, and the invalid count, stored as jsonb shape_profile. Not the declared type - see 88-declared-type.
EVIDENCE LEFT: one column_claim row per column. A table is not read until every column has one.

### 3. CENSUS OR SAMPLE, AND SAY WHICH IN THE ROW ITSELF

`rule` | authority: measured 2026-08-22 | measured: 2026-08-22 | cc

Below 300,000 rows: full census, sampled_rows NULL.
Above it: populated/null/empty/whitespace counts STILL come from a full scan - they are cheap. Only distinct counts and sample values come from a TABLESAMPLE, and sampled_rows records how many rows backed the claim.
A sampled rate supports "effectively", never "exactly". MEASURED INSTANCE: a 200,000-row sample put parcels_staging.phy_addr1 whitespace at 2.49%; the full census says 3.8%. The sample understated by a third, and the sampled figure had already been published.

### 4. IDEMPOTENCE IS ON THE NATURAL KEY, ACROSS ALL PASSES - NOT ON YOUR OWN NOTE

`rule` | authority: CC measured; verified 2026-08-22 | measured: 2026-08-22 | cc

column_claim carries UNIQUE (table_name, column_name) - column_claim_one_per_column. A pass that clears only ITS OWN rows (by note prefix, by measured_by, by date) is idempotent with itself and BLIND TO EVERY OTHER PASS.
Both failure directions were observed on 2026-08-21/22:
  - scoping the delete by note prefix left 7 columns carrying two claims from two passes, agreeing on the measurement, each correct in isolation, and any count or join double-counting silently;
  - after the unique index was added, the same scoped-delete made 30 of 475 tables FAIL outright on insert.
THE RULE: upsert on the declared natural key. If a table has three passes and three key vocabularies for the same fact, converge them - do not add a fourth dialect.

### 5. STAMP THE TABLE, AND MAKE THE STAMP UNFAKEABLE AND SELF-INVALIDATING

`rule` | authority: Murphy; built 2026-08-22 | measured: 2026-08-22 | cc

A read that is not stamped cannot be audited - the only way to answer "which tables are done" becomes re-deriving it from predicates, and two views that re-derive will disagree and neither can name the difference. That is the defect Murphy named on 2026-08-22.
table_audit_stamp records the EVENT: who, when, columns_at_stamp, rows_at_stamp, columns_read, read_method, purpose, key_column, key_verified.
TWO PROPERTIES ARE NOT OPTIONAL:
  1. CHECK (columns_read = columns_at_stamp) - you may not stamp a table whose columns you did not all read. A gate satisfiable by one arbitrary row is not a gate; layer_column_map.mapped = EXISTS(any row) is exactly that and was refused for the same reason.
  2. Staleness is DERIVED, never stored. audit_status compares the LIVE column count to columns_at_stamp, so adding a column silently un-audits the table. A record that keeps asserting something that stopped being true is how a retired defect kept firing and 84 golden divergences alarmed correctly for eleven days with nobody watching.

### 6. JOURNAL AS YOU GO - A JOURNAL KEPT BY HAND IS A JOURNAL THAT STOPS

`rule` | authority: Murphy 2026-08-22 | measured: 2026-08-22 | cc

catalogue_worklist is the reading journal: exact_rows, srid, invalid_count, extent_state, join_state, outcome, note, read_at, batch. geometry_repair_log is the repair journal: invalid_before, invalid_after, repaired, repaired_at.
Both existed. Both went stale - the worklist after 6 tables, the repair log for eleven days across 26 repairs.
THE RULE: the tool that does the work writes the journal row in the same transaction as the work. Do not leave journalling to a later human step, and do not leave a field guessed - extent_state and join_state are left NULL by a pass that did not measure them, never filled in by inference.

### 7. ARGUE THE ROLE FROM CONTENTS, AND ONLY IN VOCABULARY THAT ALREADY EXISTS

`rule` | authority: CC measured 2026-08-21/22 | measured: 2026-08-22 | cc

A geometry column is geometry because ST_GeometryType says so. A parcel key is a parcel key because it JOINS to parcels_staging at a measured rate - not because it is called parcelid.
MEASURED: Pinellas CAMA joined at ZERO of 432,360 on the raw key and at 431,876 (99.89%) through cama_key(62, parcel_id). Zero is the signature of a key-space mismatch, not of missing data.
Where the contents do not decide the role, FLAG IT - do not guess. LA_SpatialSource and VM_Valuation were left unassigned for exactly this reason.
And never mint a term. col_role has no CHECK constraint, so the vocabulary is whatever usage has established; check usage counts first. A per-class derivation rule proposed on 2026-08-21 fit ONE of its own four evidence points and would have created seven permanent terms - see 85-geom-vocab.

### 8. A DISPOSITION AND ITS DETECTION MUST NOT CONTRADICT EACH OTHER

`rule` | authority: CC measured 2026-08-22 | measured: 2026-08-22 | cc

On 2026-08-22, 13 active defects carried disposition=normalise_at_read. TEN fired. SEVEN of those ten had predicates applying NO transform - they asserted on the RAW SOURCE COLUMN, which a read-time normalisation by definition never changes. Those seven are permanently red and would stay red if every one were perfectly fixed.
That is the mirror of the nine detections found the same morning that could never FAIL, being instance-pinned to the one table where the problem was found while claiming class coverage.
THE RULE: a normalise_at_read defect asserts on the NORMALISED path - the view, or the declared key_transform. A repair defect asserts on the repaired state. A detection that cannot register its own fix carries no information and inflates the count it belongs to.

## 90-sop-long-jobs

### 1. NEVER STOP A JOB BY PATTERN - STOP IT BY PID

`rule` | authority: CC; twice on 2026-08-22 | measured: 2026-08-22 | cc

Invariant 4 says a liveness check must not self-match. It is stronger than that: pkill -f matches the WHOLE COMMAND LINE of every process, including the shell that is running your own script, if that command line mentions the target anywhere - in a cp, in a nohup, in an echo.
IT HAPPENED TWICE ON 2026-08-22. Both times the guard killed its own harness. The second time it also took down every supervisor that was a child of that interactive shell, stopping all five long-running jobs at once - two Volusia collectors, two Landmark collectors and the read sweep - and nothing reported an error because the killer died with them.
THE RULE: write a pidfile at launch and kill -0 / kill by PID. pkill -f is banned from project tooling. The [b]racket trick is not sufficient; it only protects against matching the pattern string, not against matching the rest of the line.

### 2. DETACH WITH setsid, AND SUPERVISE - A CHILD OF AN INTERACTIVE SHELL DIES WITH IT

`rule` | authority: CC measured 2026-08-22 | measured: 2026-08-22 | cc

nohup and & are not enough when the parent is a wsl -e bash -lc invocation: the supervisors launched that way on 2026-08-22 were children of an interactive shell and vanished with it.
Separately, a WSL restart the same day killed three collectors with psycopg2.InterfaceError: connection already closed - they rebuilt the HTTP session on failure but never the DB connection, so a host restart ended the run silently while the log looked healthy.
THE RULE: setsid to detach into a new session; wrap each job in a restart loop that retries on non-zero exit; and make every job RESUMABLE and IDEMPOTENT so re-entry costs one skipped scan rather than duplicate rows. The Landmark collector is the pattern - it stamps progress per window, holds a unique index on the natural key, and inserts ON CONFLICT DO NOTHING, so an unconditional restart is always safe.

### 3. THE POOLER 2-MINUTE CAP IS A CONNECTION ARTIFACT - DO NOT DESIGN AROUND IT

`rule` | authority: CC measured 2026-08-22 | measured: 2026-08-22 | cc

run_defect_detections() runs all 153 predicates inside ONE statement, so the pooler applies its 2-minute statement_timeout to the SUM, not to any single detection. The batch had not completed since 2026-08-20 for that reason, and the first diagnosis - "one slow predicate" - was wrong. Measured total: 365.3 s.
The pooler strips startup options but HONOURS an in-session SET statement_timeout = 0, which needs a real session (psycopg2), not the MCP path and not a DO block. CREATE INDEX CONCURRENTLY additionally cannot run inside a transaction block, so it needs autocommit as well - and it can return WITHOUT ERROR having produced an index with indisvalid = FALSE, which enforces nothing and no query will use. ALWAYS assert indisvalid after building one.
THE RULE: run long batches from a real session with the timeout lifted. Do not bend high-consequence served-path predicates into fitting an arbitrary connection limit. Optimise them when they are WASTEFUL - the orphan predicate cast a column (co_no::int = 0), disabling an existing btree index and costing 105 s of a 365 s batch for one cast - not merely because they are slow.

## 91-floodway-domain

### 1. THE FLOODWAY COLUMN IS NOT ONE VOCABULARY - IT IS FOUR, AND FOUR TABLES CARRY NO FLOODWAY AT ALL

`measurement` | authority: CC; 20 tables read 2026-08-22 | measured: 2026-08-22 | cc

The lee_firm_floodways remediation said "CHECK EVERY OTHER COUNTY FLOODWAY LAYER FOR THE SAME SHAPE". Run 2026-08-22 across all 20 public tables carrying a floodway column. Recorded in floodway_token_map (47 tokens).
A SERVED TEST OF floodway = 'FLOODWAY' RETURNS ZERO FOR FOUR COUNTIES THAT HAVE ONE:
  charlotte_flood_zones_2022 uses IN / OUT
  charlotte_flood_zones_pre2003 uses FW
  marion_fema_flood_1983 and marion_fema_flood_2008 use Fldwy
A SERVED TEST OF floodway <> 'OUTSIDE' RETURNS NEARLY EVERYTHING: the negative token is a single SPACE in nine tables and an EMPTY STRING in others. OUTSIDE appears in only two tables.
THE COLUMN CARRIES A DIFFERENT CONCEPT ENTIRELY IN THREE:
  lee_firm_flood_zones - 38 values, 36 of them WATERCOURSE NAMES (Estero River, Orange River, Ten Mile Canal): the stream whose floodway it is, not a flag. A SECOND Lee table and a different defect from the jurisdiction names, found only because the class check was run.
  pasco_fema_floodways - FLOOD ZONE descriptions (0.2 PCT ANNUAL CHANCE...)
  clay_flood_zones - the value 1000, an internal identifier
FOUR TABLES CARRY NO FLOODWAY INFORMATION AT ALL and must serve not_available, never a negative: broward_flood_zones_2014, pompanobeach_city_flood_zones, marion_fema_flood_other_areas, clay_flood_zones.
Also: lee_firm_flood_zones holds BOTH 'OUTSIDE' and 'Outside' in the same column, and okaloosa_flood_zones / marion_fema_flood_2008 hold ONLY the positive token - there is no negative in those tables, so absence of a row is not absence of floodway.
THE RULE: read floodway_token_map before testing any floodway column. Never assume the token, never test for NOT-the-negative, and re-read the domain after every pull.

### 2. I MINTED A TERM IN THE QUERY AFTER WRITING THE RULE AGAINST IT

`correction` | authority: CC; self-observed 2026-08-22 | measured: 2026-08-22 | cc

The entry above was first submitted with kind='measured'. The lens_kind_check vocabulary is {principle, rule, test, mapping, measurement, open, closed, correction} - 'measurement', not 'measured'. The constraint rejected it.
This happened in the query IMMEDIATELY AFTER inserting 89-sop-read-audit ordinal 7, which says never mint a term and check usage first. Knowing the rule did not produce compliance; the CHECK did.
That is the sixth time in two days a schema has held a vocabulary someone invented past - E2_own_content_read, UNGRADED, kind, col_role, claim_shape, and now lens.kind. In every case the constraint caught it and the intention did not. It is the argument for constraints over conventions, made against the author of the convention.

### 3. THE FLOODWAY CLASS CHECK WAS WRITTEN INTO A REMEDIATION AND NEVER RUN - AND NO SERVED FUNCTION READS FLOODWAY AT ALL

`measurement` | authority: CC class check; served path verified 2026-08-22 | measured: 2026-08-22 | cc

CC RAN THE CLASS CHECK MY OWN REMEDIATION DEMANDED - "check every other county floodway layer for the same shape" -
FOUR DAYS AFTER I WROTE IT. IT HAD NEVER BEEN RUN.
*** TWENTY TABLES CARRY A floodway COLUMN AND A TEST FOR = 'FLOODWAY' RETURNS ZERO ON FOUR COUNTIES THAT HAVE ONE.
VERIFIED: charlotte_flood_zones_2022 HOLDS "IN" AND "OUT". A FLOODWAY TEST AGAINST IT MATCHES 0 OF ITS ROWS. ***
  as expected FLOODWAY   baker, bocaraton, desoto, hardee, jefferson, marion_2017, okaloosa, palmbeach, walton
  DIFFERENT TOKEN        charlotte_2022 IN/OUT | charlotte_pre2003 FW | marion_1983 and 2008 Fldwy
  NO FLOODWAY DATA       clay (blank, space, and the value 1000 - an internal id) | broward_2014, pompanobeach,
                         marion_other (blanks only)
  A DIFFERENT CONCEPT    lee_firm_flood_zones = 36 WATERCOURSE NAMES - Estero River, Orange River, Ten Mile Canal |
                         pasco_fema_floodways = FLOOD ZONE DESCRIPTIONS
AND THE INVERSE TEST IS WORSE: floodway <> 'OUTSIDE' RETURNS NEARLY EVERYTHING, BECAUSE THE NEGATIVE IS A SINGLE
SPACE IN NINE TABLES AND "OUTSIDE" APPEARS IN ONLY TWO.
*** BUT I MEASURED THE SERVED PATH BEFORE CALLING IT DAMAGE, AND IT CHANGES THE CLASSIFICATION: NO SERVED FUNCTION
READS floodway. NOT ONE. IT IS A GAP IN THE REPORT, NOT A WRONG ANSWER IN IT. ***
THAT IS THE SIXTH SOURCE-SIDE ALARM IN A ROW TO CHANGE SHAPE WHEN TESTED AGAINST SERVING - AND THIS TIME IT DOES NOT
COLLAPSE TO NOTHING, IT INVERTS. THE DEFECT IS THAT A REGULATORY FLOODWAY - 44 CFR 60.3(d), THE STRICTEST FLOOD
RESTRICTION THERE IS, PROHIBITING ANY DEVELOPMENT CAUSING ANY RISE - IS HELD IN TWENTY TABLES AND SERVED IN NONE.
SO THE CROSSWALK IS NOT A REPAIR, IT IS A PREREQUISITE. floodway_token_map - 47 TOKENS, 20 TABLES, FOUR MEANINGS -
IS WHAT MAKES WIRING IT POSSIBLE. Wiring it without the crosswalk would have shipped a confident "no floodway" for
Charlotte and Marion.
AND THE FOUR TABLES WITH NO FLOODWAY DATA MUST SERVE not_available, NEVER A NEGATIVE - which is only knowable because
the class check distinguished a blank from an OUT.

## 92-contains-vs-intersects

### 1. RULING 284 - ST_Contains ON A SERVED CONTAINMENT PATH DROPS 5.1% OF BROWNFIELD HITS, MEASURED

`rule` | authority: CC found; measured and ruled 2026-08-22 | measured: 2026-08-22 | murphy

CC FOUND probe_in_extent AND THE SERVED PATH USE DIFFERENT PREDICATES. VERIFIED: probe_in_extent NOW READS THE TYPE SET
PER RULING 283, AND FIVE SERVED FUNCTIONS USE ST_Contains - INCLUDING get_pir_report ITSELF, PLUS brownfield, census,
econzone AND subdivision.
*** MEASURED THE EXPOSURE RATHER THAN ARGUING IT. 3,000 MIAMI-DADE PARCELS AGAINST miamidade_brownfield_areas:
  315 INTERSECT | 299 ARE CONTAINED | 16 DIFFER - 5.1% ***
SIXTEEN PARCELS PARTIALLY OVERLAP A BROWNFIELD AND ST_Contains DROPS EVERY ONE. A PARCEL HALF INSIDE A DESIGNATED
BROWNFIELD IS INSIDE A DESIGNATED BROWNFIELD - the BSRA restrictions, the recorded deed restrictions and the
groundwater limits attach to the land, not to the majority of it.
*** AND THE FAILURE RENDERS AS A CLEAN NEGATIVE. The report does not say "partially overlapping"; IT SAYS NOTHING, AND
NOTHING READS AS NO BROWNFIELD. That is a false clearance on the finding the spec ranks ABOVE SFHA. ***
RULED: THE SERVED CONTAINMENT PATH USES ST_Intersects, NOT ST_Contains, FOR RESTRICTION LAYERS.
  ST_Contains ANSWERS "is the parcel wholly inside" - a question no restriction asks.
  ST_Intersects ANSWERS "does the restriction touch this parcel" - which is the question a buyer is paying for.
CC IS RIGHT THAT THE FRAGMENT DEFECT MAKES IT WORSE AND NOT BETTER: 97,380 PARCELS ARE STORED AS MULTIPLE GEOMETRY
PIECES, AND ST_Contains AGAINST A FRAGMENT ASKS WHETHER THE RESTRICTION CONTAINS ONE SHARD. The Vizcaya parcel read
36.5 of 50.6 acres for exactly this reason.
SCOPE, AND IT IS NOT A BLANKET CHANGE: *** THIS APPLIES TO RESTRICTION AND HAZARD LAYERS, WHERE TOUCHING IS THE
FINDING. It does NOT apply to a jurisdiction assignment - "which county is this parcel in" IS a containment question
and ST_Contains is correct there. THE PREDICATE FOLLOWS THE QUESTION, WHICH IS THE SAME REASONING AS THE GEOMETRY ROLE
RULING. ***
AND THE 5.1% IS A MIAMI-DADE BROWNFIELD SAMPLE, NOT A STATEWIDE RATE. Every affected layer needs its own measurement
before any figure is published - a sampled rate supports "effectively", never "exactly".

## 92-fragmentation-by-county

### 1. FRAGMENTATION IS A PER-COUNTY RECORDING PRACTICE, 0.5% TO 93.6% - NO SINGLE RULE OR THRESHOLD CAN BE RIGHT

`measurement` | authority: CC; 12 counties measured 2026-08-23 | measured: 2026-08-23 | cc

Backlog 181 measured St Johns and found ~49% of multi-row parcel_id groups genuinely disjoint after ST_UnaryUnion. Measured across 12 counties 2026-08-23, capped at 250 groups each so the denominator is the sample:
   Miami-Dade 93.6% (max 39 components) | co 48 82.4% (13) | co 29 81.6% (8)
   Broward 80.4% (15) | co 13 74.0% (5) | ST JOHNS 53.2% (27) | co 50 44.2% (4)
   St Lucie 12.2% (4) | PINELLAS 2.1% (30) | VOLUSIA 0.5% (2)
St Johns REPRODUCES independently at 53.2% against the 49% originally measured. The finding was sound; generalising it was not.
The spread is 187-fold. A parcel_id repeating with disjoint geometry is COMMON in Miami-Dade and essentially ABSENT in Volusia, which means it reflects how each county records parcels, not a property of Florida land. A single threshold, a single aggregation rule, or a single LA_SpatialUnit-vs-LA_BAUnit verdict applied statewide will be wrong for most counties.
NOTE THE COUNTS, NOT ONLY THE RATES: Brevard produced ONE multi-row group in the sample and Lee eleven - in those counties parcel_id barely repeats at all, so their percentages carry no weight and must not be quoted. Pinellas is the opposite trap: only 2.1% disjoint but a maximum of 30 components, so when it does fragment it fragments hard.
THE RULE: measure fragmentation PER COUNTY before applying any aggregation or containment rule, and state the group count alongside the rate.

### 2. THE SEVERED-VS-GENUINE CLASSIFIER IS NOT TESTABLE WHERE IT MATTERS - ROAD COVERAGE AND FRAGMENTATION DO NOT OVERLAP

`test` | authority: CC measured 2026-08-23 | measured: 2026-08-23 | cc

A distance threshold is a proxy. The direct test is whether a ROAD physically lies between two disjoint components: build ST_ShortestLine between them and ask whether a road centerline crosses it. Built and run 2026-08-23.
IT CANNOT BE VALIDATED WHERE THE PROBLEM IS.
  St Johns (53.2% disjoint) - NO road layer held.
  Miami-Dade (93.6% disjoint, up to 39 components) - NO road centerline layer held.
  Volusia HAS volusia_public_works_streets (34,002) and has ONE disjoint group in 183, so the test runs and proves nothing.
Road centerlines are held for Lee, Orange, Hillsborough, Palm Beach, Pinellas, Brevard, Volusia, St Lucie, Collier and two cities. The high-fragmentation counties are not among them.
ALSO: hillsborough_right_of_way cannot settle a threshold either - it is ST_MultiLineString, right-of-way LINES with no width to measure, and widths appear only as free text ("50.00 FOOT W...") in a problems column populated on 7,437 of 208,281 rows.
So this is a COVERAGE GAP, not a threshold question. Acquiring road centerlines for Miami-Dade and St Johns makes the classifier testable; guessing a threshold does not.

### 3. THE DISTANCE THRESHOLD IS NOT IMPRECISE - IT IS INVERTED. WIDE GAPS ARE THE MOST LIKELY TO BE ROADS, NARROW GAPS THE LEAST

`measurement` | authority: CC; Miami-Dade measured 2026-08-23 | measured: 2026-08-23 | cc

The proposed ~150 ft threshold assumed a narrow gap means "severed by a road, still one parcel" and a wide gap means "genuinely separate parcels". MEASURED in Miami-Dade 2026-08-23, 284 disjoint parcel_id groups, using miamidade_street_centerlines (116,466 segments, verified 0 missing / 0 extra by returnIdsOnly set-diff) and ST_ShortestLine between the two largest components:
   gap <  50 ft   133 groups   a road crosses  38   29%
   gap 50-150 ft   99 groups   a road crosses  64   65%
   gap 150-500 ft  33 groups   a road crosses  16   48%
   gap >  500 ft   19 groups   a road crosses  14   74%
   OVERALL        284 groups   a road crosses 132   46.5%
THE RELATIONSHIP RUNS THE WRONG WAY AT BOTH ENDS. A 150 ft threshold would call the <50 ft cases road-severed when only 29% are, and call the >500 ft cases separate parcels when 74% of them ARE road-severed - a major road or highway has a wide right-of-way, while a sub-50-foot gap is more often a sliver, a digitising artifact, or two genuinely adjacent pieces. Median gap is 51.6 ft and the minimum is 0.0 ft - components that touch at a point and are still topologically disjoint.
53.5% of disjoint groups have NO road in the gap and remain unexplained. Key collision is already ruled out (864 groups, 100% one owner), so those are candidates for the LA_BAUnit reading - one ownership over several spatial units - or for severance by a feature we do not hold: canal, rail, water.
THE RULE: do not classify severance by distance. Ask whether a severing feature is actually there. Where no feature layer is held, the honest state is unexplained, not a threshold guess.

### 4. THE THRESHOLD IS INVERTED, NOT IMPRECISE - AND THE ACQUISITION IS WHAT PROVED IT

`measurement` | authority: CC severance test 2026-08-22 | measured: 2026-08-22 | cc

CC LOADED THE MIAMI-DADE STREET LAYER - VERIFIED BY ID SET-DIFF, 116,466 SOURCE, 116,466 LOADED, 0 MISSING, 0 EXTRA,
NOT A ROW COUNT - AND RAN THE SEVERANCE TEST FOR THE FIRST TIME.
284 DISJOINT GROUPS, ST_ShortestLine BETWEEN THE TWO LARGEST PARTS, DOES A ROAD CROSS IT:
  UNDER 50 FT   29% ARE ROADS      50-150 FT  65%      150-500 FT  48%      OVER 500 FT  74%
*** A 150-FOOT RULE WOULD CALL THE SUB-50-FOOT CASES ROAD-SEVERED WHEN ONLY 29% ARE, AND CALL THE OVER-500-FOOT CASES
SEPARATE PARCELS WHEN 74% OF THEM ARE ROAD-SEVERED. THE THRESHOLD IS NOT MISCALIBRATED. IT IS BACKWARDS. ***
AND THE REASON IS OBVIOUS ONCE MEASURED AND WAS INVISIBLE BEFORE: A MAJOR ROAD OR HIGHWAY HAS A WIDE RIGHT OF WAY, SO
THE BIGGEST GAPS ARE THE MOST LIKELY TO BE ROADS. A SUB-50-FOOT GAP IS MORE OFTEN A SLIVER OR TWO GENUINELY ADJACENT
PIECES. Minimum gap 0.0 ft - components touching at a point and still topologically disjoint.
I PROPOSED THE 150-FOOT THRESHOLD FROM SEVEN ST JOHNS MEASUREMENTS. IT WAS WRONG IN DIRECTION, NOT DEGREE, AND NO
AMOUNT OF TUNING WOULD HAVE FIXED IT.
*** 152 OF 284 - 53.5% - HAVE NO ROAD IN THE GAP, AND COLLISION IS ALREADY RULED OUT AT 100% ONE-OWNER ACROSS 864
GROUPS. SO THOSE ARE EITHER THE LA_BAUnit CASE OR SEVERANCE BY SOMETHING WE DO NOT HOLD FOR MIAMI-DADE - CANAL, RAIL
OR WATER. Answerable the same way, by acquisition and measurement rather than by rule. ***
THE METHOD IS THE FINDING: A PROXY WAS REPLACED BY EVIDENCE, AND THE EVIDENCE POINTED THE OPPOSITE WAY.

## 93-fragment-attributes

### 1. KEY COLLISION IS RULED OUT - 864 DISJOINT GROUPS, THREE COUNTIES, ZERO COLLISIONS

`measurement` | authority: CC; 3 counties measured 2026-08-23 | measured: 2026-08-23 | cc

The serious hypothesis for a disjoint multi-row parcel_id was a KEY COLLISION: two different properties recorded under one parcel_id, which would break every join, report and containment test that assumes the key is unique.
TESTED 2026-08-23 by comparing own_name / phy_addr1 / jv ACROSS the rows sharing a parcel_id:
   Miami-Dade  375 disjoint groups  100% one owner, one address, one just-value
   Broward     337 disjoint groups  100%
   St Johns    152 disjoint groups  100%
864 disjoint groups, ZERO groups with differing owner or address. The collision hypothesis is dead. Every case is ONE holding recorded as several rows.
AND alt_key CANNOT BE USED FOR THIS TEST. Measured: populated on 306,889 of 306,889 Volusia parcels and on ZERO of 585,220 Miami-Dade and ZERO of 205,773 St Johns. It is a Volusia-only column and any rule built on it holds for one county.

### 2. AGGREGATE THE GEOMETRY, NEVER THE ATTRIBUTES - THEY ARE REPEATED ON EVERY FRAGMENT, AND SUMMING jv OVERSTATES BROWARD BY $57 BILLION

`rule` | authority: CC measured 2026-08-23 | measured: 2026-08-23 | cc

The July ruling "aggregate, never dedupe" is correct for GEOMETRY - Vizcaya read 36.5 of 50.6 acres because one fragment was read instead of the union, and _parcel_geom_agg rightly does ST_Union.
IT IS THE OPPOSITE FOR ATTRIBUTES. Measured on 300 Miami-Dade multi-row groups:
   jv IDENTICAL on every row          300 of 300
   lnd_sqfoot IDENTICAL on every row  300 of 300
   average 2.81 rows per group, worst case 41 rows
The county copies the parcel's attributes onto EVERY fragment. They are not split, so summing them multiplies the value by the fragment count - up to 41x on a single Miami-Dade parcel.
LIVE DEFECT: get_area_findings computes 'total_just_value', sum(p.jv) joined to parcels_staging. Measured overstatement:
   Broward     naive $537,414,977,200 vs correct $480,140,046,980  = +11.93%  (+$57.3 BILLION)
   Miami-Dade  naive $617,732,207,453 vs correct $581,978,420,072  = + 6.14%  (+$35.8 BILLION)
   Volusia                                                          = + 0.02%  (0.5% fragmentation)
The error tracks the county fragmentation rate exactly, so it is invisible in Volusia - the county everything is tested against - and worst in the two largest counties by value.
THE RULE: geometry aggregates by ST_Union; area is measured from the union. Attributes are taken ONCE per parcel_id (any row - they are identical), never summed, never averaged. A per-parcel attribute repeated across fragments is not N observations.

### 3. CORRECTION: I NAMED THE WRONG FUNCTION. get_area_findings IS VOLUSIA-HARDCODED; search_properties_stats IS THE LIVE ONE

`correction` | authority: CC self-correction; verified 2026-08-23 | measured: 2026-08-23 | cc

I reported get_area_findings as overstating Broward just-value by $57.3 BILLION and ruling 285 was made on that basis. The arithmetic was right and the function was wrong.
get_area_findings has NO county parameter - its signature is (p_unit text, p_value text, p_city text) - and it hardcodes co_no=74 in ALL NINETEEN places. It serves VOLUSIA ONLY, where the inflation is 0.02%. The $57.3B Broward figure is what happens WHEN THAT FUNCTION IS EXTENDED beyond Volusia. It is latent, not live.
THE LIVE ONE IS search_properties_stats(p_co_no numeric DEFAULT NULL, ...). The default is NULL, so it runs STATEWIDE, and it returns count(*) and avg(p.jv) straight off parcels_staging rows. MEASURED:
   Broward     match_count 764,950 -> 752,533  +1.65%   avg_value $702,549 -> $638,032   +10.11%
   Miami-Dade  match_count 570,598 -> 567,700  +0.51%   avg_value $1,082,605 -> $1,025,151 +5.60%
   Volusia     match_count 302,561 -> 302,378  +0.06%   avg_value                          -0.04%
A Broward search reports the average property value TEN PERCENT HIGH - $702,549 against $638,032 - because fragmented parcels average 7.2x the value of single-row parcels and each fragment votes.
THE LESSON, AND IT IS THE ONE WE KEEP RE-LEARNING: I measured the arithmetic on Broward data without checking WHICH COUNTY THE FUNCTION READS. Measuring a defect is not the same as measuring the served path, and I have written that rule down twice this week.
Ruling 285 stands unchanged - aggregate geometry, take attributes once. Only the target changes.

### 4. RULING 286 - FIX IT AT REST, NOT IN THE QUERY. THE DUPLICATION IS A STORAGE FACT AND EVERY READER PAYS FOR IT.

`rule` | authority: CC queued; measured and ruled 2026-08-22 | measured: 2026-08-22 | murphy

CC ASKED FOR AN A/B CALL: THE CORRECT search_properties_stats QUERY TAKES 157-276s AGAINST A 60-SECOND BUDGET.
*** NEITHER A NOR B. THE QUESTION ASSUMES THE FIX BELONGS IN THE QUERY, AND IT DOES NOT. ***
MEASURED: THE REDUNDANCY IS SMALL AND THE COST OF CARRYING IT IS NOT.
  BROWARD     765,030 rows / 752,606 parcels = 12,424 REDUNDANT, 1.62%
  MIAMI-DADE  585,220 / 579,992 = 5,228, 0.89%
  VOLUSIA     306,889 / 306,706 = 183, 0.06%
*** ONE AND A HALF PERCENT OF ROWS IS FORCING A DISTINCT ON ACROSS 10.7 MILLION IN EVERY QUERY THAT TOUCHES AN
ATTRIBUTE. THAT IS THE ST_MakeValid LESSON IN A FOURTH FORM: repair once at rest, or pay per call forever. ***
RULED: BUILD parcel_attributes - ONE ROW PER (co_no, parcel_id), CARRYING THE ATTRIBUTES ONLY, NO GEOMETRY.
  IT IS SAFE BECAUSE IT IS MEASURED SAFE: jv IDENTICAL ON 300 OF 300 GROUPS, lnd_sqfoot IDENTICAL ON 300 OF 300, AND
  864 DISJOINT GROUPS ACROSS THREE COUNTIES AT 100% ONE OWNER ONE ADDRESS ONE VALUE. THERE IS NOTHING TO CHOOSE
  BETWEEN THE COPIES BECAUSE THEY ARE THE SAME COPY.
  *** AND IT IS THE LADM SHAPE RATHER THAN A CONVENIENCE: THE GEOMETRY IS MULTIPART AND BELONGS TO THE SPATIAL UNIT;
  THE OWNER, VALUE AND ADDRESS BELONG TO THE BAUnit. WE HAVE BEEN STORING A BAUnit FACT ON EVERY SPATIAL UNIT ROW AND
  THEN SUMMING IT. ***
  A UNIQUE INDEX ON (co_no, parcel_id) MAKES THE DUPLICATION UNREPRESENTABLE RATHER THAN MERELY CORRECTED - AND A
  CONSTRAINT HAS HELD EVERY TIME A RULE HAS FAILED THIS WEEK.
  parcels_staging KEEPS EVERY ROW AND EVERY FRAGMENT. NOTHING IS DELETED. Geometry still aggregates from it.
THE SERVED FIX BECOMES A JOIN TO A TABLE WITH ONE ROW PER PARCEL, WHICH IS FAST BY CONSTRUCTION - NO DISTINCT ON, NO
WINDOW FUNCTION, NO BUDGET QUESTION. AND IT FIXES EVERY FUTURE AGGREGATE, NOT THE TWO WE FOUND.
DO NOT SHIP A FASTER-BUT-STILL-WRONG QUERY IN THE MEANTIME. Broward reading 10.11% high for another day is worse than
Broward reading 10.11% high for another day AND a workaround nobody remembers to remove.

## 94-satisfaction-closed

### 1. THE SATISFACTION GAP IS CLOSED IN BOTH DIRECTIONS - EXPOSURE 80.2% TO 0.0%, AND THE REGISTER REACHES 1988

`measurement` | authority: CC backfill; exposure re-measured 2026-08-22 | measured: 2026-08-22 | cc

CC BACKFILL COMPLETED. VERIFIED INDEPENDENTLY - ALL EIGHT DOCTYPES NOW SPAN 1988-01-01 TO 2026-08-20:
  SATISFACTION 909 weeks, 0 failed | RELEASE 909, 1 | PARTIAL SATISFACTION 909, 0 | DEED 909, 2
  LIEN 913, 0 | JUDGMENT/ORDER 913, 1 | LIS PENDENS 913, 0 | RESTRICTIONS 913, 0
  *** FOUR FAILURES IN 7,288 JOBS. ***
SATISFACTIONS WENT FROM 245,757 ROWS ENDING 2019-03-06 TO 1,184,132 ENDING 2026-08-21.
*** AND I RE-MEASURED THE EXPOSURE RATHER THAN QUOTING IT, BECAUSE CC WARNED IT WAS STALE IN OUR FAVOUR:
  6,923 matched encumbrances. AFTER THE OLD WINDOW: 5,552 = 80.2%. AFTER THE NEW WINDOW: ZERO = 0.0%.
  EVERY MATCHED ENCUMBRANCE NOW FALLS INSIDE A WINDOW WHERE WE HOLD THE SATISFACTIONS. ***
FOUR IN FIVE LIENS WERE UNKNOWABLE ON FRIDAY. NONE ARE NOW. THE BLOCKER ON THE LIEN BLOCK IS GONE.
AND THE SECOND HALF MATTERS AS MUCH: THE REGISTER REACHES 1988 RATHER THAN 2015 - TWENTY-SEVEN YEARS OF VOLUSIA
PROPERTY HISTORY THAT DID NOT EXIST ON FRIDAY. 1988 IS THE MEASURED FLOOR, NOT AN ASSUMED ONE: 1987 AND EVERY EARLIER
YEAR RETURNS ZERO THROUGH THE IDENTICAL CODE PATH.
*** MURPHY RULING NOW APPLIES CLEANLY: REPORT WHAT IS ON RECORD, DO NOT EDIT THE RECORD. An unsatisfied lien is a fact
about the register, and the report must state the window - "no satisfaction or release recorded through 2026-08-20".
THAT SENTENCE IS NOW TRUE FOR EVERY MATCHED ENCUMBRANCE INSTEAD OF ONE IN FIVE. ***
AND THE parcel_encumbrance_satisfaction REBUILD IS THE REMAINING STEP, NOT AN OPTIONAL ONE: ITS 139 LINKS OVER 117
PARCELS WERE DERIVED FROM A 218-WEEK WINDOW THAT IS NOW 909. REBUILD, DO NOT APPEND - a link set derived from a
truncated window is a sample of a sample, and appending to it preserves the truncation invisibly.

## 95-corroboration-bar

### 1. RULING 287 - THE CORROBORATION STANDARD, FOR BOTH THE SATISFACTION REBUILD AND THE 10,900 CANDIDATES

`rule` | authority: CC queued; ruled 2026-08-22 | measured: 2026-08-22 | murphy

CC ASKED FOR ONE RULING TO SETTLE BOTH, AND THEY ARE THE SAME QUESTION: WHEN IS A RECORDED INSTRUMENT PROVEN TO ATTACH
TO A PARCEL.
READ THE EXISTING EVIDENCE FIRST. THE 139 PAIRINGS ARE ALL party+legal_corroborated, 117 PARCELS, AND *** ZERO HAVE A
SATISFACTION DATED BEFORE THEIR LIEN. A CLEAN TEMPORAL RECORD ACROSS EVERY ROW. *** That is not proof the method is
right, but it is the one falsifiable check available and it passes.
*** THE STANDARD: TWO INDEPENDENT IDENTIFIERS, PLUS A TEMPORAL ORDER THAT IS POSSIBLE. ***
  1. TWO INDEPENDENT IDENTIFIERS AGREE - party name AND legal description. NOT one, and not two facets of one.
     A NAME ALONE IS NOT A MATCH: Florida has thousands of SMITH JOHN, and the Polk 844-owner parcel showed what a
     name-only join does at scale.
  2. THE SEQUENCE MUST BE POSSIBLE - a satisfaction cannot precede its lien. Zero violations in 139 today; ANY
     VIOLATION AFTER THE REBUILD IS A DEFECT IN THE MATCH, NOT AN ODDITY IN THE RECORD.
  3. WHERE ONLY ONE IDENTIFIER AGREES, IT IS A CANDIDATE AND IS SERVED AS ONE. NOT PROMOTED, NOT DISCARDED.
*** AND THE THIRD IS WHERE MURPHY RULING DOES THE WORK: REPORT WHAT IS ON RECORD. A single-identifier candidate is a
real fact about the register - "an instrument naming this owner was recorded against a property with this legal
description" - AND THE PIR CAN SAY THAT WITHOUT ASSERTING THE MATCH. It gives the purchaser what they need to dig
deeper, which is the whole point. IT MUST NEVER APPEAR IN THE SAME LIST AS A CORROBORATED ONE. ***
THAT SETTLES THE 10,900 TOO: they agreed with the confirmed set 6,052 OF 6,052 against a 0.014% chance rate, WHICH IS
STRONG EVIDENCE THE METHOD GENERALISES AND IS NOT A SECOND IDENTIFIER. Promote the ones meeting the two-identifier
test; SERVE THE REMAINDER AS CANDIDATES WITH THE EVIDENCE NAMED.
BUILD IT AS A FUNCTION, NOT A STATEMENT - CC point, and it is the difference between or_satisfaction_frontier(), which
ADVANCED ON ITS OWN FROM 2019-03-06 TO 2026-08-21 WITH NOBODY REMEMBERING TO UPDATE IT, and the pairing table, which
sat at a truncated window for seven years. *** THE FRONTIER IS THE MODEL FOR EVERY DERIVED ARTEFACT WE BUILD. ***
REBUILD, NEVER APPEND. And CC was right to stop before adding an index on the private records table - an index is a
decision about that table, not a free measurement. ADD IT DELIBERATELY IF THE REBUILD NEEDS IT.

### 3. THE LEGAL DESCRIPTION IS RECORDED VERBATIM - IT IS THE MATCHING KEY THAT IS DERIVED

`correction` | authority: CC measured; supersedes 95/2 which was ruled on an unverified premise | measured: 2026-08-23 | cc

Ruling 287 was amended on the belief that legal_description is produced by an untested 235-line parser. Measured 2026-08-23, that is false in both halves.
RECORDED: volusia_or_collect.py line 62 stores legal_description as c[6], the Clerk grid column, verbatim. The collector comment reads "Document Type|Name|Legal|Status|Direction ... Index-based so a blank Legal cannot shift columns." The Clerk publishes a Legal column.
POPULATED: 4,680,533 of 5,273,113 rows = 88.8%, 945,707 distinct, 0 whitespace-only. Not NULL.
NO SUCH FUNCTION: nothing in the database is a 235-line legal parser. The only derived artifact is enc_legal_key(text), 26 lines.
The rule criterion 4 states is RIGHT and is retained - a derived identifier needs a measured error rate before it counts as one of two. It simply attaches to enc_legal_key, not to legal_description.

### 4. enc_legal_key ERROR RATE - 27% YIELD NO KEY, AND IT EMITS CONFIDENT KEYS FOR TEXT WITH NO PROPERTY IN IT

`measurement` | authority: CC measured 2026-08-23; backlog 183 | measured: 2026-08-23 | cc

Audited over the LN/PS/SF/RE/JDO1 corpus, 108,828 distinct legals, 2026-08-23.
FALSE NEGATIVE: 29,593 (27.19%) return NULL - those liens can never match anything, silently.
FALSE POSITIVE: the function strips $ amounts first, so a Legal field holding only an amount and an annotation reduces to the annotation. "$6,624.00 AMENDED", "$351,841.50 AMENDED" and 573 other distinct legals all collapse to the single key AMENDED. CORRECTSORIGINAL absorbs 403, CORRECTIVE 363, REFILED 88. 1,046 keys are 6 characters or fewer.
The predicted failure - the LOT/LT anchor discarding the subdivision name ahead of it - is real in the code but is NOT the dominant mode. Junk annotation keys are.
THE EXISTING SET IS CLEAN: of the 6,923 rows in parcel_encumbrance_match, all legal+owner_corroborated, the keys behind them are 0 NULL, 0 digit-free, 8 (0.1%) short. Owner corroboration filtered the junk out. The contamination risk is in EXPANSION, not in what is already there.

### 5. A REBUILD MUST REFUSE A KEY THAT IS NULL, DIGIT-FREE, OR TEN CHARACTERS OR SHORTER

`rule` | authority: CC proposed 2026-08-23; awaiting ruling under 287 crit 4 | measured: 2026-08-23 | cc

These three exclusions are not style. Each is a measured failure mode of enc_legal_key: NULL never matches, digit-free means the property description was stripped away leaving an annotation, and a very short key is generic enough to match unrelated parcels. Any rebuild of parcel_encumbrance_satisfaction asserts them at build time and fails the build rather than writing a row that rests on one.
The general form, which is criterion 4 kept: a derived identifier counts as an identifier only once its derivation has a measured error rate. Until then it is an assumption wearing one.

### 6. THE TWO-IDENTIFIER CEILING IS 472 KEY-GROUPS - THE 3,102 FIGURE WAS ONE IDENTIFIER

`measurement` | authority: CC measured 2026-08-23; handoff to claude | measured: 2026-08-23 | cc

Measured 2026-08-23 over the Volusia LN+PS pool, 327,876 rows carrying a legal.
Applying the exclusion rule (key not null, contains a digit, longer than 10 characters): 108,027 rows excluded (32.9%), 219,849 survive (67.1%), yielding 64,701 distinct usable keys.
Of those 64,701 usable keys, only 472 appear on BOTH a lien and a satisfaction. That is the ceiling for legal-key corroboration, and it is before requiring that the discharge post-date the lien or that the party corroborate - so the real yield is lower still.
The earlier 3,102 figure counted liens with a party-matching discharge. That is ONE identifier. Under a genuine two-identifier standard the rebuild is worth hundreds of key-groups, not thousands. A prize quoted on one identifier will always look larger than the standard can deliver.

### 7. THE LEGAL KEY FAILS BY TEXT DIVERGENCE (69.3%), NOT AMBIGUITY (5.0%) - MEASURED AGAINST A RECORDED LINK

`measurement` | authority: CC measured 2026-08-24; confirms claude ambiguity, reframes the cause | measured: 2026-08-24 | cc

Measured 2026-08-24. DOR records parcel to deed book/page in the SDF (67 of 67 counties), which links a parcel to a deed WITHOUT the parser. 67,408 sale rows covering 53,365 parcels; 42,792 parcels (80.2%) resolved to an OR record by book+page.
Against that independent link the parser agreed on 30.7% and disagreed on 69.3%. The control proves this is NOT parser error: parcel_legal_key.legal_key equals enc_legal_key(volusia_cama_legal.LEGDESC) on 278,602 of 278,602 rows, 100.0%. Same function both sides. The 69.3% is one deterministic parser applied to two different TEXTS - the appraiser legal and the deed legal.
Key ambiguity is real but small: 3,898 of 268,578 distinct keys (1.45%) map to more than one parcel, worst case 60, affecting 13,922 of 278,602 rows (5.0%).
THREE CATEGORIES, NOT TWO: parser error (fixable), key ambiguity (5.0%), text divergence (69.3%, dominant, unfixable by parsing). A fix aimed at ambiguity would have looked like progress while divergence stayed put.
And enc_legal_key STRIPS the recorded cross-reference it should be extracting: 95.4% of CAMA legals carry an OR book/page reference and step 3 truncates the string at it. But liens carry one only 1.3% of the time, so book/page cannot serve as the lien-side second identifier - the SDF records sales, and a lien has its own book/page identifying the lien, not the parcel.

## 96-built-not-usable

### 1. AN ARTIFACT THAT PASSES ITS OWN BUILD ASSERTION IS NOT VERIFIED - THE INDEX WAS VALID AND THE TABLE WAS UNUSABLE

`principle` | authority: CC measured 2026-08-23/24 | measured: 2026-08-24 | cc

parcel_attributes (ruling 286) was built to make a corrected aggregate affordable. The build script asserted its unique index was valid and declared success. Measured 2026-08-23, the finished table answered the served query in 328.2 s statewide and 23.9 s for Broward, against 36.0 s and 0.2 s on the uncorrected table and a 60 s statement_timeout. It was slower than the bug it fixed.
Three things the build never did: ANALYZE (no planner statistics), VACUUM (no visibility map, so no index-only scan is possible on a fresh CTAS table), and any index suited to the query - it built (co_no, parcel_id), which cannot serve an aggregate over jv. After ANALYZE, a 315 MB covering index on (co_no, jv) and VACUUM ANALYZE: Broward 2.50 s, statewide 32.04 s, every scope inside budget.
THE RULE: a build assertion tests what the builder thought to test. Verification means exercising the query the served function actually runs, at the scope it actually runs it. "The index is valid" and "the query is affordable" are different claims, and only the second one was the point of building it.

## 97-recorded-but-not-present

### 1. BOOK AND PAGE IS A DOR SCHEMA COLUMN IN 67 COUNTIES AND DATA IN 50 - 10.8% OF FLORIDA PARCELS

`measurement` | authority: CC measured 2026-08-24 under ruling 288 | measured: 2026-08-24 | cc

Measured 2026-08-24 across all 67 <county>_nal_dor_source and <county>_sdf_dor_source tables.
53 counties carry any OR_BOOK1 (8,022,143 parcels) and 14 carry none (2,717,738 parcels, 25.3%). Three of the 53 are noise - Orange 100 rows of 490,529, Manatee 6, Hendry 36 - so 50 counties really carry it. Statewide, 1,155,952 of 10,739,881 parcels have a recorded book+page: 10.8%.
BROWARD IS ZERO. broward_nal_dor_source holds 754,371 rows and broward_sdf_dor_source 115,745 - fully populated tables - with OR_BOOK1/OR_BOOK NULL on every row. Schema presence is not data presence, which is the layer-name trap in a new costume: the column is a DOR standard, so it exists everywhere the standard does, whether or not the county populated it.
Where it exists the fill is 10-22% of parcels because the SDF is a sales file, so not_available is the honest answer for roughly 89% of Florida parcels.
FORMATTING TRAP, and it cost me a wrong number: SDF zero-pads OR_BOOK and OR_PAGE to four characters (19.7% of pages carry a leading zero) while the clerk index pads neither. Raw string equality silently drops every page below 1000. I reported the parcel-to-deed link at 80.2% on raw equality; normalised it is 96.6%. Normalise both sides or lose a fifth of the pages.

## 98-clerk-indexes-by-parcel

### 1. THE CLERK INDEXES BY PARCEL AND WE NEVER USED IT - THERE IS NO DETAIL PAGE, THERE IS A PARCEL SEARCH FIELD

`measurement` | authority: CC measured 2026-08-24 under ruling 289 | measured: 2026-08-24 | cc

Measured 2026-08-24 against app02.clerk.org/or_m/inquiry.aspx.
The grid "View" cell is not a metadata link - it is viewDoc(...) around <img id="Imagepdf">, the scanned image. For this Clerk the search grid IS the metadata and there is nothing richer behind it. A detail-page scraper would have had nothing to scrape.
The search form carries a PARCEL field. Tested against a DOR-known deed: parcel 030300000122 returns "Records found 4" including instrument 2024116693 at book 8570 page 0973 - exactly the deed DOR records. The dashed form works too; a malformed parcel returns 0 rows, so the field genuinely filters rather than being ignored. The DOR parcel_id works UNTRANSFORMED.
This is the recorded parcel attachment the two-identifier standard needed. It is not derived, not sales-conditioned, and not subject to the 10.8% book/page ceiling. Four of five existing parcel_encumbrance_match liens were corroborated against it directly; the fifth returned an empty label and zero rows, which is INDETERMINATE and awaiting retry, not a refutation.
THE LESSON: we built a parser, a legal key, a corroboration standard and three rulings around inferring which parcel a document attaches to, while the register exposed that field in its own search form the whole time. Before modelling a link, check whether the source already publishes it.
