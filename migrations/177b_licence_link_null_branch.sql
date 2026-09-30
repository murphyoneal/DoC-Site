-- 177b - make 177a's licence states reachable.
--
-- 177a added not_applicable / no_match as the CASE's ELSE, but the CASE opens with
-- `WHEN c.match_state IS NULL THEN NULL`, which catches every unmatched permit first. So the 710,832 permits still
-- served silence. 177a's own control did not catch it: `g->...->>'link_state' <> 'no_match'` is NULL when the field
-- is absent, and IF NULL does not raise. Every control below uses IS DISTINCT FROM.

do $$
declare d text; n int; pat text := 'WHEN c\.match_state IS NULL THEN NULL\s+';
begin
  d := pg_get_functiondef('public.get_parcel_permit_facts(numeric,text)'::regprocedure);
  n := (select count(*) from regexp_matches(d, pat, 'g'));
  if n <> 1 then raise exception '177b: null branch matched % times, expected 1', n; end if;
  d := regexp_replace(d, pat, '');
  execute d;
end $$;

select public._log_action('cc', 'reach_licence_link_states', 'get_parcel_permit_facts', array['get_parcel_permit_facts'],
  null, jsonb_build_object('removed','WHEN c.match_state IS NULL THEN NULL'),
  '177a licence states were unreachable behind an earlier NULL branch; removed so a failed lookup is stated on the row.', null);

do $$
declare g jsonb; nc jsonb; bad int;
begin
  g := (select p from jsonb_array_elements(get_parcel_permit_facts(74,'633001001890')->'permits') p where p->>'permit_number' = '20260601013');
  if g->'contractor_licence'->>'link_state' is distinct from 'no_match' then raise exception '177b: generator licence is %', g->'contractor_licence'; end if;
  if (select count(*) from jsonb_array_elements(get_parcel_permit_facts(74,'633001001890')->'permits') p where p->'contractor_licence' is null or p->'contractor_licence' = 'null'::jsonb) <> 0 then
    raise exception '177b: a founding-parcel permit still has no licence state';
  end if;
  if (get_parcel_permit_facts(74,'633001001890')->>'count')::int is distinct from 5 then raise exception '177b: founding parcel lost permits'; end if;
  if public.permit_surface_count_mismatches() is distinct from 0 then raise exception '177b: store/surface counts differ'; end if;
end $$;
