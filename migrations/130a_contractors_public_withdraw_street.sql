-- 130a — Withdraw contractor street addresses from every public surface (ruling 2026-09-24,
-- ahead of the queue: a live exposure, not a build).
--
-- contractors_public is anon-readable over REST with the publishable key (in page source by
-- design). It carried address_line_1/address_line_2 for 112,459 licence records — mostly sole
-- traders' homes, worst case a profile headed "INDIVIDUAL" showing someone's house — plus
-- lat/lng at 7 decimals, Census-TIGER-geocoded FROM that street address (98,409 rows). The
-- coordinates are the address in another encoding; withdrawing one and not the other withdraws
-- nothing.
--
-- Ruling: publish city, county, state, zip. Street returns only by the claimant's own choice at
-- claim time (row 639, schema default off) — not built yet.
--
-- HOW: CREATE OR REPLACE with the SAME columns, same names and types. address_line_1/2 become
-- null; lat/lng are rounded to 2 decimals (cast back to numeric(10,7), the column's type, so
-- CREATE OR REPLACE is allowed; the check is value = round(value,2), not scale) (~1.1 km — a map pin at neighbourhood level, not a
-- house). No column disappears, so nothing that selects them breaks (forMap selects
-- address_line_1 explicitly), the dependent view work_gallery_public is untouched, and the
-- grants survive (no DROP). The profile, vCard ADR and map popup already fall back cleanly on
-- null, so all four surfaces lose the street the moment this applies. The app is tidied
-- separately so a future view change cannot silently re-expose it.
--
-- NOT CHANGED, noted: phone/email are also served (business contact, from DBPR); the stored
-- values in contractors are untouched (nothing deleted — the claim tick-box needs them).

create or replace view public.contractors_public as
 SELECT id, slug, business_name, trading_name, display_name, trade_code, trade_label, doc_category,
    service_categories, classifications, license_number, license_status, primary_status,
    secondary_status, original_date, effective_date, expiry_date, phone, email, website,
    NULL::text AS address_line_1,
    NULL::text AS address_line_2,
    city, state, zip_code, county_code, county_name, country, service_radius_km, service_lat,
    service_lng, in_volusia, bond_amount, bond_company, bond_expiry, bond_status,
    workers_comp_on_file, insurance_company, insurance_expiry, rmi_name, license_endorsement, tier,
    verified, verified_at, claimed, active, profile_tier_label, description, years_in_business,
    employee_count, certifications, specialist_notes, profile_photo, work_photos, logo_url,
    ada_compliant_work, aging_in_place, chemical_sensitivity_aware, mobility_accessible_worksite,
    hurricane_hardening, impact_window_certified, roof_certification, storm_restoration,
    emergency_available, emergency_response_hours, emergency_plumbing, emergency_roofing,
    emergency_electrical, emergency_storm_damage, emergency_water_damage, emergency_board_up,
    lbp_number, lbp_classes, lbp_status, lbp_expiry, qr_code_url, source, source_url, source_state,
    created_at, updated_at, geocoded,
    round(lat, 2)::numeric(10,7) AS lat,
    round(lng, 2)::numeric(10,7) AS lng,
    country_code, geocode_quality
   FROM contractors
  WHERE active IS TRUE AND NOT (EXISTS ( SELECT 1
           FROM trade_code_registry tr
          WHERE tr.trade_code = contractors.trade_code AND tr.department = 'none'::text));

insert into public.data_defect_registry
  (defect_id, name, discovered_on, discovered_via, class, severity, detection_sql, expected_denominator,
   false_positive_notes, status, attribution, expected_state, remediation)
values
('contractors-public-serves-street-or-rooftop-coordinates',
 'The anon-readable contractors_public view must serve no street address and no coordinate finer than 2 decimals',
 date '2026-09-24', 'full audit (row 638) and ruling 639', 'access_control', 'blocking',
 $d$select (
    not exists (select 1 from public.contractors_public
                 where address_line_1 is not null or address_line_2 is not null
                    or lat <> round(lat, 2) or lng <> round(lng, 2))
    and exists (select 1 from public.contractors_public where city is not null)
  ) as ok$d$,
 'every row of contractors_public',
 'SERVED SURFACE: contractors_public is what /c/[slug], /api/vcard, the map and anon REST read. The last term keeps it from passing on an empty view. It cannot see a NEW view or RPC that reads contractors.address_line_1 directly — a street served some other way is invisible to it. When the claim-time "show my street address" choice (row 639) is built, this check must be rewritten to allow street only for an approved claim that chose it, not deleted. Negative control 2026-09-24: the pre-130a view definition failed this check (112k rows with street, 98k 7-decimal coordinates).',
 'active', 'ours', 'clean',
 'Find what re-exposed it; the view must null address_line_1/2 and round lat/lng to 2 decimals.')
on conflict (defect_id) do nothing;
