-- 126b — correct 126a's UNANIMITY rule to a MODAL-SHARE rule.
--
-- 126a required every sampled point in a prefix to land in one county. Against live data that rejected
-- bay, glades, liberty, pinellas, polk, seminole AND volusia — seven real counties, Volusia the flagship —
-- because a county's own layers legitimately carry features just over the line (a road centreline, an
-- address point, a brownfield site near a border). Those counties would then have had NO verified prefix
-- and returned ZERO LAYERS: the exact defect being repaired, rebuilt by the repair.
--
-- Unanimity also never did the work it was meant to: nhd, hifld and control are genuinely statewide and
-- also showed 2 distinct counties, so a distinct-count test never separated them from Volusia.
--
-- THE DISCRIMINATOR IS MODAL SHARE, NOT DISPERSION. A county prefix has one dominant county and a few
-- stragglers; a statewide prefix has no dominant county. Sample wider (up to 6 tables x 3 rows) and
-- attribute on a >= 0.70 modal share. Measured separation is clean, not a knife edge:
--   rejected prefixes top out at 0.500 (control)      accepted counties bottom out at 0.750 (glades, liberty)
-- The threshold sits in an empty band. geoid_histogram records the full distribution either way, so a
-- rejection can be READ rather than trusted.
--
-- SAMPLING CAVEAT, recorded rather than hidden: rows are taken with LIMIT and no ORDER BY, so they come
-- off the first pages and can be spatially clustered (ruling 274 — control_points' first 200 rows were
-- one corner of the county). Drawing across up to 6 DIFFERENT tables is what mitigates it. Adequate for
-- "which county does this prefix belong to"; NOT adequate for any question about a layer's extent.
--
-- Applied 2026-08-28. Result: 109 prefixes county_verified across ALL 67 COUNTIES; 15 rejected as
-- multi_county_or_statewide (fl, fdep, fema, epa, nhd, nrhp, fuds, fgs, hifld, census, control, funnel,
-- gwca, hydrology, traffic); 4 no_geometry; 1 unattributable (sjrwmd).
-- The full function body as applied is in the Supabase migration of the same name.

ALTER TABLE public.county_table_prefix
  ADD COLUMN IF NOT EXISTS modal_share numeric,
  ADD COLUMN IF NOT EXISTS geoid_histogram jsonb;
