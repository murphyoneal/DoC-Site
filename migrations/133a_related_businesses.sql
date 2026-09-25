-- 133a — Related businesses for the profile page (work order 653 (c)).
--
-- The profile was a dead end: the only way off it was the browser back button. The question
-- behind most visits is "who else does this, near here" — answerable from data we hold.
--
-- RULES (rulings 2026-09-24/25):
--   * Same trade (doc_category) and same county as the business shown.
--   * ORDER IS NEVER EVALUATIVE: claimed first, then alphabetical. Anything else is a ranking.
--   * One entry per BUSINESS (the canonical licence record), never per licence row.
--   * Businesses under a ruled placeholder name are left out of the list: they would render as
--     "INDIVIDUAL", naming nobody. They stay findable by search.
--   * Reads contractors_public, so continuing-education providers (department none) never appear.
--
-- Three coverage states: present / none_recorded (none in that trade+county) / null (the slug is
-- not in the register).

create index if not exists businesses_canonical_contractor_idx on public.businesses (canonical_contractor_id);
create index if not exists contractors_doc_category_county_idx on public.contractors (doc_category, county_code);

create or replace function public.get_related_businesses(p_slug text, p_limit int default 6)
returns jsonb language sql stable security definer set search_path = public, pg_temp as
$$
  with me as (
    select b.id, c.doc_category, c.county_code, c.county_name
      from businesses b join contractors c on c.id = b.canonical_contractor_id
     where b.slug = p_slug),
  cand as (
    select b.slug, coalesce(c.display_name, c.business_name) as name, c.trade_label, c.city,
           coalesce(c.claimed, false) as claimed
      from me
      join contractors_public c on c.doc_category = me.doc_category and c.county_code = me.county_code
      join businesses b on b.canonical_contractor_id = c.id
     where b.id <> me.id and b.key_basis <> 'singleton_placeholder_name'
     order by coalesce(c.claimed, false) desc, coalesce(c.display_name, c.business_name)
     limit greatest(1, least(coalesce(p_limit, 6), 20)))
  select case
    when not exists (select 1 from me) then null
    else jsonb_build_object(
      'field_status', case when exists (select 1 from cand) then 'present' else 'none_recorded' end,
      'county_name', (select county_name from me),
      'order', 'claimed first, then alphabetical — not a ranking',
      'items', coalesce((select jsonb_agg(jsonb_build_object('slug', slug, 'name', name,
                  'trade_label', trade_label, 'city', city, 'claimed', claimed)
                  order by claimed desc, name) from cand), '[]'::jsonb))
  end
$$;

revoke all on function public.get_related_businesses(text, int) from public, anon, authenticated;
grant execute on function public.get_related_businesses(text, int) to service_role;
