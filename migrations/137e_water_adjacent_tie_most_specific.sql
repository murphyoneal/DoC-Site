-- 137e — Tie-break for the adjacent water body: the most SPECIFIC one (named, then smallest).
--
-- 137c added a deterministic tie-break (named first, then objectid). The golden suite then showed
-- Miami-Dade 0141280040170 diverge: that parcel meets Biscayne Bay and the Atlantic Ocean along the
-- SAME 186 ft (their shared boundary), and objectid order picked the Atlantic Ocean where the
-- baseline served Biscayne Bay. For a bayfront parcel the bay is the true description, so the tie
-- now prefers a named body, then the SMALLER polygon (the bay inside the ocean, the inlet inside the
-- bay), then objectid. Glory Hole (74/961900000010, named, vs an unnamed stream area) is unchanged.
-- ST_Area(geom), not areasqkm, because 55 of 5,776 polygons have no areasqkm.

do $f$
declare def text; new_def text;
begin
  def := pg_get_functiondef('public.get_parcel_water_facts(numeric,text)'::regprocedure);
  new_def := replace(def, '(a.gnis_name is null), a.objectid limit 1;', '(a.gnis_name is null), ST_Area(a.geom), a.objectid limit 1;');
  if new_def = def then raise exception '137e: anchor not found - nothing changed'; end if;
  execute new_def;
end $f$;

grant execute on function public.get_parcel_water_facts(numeric, text) to service_role;
