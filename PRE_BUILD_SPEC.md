# Department of Construction — Pre-Build Specification
# Read alongside CLAUDE.md before starting any build session

---

## REVENUE MODEL — FINALISED

### Contractor tiers (three levels)

**Tier 1: Listed (FREE — always)**
Source: DBPR and other government registries, self-registration
What they get:
- Listed in public directory
- Basic profile: name, trade, city, licence number, status
- Screen-resolution QR card (auto-generated, on profile page)
- Google-indexed profile page
- Permitting authority links
No payment. No expiry. No registration required.
DoC value: Dataset + SEO footprint + marketing list

**Tier 2: Enhanced (PAID — one-off or annual)**
Requires: Profile claim + licence verification
What they get:
- Verified badge
- Logo upload
- Up to 20 work photos and project files
- Specialist capability flags (ADA, aging-in-place, hurricane etc.)
- Priority position in search results and map
- Hi-res print-ready QR card download
- Full contact details visible to homeowners
Pricing TBD: ~$49-99/year or ~$19 one-off
Status: BUILD SCHEMA NOW, activate payment Phase 2

**Tier 3: RFQ Member (PAID — per-bid or subscription)**
Requires: Enhanced profile + platform agreement signed
What they get:
- Access to RFQ feed in purchased geographic radius
- Bid on homeowner job requests
- Pre-scoped, pre-documented client briefs
- Post-project debrief participation
Pricing TBD: ~$9.99 per RFQ or ~$49-149/month subscription
Status: SCHEMA ONLY — no UI, no activation until Phase 2

### The contractor database as marketing list
Every contractor record = warm lead for RFQ system launch.
Known: trade, city, licence status, whether claimed profile.
Marketing sequence when RFQ goes live:
1. Email all claimed + verified contractors in a market first
2. Email all claimed (unverified) contractors second  
3. Email all unclaimed contractors last (less engaged)
Supabase email field + Resend = the marketing pipeline.

### Government registry polling schedule
Monthly (1st of month, 03:00 UTC) — not weekly at this stage.
Weekly is Phase 2 when verified contractors are paying customers.
Sources:
- FL DBPR: myfloridalicense.com/sto/file_download/extracts/CONSTRUCTIONLICENSE_1.csv
- CA CSLB: cslb.ca.gov (manual download until API confirmed)
- WA L&I: data.wa.gov (Socrata API — automated)
- OR CCB: data.oregon.gov (Socrata API — automated)
Sync log: import_log table records every run.

---

## COMPLETE DATABASE SCHEMA — ALL TABLES

### Table 1: contractors (existing — v1.1)
See CLAUDE.md for full field list.
New fields to add:
- subscription_tier text default 'listed'  -- listed/enhanced/member
- subscription_status text                 -- null/active/expired/cancelled
- subscription_started_at timestamptz
- subscription_expires_at timestamptz
- stripe_customer_id text                  -- Phase 2
- stripe_subscription_id text              -- Phase 2
- marketing_email_consent boolean default true
- last_marketed_at timestamptz
- onboarding_email_sent boolean default false

### Table 2: markets (existing)
No changes.

### Table 3: permitting_authorities (existing)
No changes.

### Table 4: market_permitting_authorities (existing)
No changes.

### Table 5: service_categories (existing)
No changes.

### Table 6: import_log (existing)
No changes.

### Table 7: construction_flaws (existing — NZ)
No changes.

### Table 8: properties (new — Phase 1)
See CLAUDE.md for full field list.

### Table 9: contractor_subscriptions (new — Phase 2 ready)
-- Build table now, activate when RFQ goes live
create table if not exists contractor_subscriptions (
  id                    uuid primary key default uuid_generate_v4(),
  contractor_id         uuid references contractors(id) on delete cascade,
  tier                  text not null,  -- enhanced/member
  billing_type          text,           -- one_off/monthly/annual
  status                text default 'inactive',  -- inactive/active/expired/cancelled
  amount_cents          integer,
  currency              text default 'USD',
  stripe_customer_id    text,
  stripe_subscription_id text,
  stripe_payment_intent text,
  started_at            timestamptz,
  expires_at            timestamptz,
  cancelled_at          timestamptz,
  created_at            timestamptz default now()
);

### Table 10: rfq_access_purchases (new — Phase 2 ready)
-- Per-RFQ purchase tracking
create table if not exists rfq_access_purchases (
  id              uuid primary key default uuid_generate_v4(),
  contractor_id   uuid references contractors(id),
  rfq_id          uuid,               -- references rfqs(id) when that table exists
  amount_cents    integer,
  currency        text default 'USD',
  stripe_payment_intent text,
  status          text default 'pending',  -- pending/paid/refunded
  created_at      timestamptz default now()
);

### Table 11: completed_works (new — Phase 2 ready)
-- Records of contractor work at properties
-- Populated from post-project debrief data
create table if not exists completed_works (
  id                uuid primary key default uuid_generate_v4(),
  contractor_id     uuid references contractors(id),
  property_id       uuid references properties(id),
  trade_category    text,
  work_description  text,
  work_date         date,
  permit_number     text,
  permit_authority_id uuid references permitting_authorities(id),
  materials_used    text[],
  before_photos     text[],
  after_photos      text[],
  -- Post-project debrief outcomes
  homeowner_rating  integer,           -- 1-5, Phase 2
  contractor_rating integer,           -- 1-5, Phase 2
  scope_changed     boolean,
  price_as_quoted   boolean,
  timeline_met      boolean,
  -- Status
  verified          boolean default false,
  source            text,              -- self_reported/debrief/permit_data
  created_at        timestamptz default now()
);

### Table 12: rfqs (new — Phase 2 skeleton only)
-- Just the structure — no UI built until Phase 2
create table if not exists rfqs (
  id                uuid primary key default uuid_generate_v4(),
  property_id       uuid references properties(id),
  homeowner_id      uuid,             -- references auth.users
  trade_category    text not null,
  title             text,
  description       text,
  scope_notes       text,
  urgency_level     integer,          -- 1-5
  budget_stated     integer,
  status            text default 'draft',  -- draft/open/awarded/completed/cancelled
  -- Privacy
  address_revealed  boolean default false,
  -- Geographic
  lat               decimal(10,7),
  lng               decimal(10,7),
  -- RFQ data
  photos            text[],
  ldar_model_url    text,
  aerial_data       jsonb,
  -- Timestamps
  published_at      timestamptz,
  awarded_at        timestamptz,
  completed_at      timestamptz,
  created_at        timestamptz default now(),
  updated_at        timestamptz default now()
);

### Table 13: bids (new — Phase 2 skeleton only)
create table if not exists bids (
  id              uuid primary key default uuid_generate_v4(),
  rfq_id          uuid references rfqs(id),
  contractor_id   uuid references contractors(id),
  amount_cents    integer,
  currency        text default 'USD',
  timeline_days   integer,
  notes           text,
  status          text default 'submitted',  -- submitted/viewed/accepted/declined/withdrawn
  viewed_at       timestamptz,
  accepted_at     timestamptz,
  created_at      timestamptz default now()
);

### Table 14: post_project_debriefs (new — Phase 2 skeleton)
create table if not exists post_project_debriefs (
  id                    uuid primary key default uuid_generate_v4(),
  completed_work_id     uuid references completed_works(id),
  respondent_type       text,           -- homeowner/contractor
  -- Homeowner responses
  scope_changed         boolean,
  price_changed         boolean,
  price_change_reason   text,
  timeline_met          boolean,
  communication_good    boolean,
  would_use_again       boolean,
  neighbour_recommend   text,
  -- Contractor responses
  brief_accurate        boolean,
  client_changed_scope  boolean,
  decisions_on_time     boolean,
  payment_on_time       boolean,
  easier_with           text,
  would_take_again      boolean,
  -- AI structured output
  ai_summary            text,
  sentiment_score       decimal,
  flags                 text[],
  created_at            timestamptz default now()
);

### Table 15: honeypot_records (new — admin only, private)
-- Fake contractor records to detect scrapers
-- Never shown in public search results
create table if not exists honeypot_records (
  id            uuid primary key default uuid_generate_v4(),
  slug          text unique not null,
  business_name text not null,
  trade_code    text,
  city          text,
  state         text,
  fake_license  text,
  active        boolean default true,
  created_at    timestamptz default now()
);
-- RLS: no public access at all
alter table honeypot_records enable row level security;
create policy "Admin only" on honeypot_records
  for all using (auth.jwt() ->> 'role' = 'admin');

### Table 16: claim_requests (new)
create table if not exists claim_requests (
  id              uuid primary key default uuid_generate_v4(),
  contractor_id   uuid references contractors(id),
  requester_name  text not null,
  requester_email text not null,
  requester_phone text,
  license_number  text,
  message         text,
  status          text default 'pending',  -- pending/approved/rejected
  reviewed_at     timestamptz,
  created_at      timestamptz default now()
);

### Table 17: emergency_contacts (new — DoA Protect, Phase 3)
create table if not exists emergency_contacts (
  id              uuid primary key default uuid_generate_v4(),
  property_id     uuid references properties(id),
  name            text not null,
  relationship    text,               -- spouse/child/neighbour/carer
  phone           text not null,
  email           text,
  notify_sms      boolean default true,
  notify_email    boolean default true,
  priority_order  integer default 1,
  active          boolean default true,
  created_at      timestamptz default now()
);

### Table 18: alert_events (new — DoA Protect, Phase 3)
create table if not exists alert_events (
  id              uuid primary key default uuid_generate_v4(),
  property_id     uuid references properties(id),
  alert_type      text,  -- fall/inactivity/no_movement/breathing_anomaly/manual
  severity        text,  -- low/medium/high/critical
  detected_at     timestamptz not null,
  -- Notification chain
  sms_sent        boolean default false,
  sms_sent_at     timestamptz,
  email_sent      boolean default false,
  email_sent_at   timestamptz,
  -- Resolution
  resolved        boolean default false,
  resolved_at     timestamptz,
  resolution_note text,
  false_alarm     boolean,
  -- RuView data
  ruview_data     jsonb,
  created_at      timestamptz default now()
);

### Table 19: ambassadors (new — Phase 3)
create table if not exists ambassadors (
  id                uuid primary key default uuid_generate_v4(),
  name              text not null,
  email             text not null,
  phone             text,
  -- Territory
  market_id         uuid references markets(id),
  territory_notes   text,
  -- Revenue share
  revenue_share_pct decimal,          -- e.g. 15.00 for 15%
  vesting_started   date,
  vesting_cliff_months integer default 6,
  -- Status
  status            text default 'active',  -- active/suspended/terminated
  badge_issued      boolean default false,
  platform_agreement boolean default false,
  -- Performance
  contractors_onboarded integer default 0,
  properties_registered integer default 0,
  created_at        timestamptz default now()
);

---

## COMMUNICATIONS ARCHITECTURE

### Inbound triggers → Murphy notification
| Event | Channel | Priority |
|-------|---------|----------|
| New claim request | Email + Resend | High |
| Claim pending >48h | Email reminder | Medium |
| Verification docs submitted | Email | High |
| New self-registration | Email digest (daily) | Low |
| DBPR sync completed | Email summary | Low |
| DBPR sync found expired verified contractor | Email | High |
| New DoA walk-through completed | Email | Medium |
| New property claimed | Email digest | Low |

### Outbound to contractors
| Trigger | What we send | What we DON'T send |
|---------|-------------|-------------------|
| Registration complete | Welcome + profile link + QR card | Scan analytics |
| Claim approved | Confirmation + hi-res QR download | View counts |
| Verification approved | Verified badge + next steps | Search ranking |
| Trial expiry -7 days | Reminder (Phase 2) | Competitor data |
| Trial expired | Expired notice + upgrade CTA | — |
| Monthly digest (Phase 2) | RFQ opportunities in their area | — |

IMPORTANT: Never send contractors their scan/view analytics.
That data belongs to DoC. Contractors get their profile URL and QR only.

### Outbound to homeowners (Phase 2)
| Trigger | What we send |
|---------|-------------|
| DoA walk-through complete | Session summary PDF |
| Property claimed | Confirmation + DoA next steps |
| Bid received on RFQ | Notification (no contractor details yet) |
| Bid accepted | Full contractor details revealed |
| DoA subscription renewal | Renewal reminder -30 days |

### DoA Protect alert chain (Phase 3)
1. RuView detects event → logs to alert_events table
2. Severity assessment (automated)
3. High/critical: SMS to emergency_contacts priority 1 immediately
4. If no response in 15 minutes: SMS to priority 2
5. All severity: Email to all emergency_contacts
6. Critical only: In-app prompt to call 911
7. All events logged with resolution outcome

---

## SITE PAGES — BUILD ORDER

### Phase 1 — DoC contractor register

Priority 1 (build first):
/ — homepage = Mapbox map, geolocation, trade filter chips
/c/[slug] — contractor profile page
/florida — Florida state market page
/florida/volusia — Volusia County market page
/florida/volusia/spruce-creek — Spruce Creek community page
/disclaimer — full disclaimer page
/api/contractors — bounding box query (scraping protected)
/api/qr/[slug] — QR card generation + download
/c/[slug]/track — tracking redirect (fires analytics, then redirects)

Priority 2 (build second):
/claim/[slug] — claim flow (verify licence → complete profile)
/register — self-registration form
/api/claim — claim request handler
/california — CA market page
/washington — WA market page
/oregon — OR market page

Priority 3 (before launch):
/about — what is DoC
/for-contractors — contractor value proposition page
/privacy — privacy policy
/terms — terms of service
/sitemap.xml — auto-generated from contractor + market records

### Phase 2 — DoP/DoA (separate build session)
/doa — Department of Assurance landing
/doa/register — DoA walk-through signup
/property/[id] — property record page
/api/doa/walthrough — AI chatbot endpoint
/api/properties — bounding box query

---

## SCRAPING PROTECTION — IMPLEMENTATION CHECKLIST

Before going live, confirm ALL of these are in place:

[ ] Cloudflare rate limiting: 60 req/min per IP on /api/ routes
[ ] Cloudflare Bot Fight Mode: enabled
[ ] robots.txt: Disallow /api/
[ ] Next.js middleware: validates bounding box on every /api/contractors request
[ ] Max 50 records per bounding box query — enforced server-side
[ ] No paginated list endpoint exists
[ ] Supabase anon key: NOT in any client component
[ ] Supabase service key: only in server-side API routes
[ ] Honeypot records: 100 seeded before launch
[ ] Honeypot link: hidden in HTML, logs and bans IP on access
[ ] ToS: explicit scraping prohibition clause
[ ] Cloudflare Turnstile: on claim form and registration form
[ ] API response: never returns full contractor dataset fields (only map fields)

---

## SEO STRATEGY

### Page title patterns:
/ → "Find Licensed Contractors Near You | Department of Construction"
/c/[slug] → "[Business Name] — [Trade] in [City], [State] | DoC"
/[state] → "Licensed Contractors in [State] | [State] Department of Construction"
/[state]/[county] → "[County] County Licensed Contractors | Department of Construction"

### Structured data (JSON-LD) on every contractor profile:
- LocalBusiness schema
- Licence number as identifier
- Service area
- Trade category

### Sitemap priority:
- Verified contractor profiles: 0.8
- County market pages: 0.9
- State market pages: 0.7
- Unclaimed profiles: 0.5

---

## WHAT CLAUDE CODE BUILDS IN SESSION 1

Session 1 scope — DoC MVP:
1. Next.js scaffold with Tailwind + DoC brand colours
2. Supabase client setup (server-side only)
3. Prisma schema matching all tables above
4. Homepage with Mapbox map + geolocation + trade filter
5. /api/contractors bounding box endpoint (rate limited)
6. Contractor profile page /c/[slug]
7. Florida, Volusia, Spruce Creek market pages
8. QR card generation endpoint /api/qr/[slug]
9. Tracking redirect /c/[slug]/track
10. Disclaimer page
11. Seed 100 honeypot records
12. robots.txt + basic sitemap

Session 1 does NOT build:
- Claim flow (Session 2)
- Registration form (Session 2)
- Payment (Phase 2)
- DoA (separate project)

---

## BRAND CSS VARIABLES

```css
:root {
  --color-ink:    #1C1C1C;
  --color-bronze: #8B6F47;
  --color-sage:   #6B7F6B;
  --color-cream:  #FAF7F2;
  --color-navy:   #1B2A4A;
  --color-gold:   #C9A84C;
  --color-white:  #FFFFFF;
  --color-light-gray: #F0EDEA;
}
```

Tailwind config additions:
```js
colors: {
  ink:    '#1C1C1C',
  bronze: '#8B6F47',
  sage:   '#6B7F6B',
  cream:  '#FAF7F2',
  navy:   '#1B2A4A',
  gold:   '#C9A84C',
}
```

---

## FINAL PRE-BUILD CHECKLIST

[ ] Supabase project created
[ ] Supabase schema SQL run (v1.1 + additions above)
[ ] Volusia contractor JSON imported (DoC_Volusia_v1.1.json)
[ ] Mapbox account created and token obtained
[ ] Vercel project connected to GitHub repo
[ ] Cloudflare DNS pointing departmentofconstruction.com to Vercel
[ ] Resend account + domain verified
[ ] .env.local populated with all keys
[ ] CLAUDE.md in project root
[ ] This file (PRE_BUILD_SPEC.md) in project root
[ ] Honeypot records seeded (100 records)
[ ] Volusia permitting authorities seeded

When all boxes checked: start Session 1 build.
