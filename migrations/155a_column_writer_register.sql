-- 155a: column_writer - who may write a VALUE into each column (rulings 739, 742).
--
-- A second axis, deliberately separate from column_default_authorship. That table answers "what may a
-- DEFAULT assert, about whom" and covers exactly the columns with literal defaults (217 + 20
-- deliberate no-default registrations). This one answers "who is the author of the value", and it
-- must be COMPLETE over a table before any guard is built on it, because the columns holding a
-- business's own words mostly have no default and so never entered the defaults register.
--
--   subject  - the subject's own statement. Only the sanctioned save path writes a value; a migration
--              may clear it to NULL, never set one (153a's backfill of coverage_scope is the case).
--   register - reproduced from a source by a loader.
--   derived  - OUR computation about the subject. It looks exactly like a fact on a page, so every
--              derived row records its inputs and its rule, and it never renders as a bare fact.
--   ours     - our own state: keys, switches, review decisions, timestamps.
--
-- Scope now: the five self-declared tables, all 91 columns. Found while classifying:
--   - registered_business.country_iso is written as the literal 'US' by self_register; the registrant
--     never sends it. derived (from state_geo_id), not subject.
--   - registered_credential.profession is never stated by the registrant: /api/register derives it
--     from the declared trade, and registration_check_credential overrides it to 'electrical' for a
--     Florida E[CRF] licence number; self_register stores the CHECK's value (c || ck). derived.
--     0 rows today and nothing reads it, so no exposure.
-- Deliberately NOT here: attestation_register.disputes_finding (ruling 742: no identifiable author,
-- so it cannot be classified; asserted unreachable instead). The trigger and the detection that use
-- this register wait until the sites are live (ruling 742).

create table public.column_writer (
  table_name         text not null,
  column_name        text not null,
  writer_class       text not null check (writer_class in ('subject', 'register', 'derived', 'ours')),
  sanctioned_writers text[],
  derived_inputs     text[],
  derived_rule       text,
  reason             text not null,
  classified_by      text not null,
  classified_on      date not null default current_date,
  primary key (table_name, column_name),
  constraint column_writer_subject_has_writer check (writer_class <> 'subject' or cardinality(sanctioned_writers) > 0),
  constraint column_writer_derived_is_explained check (writer_class <> 'derived' or (cardinality(derived_inputs) > 0 and derived_rule is not null))
);
alter table public.column_writer enable row level security;
comment on table public.column_writer is
  'Write authority per column: subject (only the subject''s own save writes a value; a migration may only clear it) / register (a loader reproduces a source) / derived (our computation - records inputs and rule, never renders as a bare fact) / ours. Separate axis from column_default_authorship, which covers only what a DEFAULT may assert. Complete over business_profile, agent_public_profile, business_declared_insurance, registered_business, registered_credential (155a, rulings 739/742).';

insert into public.column_writer (table_name, column_name, writer_class, sanctioned_writers, derived_inputs, derived_rule, reason, classified_by) values
-- business_profile: 11 subject, 13 ours
('business_profile','public_phone','subject','{business_profile_save}',null,null,'the business''s own public phone','cc'),
('business_profile','public_email','subject','{business_profile_save}',null,null,'the business''s own public email','cc'),
('business_profile','website','subject','{business_profile_save}',null,null,'the business''s own website','cc'),
('business_profile','description','subject','{business_profile_save}',null,null,'the business''s own description','cc'),
('business_profile','specialties','subject','{business_profile_save}',null,null,'services the business says it offers','cc'),
('business_profile','other_specialties','subject','{business_profile_save}',null,null,'free-text services the business says it offers','cc'),
('business_profile','counties_worked','subject','{business_profile_save}',null,null,'counties the business listed; stored as sent, published only under coverage_scope=counties (153b)','cc'),
('business_profile','years_in_business','subject','{business_profile_save}',null,null,'the business''s own statement','cc'),
('business_profile','coverage_scope','subject','{business_profile_save}',null,null,'where the business says it works; NULL until chosen, never inferred (733, 153b)','cc'),
('business_profile','coverage_state_geo_id','subject','{business_profile_save}',null,null,'the state chosen with statewide coverage','cc'),
('business_profile','logo_path','subject','{business_logo_set}',null,null,'present only because the business uploaded a logo; the path string is ours, its existence is their act','cc'),
('business_profile','business_id','ours',null,null,null,'key','cc'),
('business_profile','publish_phone','ours',null,null,null,'publish switch - our state, default off','cc'),
('business_profile','publish_email','ours',null,null,null,'publish switch','cc'),
('business_profile','publish_website','ours',null,null,null,'publish switch','cc'),
('business_profile','publish_description','ours',null,null,null,'publish switch','cc'),
('business_profile','publish_specialties','ours',null,null,null,'publish switch','cc'),
('business_profile','publish_counties','ours',null,null,null,'publish switch (superseded by publish_coverage, kept in lockstep)','cc'),
('business_profile','publish_years','ours',null,null,null,'publish switch','cc'),
('business_profile','publish_coverage','ours',null,null,null,'publish switch','cc'),
('business_profile','publish_logo','ours',null,null,null,'publish switch','cc'),
('business_profile','updated_by','ours',null,null,null,'audit: who saved','cc'),
('business_profile','updated_at','ours',null,null,null,'audit: when saved','cc'),
('business_profile','logo_updated_at','ours',null,null,null,'audit: when the logo changed','cc'),
-- agent_public_profile: 7 subject, 11 ours
('agent_public_profile','public_phone','subject','{agent_profile_save}',null,null,'the agent''s own public phone','cc'),
('agent_public_profile','public_email','subject','{agent_profile_save}',null,null,'the agent''s own public email','cc'),
('agent_public_profile','website','subject','{agent_profile_save}',null,null,'the agent''s own website','cc'),
('agent_public_profile','bio','subject','{agent_profile_save}',null,null,'the agent''s own words','cc'),
('agent_public_profile','counties_served','subject','{agent_profile_save}',null,null,'counties the agent says they serve','cc'),
('agent_public_profile','property_classes','subject','{agent_profile_save}',null,null,'property classes the agent says they work','cc'),
('agent_public_profile','declared_brokerage','subject','{agent_profile_save}',null,null,'brokerage as the agent states it - not the register''s','cc'),
('agent_public_profile','license_number','ours',null,null,null,'key: the licence the approved claim is for; written by review_agent_claim','cc'),
('agent_public_profile','slug','ours',null,null,null,'key: our URL','cc'),
('agent_public_profile','publish_phone','ours',null,null,null,'publish switch','cc'),
('agent_public_profile','publish_email','ours',null,null,null,'publish switch','cc'),
('agent_public_profile','publish_website','ours',null,null,null,'publish switch','cc'),
('agent_public_profile','publish_bio','ours',null,null,null,'publish switch','cc'),
('agent_public_profile','publish_counties','ours',null,null,null,'publish switch','cc'),
('agent_public_profile','publish_classes','ours',null,null,null,'publish switch','cc'),
('agent_public_profile','publish_declared_brokerage','ours',null,null,null,'publish switch','cc'),
('agent_public_profile','updated_by','ours',null,null,null,'audit','cc'),
('agent_public_profile','updated_at','ours',null,null,null,'audit','cc'),
-- business_declared_insurance: 4 subject, 4 ours
('business_declared_insurance','kind','subject','{business_profile_save}',null,null,'the kind of cover the business declares','cc'),
('business_declared_insurance','carrier','subject','{business_profile_save}',null,null,'insurer as the business states it; stated, not verified','cc'),
('business_declared_insurance','cover_note','subject','{business_profile_save}',null,null,'the business''s own note','cc'),
('business_declared_insurance','expires_on','subject','{business_profile_save}',null,null,'expiry as the business states it','cc'),
('business_declared_insurance','id','ours',null,null,null,'key','cc'),
('business_declared_insurance','business_id','ours',null,null,null,'key','cc'),
('business_declared_insurance','publish','ours',null,null,null,'publish switch','cc'),
('business_declared_insurance','declared_at','ours',null,null,null,'audit','cc'),
-- registered_business: 11 subject, 3 derived, 10 ours
('registered_business','business_name','subject','{self_register}',null,null,'the name the registrant gives','cc'),
('registered_business','state_geo_id','subject','{self_register}',null,null,'state the registrant chooses','cc'),
('registered_business','county_geo_id','subject','{self_register}',null,null,'county the registrant chooses','cc'),
('registered_business','place_geo_id','subject','{self_register}',null,null,'place the registrant chooses (validated against geo_place_county)','cc'),
('registered_business','place_state','subject','{self_register}',null,null,'place vs unincorporated - the registrant''s choice, recorded as a state','cc'),
('registered_business','trades','subject','{self_register}',null,null,'trades the registrant declares','cc'),
('registered_business','other_services','subject','{self_register}',null,null,'free-text services','cc'),
('registered_business','contact_name','subject','{self_register}',null,null,'private contact name','cc'),
('registered_business','contact_email','subject','{self_register}',null,null,'private contact email','cc'),
('registered_business','public_phone','subject','{self_register}',null,null,'public phone the registrant offers','cc'),
('registered_business','website','subject','{self_register}',null,null,'website the registrant offers','cc'),
('registered_business','country_iso','derived',null,'{state_geo_id}','self_register writes the literal ''US''; the form accepts US admin1 states only, so the country follows from the state','NOT sent by the registrant - found while classifying; would otherwise read as their statement','cc'),
('registered_business','florida_duplicate_state','derived',null,'{business_name,registered_credential.number,contractors.license_number,businesses.display_name}','near_match_licence if a declared licence matches a DBPR row (registration_check_credential); else near_match_name on _reg_norm_name equality with a Florida business; else no_match; not_checked outside Florida with no licence match','our finding about whether the registrant duplicates a Florida licensee','cc'),
('registered_business','florida_duplicate_slugs','derived',null,'{business_name,registered_credential.number,contractors.license_number,businesses.display_name}','distinct slugs from the licence and name matches above, up to 10 name matches','the Florida entries the duplicate check pointed at','cc'),
('registered_business','id','ours',null,null,null,'key','cc'),
('registered_business','slug','ours',null,null,null,'our URL: normalised name + state + random suffix','cc'),
('registered_business','publish_listing','ours',null,null,null,'publish switch','cc'),
('registered_business','publish_city','ours',null,null,null,'publish switch','cc'),
('registered_business','publish_phone','ours',null,null,null,'publish switch','cc'),
('registered_business','publish_website','ours',null,null,null,'publish switch','cc'),
('registered_business','review_state','ours',null,null,null,'our review decision (review_registration)','cc'),
('registered_business','reviewed_at','ours',null,null,null,'audit','cc'),
('registered_business','review_note','ours',null,null,null,'our reviewer''s note','cc'),
('registered_business','created_at','ours',null,null,null,'audit','cc'),
-- registered_credential: 6 subject, 6 derived, 5 ours
('registered_credential','kind','subject','{self_register}',null,null,'licence / insurance / certification as declared','cc'),
('registered_credential','issuing_state_geo_id','subject','{self_register}',null,null,'issuing state as declared','cc'),
('registered_credential','trade','subject','{self_register}',null,null,'trade as declared','cc'),
('registered_credential','number','subject','{self_register}',null,null,'licence or policy number as declared','cc'),
('registered_credential','issuer','subject','{self_register}',null,null,'issuer as declared','cc'),
('registered_credential','expires_on','subject','{self_register}',null,null,'expiry as declared','cc'),
('registered_credential','profession','derived',null,'{trade,number,issuing_state_geo_id}','/api/register sets electrical if trade=electrical else construction; registration_check_credential overrides to electrical for a Florida E[CRF] number; self_register stores the check''s value','NEVER stated by the registrant - found while classifying; 0 rows, not read anywhere','cc'),
('registered_credential','check_state','derived',null,'{kind,issuing_state_geo_id,number,profession,register_coverage,contractors,reg_us_or.ccb_active_license}','registration_check_credential: register_not_held / register_held_no_match / register_held_matched against the held register for that state and profession','our check against a register','cc'),
('registered_credential','checked_against','derived',null,'{register_coverage.source,register_coverage.retrieved_date,register_coverage.posted_date}','the register source and its date, as used by the check','names the evidence the check used','cc'),
('registered_credential','check_note','derived',null,'{check_state,register_coverage,contractors.register_file_state,reg_us_or.ccb_active_license.register_file_state}','plain-language sentence composed by registration_check_credential from the check result','the check''s own wording','cc'),
('registered_credential','matched_contractor_id','derived',null,'{number,contractors.license_number}','_reg_norm_licence equality, latest file preferred (Florida construction only)','the DBPR row the check matched','cc'),
('registered_credential','matched_slug','derived',null,'{matched_contractor_id,business_licences,businesses.slug}','slug of the business holding the matched licence','the public entry the check matched','cc'),
('registered_credential','id','ours',null,null,null,'key','cc'),
('registered_credential','business_id','ours',null,null,null,'key','cc'),
('registered_credential','publish','ours',null,null,null,'publish switch','cc'),
('registered_credential','checked_at','ours',null,null,null,'audit','cc'),
('registered_credential','declared_at','ours',null,null,null,'audit','cc');

-- completeness: every column on the five tables has exactly one row, and nothing else is classified.
-- Read from pg_attribute, the catalog itself. (An earlier column read of attestation_register showed 6 of
-- 18 columns: that query UNIONed string_agg under a `name`-typed column, which cut it to 63 bytes.)
do $m$
declare v_missing text; v_extra text;
begin
  with cols as (
    select c.relname as table_name, a.attname as column_name
      from pg_attribute a join pg_class c on c.oid = a.attrelid
     where c.relnamespace = 'public'::regnamespace and a.attnum > 0 and not a.attisdropped
       and c.relname in ('business_profile','agent_public_profile','business_declared_insurance','registered_business','registered_credential'))
  select string_agg(table_name || '.' || column_name, ', ') into v_missing from cols k
   where not exists (select 1 from public.column_writer w where w.table_name = k.table_name and w.column_name = k.column_name);
  if v_missing is not null then raise exception '155a: unclassified: %', v_missing; end if;
  select string_agg(w.table_name || '.' || w.column_name, ', ') into v_extra
    from public.column_writer w
   where not exists (select 1 from pg_attribute a join pg_class c on c.oid = a.attrelid
                      where c.relnamespace = 'public'::regnamespace and c.relname = w.table_name
                        and a.attname = w.column_name and a.attnum > 0 and not a.attisdropped);
  if v_extra is not null then raise exception '155a: classified but not a column: %', v_extra; end if;
  if (select count(*) from public.column_writer) <> 91 then raise exception '155a: expected 91 rows'; end if;
end $m$;
