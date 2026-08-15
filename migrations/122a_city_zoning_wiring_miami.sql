-- =============================================================================
-- Ruling 162, steps 1/2/5 — the first city-layer wiring, and the Vizcaya proof. Applied to production.
-- The resolver's municipal rung now carries a value: 3251 S Miami Ave zoning moves not_established -> CI
-- (City of Miami), jurisdiction MIAMI, municipal. Steps 3/4 (the other 55 layers + precedence) follow.
-- =============================================================================

-- 1. Re-key the two Daytona Beach rows off the Volusia COUNTY geo_id onto the MUNICIPALITY geo_id.
--    US-12-16525.dor_co_no=74 (inherited from the parent county), so zoning_layer_selection still maps
--    them to co_no 74 and _zoning_lookup's municipal-first ordering keeps them winning — the hand-tuned
--    precedence 3 is no longer load-bearing (ruling 162: let the hierarchy do what precedence hand-did).
UPDATE layer_resolution SET geo_id='US-12-16525'
WHERE table_name IN ('daytonabeach_city_zoning','daytonabeach_city_future_land_use') AND geo_id='US-12127';

-- 2. Wire the Miami-Dade municipal COMPILATION via option (a): keyed to the county geo_id, jurisdiction_level
--    municipal, the specific city resolved at query time by ST_Contains + municname. It is a genuinely
--    county-level multi-municipality source (35 munis, 4606 rows), so the county key is honest — unlike
--    Daytona, a single-city layer wrongly under a county key. One refreshable table, no per-city split.
INSERT INTO layer_resolution (geo_id, concept, table_name, geom_column, jurisdiction_level, jurisdiction_name, precedence, srid, selected_by, verified, notes)
SELECT 'US-12086','zoning','miamidade_municipal_zoning','geom','municipal','Miami-Dade municipalities (county compilation)', 2, 4326, 'ruling162', true,
  'Multi-municipality county compilation. City resolved at query time via ST_Contains + municname. Hialeah is ALSO covered by hialeah_city_zoning (city-own) which must outrank this once wired (precedence, step 3).'
WHERE NOT EXISTS (SELECT 1 FROM layer_resolution WHERE geo_id='US-12086' AND table_name='miamidade_municipal_zoning' AND concept='zoning');

INSERT INTO layer_column_map (table_name, col_role, column_name)
SELECT * FROM (VALUES ('miamidade_municipal_zoning','code','zone'), ('miamidade_municipal_zoning','municipality','municname')) v(t,r,c)
WHERE NOT EXISTS (SELECT 1 FROM layer_column_map WHERE table_name='miamidade_municipal_zoning');

-- _zoning_lookup: report the RESOLVED municipality (municname) as the jurisdiction, not the layer's
-- compilation name — so the Vizcaya parcel reads "MIAMI", not "Miami-Dade municipalities (county compilation)".
CREATE OR REPLACE FUNCTION public._zoning_lookup(p_pt geometry, p_co_no numeric, p_kind text)
 RETURNS jsonb LANGUAGE plpgsql STABLE AS $function$
DECLARE r record; v record; q text; v_not_mine boolean; v_flagged boolean;
BEGIN
  FOR r IN SELECT * FROM public.zoning_layer_selection WHERE co_no=p_co_no AND kind=p_kind
    ORDER BY (jurisdiction_level='municipal') DESC, jurisdiction_name LOOP
    q := format('SELECT (%I)::text AS code, %s AS name, %s AS url, %s AS muni FROM public.%I WHERE ST_Contains(%I,$1) LIMIT 1',
       r.code_column,
       CASE WHEN r.name_column IS NULL THEN 'NULL::text' ELSE '('||quote_ident(r.name_column)||')::text' END,
       CASE WHEN r.url_column  IS NULL THEN 'NULL::text' ELSE '('||quote_ident(r.url_column)||')::text' END,
       CASE WHEN r.municipality_column IS NULL THEN 'NULL::text' ELSE '('||quote_ident(r.municipality_column)||')::text' END,
       r.table_name, r.geom_column);
    BEGIN EXECUTE q INTO v USING p_pt; EXCEPTION WHEN others THEN CONTINUE; END;
    IF v.code IS NOT NULL AND nullif(trim(v.code),'') IS NOT NULL THEN
      v_not_mine := r.not_mine_values IS NOT NULL AND EXISTS (SELECT 1 FROM unnest(r.not_mine_values) x WHERE upper(trim(x))=upper(trim(v.code)));
      v_flagged  := r.flagged_values  IS NOT NULL AND EXISTS (SELECT 1 FROM unnest(r.flagged_values)  x WHERE upper(trim(x))=upper(trim(v.code)));
      RETURN jsonb_build_object('code', trim(v.code), 'name', nullif(trim(v.name),''), 'url', nullif(trim(v.url),''),
        'jurisdiction_level', r.jurisdiction_level,
        'jurisdiction', coalesce(nullif(trim(v.muni),''), r.jurisdiction_name), 'source', r.table_name,
        'is_not_mine', v_not_mine, 'municipality', nullif(trim(v.muni),''), 'is_flagged', v_flagged);
    END IF;
  END LOOP;
  RETURN NULL;
END $function$;

-- STILL OPEN (step 3/4): wire the other 55 city layers (largest first), add a precedence tier to
-- _zoning_lookup so city-own > county-compilation > county (the Hialeah double-coverage), and give
-- _zoning_lookup's ST_Contains a deterministic ORDER BY (overlapping polygons currently pick arbitrarily).
