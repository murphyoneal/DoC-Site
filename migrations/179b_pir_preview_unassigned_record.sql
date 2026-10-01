-- 179b - fix 179a: get_pir_preview raised 55000 "record v_si is not assigned yet" on every parcel WITH an address,
-- because coalesce(v_prop.address_line_1, v_si.phy_addr1) still evaluates v_si.phy_addr1 when the record was never
-- selected into. Caught by calling the function immediately after 179a applied (nothing consumed it yet). The fallback
-- now goes through a text variable, assigned only when needed; the expression's result is unchanged.

create or replace function public.get_pir_preview(p_co_no numeric, p_parcel_id text)
returns jsonb language plpgsql stable security definer set search_path to 'public', 'pg_temp' as $$
declare v_addr text; v_idf jsonb;
begin
  select address_line_1 into v_addr from properties
   where dor_parcel_id = p_parcel_id
     and county_fips = (select fips from county_registry where dor_county_no = p_co_no::text)
   order by updated_at desc nulls last limit 1;
  if v_addr is null then
    select si.phy_addr1 into v_addr from get_site_intelligence(p_co_no, p_parcel_id) si limit 1;
  end if;
  v_idf := public.get_parcel_identity_frame(p_co_no, p_parcel_id);
  return jsonb_build_object(
    'meta', jsonb_build_object('coNo', p_co_no, 'parcelId', p_parcel_id, 'preview', true, 'generatedAt', now()),
    'address', v_addr,
    'frameLabel', v_idf->>'frame_label');
end $$;
revoke all on function public.get_pir_preview(numeric, text) from public, anon, authenticated;
grant execute on function public.get_pir_preview(numeric, text) to service_role;

select public._log_action('cc', 'fix_pir_preview_unassigned_record', 'pg_proc', array['get_pir_preview'], null, null,
  '179a raised 55000 on parcels with an address (unassigned record in coalesce); fallback moved to a text variable.', null);
