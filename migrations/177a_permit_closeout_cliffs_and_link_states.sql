-- 177a - completion dates gated on the county's own cliff, a stated licence state on every permit, and the
-- store-vs-surface count check (WO 870 items 1, 2a, 2c; rulings 867, 868; 857 step 2).
--
-- MEASURED 2026-09-30 on the served expression coalesce(COMPL_DATE, OCC_DATE) by permit year, Volusia:
--   2010 39.5  2013 50.0  2016 50.6  2017 54.1 | 2018 24.5  2019 16.2  2020 21.3  2022 24.7  2024 26.4  2026 17.6
--   A cliff at 2018. Before it, completion was recorded on only about half of permits in any year.
-- Pinellas sign_off_dt (real dates only, 1899 sentinel excluded) by issue year: never above 8.8% in any year,
--   exactly 0.0% from 2009 through 2026. It was never an established recording practice.
-- These are the only two permit stores we hold (information_schema sweep: property_permit_history is derived from
-- Volusia). Both are recorded below as data, so the next county's cliff is a row, not a code change.
--
-- Served consequence, before this: every Volusia and Pinellas permit without a completion date carried "An
-- authorized-but-unfinaled permit can be inherited by a buyer at closing" - an implication about THAT permit drawn
-- from a field the county stopped filling in (867: the Earhart generator sentence).
--
-- Licence link: 710,832 Volusia permits name a contractor and have no link state; the 170a CASE fell through to
-- NULL (silence). They now carry link_state no_match; the 89,945 that name no contractor carry not_applicable.
-- Same {link:'none', matched:false, note} shape as the existing ambiguous state, which the deployed page
-- (fact-render.mjs, report page) and Roz already render - no front-end change is required first.
-- The no_match note names the electrical board as "added but not yet checked": 3b must update it when permits
-- are checked against reg_us_fl.eclb_licence.
-- By-era sentence (866, re-measured on SERVED states): the served link is 0.1% of pre-1990 named permits, 3.7% in
-- the 1990s, 10.7% 2000s, 17.4% 2010s, 14.8% 2020-26 (11.0% overall).

create table public.permit_field_coverage (
  co_no                    numeric not null,
  source_table             text    not null,
  field                    text    not null,
  not_available_from_year  integer,          -- absence from this issue year on says nothing
  not_available_all_years  boolean not null, -- absence says nothing in any year
  basis                    text    not null check (length(basis) >= 20),
  measured_at              date    not null,
  primary key (co_no, source_table, field)
);
comment on table public.permit_field_coverage is
  'Per county permit store: the issue years in which a field''s ABSENCE carries no information, measured by year (867: a dead column kills the answer, not the question). Read by get_parcel_permit_facts.';
insert into public.permit_field_coverage values
 (74, 'volusia_cama_permits', 'completion', 2018, false,
  'coalesce(COMPL_DATE,OCC_DATE) by permit year: 54.1% in 2017, 24.5% in 2018, 16.2% in 2019, 17.6-28.7% since. Measured 2026-09-30.', date '2026-09-30'),
 (62, 'pinellas_cama_rp_permits', 'completion', null, true,
  'sign_off_dt (real dates, 1899 sentinel excluded) never above 8.8% in any issue year and 0.0% from 2009 to 2026. Measured 2026-09-30.', date '2026-09-30');
revoke all on public.permit_field_coverage from public, anon, authenticated;
grant select on public.permit_field_coverage to service_role;

do $$
declare d text; n int;
  pv text := 'ELSE jsonb_build_object\(\s+''predicate'',''permit_closeout'',''value'', NULL, ''field_status'',''not_recorded'',\s+''finaled_date'', NULL, ''source'',''volusia_cama_permits'',''source_tier'',''county_assessor_record'',\s+''disclosure'',''Closeout not on record[^'']*''\)';
  pp text := 'ELSE jsonb_build_object\(\s+''predicate'',''permit_closeout'',''value'', NULL, ''field_status'',''not_recorded'',\s+''finaled_date'', NULL,\s+''source'',''pinellas_cama_rp_permits'',''source_tier'',''county_assessor_record'',\s+''disclosure'',''Closeout not on record[^'']*''\)';
  pl text := 'ELSE NULL\s+END FROM c\)';
  pr text := 'RETURN jsonb_build_object\(''field_status'',''present'',''count'', v_cnt, ''permits'', v_permits,\s+''closeout_not_recorded_count'', v_open, ''coverage_note'', NULL\);';
begin
  d := pg_get_functiondef('public.get_parcel_permit_facts(numeric,text)'::regprocedure);
  foreach n in array array[
      (select count(*) from regexp_matches(d, pv, 'g'))::int, (select count(*) from regexp_matches(d, pp, 'g'))::int,
      (select count(*) from regexp_matches(d, pl, 'g'))::int, (select count(*) from regexp_matches(d, pr, 'g'))::int] loop
    if n <> 1 then raise exception '177a: an anchor matched % times, expected 1', n; end if;
  end loop;

  -- Volusia: post-cliff absence is not_available; pre-cliff absence is not_recorded, worded without inference
  d := regexp_replace(d, pv, $r$WHEN extract(year from c.permit_date) >= (SELECT f.not_available_from_year FROM public.permit_field_coverage f WHERE f.co_no = 74 AND f.field = 'completion') THEN jsonb_build_object(
                'predicate','permit_closeout','value', NULL, 'field_status','not_available',
                'finaled_date', NULL, 'source','volusia_cama_permits','source_tier','county_assessor_record',
                'disclosure','Completion is not available for this permit. Volusia County stopped recording a completion date on most permits from 2018 (fewer than 3 in 10 carry one), so nothing follows from its absence. To confirm sign-off, ask the building department that issued it.')
              ELSE jsonb_build_object(
                'predicate','permit_closeout','value', NULL, 'field_status','not_recorded',
                'finaled_date', NULL, 'source','volusia_cama_permits','source_tier','county_assessor_record',
                'disclosure','No completion date is recorded for this permit. Before 2018 Volusia recorded completion on only about half of permits, so this does not show the work was left unfinished. To confirm sign-off, ask the building department that issued it.')$r$);

  -- Pinellas: sign-off was never an established field, so absence is not_available in every year
  d := regexp_replace(d, pp, $r$ELSE jsonb_build_object(
                'predicate','permit_closeout','value', NULL, 'field_status','not_available',
                'finaled_date', NULL,
                'source','pinellas_cama_rp_permits','source_tier','county_assessor_record',
                'disclosure','Completion is not available for this permit. Pinellas records a sign-off date on very few permits (never more than 9% in any year, none since 2009), so nothing follows from its absence. To confirm sign-off, ask the building department that issued it.')$r$);

  -- licence link: a failed lookup is a stated state on the row, never silence
  d := regexp_replace(d, pl, $r$WHEN c.contractor IS NULL THEN jsonb_build_object(
                'predicate','contractor_name_linked_to_register', 'link','none', 'matched', false, 'link_state','not_applicable',
                'contractor_as_recorded', NULL,
                'note', 'The county recorded no contractor on this permit (an owner-builder permit, or the field was left empty), so there is nothing to check against a licence register.')
              ELSE jsonb_build_object(
                'predicate','contractor_name_linked_to_register', 'link','none', 'matched', false, 'link_state','no_match',
                'contractor_as_recorded', c.contractor,
                'note', 'The county recorded "'||c.contractor||'" as the contractor. No business of that name is in the Florida construction licence file we check permits against. Electrical and alarm contractors are licensed by a separate board whose file we have added but do not yet check permits against. These files list current licensees only'
                        ||CASE WHEN extract(year from c.permit_date) < 2000
                               THEN ', and Florida does not publish who used to be licensed, so for work this old we cannot establish whether the contractor was licensed.'
                               ELSE ', so this says nothing about whether the contractor was licensed when the work was done.' END)
            END FROM c)$r$);

  -- additive roll-up
  d := regexp_replace(d, pr, $r$RETURN jsonb_build_object('field_status','present','count', v_cnt, 'permits', v_permits,
    'closeout_not_recorded_count', v_open,
    'closeout_not_available_count', (SELECT count(*) FROM jsonb_array_elements(v_permits) e WHERE e->'closeout'->>'field_status' = 'not_available'),
    'coverage_note', NULL);$r$);
  execute d;
end $$;

-- the count check (868): the permits a parcel shows must equal the permits the store holds for it
create or replace function public.permit_surface_count_mismatches() returns integer
language plpgsql stable security definer set search_path to 'public' as $$
declare bad int := 0; r record; surf int; store int;
begin
  for r in (select 74::numeric co_no, '633001001890'::text parcel_id
            union all (select 74, a.parcel_id from parcel_attributes a where a.co_no = 74 and a.alt_key in (select "PARID" from volusia_cama_permits) order by md5(a.parcel_id) limit 60)
            union all (select 62, a.parcel_id from parcel_attributes a where a.co_no = 62 order by md5(a.parcel_id) limit 30)) loop
    surf := coalesce((get_parcel_permit_facts(r.co_no, r.parcel_id)->>'count')::int, 0);
    if r.co_no = 74 then
      select count(*) into store from volusia_cama_permits where "PARID" = parcel_alt_key(74, r.parcel_id);
    else
      select count(*) into store from pinellas_cama_rp_permits where strap = cama_key(62, r.parcel_id);
    end if;
    if surf <> store then bad := bad + 1; end if;
  end loop;
  return bad;
end $$;
revoke all on function public.permit_surface_count_mismatches() from public, anon, authenticated;
grant execute on function public.permit_surface_count_mismatches() to service_role;

insert into data_defect_registry (defect_id, name, class, severity, detection_sql, false_positive_notes)
values ('permit-surface-count-differs-from-store',
  'A parcel shows fewer (or more) permits than the county permit store holds for it - an inner join or filter has crept into the served path',
  'completeness', 'blocking',
  'select (public.permit_surface_count_mismatches() = 0) as ok',
  'Served-path check (868): calls get_parcel_permit_facts on the founding parcel plus 60 Volusia and 30 Pinellas parcels (stable md5 sample) and compares its count with a direct count of the store for the same key. Cannot see parcels outside the sample; a filter that only bites on rare keys could pass.');

insert into data_defect_registry (defect_id, name, class, severity, detection_sql, false_positive_notes)
values ('permit-closeout-absence-served-as-signal-after-cliff',
  'A permit issued after its county''s completion cliff is served as not_recorded (implying unfinished) instead of not_available',
  'null_as_value', 'material',
  $q$select (select p->'closeout'->>'field_status' from jsonb_array_elements(public.get_parcel_permit_facts(74,'633001001890')->'permits') p where p->>'permit_number' = '20260601013') = 'not_available' as ok$q$,
  'Served-path check on the founding parcel''s 2026 generator permit (issued after the 2018 Volusia cliff, no completion recorded). One permit; the cliff rule itself lives in permit_field_coverage.');

select public._log_action('cc', 'gate_closeout_and_state_licence_link', 'get_parcel_permit_facts', array['permit_field_coverage','get_parcel_permit_facts','permit_surface_count_mismatches'],
  null, jsonb_build_object('closeout','not_available after county cliff','licence','no_match / not_applicable stated'),
  'WO 870 items 1/2a/2c: completion absence gated on each county''s measured cliff; failed licence lookup stated on the row; store-vs-surface count check.', null);

do $$
declare g jsonb; h jsonb; old_cnt int;
begin
  g := (select p from jsonb_array_elements(get_parcel_permit_facts(74,'633001001890')->'permits') p where p->>'permit_number' = '20260601013');
  if g->'closeout'->>'field_status' <> 'not_available' then raise exception '177a: generator closeout is %', g->'closeout'->>'field_status'; end if;
  if g->'contractor_licence'->>'link_state' <> 'no_match' then raise exception '177a: generator licence state is %', g->'contractor_licence'; end if;
  if (get_parcel_permit_facts(74,'633001001890')->>'count')::int <> 5 then raise exception '177a: founding parcel lost permits'; end if;
  -- the 2009 roofing permit is pre-cliff and finaled; must be untouched
  if (select p->'closeout'->>'field_status' from jsonb_array_elements(get_parcel_permit_facts(74,'633001001890')->'permits') p where p->>'permit_number' = '20090929013') <> 'present' then
    raise exception '177a: a finaled permit changed state';
  end if;
  if public.permit_surface_count_mismatches() <> 0 then raise exception '177a: store/surface counts differ'; end if;
  if not has_function_privilege('anon', 'public.contractor_register_search'::regproc, 'execute')
     or not has_function_privilege('anon', 'public.agent_register_search'::regproc, 'execute') then raise exception '177a: register grants lost'; end if;
end $$;
