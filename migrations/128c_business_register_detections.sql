-- 128c — Standing checks for the business register (128a).

insert into public.data_defect_registry
  (defect_id, name, discovered_on, discovered_via, class, severity, detection_sql, expected_denominator,
   false_positive_notes, status, attribution, expected_state, remediation)
values
('business-register-integrity',
 'Business register: every register licence has one home business, keys are unique, no redirect shadows a live slug, and a retired slug still resolves on the served path',
 date '2026-09-24', 'work order 615 build', 'key_integrity', 'blocking',
 $d$select (
    (select count(*) = count(distinct business_key) from public.businesses)
    and not exists (select 1 from public.business_slug_redirects r join public.businesses b on b.slug = r.old_slug)
    and not exists (select 1 from public.contractors c join public.trade_code_registry t using (trade_code)
                     where t.department <> 'none'
                       and not exists (select 1 from public.business_licences bl
                                        where bl.contractor_id = c.id and bl.link_basis = 'member'))
    and not exists (select 1 from public.businesses b
                     where not exists (select 1 from public.business_licences bl
                                        where bl.business_id = b.id and bl.contractor_id = b.canonical_contractor_id
                                          and bl.link_basis = 'member'))
    and (public.resolve_business_slug('red-stag-contracting-inc-jacksonville-fl-2')->>'slug') = 'red-stag-contracting-inc-jacksonville-fl'
    and (public.resolve_business_slug('red-stag-contracting-inc-jacksonville-fl-2')->>'redirect')::boolean
    and jsonb_array_length(public.get_business_licences('red-stag-contracting-inc-jacksonville-fl')) = 2
  ) as ok$d$,
 'all register rows (contractors where department <> none); all businesses; all redirects',
 'SERVED PATH: the last three terms call resolve_business_slug / get_business_licences — the RPCs the /c/[slug] page uses — on the founding case (Red Stag Contracting: CBC1255193 + CCC1329994, two rows, one business). If DBPR ever drops one of those licences the licence-count term goes red for a real reason; re-point the founding case, do not delete the term. The structural terms cannot see whether the KEY is right, only that it is consistent — the key rules are rulings, not measurements. Negative control 2026-09-24: a redirect shadowing a live slug turned the shadow term false (rolled back).',
 'active', 'ours', 'clean',
 'Re-run public.rebuild_business_register() — idempotent. If it raises, the build is empty or inconsistent and nothing was committed.'),
('business-name-cardinality-unruled',
 'A business name shared by many rows at many addresses has no ruling — it may be a placeholder (never merge) or a real brand (merge per store)',
 date '2026-09-24', 'work order 615 build', 'entity_confusion', 'material',
 $d$with k as (
    select public.business_norm(c.business_name) nm,
           public.business_norm(c.address_line_1) || '|' || left(coalesce(c.zip_code,''),5) addr
      from public.contractors c join public.trade_code_registry t using (trade_code)
     where t.department <> 'none'),
  flagged as (
    select nm from k where nm <> '' group by nm
    having count(*) >= 15 and count(distinct addr)::numeric / count(*) >= 0.8)
  select not exists (select 1 from flagged f
                      where not exists (select 1 from public.business_name_rulings r where r.name_norm = f.nm)) as ok,
         (select count(*) from flagged f
           where not exists (select 1 from public.business_name_rulings r where r.name_norm = f.nm)) as row_count,
         (select string_agg(f.nm, ', ') from flagged f
           where not exists (select 1 from public.business_name_rulings r where r.name_norm = f.nm)) as detail$d$,
 'business names with >= 15 register rows',
 'A REVIEW LIST, NEVER AN ACTION LIST. Calibrated 2026-09-24: the thresholds flag INDIVIDUAL (placeholder, 0.94), PINCH A PENNY (franchise, 0.82) and D R HORTON INC (0.88) — the rule cannot tell a placeholder from a franchise, which is why a ruling in business_name_rulings decides and this check only queues. Red means a name awaits a ruling, not that anything was merged wrongly. Went red on day one for D R HORTON INC, by design.',
 'active', 'ours', 'clean',
 'Insert a row into business_name_rulings (placeholder | real_business) with the evidence, then re-run rebuild_business_register().')
on conflict (defect_id) do nothing;
