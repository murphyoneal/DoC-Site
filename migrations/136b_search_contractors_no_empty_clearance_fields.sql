-- 136b — search_contractors (the Roz find_contractors tool) stops serving fields we do not hold.
-- Ruling 2026-09-26. COUPLED DEPLOY, prompt first: the tool description stopped naming these
-- fields in PR #31 (live in production b98e07d) before this migration ran.
--
-- complaint_count, bond_status, insurance_expiry, workers_comp_on_file, phone and website are
-- empty on every row (0 of 114,104). The caveat called complaint_count "roster-carried"; the roster
-- carries nothing. A model handed complaint_count = null after being told it has complaint counts
-- says "no complaints on record" — a clearance about a named business that nobody checked.
--
-- Consumers enumerated (three classes): repo — app/api/roz/route.ts only, which JSON.stringifies
-- the result and reads no field; pg_proc — no other function calls it; prompt — PR #31 removed the
-- field names. Removing keys is therefore safe. Ordering no longer uses complaint_count (always 0).
-- Replaces its own grants (the secdef guard); it was service_role-only and is re-asserted so.

create or replace function public.search_contractors(p_trade text default null::text, p_city text default null::text,
  p_county numeric default 74, p_active_only boolean default true, p_limit integer default 20)
returns jsonb language plpgsql stable security definer
set search_path to 'public', 'pg_temp' set statement_timeout to '25s'
as $function$
declare res jsonb;
begin
  select coalesce(jsonb_agg(x order by same_city desc, bn), '[]'::jsonb) into res from (
    select jsonb_build_object('business_name', coalesce(display_name,business_name), 'trade', trade_label,
      'license_number', license_number, 'license_status', license_status, 'license_expiry', expiry_date,
      'business_city', city, 'county', public.county_display(county_name),
      'not_held', 'complaints, discipline, bond, insurance and workers comp: we hold none of these for any contractor. Do not state or imply a clean record; check myfloridalicense.com.',
      'caveat', 'DBPR construction licence file (DBPR_FL); the city shown is the business address, NOT service area. Licence status/expiry as recorded - verify current standing at myfloridalicense.com. Electrical contractors are licensed by a separate board whose file we do not hold. County is the county recorded on the licence, which is not always the county the business address falls in; where they differ we hold both.') x,
      (case when p_city is not null and city ilike p_city then 1 else 0 end) same_city,
      coalesce(display_name,business_name) bn
    from contractors
    where active='True'
      and trade_code not in (select r.trade_code from public.trade_code_registry r where r.department = 'none')
      and (not p_active_only or license_status='active')
      and (p_trade is null or trade_label ilike '%'||p_trade||'%' or doc_category ilike '%'||p_trade||'%' or trade_code ilike p_trade
           or (p_trade ilike '%electric%' and (trade_label ilike '%electric%' or doc_category ilike '%electric%'))
           or (p_trade ilike '%plumb%' and (trade_label ilike '%plumb%' or doc_category ilike '%plumb%'))
           or (p_trade ilike '%roof%' and (trade_label ilike '%roof%' or doc_category ilike '%roof%')))
      and (p_county is null or county_code = p_county::text)
    order by same_city desc, bn
    limit p_limit) s;
  return res;
end $function$;

grant execute on function public.search_contractors(text, text, numeric, boolean, integer) to service_role;

do $a$
declare r jsonb;
begin
  if not has_function_privilege('service_role', 'public.search_contractors(text,text,numeric,boolean,integer)', 'EXECUTE') then
    raise exception '136b: service_role lost EXECUTE';
  end if;
  r := public.search_contractors('roofing', null, 74, true, 5);
  if jsonb_array_length(r) = 0 then raise exception '136b: roofing in Volusia returned nothing'; end if;
  if exists (select 1 from jsonb_array_elements(r) e
              where e ?| array['complaint_count','bond_status','insurance_expiry','workers_comp_on_file','phone','website']) then
    raise exception '136b: an unheld field is still served';
  end if;
end $a$;
