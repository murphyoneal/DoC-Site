-- 134a — Work gallery, app half: storage buckets and the location check (653 (d); 611, 613).
--
-- BUCKETS. The private bucket is created PRIVATE here, in its first migration — never public and
-- then tightened (ruling). It holds the ORIGINAL upload, metadata intact, for AddressFolder, which
-- will read it once owner verification exists. The public bucket only ever receives a server
-- re-encoded JPEG whose metadata has been stripped AND verified absent by reading the stored copy
-- back. No storage.objects policy is written for either: service_role (the upload route) bypasses
-- storage RLS, the public bucket is readable by its public flag, and the private bucket is
-- readable by nobody else. A policy that cannot fire is not a control (ruling 613).
--
-- LOCATION CHECK. The camera's GPS and the contractor's typed address are two independent claims
-- about one fact. Four states, never a boolean:
--   location_confirmed      GPS inside the claimed parcel
--   location_divergent      GPS elsewhere — recorded with the distance, NOT a rejection
--   location_not_available  no GPS in the file — never read as agreement
--   location_not_checked    the parcel could not be resolved from the address
-- The route calls this BEFORE stripping: extract GPS -> check -> record -> strip -> publish.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('work-private', 'work-private', false, 15728640, array['image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('work-public', 'work-public', true, 5242880, array['image/jpeg'])
on conflict (id) do nothing;

create or replace function public.check_work_location(
  p_co_no numeric, p_parcel_id text, p_lat double precision, p_lng double precision)
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as
$$
declare v_geom geometry; v_pt geometry; v_m numeric;
begin
  if p_co_no is null or p_parcel_id is null then
    return jsonb_build_object('location_state', 'location_not_checked', 'divergence_m', null,
      'note', 'The address could not be resolved to a parcel, so the photo location could not be checked.');
  end if;
  v_geom := public._parcel_geom_agg(p_co_no, p_parcel_id);
  if v_geom is null then
    return jsonb_build_object('location_state', 'location_not_checked', 'divergence_m', null,
      'note', 'The parcel has no mapped geometry here, so the photo location could not be checked.');
  end if;
  if p_lat is null or p_lng is null then
    return jsonb_build_object('location_state', 'location_not_available', 'divergence_m', null,
      'note', 'The photo carries no location data. This is not agreement with the address.');
  end if;
  v_pt := ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326);
  if ST_Contains(v_geom, v_pt) then
    return jsonb_build_object('location_state', 'location_confirmed', 'divergence_m', 0,
      'note', 'The photo was taken inside the parcel given.');
  end if;
  v_m := round(ST_Distance(v_geom::geography, v_pt::geography)::numeric);
  return jsonb_build_object('location_state', 'location_divergent', 'divergence_m', v_m,
    'note', 'The photo was taken about ' || v_m || ' m from the parcel given. Recorded, not rejected.');
end
$$;

revoke all on function public.check_work_location(numeric, text, double precision, double precision) from public, anon, authenticated;
grant execute on function public.check_work_location(numeric, text, double precision, double precision) to service_role;

insert into public.data_defect_registry
  (defect_id, name, discovered_on, discovered_via, class, severity, detection_sql, expected_denominator,
   false_positive_notes, status, attribution, expected_state, remediation)
values
('work-private-bucket-must-stay-private',
 'The work-private bucket (original uploads, GPS intact) must be private and have no storage policy granting access',
 date '2026-09-25', 'work order 653 (d)', 'access_control', 'blocking',
 $d$select (
    coalesce((select not public from storage.buckets where id = 'work-private'), false)
    and coalesce((select public from storage.buckets where id = 'work-public'), false)
    and not exists (select 1 from pg_policies where schemaname = 'storage'
                     and (coalesce(qual,'') ilike '%work-private%' or coalesce(with_check,'') ilike '%work-private%'))
  ) as ok$d$,
 'the two work buckets and every storage policy',
 'CATALOG CHECK. It proves the flag and the absence of a granting policy; it does not fetch an object. The served-path half is the fixture test (scripts/work-exif-fixture-test.mjs step 4 and the anon fetch of the private object, which must fail). Returns false (errored-as-red, not clean) if either bucket is missing.',
 'active', 'ours', 'clean',
 'Set storage.buckets.public = false for work-private and drop any policy naming it.')
on conflict (defect_id) do nothing;
