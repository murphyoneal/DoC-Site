
-- ============================================================
-- Department of Construction — Extended Supabase Schema v1.1
-- Generated: 2026-06-23
-- Additions from multi-state import:
--   phone, bond_amount, bond_company, bond_expiry, bond_status,
--   workers_comp_on_file, workers_comp_company, workers_comp_policy,
--   workers_comp_expiry, insurance_company, insurance_expiry,
--   ubi_number, rmi_name, license_endorsement, complaint_count,
--   personnel_names, classifications, county_name,
--   source_state, profile_score, profile_tier_label
-- ============================================================

create extension if not exists "uuid-ossp";
create extension if not exists "pg_trgm";  -- for fuzzy name search

-- ── MAIN CONTRACTORS TABLE ─────────────────────────────────────────────────

create table if not exists contractors (
  id                    uuid primary key default uuid_generate_v4(),
  slug                  text unique not null,

  -- Identity
  business_name         text not null,
  trading_name          text,
  display_name          text not null,

  -- Trade classification
  trade_code            text,
  trade_label           text,
  doc_category          text,
  service_categories    text[] default '{}',
  classifications       text[] default '{}',  -- CA multi-classification

  -- Licence
  license_number        text,
  license_status        text default 'unknown',
  primary_status        text,
  secondary_status      text,
  original_date         text,
  effective_date        text,
  expiry_date           text,

  -- Contact (state-provided where available, self-completed on claim)
  phone                 text,
  email                 text,
  website               text,

  -- Address
  address_line_1        text,
  address_line_2        text,
  city                  text,
  state                 text,
  zip_code              text,
  county_code           text,
  county_name           text,   -- OR provides directly
  country               text default 'US',

  -- Geographic (Phase 2)
  market_id             uuid,
  service_radius_km     integer,
  service_lat           decimal(10,7),
  service_lng           decimal(10,7),
  in_volusia            boolean default false,

  -- Bond data (CA, WA, OR)
  bond_amount           integer,           -- dollars e.g. 25000
  bond_company          text,
  bond_expiry           text,
  bond_status           text,              -- WA: active/suspended/lapsed

  -- Workers comp / insurance (CA, WA, OR)
  workers_comp_on_file  boolean,
  workers_comp_company  text,
  workers_comp_policy   text,
  workers_comp_expiry   text,
  insurance_company     text,              -- OR general liability carrier
  insurance_expiry      text,

  -- State-specific identifiers
  ubi_number            text,              -- WA Unified Business Identifier
  rmi_name              text,              -- OR Responsible Managing Individual
  license_endorsement   text,              -- OR: residential/commercial/both

  -- Personnel and compliance
  personnel_names       text[] default '{}',  -- CA associated people
  complaint_count       integer,           -- CA disciplinary actions

  -- Platform tier
  tier                  text default 'public',
  verified              boolean default false,
  verified_at           timestamptz,
  claimed               boolean default false,
  claimed_at            timestamptz,
  active                boolean default true,
  platform_agreement    boolean default false,
  platform_agreed_at    timestamptz,
  profile_score         integer default 0,
  profile_tier_label    text default 'Listed',

  -- Contact (self-completed)
  description           text,
  years_in_business     integer,
  employee_count        text,
  abn_ein               text,
  certifications        text[] default '{}',
  specialist_notes      text,

  -- Media
  profile_photo         text,
  work_photos           text[] default '{}',
  logo_url              text,

  -- Specialist capability flags
  ada_compliant_work        boolean default false,
  aging_in_place            boolean default false,
  chemical_sensitivity_aware boolean default false,
  mobility_accessible_worksite boolean default false,
  hurricane_hardening        boolean default false,
  impact_window_certified    boolean default false,
  roof_certification         boolean default false,
  storm_restoration          boolean default false,
  emergency_available        boolean default false,
  emergency_response_hours   text,
  emergency_plumbing         boolean default false,
  emergency_roofing          boolean default false,
  emergency_electrical       boolean default false,
  emergency_storm_damage     boolean default false,
  emergency_water_damage     boolean default false,
  emergency_board_up         boolean default false,

  -- NZ fields
  lbp_number            text,
  lbp_classes           text[] default '{}',
  lbp_status            text,
  lbp_expiry            date,
  disciplinary_history  boolean default false,

  -- QR
  qr_code_url           text,

  -- Verification docs (private - RLS)
  insurance_cert_url    text,
  insurance_expiry_doc  date,

  -- Ratings (Phase 2 - deferred)
  -- rating_avg         decimal(3,2),
  -- rating_count       integer default 0,

  -- Source
  source                text,
  source_url            text,
  source_state          text,

  -- Timestamps
  created_at            timestamptz default now(),
  updated_at            timestamptz default now()
);

-- ── INDEXES ────────────────────────────────────────────────────────────────

create index if not exists idx_con_city          on contractors(city);
create index if not exists idx_con_state         on contractors(state);
create index if not exists idx_con_zip           on contractors(zip_code);
create index if not exists idx_con_doc_cat       on contractors(doc_category);
create index if not exists idx_con_tier          on contractors(tier);
create index if not exists idx_con_active        on contractors(active);
create index if not exists idx_con_license       on contractors(license_number);
create index if not exists idx_con_slug          on contractors(slug);
create index if not exists idx_con_source_state  on contractors(source_state);
create index if not exists idx_con_volusia       on contractors(in_volusia);
create index if not exists idx_con_emergency     on contractors(emergency_available);
create index if not exists idx_con_aging         on contractors(aging_in_place);
create index if not exists idx_con_hurricane     on contractors(hurricane_hardening);
create index if not exists idx_con_ada           on contractors(ada_compliant_work);
create index if not exists idx_con_bond          on contractors(bond_amount);
create index if not exists idx_con_ubi           on contractors(ubi_number);
create index if not exists idx_con_county        on contractors(county_name);

-- Full text search
create index if not exists idx_con_fts on contractors
  using gin(to_tsvector('english',
    coalesce(display_name,'') || ' ' ||
    coalesce(trade_label,'') || ' ' ||
    coalesce(city,'') || ' ' ||
    coalesce(state,'') || ' ' ||
    coalesce(county_name,'') || ' ' ||
    coalesce(description,'')
  ));

-- Trigram index for fuzzy business name search
create index if not exists idx_con_name_trgm on contractors
  using gin(display_name gin_trgm_ops);

-- ── ROW LEVEL SECURITY ─────────────────────────────────────────────────────

alter table contractors enable row level security;

create policy "Public read" on contractors for select using (true);

create policy "Contractor update own" on contractors for update
  using (auth.uid()::text = id::text);

-- ── MARKETS TABLE ──────────────────────────────────────────────────────────

create table if not exists markets (
  id            uuid primary key default uuid_generate_v4(),
  slug          text unique not null,
  name          text not null,
  short_name    text not null,
  level         text not null,   -- national/state/county/community
  parent_id     uuid references markets(id),
  state_code    text,
  county_code   text,
  zip_codes     text[] default '{}',
  seo_title     text,
  seo_description text,
  hero_headline text,
  active        boolean default true,
  launched_at   date,
  created_at    timestamptz default now()
);

-- Seed initial markets
insert into markets (slug, name, short_name, level, state_code, county_code, active) values
  ('us',                          'Department of Construction',                    'National',       'national',   null,  null,  true),
  ('florida',                     'Florida Department of Construction',             'Florida',        'state',      'FL',  null,  true),
  ('florida/volusia',             'Volusia County Department of Construction',      'Volusia County', 'county',     'FL',  '64',  true),
  ('florida/volusia/spruce-creek','Spruce Creek Contractor Register',               'Spruce Creek',   'community',  'FL',  '64',  true),
  ('california',                  'California Department of Construction',          'California',     'state',      'CA',  null,  true),
  ('washington',                  'Washington Department of Construction',          'Washington',     'state',      'WA',  null,  true),
  ('oregon',                      'Oregon Department of Construction',              'Oregon',         'state',      'OR',  null,  true),
  ('new-zealand',                 'New Zealand — Licensed Building Practitioners',  'New Zealand',    'state',      'NZ',  null,  false)
on conflict (slug) do nothing;

-- ── DBPR SYNC LOG ──────────────────────────────────────────────────────────

create table if not exists import_log (
  id                  uuid primary key default uuid_generate_v4(),
  import_date         timestamptz default now(),
  source              text not null,
  source_state        text,
  records_parsed      integer,
  records_inserted    integer,
  records_updated     integer,
  records_skipped     integer,
  records_deactivated integer,
  status              text default 'completed',
  notes               text
);

-- ── SERVICE CATEGORIES ─────────────────────────────────────────────────────

create table if not exists service_categories (
  id          uuid primary key default uuid_generate_v4(),
  code        text unique not null,
  label       text not null,
  sort_order  integer default 0,
  active      boolean default true
);

insert into service_categories (code, label, sort_order) values
  ('general_contractor','General Contractor',1),('roofing','Roofing',2),
  ('plumbing','Plumbing',3),('hvac','Air Conditioning / HVAC',4),
  ('electrical','Electrical',5),('pool_spa','Swimming Pool / Spa',6),
  ('solar','Solar',7),('fire_protection','Fire Protection',8),
  ('mechanical','Mechanical',9),('commercial_contractor','Commercial Contractor',10),
  ('residential_contractor','Residential Contractor',11),
  ('underground_utility','Underground Utility',12),('painting','Painting',13),
  ('flooring','Flooring',14),('tiling','Tiling',15),('landscaping','Landscaping',16),
  ('lawn_care','Lawn Care',17),('pressure_washing','Pressure Washing',18),
  ('pest_control','Pest Control',19),('handyman','Handyman Services',20),
  ('windows_doors','Windows and Doors',21),('kitchen_renovation','Kitchen Renovation',22),
  ('bathroom_renovation','Bathroom Renovation',23),
  ('decking_pergolas','Decking and Pergolas',24),('fencing','Fencing',25),
  ('general_engineering','General Engineering',26),('masonry','Masonry',27),
  ('glazing','Glazing',28),('insulation','Insulation',29),('welding','Welding',30),
  ('qualifier_business','Qualifier / Business',99)
on conflict (code) do nothing;

-- ── CONSTRUCTION FLAWS (NZ) ────────────────────────────────────────────────

create table if not exists construction_flaws (
  id               uuid primary key default uuid_generate_v4(),
  address_line_1   text,
  suburb           text,
  city             text,
  region           text,
  country          text default 'NZ',
  flaw_category    text,
  flaw_description text,
  severity         text,
  build_year       integer,
  cladding_type    text,
  source_type      text,
  source_reference text,
  remediated       boolean default false,
  remediation_date date,
  verified         boolean default false,
  address_public   boolean default false,
  created_at       timestamptz default now(),
  updated_at       timestamptz default now()
);

-- ============================================================
-- END SCHEMA v1.1
-- ============================================================
