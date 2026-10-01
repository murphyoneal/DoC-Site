-- 187c - the roof gate's reason names the source file date (2026-06-21), not the build date (187b corrected the as-of).
do $$
declare d text; n int;
begin
  d := pg_get_functiondef('public.get_parcel_roof_lifespan(numeric,text)'::regprocedure);
  n := (select count(*) from regexp_matches(d, 'built from a permit history compiled on 28 June 2026', 'g'));
  if n <> 1 then raise exception '187c: reason anchor matched % times', n; end if;
  d := replace(d, 'built from a permit history compiled on 28 June 2026', 'built from a permit history compiled from the county''''s 21 June 2026 permit file');
  execute d;
end $$;
grant execute on function public.get_parcel_roof_lifespan(numeric,text) to service_role, roz_payload_reader, consumer_report_readonly;

select public._log_action('cc', 'roof_gate_reason_source_date', 'get_parcel_roof_lifespan', array['get_parcel_roof_lifespan'], null,
  jsonb_build_object('reason_date', '21 June 2026 permit file'),
  '187b moved the derived permit history as-of to its source export (2026-06-21); the gate reason now names that date rather than the build date.', null);

do $$
declare r jsonb;
begin
  r := get_parcel_roof_lifespan(74, '701710160110');
  if r->0->>'field_status' is distinct from 'not_available' or r->0->>'reason' not like '%21 June 2026 permit file%' then raise exception '187c: %', r; end if;
  if not has_function_privilege('roz_payload_reader', 'public.get_parcel_roof_lifespan(numeric,text)', 'execute') then raise exception '187c: grant lost'; end if;
end $$;
