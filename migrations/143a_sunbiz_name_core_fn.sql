-- 143a — the exact expression behind sunbiz_corporate.name_core (a generated column, read from
-- pg_attrdef), as a function, so a registrant's name is normalised IDENTICALLY to the 12.8M-row side
-- (work order 706). Asserted equal to the stored column on a ~20,000-row sample.
create or replace function public.sunbiz_name_core(p text) returns text
language sql immutable parallel safe set search_path = public as $$
  select regexp_replace(btrim(regexp_replace(regexp_replace(upper(p), '[^A-Z0-9 ]', ' ', 'g'),
         '\s+(INC|LLC|L L C|CORP|CORPORATION|CO|COMPANY|LTD|LP|LLP|PA|PLLC)\s*$', '', 'g')), '\s+', ' ', 'g')
$$;
comment on function public.sunbiz_name_core(text) is
  'Identical to the generated expression of sunbiz_corporate.name_core (pg_attrdef, 2026-09-27). Asserted equal on a 20,000-row sample in 143a. WO 706.';

do $a$
declare bad int; n int;
begin
  select count(*), count(*) filter (where public.sunbiz_name_core(corporation_name) is distinct from name_core)
    into n, bad
    from (select corporation_name, name_core from sunbiz_corporate tablesample system (0.2) limit 20000) s;
  if n < 5000 or bad <> 0 then raise exception '143a: normaliser differs from name_core on % of % rows', bad, n; end if;
end $a$;
