-- 128b — search_contractors (the Roz tool) read contractors directly and served department='none'
-- rows: a CRS1 query returned 50 of 50 continuing-education providers. contractors_public already
-- excludes them, so profiles/map/QR/vCard never served them; this was the one path that did.
--
-- Patched in place with an anchored replace — payload shape unchanged. search_contractors is
-- SECURITY DEFINER, so replacing it revokes its own grants: they are re-asserted below.

do $mig$
declare
  v_def text := pg_get_functiondef('public.search_contractors(text,text,numeric,boolean,integer)'::regprocedure);
  v_anchor text := $a$where active='True' and (not p_active_only$a$;
begin
  if position(v_anchor in v_def) = 0 then
    raise exception '128b: anchor not found in search_contractors — body has moved, not applying';
  end if;
  execute replace(v_def, v_anchor,
    $r$where active='True'
      and trade_code not in (select r.trade_code from public.trade_code_registry r where r.department = 'none')
      and (not p_active_only$r$);
end
$mig$;

grant execute on function public.search_contractors(text,text,numeric,boolean,integer) to service_role, roz_payload_reader;
