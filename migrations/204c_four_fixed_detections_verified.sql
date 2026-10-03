-- 204c - the four "expected defect, now green" detections: populations declared, each one's verdict measured (ruling 936).
--
-- 936: these were the only rows where the board gave good news nobody could verify - a fix and a blinded check look the
-- same without a population. Measured 2026-10-02. All four have been GREEN on every run since 2026-08-20; none went
-- green recently - their expected_state was simply never updated. Verdicts:
--   registry-derivation-unexpressed   REAL FIX. 628 served layer tables, 0 without a registry row (172 on 2026-08-11).
--                                     -> expected clean, population = served layer tables examined.
--   miamidade-zoning-wired-to-unincorporated-only  REAL FIX for its predicate: miamidade_municipal_zoning (4,606 rows) is in
--                                     layer_resolution. Whether it SERVES is a separate detection
--                                     (miamidade-municipal-zoning-inert-on-null-rowcount), which is red.
--                                     -> expected clean, population = rows of the municipal table.
--   DEF-024                           PASSES, BUT A NARROW PROXY: it checks only that parcel_elevations has a provenance URL
--                                     in table_inventory, not its name ("model emitted provenance absent from the payload").
--                                     -> expected clean, population = the inventory row; documented as a single-source proxy.
--   municipal-boundary-annexation-lag HALF DONE - the green was partly blind. Its own notes say green only when the
--                                     staleness is disclosed in the registry AND the served municipal answer surfaces it.
--                                     It checked only the registry (fl_city_limits: temporal_extent_end 2021-12-31, publisher
--                                     stated). get_parcel_municipality returns the city with source 'fl_city_limits' and NO
--                                     date - 74/643010000010 and 74/633001001890 measured. Now checks both halves -> RED,
--                                     expected defect, acknowledged with the measured reason.

update public.data_defect_registry set
  detection_sql = $q$with lr as (select distinct lr.table_name from public.layer_resolution lr where lr.table_name is not null)
select not exists (select 1 from lr where not exists (select 1 from public.data_source_registry r where r.table_name = lr.table_name)) as ok,
       (select count(*) from lr where not exists (select 1 from public.data_source_registry r where r.table_name = lr.table_name)) as row_count,
       (select count(*) from lr) as population$q$,
  expected_state = 'clean', acknowledgement = null, expires_at = null,
  false_positive_notes = coalesce(false_positive_notes, '') || ' | 204c: verified a REAL FIX (628 served layer tables, 0 unregistered; 172 on 2026-08-11). Expected clean; population = served layer tables.'
 where defect_id = 'registry-derivation-unexpressed';

update public.data_defect_registry set
  detection_sql = $q$select not ((select count(*) from public.miamidade_municipal_zoning) > 0
            and not exists (select 1 from public.layer_resolution where table_name = 'miamidade_municipal_zoning')) as ok,
       (select count(*) from public.miamidade_municipal_zoning) as population$q$,
  expected_state = 'clean', acknowledgement = null, expires_at = null,
  false_positive_notes = coalesce(false_positive_notes, '') || ' | 204c: verified fixed for its predicate - the 4,606-row municipal layer is in layer_resolution. Serving is guarded by miamidade-municipal-zoning-inert-on-null-rowcount. Expected clean; population = municipal rows (an emptied table errors the run).'
 where defect_id = 'miamidade-zoning-wired-to-unincorporated-only';

update public.data_defect_registry set
  detection_sql = $q$select coalesce((select source_url is not null from public.table_inventory where table_name = 'parcel_elevations' limit 1), false) as ok,
       (select count(*) from public.table_inventory where table_name = 'parcel_elevations') as population$q$,
  expected_state = 'clean', acknowledgement = null, expires_at = null,
  false_positive_notes = coalesce(false_positive_notes, '') || ' | 204c: NARROW PROXY, single source - checks only that parcel_elevations carries a provenance URL in table_inventory, not that every model-emitted provenance is in the payload. Passes for real on that predicate. Candidate for retirement or a served-path rewrite.'
 where defect_id = 'DEF-024';

update public.data_defect_registry set
  detection_sql = $q$with reg as (
      select count(*) filter (where temporal_extent_end is not null and temporal_extent_basis is not null) ok_n, count(*) n
        from public.data_source_registry where table_name = 'fl_city_limits'),
    served as (
      select x.pid, public.get_parcel_municipality(74, x.pid) m
        from (values ('643010000010'), ('633001001890')) x(pid))
select (select n from reg) > 0 and (select ok_n from reg) = (select n from reg)
       and not exists (select 1 from served where m->>'municipality' is not null
                        and m::text !~ '(2021|as_of|boundary_date|temporal)') as ok,
       (select count(*) from served where m->>'municipality' is not null and m::text !~ '(2021|as_of|boundary_date|temporal)') as row_count,
       (select count(*) from served where m->>'municipality' is not null) as population$q$,
  expected_state = 'defect',
  acknowledgement = 'Measured 2026-10-02: the registry discloses fl_city_limits as 2021-12-31 (publisher stated), but get_parcel_municipality returns the city with no date, so a parcel''s jurisdiction is served from 2021 boundaries without saying so. Fix: surface the boundary date in the served answer.',
  expires_at = timestamptz '2026-10-16 23:59:59-04',
  false_positive_notes = coalesce(false_positive_notes, '') || ' | 204c: was green on the registry half only (partly blind). Now checks the served half too on two Volusia parcels; population = parcels with a municipality answer.'
 where defect_id = 'municipal-boundary-annexation-lag';

do $$
declare r record; res record;
begin
  for r in select defect_id, detection_sql, expected_state from public.data_defect_registry
            where defect_id in ('registry-derivation-unexpressed','miamidade-zoning-wired-to-unincorporated-only','DEF-024','municipal-boundary-annexation-lag') loop
    execute r.detection_sql into res;
    if coalesce(res.population, 0) <= 0 then raise exception '204c: % has no population', r.defect_id; end if;
    if r.expected_state = 'clean' and res.ok is distinct from true then raise exception '204c: % expected clean but red', r.defect_id; end if;
    if r.defect_id = 'municipal-boundary-annexation-lag' and res.ok is distinct from false then raise exception '204c: municipal check should now read the served half red'; end if;
  end loop;
end $$;

select public._log_action('cc', 'four_fixed_detections_verified', 'data_defect_registry',
  array['registry-derivation-unexpressed','miamidade-zoning-wired-to-unincorporated-only','DEF-024','municipal-boundary-annexation-lag'], null,
  jsonb_build_object('real_fix', jsonb_build_array('registry-derivation-unexpressed','miamidade-zoning-wired-to-unincorporated-only'),
                     'proxy', 'DEF-024', 'half_blind_now_red', 'municipal-boundary-annexation-lag'),
  'Ruling 936: the four expected-defect-now-green rows were the board''s unverifiable good news; each now declares a population and its verdict is measured.', null);
