-- 181a - a parcel that does not exist is not a sellable parcel (ruling 878 item 4 / 880 / 881 order item 2).
--
-- get_pir_report(74,'000000000000') returns a document WITH meta and every block empty, and 179a's get_pir_preview
-- deliberately preserved that. So /report/<co>/<anything> showed "This property" and the $5 button, and
-- /api/checkout created a Stripe session for any (co, parcel) string it was sent. pir_purchases holds 0 rows, so
-- nothing was ever sold this way - the absence of a parcel rendering as a sellable parcel, caught before money.
--
-- The preview now states the parcel's existence in three states, keyed on co_no + parcel_id (never a name):
--   present        the parcel is in parcel_attributes (the statewide roll, UNIQUE (co_no, parcel_id))
--   none_recorded  the county is held - parcel_attributes holds rows for this co_no - but not this parcel id
--   not_available  no county with this number is held (measured: all 67 Florida counties 11..77 are held, so
--                  inside Florida this state is unreachable; it names a co_no outside the 67)
-- Both gates read this one expression: the report page (no buy button unless present) and /api/checkout (no
-- Stripe session unless present). The checkout also takes the address from here, not from the request body.

create or replace function public.get_pir_preview(p_co_no numeric, p_parcel_id text)
returns jsonb language plpgsql stable security definer set search_path to 'public', 'pg_temp' as $$
declare v_addr text; v_idf jsonb; v_state text; v_county text;
begin
  select cr.county_name into v_county from county_registry cr where cr.dor_county_no = p_co_no::text;
  v_state := case
    when exists (select 1 from parcel_attributes a where a.co_no = p_co_no and a.parcel_id = p_parcel_id) then 'present'
    when exists (select 1 from parcel_attributes a where a.co_no = p_co_no) then 'none_recorded'
    else 'not_available' end;

  if v_state <> 'present' then
    return jsonb_build_object(
      'meta', jsonb_build_object('coNo', p_co_no, 'parcelId', p_parcel_id, 'preview', true, 'generatedAt', now()),
      'parcelState', v_state, 'countyName', v_county, 'address', null, 'frameLabel', null);
  end if;

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
    'parcelState', 'present', 'countyName', v_county,
    'address', v_addr,
    'frameLabel', v_idf->>'frame_label');
end $$;
revoke all on function public.get_pir_preview(numeric, text) from public, anon, authenticated;
grant execute on function public.get_pir_preview(numeric, text) to service_role;

select public._log_action('cc', 'gate_parcel_existence', 'pg_proc', array['get_pir_preview'], null,
  jsonb_build_object('adds', jsonb_build_array('parcelState','countyName')),
  'Ruling 878/881: a nonexistent parcel id rendered a buy button and could be sent to checkout; the preview now states present / none_recorded / not_available for both gates.', null);

do $$
declare a jsonb; b jsonb; c jsonb;
begin
  a := get_pir_preview(74, '633001001890');
  b := get_pir_preview(74, '000000000000');
  c := get_pir_preview(99, '633001001890');
  if a->>'parcelState' is distinct from 'present' or a->>'address' is distinct from '1778 EARHART CT' or a->>'frameLabel' is distinct from 'Residential property' then
    raise exception '181a: present parcel changed: %', a; end if;
  if b->>'parcelState' is distinct from 'none_recorded' or b->>'address' is not null then raise exception '181a: nonexistent parcel: %', b; end if;
  if c->>'parcelState' is distinct from 'not_available' then raise exception '181a: unheld county: %', c; end if;
end $$;
