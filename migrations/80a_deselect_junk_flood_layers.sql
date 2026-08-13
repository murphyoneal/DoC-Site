-- =============================================================================
-- Item 80, step 1 (harm reduction, shipped first, alone):
-- De-select 8 flood layers that hold ~0 interior points in their named county
-- (20-118 rows each, wrong/empty). While selected they made get_parcel_flood_zone
-- return none_intersecting -> the report asserted "not in a Special Flood Hazard
-- Area" on EVERY parcel in these counties: a live regulatory false negative.
--
-- Setting table_name = NULL makes get_parcel_flood_zone return not_available
-- ("No county FEMA NFHL layer is held...") routed to §7 with msc.fema.gov — an
-- honest coverage gap instead of a false negative. The row is kept (not deleted)
-- so the de-selection reason is on record. These 8 counties hold no real layer;
-- they go to the flood-pull backlog.
--
-- Measured 2026-08-08 (interior-point-in-county / sampled): Alachua 0/36, Bay 6/35,
-- Brevard 2/32, Glades 6/118, Liberty 0/20, Manatee 1/21, Polk 0/71, Sarasota 0/26.
-- =============================================================================
UPDATE flood_layer_selection
   SET table_name = NULL,
       selected_by = 'de-selected 2026-08-08: junk layer (~0 interior points in county); no real FIRM held',
       needs_curation = false,
       notes = concat('DE-SELECTED (item 80): prior table ', coalesce(table_name,'?'),
                      ' had ~0 polygons inside the county — it was serving a false "not in SFHA". ',
                      'No real county FIRM is held; flood-pull backlog.')
 WHERE co_no IN (11, 13, 15, 32, 49, 51, 63, 68)   -- Alachua, Bay, Brevard, Glades, Liberty, Manatee, Polk, Sarasota
   AND table_name IS NOT NULL;
