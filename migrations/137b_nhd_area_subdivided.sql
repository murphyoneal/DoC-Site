-- 137b — nhd_area_sub: NHD area polygons subdivided for distance queries (backlog 258, ruling
-- row 676 item 4: fix the county-specific slow paths only; do not re-architect the report).
--
-- get_parcel_water_facts took 5.4 s on the Santa Rosa golden parcel (other parcels: 1-61 ms).
-- Measured: 5.2 s of it is ST_Distance against TWO polygons whose bounding boxes cover the parcel -
-- an unnamed river area of 42,558 vertices and the Gulf of Mexico at 21,827. 373 of 5,776 NHD areas
-- exceed 1,000 vertices. Distance to a polygon equals the minimum distance to its pieces, so a
-- subdivided copy gives the SAME answer through the index at a fraction of the cost.
--
-- DERIVED, not a source: rebuilt by refresh_nhd_area_sub() whenever nhd_area is reloaded. Guarded
-- by detection nhd-area-sub-in-sync so a reload without a rebuild is caught rather than served.

create table if not exists public.nhd_area_sub (
  objectid bigint not null,
  geom geometry not null
);

create or replace function public.refresh_nhd_area_sub() returns bigint
language plpgsql security definer set search_path = public, pg_temp as $$
declare n bigint;
begin
  truncate public.nhd_area_sub;
  insert into public.nhd_area_sub (objectid, geom)
  select a.objectid, ST_Subdivide(a.geom, 256) from public.nhd_area a where a.geom is not null;
  get diagnostics n = row_count;
  if n = 0 then raise exception 'refresh_nhd_area_sub: 0 pieces - nhd_area empty or unreadable; nothing served from it'; end if;
  return n;
end $$;

select public.refresh_nhd_area_sub();

create index if not exists nhd_area_sub_gix on public.nhd_area_sub using gist (geom);
create index if not exists nhd_area_sub_oid_ix on public.nhd_area_sub (objectid);
analyze public.nhd_area_sub;

comment on table public.nhd_area_sub is
  'DERIVED from nhd_area by refresh_nhd_area_sub() (ST_Subdivide 256): pieces for exact, index-backed distance. '
  'Rebuild after every nhd_area reload. Guarded by detection nhd-area-sub-in-sync. 137b, 2026-09-26.';

insert into public.data_defect_registry
  (defect_id, name, discovered_on, discovered_via, class, severity, detection_sql, expected_denominator,
   false_positive_notes, status, attribution, expected_state, remediation)
values
('nhd-area-sub-in-sync',
 'nhd_area_sub must hold pieces for exactly the polygons in nhd_area (else water distances are served from stale or missing geometry)',
 date '2026-09-26', 'backlog 258 (Santa Rosa report latency)', 'completeness', 'blocking',
 $d$select (
    (select count(*) from public.nhd_area where geom is not null and not ST_IsEmpty(geom)) > 0
    and not exists (select 1 from public.nhd_area a where a.geom is not null and not ST_IsEmpty(a.geom)
                     and not exists (select 1 from public.nhd_area_sub s where s.objectid = a.objectid))
    and not exists (select 1 from public.nhd_area_sub s
                     where not exists (select 1 from public.nhd_area a where a.objectid = s.objectid))
  ) as ok$d$,
 'every nhd_area polygon and every nhd_area_sub piece',
 'Catches a reload of nhd_area without refresh_nhd_area_sub(): polygons with no pieces, or pieces of polygons that no longer exist. It cannot see a polygon whose GEOMETRY changed under the same objectid; a full reload replaces objectids, which it does see. Empty nhd_area is errored-as-red, not clean. EMPTY geometries are excluded: ST_Subdivide yields no piece for them and they can never be near a parcel (1 exists: objectid 5321, found by this check''s first run; corrected in place).',
 'active', 'ours', 'clean',
 'select refresh_nhd_area_sub();')
on conflict (defect_id) do nothing;
