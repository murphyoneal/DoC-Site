-- =============================================================================
-- work order 67 Stage 1 — load Putnam (co_no 64, 36 rows) and Indian River (co_no 41,
-- 2 rows) into the statewide table. Data read verbatim from the Clerk pages 2026-08-09
-- (Putnam via full-DOM read after WebFetch mis-counted the rows as 41; the register has 36).
-- Upsert on the natural key (co_no, certificate_number). Register both as direct_fetch /
-- automated / refresh_owner=cc.
-- =============================================================================

-- data_source_registry was one-row-per-physical-table (unique(table_name)). A statewide
-- table fed by many county sources outgrows that: WO 67 requires BOTH Putnam and Indian
-- River registered against the one table. Relax the grain to (table_name, county_name) —
-- the honest per-county source identity. DEF-009 and the refresh driver iterate rows and
-- do not depend on table_name being unique. Reported as a small structural change.
ALTER TABLE data_source_registry DROP CONSTRAINT IF EXISTS data_source_registry_table_name_key;
ALTER TABLE data_source_registry ADD CONSTRAINT data_source_registry_table_county_key UNIQUE (table_name, county_name);

-- ---- Putnam (co_no 64): auction date = date_original_sale; money = ESTIMATED price ----
INSERT INTO lands_available_for_taxes
  (co_no, certificate_number, parcel_id, owner_name, legal_description,
   date_original_sale, date_available_public, estimated_purchase_price,
   county_contact_name, source_url, loaded_at)
SELECT 64, cert, parcel, owner, legal,
       to_date(auction,'MM/DD/YYYY'), to_date(avail,'MM/DD/YYYY'), price::numeric,
       'Putnam County Clerk of Court — Tax Deeds Office',
       'https://apps.putnam-fl.com/coc/taxdeeds/public/public_LAFT.php', now()
FROM (VALUES
 ('T.D. 2018-0003254','04-10-24-9030-0050-0250','PINNACLE VISTA ENTERPRISE','TROUT LAKE GARDENS MB4 P68, BLK 5 LOT 25','09/24/2025','12/23/2025','1669.80'),
 ('T.D. 2018-0008244','11-10-23-0000-0040-0010','KARY M BEARD JR','PT OF W1/2 OF NW1/4 OF NE1/4, OR962 P1790','09/17/2025','12/16/2025','1701.89'),
 ('T.D. 2018-0010882','13-10-26-0000-0650-0001','MANNA HOUSES LLC','THAT PART OF SW1/4 LYING BETWEEN MCKEANS S/D (DB V P667) AND ROLLING HILLS S/D (MB4 P207 + MB6 P18) (EX ANY PART SOLD OUT)','09/10/2025','12/09/2025','2384.88'),
 ('T.D. 2018-0017870','33-09-25-7600-0220-0480','CURTIS ROBERT BURNSIDE','PUTNAM MANOR S/D MB3 P2, BLK 22 LOT 48','09/10/2025','12/09/2025','1382.70'),
 ('T.D. 2018-0017873','33-09-25-7600-0220-0450','CURTIS ROBERT BURNSIDE','PUTNAM MANOR S/D MB3 P2, BLK 22 LOT 45','09/10/2025','12/09/2025','1432.30'),
 ('T.D. 2018-0017876','33-09-25-7600-0220-0300','CURTIS ROBERT BURNSIDE','PUTNAM MANOR S/D MB3 P2, BLK 22 LOT 30','10/08/2025','01/06/2026','1378.29'),
 ('T.D. 2018-0018391','34-09-25-2702-0060-0160','KUEHNTOPIA INVESTMENTS LLC','FLORIDIAN MANOR SECTION 2, MB3 P35 BLK 6 LOT 16','07/23/2025','10/21/2025','1562.47'),
 ('T.D. 2018-0019164','35-10-24-0000-0060-0000','MANNA HOUSES LLC','SW 1/4 OF NE 1/4 OF NE 1/4, S 1/2 OF NW 1/4 OF NE 1/4, N 1/2 OF SW 1/4 OF NE 1/4, S 1/2 OF NE 1/4 OF NW 1/4, S 1/2 OF S 1/2 OF NW 1/4 OF NW 1/4, N 1/2 OF S 1/2 OF NW 1/4 (EX numerous OR-reference exceptions — see Clerk record)','09/10/2025','12/09/2025','2411.12'),
 ('T.D. 2019-0001888','03-10-24-2570-0010-0080','CRYSTAL SCHEERER','FLAMINGO LAKE ESTATES MB4 P43, BLK 1 LOT 8','05/13/2026','08/11/2026','1510.52'),
 ('T.D. 2019-0001892','03-10-24-2570-0010-0090','CRYSTAL SCHEERER','FLAMINGO LAKE ESTATES MB4 P43, BLK 1 LOT 9','05/13/2026','08/11/2026','1521.08'),
 ('T.D. 2019-0002834','04-10-24-5533-0180-0140','RAMATH LAOBE','MARINERS LAKE HEIGHTS UNIT 2, MB4 P102 BLK 18 LOT 14','06/24/2026','09/22/2026','1372.34'),
 ('T.D. 2019-0002978','04-10-24-5540-0040-0410','RICHARD ALLEN SAYERS','MARINERS LAKE HILLS MB4 P74, BLK 4 LOT 41','06/10/2026','09/08/2026','1540.98'),
 ('T.D. 2019-0005834','07-10-24-7071-0270-0500','DAY INVESTMENT AND CONSULTING LLC','PARADISE VIEW ESTS ADD NO 2, MB4 P48 BLK 27 LOT 50','02/18/2026','05/19/2026','2283.38'),
 ('T.D. 2019-0006030','07-10-24-7072-0170-0270','FUTURES SECURITY LLC','PARADISE VIEW ESTS ADD NO 3, MB4 P49 BLK 17 LOT 27','01/07/2026','04/07/2026','1873.09'),
 ('T.D. 2019-0012547','15-11-24-4700-0130-0160','VALERIE URRUTIA','KENWOOD MB2 P8, BLK 13 LOT 16','04/08/2026','07/07/2026','1076.20'),
 ('T.D. 2019-0012594','15-11-24-4700-0070-0100','VALERIE URRUTIA','KENWOOD MB2 P8, BLK 7 LOT 10','04/08/2026','07/07/2026','1121.00'),
 ('T.D. 2019-0014047','19-08-26-0000-0062-0260','SEBASTIAN ANDRES AVILA NASSER','PT OF W1/2 OF NW1/4 OR582 P1043 (PARCEL 15-19) (EX OR1014 P1241)','06/24/2026','09/22/2026','1731.61'),
 ('T.D. 2019-0020547','35-12-27-7670-0100-0120','VALERIE URRUTIA','REA PARK MB1 P167 BLK J LOT 12','04/08/2026','07/07/2026','1155.31'),
 ('T.D. 2020-0003019','04-10-24-9025-0070-0150','VALERIE URRUTIA','TROUT LAKE ESTATES MB4 P71, BLK 7 LOT 15','04/08/2026','07/07/2026','1547.81'),
 ('T.D. 2020-0007670','09-09-23-0000-0041-0011','CHERECE L LINDSAY','PT OF GOVT LOT 1 OR312 P971 (EX OR329 P762 OR396 PP682 727 762 OR559 P1763 OR658 P1693)','01/21/2026','04/21/2026','1756.68'),
 ('T.D. 2021-0001758','03-10-24-9070-0170-0060','MICHAEL CANIZALES','TWIN LAKE ESTATES REVISED PLAT, MB4 P55 BLK 17 LOT 6','11/19/2025','02/17/2026','1565.82'),
 ('T.D. 2021-0002919','04-10-24-9030-0010-0310','SKIP WORK TRAVEL','TROUT LAKE GARDENS MB4 P68, BLK 1 LOT 31','05/13/2026','08/11/2026','1490.64'),
 ('T.D. 2021-0007005','09-10-24-0350-0180-0300','SDR 401K PLAN & TRUST','BATES ADD TO INTERLACHEN, MB1 PGS 126 127 BLK 18 LOT 30','01/08/2025','04/08/2025','1506.94'),
 ('T.D. 2021-0010397','13-11-26-8244-0360-0010','OUR LEGACY INVESTMENTS LLC','ST JOHNS RIVERSIDE ESTATES, HOOT OWL RIDGE 4TH ADDITION, CORRECTED PLATS MB5 P101, BLK 36 LOT 1','02/18/2026','05/19/2026','1544.99'),
 ('T.D. 2021-0017005','34-09-25-2702-0070-0020','SDR 401K PLAN & TRUST','FLORIDIAN MANOR SECTION 2, MB3 P35 BLK 7 LOT 2','01/08/2025','04/08/2025','1476.68'),
 ('T.D. 2022-0001768','03-10-24-9070-0080-0420','HOME EC HOME PERFORMANCE INC.','TWIN LAKE ESTATES REVISED PLAT, MB4 P55 BLK 8 LOT 42','06/25/2025','09/23/2025','1841.94'),
 ('T.D. 2022-0001769','03-10-24-9070-0080-0430','HOME EC HOME PERFORMANCE INC.','TWIN LAKE ESTATES REVISED PLAT, MB4 P55 BLK 8 LOT 43','06/25/2025','09/23/2025','1841.94'),
 ('T.D. 2022-0001770','03-10-24-9070-0080-0440','HOME EC HOME PERFORMANCE INC.','TWIN LAKE ESTATES REVISED PLAT, MB4 P55 BLK 8 LOT 44','06/25/2025','09/23/2025','1841.94'),
 ('T.D. 2022-0001831','03-10-24-9070-0150-0150','HOME EC HOME PERFORMANCE INC.','TWIN LAKE ESTATES REVISED PLAT, MB4 P55 BLK 15 LOT 15','06/25/2025','09/23/2025','1789.84'),
 ('T.D. 2022-0001847','03-10-24-9070-0150-0530','HOME EC HOME PERFORMANCE INC.','TWIN LAKE ESTATES REVISED PLAT, MB4 P55 BLK 15 LOT 53','06/25/2025','09/23/2025','1437.54'),
 ('T.D. 2022-0002146','04-10-24-4928-0100-0280','MARIA DELMAR CARPIO CAOAGDAN','LAKE LUCY MANOR MB4 P79, BLK 10 LOT 28','06/25/2025','09/23/2025','1862.22'),
 ('T.D. 2022-0002212','04-10-24-5531-0040-0200','LADY HARDT','MARINERS LAKE ESTATES MB4 P77, BLK 4 LOT 20','12/03/2025','03/03/2026','1761.18'),
 ('T.D. 2022-0002513','04-10-24-5533-0180-0280','LADY HARDT','MARINERS LAKE HEIGHTS UNIT 2, MB4 P102 BLK 18 LOT 28','12/03/2025','03/03/2026','1543.72'),
 ('T.D. 2022-0002514','04-10-24-5533-0180-0290','LADY HARDT','MARINERS LAKE HEIGHTS UNIT 2, MB4 P102 BLK 18 LOT 29','12/03/2025','03/03/2026','1543.72'),
 ('T.D. 2022-0004283','05-10-24-9045-0030-0450','ERIN DANIELS','TROUT LAKE VILLAGE MB4 P78, BLK 3 LOT 45','09/10/2025','12/09/2025','1770.64'),
 ('T.D. 2023-0002034','04-10-24-4940-0110-0080','MICHAEL CANIZALES','LAKE LUCY VILLAGE MB4 P75, BLK 11 LOT 8','01/07/2026','04/07/2026','1677.23')
) AS v(cert, parcel, owner, legal, auction, avail, price)
ON CONFLICT (co_no, certificate_number) DO UPDATE SET
  parcel_id=EXCLUDED.parcel_id, owner_name=EXCLUDED.owner_name, legal_description=EXCLUDED.legal_description,
  date_original_sale=EXCLUDED.date_original_sale, date_available_public=EXCLUDED.date_available_public,
  estimated_purchase_price=EXCLUDED.estimated_purchase_price, county_contact_name=EXCLUDED.county_contact_name,
  source_url=EXCLUDED.source_url, loaded_at=EXCLUDED.loaded_at;

-- ---- Indian River (co_no 41): opening bid = FLOOR; PUBLISHED escheat date = ground truth ----
INSERT INTO lands_available_for_taxes
  (co_no, certificate_number, case_number, parcel_id, original_opening_bid,
   date_original_sale, published_escheat_date, county_contact_name, county_contact_phone, source_url, loaded_at)
SELECT 41, cert, casenum, parcel, bid::numeric, to_date(sale,'MM/DD/YYYY'), to_date(escheat,'MM/DD/YYYY'),
       'Indian River County Tax Collector', '772-226-1338',
       'https://indianriverclerk.com/land-available-for-taxes/', now()
FROM (VALUES
 ('702-2013','17-86 TD','02239-137','30297.17','3/5/2018','4/6/2021'),
 ('1893-2016','18-138 TD','06085-000','4160.72','5/13/2019','6/13/2022')
) AS v(cert, casenum, parcel, bid, sale, escheat)
ON CONFLICT (co_no, certificate_number) DO UPDATE SET
  case_number=EXCLUDED.case_number, parcel_id=EXCLUDED.parcel_id, original_opening_bid=EXCLUDED.original_opening_bid,
  date_original_sale=EXCLUDED.date_original_sale, published_escheat_date=EXCLUDED.published_escheat_date,
  county_contact_name=EXCLUDED.county_contact_name, county_contact_phone=EXCLUDED.county_contact_phone,
  source_url=EXCLUDED.source_url, loaded_at=EXCLUDED.loaded_at;

-- ---- per-county field dictionary ----
INSERT INTO lands_available_field_map (co_no, canonical_field, source_label, is_published, note) VALUES
 (74,'certificate_number','Certificate #',true,NULL),
 (74,'parcel_id','Parcel',true,'12-digit; trailing check-digit can differ from the assessment roll'),
 (74,'date_original_sale','Date of original sale',true,'escheat anchor'),
 (74,'date_available_public','Date available to public',true,NULL),
 (74,'original_opening_bid','Original opening bid',true,'a FLOOR, not a price'),
 (74,'estimated_purchase_price',NULL,false,'Volusia does not publish an estimate'),
 (74,'published_escheat_date',NULL,false,'Volusia does not publish; computed + caveated downstream'),
 (74,'owner_name',NULL,false,NULL),(74,'legal_description',NULL,false,NULL),(74,'case_number',NULL,false,NULL),
 (74,'county_contact_phone','Volusia Tax Deed Dept',true,'(386) 736-5919'),
 (64,'certificate_number','T.D. number',true,NULL),
 (64,'parcel_id','Parcel Number',true,'dashed AA-BB-CC-DDDD-EEEE-FFFF'),
 (64,'owner_name','Owner',true,NULL),
 (64,'legal_description','Legal',true,NULL),
 (64,'date_original_sale','Auction date',true,'escheat anchor'),
 (64,'date_available_public','Available for Purchase',true,'90 days after auction'),
 (64,'estimated_purchase_price','Estimated Purchase Price',true,'clerk ESTIMATE of total, still not final — NOT an opening bid'),
 (64,'original_opening_bid',NULL,false,'Putnam publishes an estimate, not an opening bid'),
 (64,'published_escheat_date',NULL,false,'Putnam does not publish; computed + caveated downstream'),
 (64,'case_number',NULL,false,NULL),
 (64,'county_contact_phone',NULL,false,'not on the register; routes to Tax Collector / Tax Deed office'),
 (41,'certificate_number','Certificate Number',true,'published as "N of YYYY"; stored N-YYYY'),
 (41,'case_number','Case #',true,NULL),
 (41,'parcel_id','Parcel ID',true,NULL),
 (41,'original_opening_bid','Opening Bid',true,'a FLOOR; page warns it is NO LONGER the opening bid — contact Tax Collector'),
 (41,'date_original_sale','Sale Date',true,'escheat anchor'),
 (41,'published_escheat_date','Escheatment Date',true,'PUBLISHED by the county = ground truth for the escheat model'),
 (41,'date_available_public',NULL,false,NULL),
 (41,'estimated_purchase_price',NULL,false,NULL),
 (41,'owner_name',NULL,false,NULL),(41,'legal_description',NULL,false,NULL),
 (41,'county_contact_phone','Indian River Tax Collector',true,'772-226-1338')
ON CONFLICT (co_no, canonical_field) DO UPDATE SET
  source_label=EXCLUDED.source_label, is_published=EXCLUDED.is_published, note=EXCLUDED.note;

-- ---- register the two automated sources (refresh_owner=cc; fetcher scheduling is the open infra step) ----
INSERT INTO data_source_registry
  (county_name, category, table_name, source_url, access_technique, last_count, last_successful_pull_date,
   active, pull_mode, refresh_interval_days, refresh_owner, notes)
VALUES
 ('Putnam','tax_deed','lands_available_for_taxes','https://apps.putnam-fl.com/coc/taxdeeds/public/public_LAFT.php',
  'direct_fetch',36,DATE '2026-08-09',true,'auto',7,'cc',
  'Lands Available register (co_no 64). Static page, one <div> block per record (NOT a clean table): certificate, owner, legal, parcel, auction date, available date, estimated purchase price. Fetcher script TODO — scheduling is the open infra step; until then this will read stale after 7 days (a true signal).'),
 ('Indian River','tax_deed','lands_available_for_taxes','https://indianriverclerk.com/land-available-for-taxes/',
  'direct_fetch',2,DATE '2026-08-09',true,'auto',30,'cc',
  'Land Available register (co_no 41). Static HTML table: certificate, case, parcel, opening bid, sale date, PUBLISHED escheatment date (rare — ground truth for the escheat model). Fetcher script TODO — scheduling is the open infra step.');
