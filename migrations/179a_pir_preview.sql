-- 179a - the unpurchased preview fetches only what the paywall renders (ruling 875 item 2).
--
-- MEASURED 2026-10-01 over REST with a throwaway pg_sleep probe (dropped after use):
--   service_role (the report page's key): 9 s -> HTTP 500 / 57014 at 8,647 ms; 7 s -> 200.  The 8 s binds.
--   anon (publishable key):               4 s -> HTTP 500 / 57014 at 3,403 ms; 2 s -> 200.  The 3 s binds.
-- get_pir_report measured 6.5 / 7.3 / 7.6 / 11.9 s on four Volusia parcels, so some unpurchased visitors are shown
-- a bare 500 instead of the buy button: the page runs the FULL build before it knows whether the visitor paid.
-- (get_pir_report declares SET statement_timeout TO '25s'; the probe shows the outer 8 s still binds. Left alone:
-- ruling 875, a limit raised to stop a failure is a check deleted.)
--
-- ReportPaywall renders two things: the address and an identity line built ONLY from identityFrame.frame_label
-- (the owner is excluded from the preview, ruling 631). This function returns exactly those, computed by the
-- same expressions get_pir_report uses:
--   address     = COALESCE(properties.address_line_1, get_site_intelligence(...).phy_addr1)
--   frame_label = get_parcel_identity_frame(...)->>'frame_label'
-- plus meta (the socket's null test is `!res.meta`; get_pir_report always returns meta, even for a parcel that does
-- not exist, so this does too - behaviour preserved exactly, the nonexistent-parcel paywall reported separately).
-- No owner, no signals, nothing else leaves this function.

create or replace function public.get_pir_preview(p_co_no numeric, p_parcel_id text)
returns jsonb language plpgsql stable security definer set search_path to 'public', 'pg_temp' as $$
declare v_prop properties%rowtype; v_si record; v_idf jsonb;
begin
  select * into v_prop from properties
   where dor_parcel_id = p_parcel_id
     and county_fips = (select fips from county_registry where dor_county_no = p_co_no::text)
   order by updated_at desc nulls last limit 1;
  if v_prop.address_line_1 is null then
    select * into v_si from get_site_intelligence(p_co_no, p_parcel_id) limit 1;
  end if;
  v_idf := public.get_parcel_identity_frame(p_co_no, p_parcel_id);
  return jsonb_build_object(
    'meta', jsonb_build_object('coNo', p_co_no, 'parcelId', p_parcel_id, 'preview', true, 'generatedAt', now()),
    'address', coalesce(v_prop.address_line_1, v_si.phy_addr1),
    'frameLabel', v_idf->>'frame_label');
end $$;
comment on function public.get_pir_preview(numeric, text) is
  'The unpurchased report preview (179a): address + identity frame label only, by the same expressions get_pir_report uses. Never carries the owner (ruling 631).';
revoke all on function public.get_pir_preview(numeric, text) from public, anon, authenticated;
grant execute on function public.get_pir_preview(numeric, text) to service_role;

select public._log_action('cc', 'build_pir_preview', 'pg_proc', array['get_pir_preview'], null,
  jsonb_build_object('returns', jsonb_build_array('meta','address','frameLabel')),
  'Ruling 875 item 2: the paywall preview must not pay the full 6-12 s report build under an 8 s REST limit.', null);

-- The output-identity check against get_pir_report was NOT run inside this migration (four full reports risk the
-- connector timeout). It was run per parcel after 179b, which fixes a call-time error in this body (see 179b).
