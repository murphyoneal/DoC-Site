-- 140c — contractor_finder pages through its results (off). Walkthrough of work order 697: Volusia has
-- 3,288 businesses and the finder listed only the first 60, with nothing linking to the rest, so the
-- page meant to be the indexable list hid 98% of it. Same function, one more argument; the 4-argument
-- version is dropped so PostgREST's named-argument call is never ambiguous. Called server-side only
-- (service_role); the browser never calls it.

do $f$
declare def text; new_def text;
begin
  def := pg_get_functiondef('public.contractor_finder(text,text,text,integer)'::regprocedure);
  new_def := replace(def,
    'FUNCTION public.contractor_finder(q text DEFAULT NULL::text, county text DEFAULT NULL::text, trade text DEFAULT NULL::text, lim integer DEFAULT 60)',
    'FUNCTION public.contractor_finder(q text DEFAULT NULL::text, county text DEFAULT NULL::text, trade text DEFAULT NULL::text, lim integer DEFAULT 60, off integer DEFAULT 0)');
  new_def := replace(new_def,
    'LIMIT greatest(1, least(coalesce(lim, 60), 100))',
    'LIMIT greatest(1, least(coalesce(lim, 60), 100)) OFFSET greatest(0, coalesce(off, 0))');
  new_def := replace(new_def,
    '''count'', v_total, ''returned'', jsonb_array_length(v_rows),',
    '''count'', v_total, ''returned'', jsonb_array_length(v_rows), ''offset'', greatest(0, coalesce(off, 0)),');
  if position('off integer DEFAULT 0' in new_def) = 0 or position('OFFSET greatest(0' in new_def) = 0
     or position('''offset''' in new_def) = 0 then
    raise exception '140c: anchors did not apply';
  end if;
  drop function public.contractor_finder(text, text, text, integer);
  execute new_def;
end $f$;

grant execute on function public.contractor_finder(text, text, text, integer, integer) to service_role;

do $a$
declare a jsonb; b jsonb;
begin
  a := public.contractor_finder(null, 'volusia', null, 60, 0);
  b := public.contractor_finder(null, 'volusia', null, 60, 60);
  if (a->>'count')::int <> (b->>'count')::int or (a->'results'->0->>'slug') = (b->'results'->0->>'slug') then
    raise exception '140c: paging did not advance';
  end if;
  if has_function_privilege('anon', 'public.contractor_finder(text,text,text,integer,integer)', 'EXECUTE') then
    raise exception '140c: anon can execute contractor_finder';
  end if;
end $a$;
