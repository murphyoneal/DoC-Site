-- 161a: the review page's database side (ruling 762 part 5; 768: it is the PUBLICATION GATE, not a monitor).
--
-- Every action the page can take is an operator_* function that (1) refuses anyone not in
-- operator_account, (2) requires a basis, (3) makes the change, and (4) writes the append-only
-- moderation_action row in the same transaction - so an action cannot happen without its record (765.7).
-- The page never writes a table directly. Destructive actions are POSTs from an authenticated page, never
-- links in an email (762).

create or replace function public.is_operator(p_email text) returns boolean
language sql stable security definer set search_path = public as $f$
  select exists (select 1 from operator_account where email = lower(btrim(coalesce(p_email, ''))))
$f$;
revoke all on function public.is_operator(text) from public, anon, authenticated;
grant execute on function public.is_operator(text) to service_role;

create or replace function public._operator_check(p_actor text, p_basis text) returns void
language plpgsql stable security definer set search_path = public as $f$
begin
  if not is_operator(p_actor) then raise exception 'only an operator can do this'; end if;
  if length(btrim(coalesce(p_basis, ''))) < 3 then raise exception 'a basis is required'; end if;
end $f$;
revoke all on function public._operator_check(text, text) from public, anon, authenticated;

create or replace function public._log_action(p_actor text, p_action text, p_table text, p_ids text[], p_before jsonb, p_after jsonb, p_basis text, p_ip inet)
returns void language sql security definer set search_path = public as $f$
  insert into moderation_action (occurred_at, actor, actor_kind, action, target_table, target_ids, before_state, after_state, basis, via, ip)
  values (now(), lower(btrim(p_actor)), 'operator', p_action, p_table, p_ids, p_before, p_after, btrim(p_basis), '/review', p_ip)
$f$;
revoke all on function public._log_action(text, text, text, text[], jsonb, jsonb, text, inet) from public, anon, authenticated;

-- PHOTOS: approve publishes (the route has already copied the file to the public bucket and verified it
-- carries no metadata, and passes its public path); reject holds it privately. Both logged.
create or replace function public.operator_photo_decision(p_contribution_id uuid, p_approve boolean, p_public_path text, p_actor text, p_basis text, p_ip inet)
returns jsonb language plpgsql security definer set search_path = public as $f$
declare v text;
begin
  perform _operator_check(p_actor, p_basis);
  select visibility into v from work_contribution where id = p_contribution_id;
  if v is null then raise exception 'no such photo'; end if;
  if v like 'withdrawn%' then raise exception 'the business removed this photo'; end if;
  if p_approve then
    if p_public_path is null then raise exception 'approve needs the verified public copy'; end if;
    update work_contribution_image set public_path = p_public_path where contribution_id = p_contribution_id;
    update work_contribution set visibility = 'public', updated_at = now() where id = p_contribution_id;
  else
    update work_contribution set visibility = 'held', updated_at = now() where id = p_contribution_id;
  end if;
  perform _log_action(p_actor, case when p_approve then 'photo_approved' else 'photo_rejected' end, 'work_contribution',
                      array[p_contribution_id::text], jsonb_build_object('visibility', v),
                      jsonb_build_object('visibility', case when p_approve then 'public' else 'held' end), p_basis, p_ip);
  return jsonb_build_object('ok', true, 'visibility', case when p_approve then 'public' else 'held' end);
end $f$;

-- FIELDS: unpublish, never edit. Switches one publish_* flag off; optionally resolves a language flag.
create or replace function public.operator_unpublish_field(p_business_id uuid, p_field text, p_flag_id bigint, p_actor text, p_basis text, p_ip inet)
returns jsonb language plpgsql security definer set search_path = public as $f$
declare col text;
begin
  perform _operator_check(p_actor, p_basis);
  col := case p_field
    when 'phone' then 'publish_phone' when 'email' then 'publish_email' when 'website' then 'publish_website'
    when 'description' then 'publish_description' when 'specialties' then 'publish_specialties'
    when 'other_specialties' then 'publish_specialties' when 'coverage' then 'publish_coverage'
    when 'years' then 'publish_years' when 'logo' then 'publish_logo' end;
  if col is null then raise exception 'unknown field %', p_field; end if;
  -- updated_at is the BUSINESS's save time; an operator unpublish must not look like their save.
  execute format('update business_profile set %I = false where business_id = $1', col) using p_business_id;
  if col = 'publish_coverage' then update business_profile set publish_counties = false where business_id = p_business_id; end if;
  perform _log_action(p_actor, 'field_unpublished', 'business_profile', array[p_business_id::text],
                      jsonb_build_object(col, true), jsonb_build_object(col, false), p_basis, p_ip);
  if p_flag_id is not null then
    perform _log_action(p_actor, 'language_flag_unpublished', 'language_flag', array[p_flag_id::text], null,
                        jsonb_build_object('unpublished', col), p_basis, p_ip);
  end if;
  return jsonb_build_object('ok', true, 'unpublished', col);
end $f$;

create or replace function public.operator_flag_ok(p_flag_id bigint, p_actor text, p_basis text, p_ip inet)
returns jsonb language plpgsql security definer set search_path = public as $f$
begin
  perform _operator_check(p_actor, p_basis);
  if not exists (select 1 from language_flag where id = p_flag_id) then raise exception 'no such flag'; end if;
  perform _log_action(p_actor, 'language_flag_reviewed_ok', 'language_flag', array[p_flag_id::text], null, null, p_basis, p_ip);
  return jsonb_build_object('ok', true);
end $f$;

-- CLAIMS AND REGISTRATIONS: the existing review functions, behind the operator check, with a record.
create or replace function public.operator_review(p_kind text, p_id uuid, p_decision text, p_actor text, p_basis text, p_ip inet)
returns jsonb language plpgsql security definer set search_path = public as $f$
declare r jsonb;
begin
  perform _operator_check(p_actor, p_basis);
  r := case p_kind
    when 'contractor_claim' then review_claim(p_id, p_decision, p_basis)
    when 'agent_claim' then review_agent_claim(p_id, p_decision, p_basis)
    when 'registration' then review_registration(p_id, p_decision, p_basis)
  end;
  if r is null then raise exception 'unknown kind %', p_kind; end if;
  perform _log_action(p_actor, p_kind || '_' || p_decision, case p_kind when 'contractor_claim' then 'claim_requests'
                        when 'agent_claim' then 'agent_claim_request' else 'registered_business' end,
                      array[p_id::text], null, jsonb_build_object('decision', p_decision), p_basis, p_ip);
  return r;
end $f$;

-- THE QUEUE: everything the page shows, in one read. Flags first.
create or replace function public.review_queue() returns jsonb
language sql stable security definer set search_path = public as $f$
  select jsonb_build_object(
    'flags', coalesce((select jsonb_agg(x order by x->>'flagged_at' desc) from (
        select jsonb_build_object('id', f.id, 'table', f.subject_table, 'key', f.subject_key, 'field', f.field, 'text', f.text_as_saved,
                 'rules', f.rules, 'flagged_at', f.flagged_at,
                 'slug', case f.subject_table when 'business_profile' then (select slug from businesses where id::text = f.subject_key)
                                              when 'agent_public_profile' then f.subject_key
                                              when 'registered_business' then (select slug from registered_business where id::text = f.subject_key) end,
                 'business_id', case when f.subject_table = 'business_profile' then f.subject_key end) x
          from language_flag_state f where f.state = 'flagged') q), '[]'::jsonb),
    'photos', coalesce((select jsonb_agg(x order by x->>'created_at') from (
        select jsonb_build_object('id', c.id, 'visibility', c.visibility, 'created_at', c.created_at, 'description', c.description,
                 'held_path', i.held_path, 'image_id', i.id,
                 'slug', b.slug, 'name', b.display_name,
                 'unchecked', not exists (select 1 from scan_result s where s.image_id = i.id and s.slot = 'classification' and s.state in ('pass', 'flag')),
                 'scans', (select jsonb_agg(jsonb_build_object('slot', s.slot, 'provider', s.provider, 'state', s.state) order by s.slot)
                             from scan_result s where s.image_id = i.id)) x
          from work_contribution c
          join work_contribution_image i on i.contribution_id = c.id
          left join business_licences bl on bl.contractor_id = c.contractor_id
          left join businesses b on b.id = bl.business_id
         where c.visibility in ('pending_scan', 'pending_review', 'held')) q), '[]'::jsonb),
    'profiles', coalesce((select jsonb_agg(x order by x->>'updated_at' desc) from (
        select jsonb_build_object('business_id', p.business_id, 'slug', b.slug, 'name', b.display_name, 'updated_at', p.updated_at,
                 'description', case when p.publish_description then p.description end,
                 'specialties', case when p.publish_specialties then p.specialties end,
                 'other_specialties', case when p.publish_specialties then p.other_specialties end,
                 'website', case when p.publish_website then p.website end,
                 'logo_path', case when p.publish_logo then p.logo_path end,
                 'suspended', business_is_suspended(p.business_id)) x
          from business_profile p join businesses b on b.id = p.business_id
         where p.updated_at > now() - interval '14 days') q), '[]'::jsonb),
    'claims', coalesce((select jsonb_agg(jsonb_build_object('id', cr.id, 'kind', 'contractor_claim', 'licence', cr.license_number,
                 'name', cr.requester_name, 'email', cr.requester_email, 'match', cr.licence_match_state, 'at', cr.created_at,
                 'slug', (select b.slug from business_licences bl join businesses b on b.id = bl.business_id where bl.contractor_id = cr.contractor_id limit 1))
                 order by cr.created_at)
          from claim_requests cr where cr.status = 'pending'), '[]'::jsonb)
      || coalesce((select jsonb_agg(jsonb_build_object('id', a.id, 'kind', 'agent_claim', 'licence', a.license_number,
                 'name', a.requester_name, 'email', a.requester_email, 'at', a.created_at) order by a.created_at)
          from agent_claim_request a where a.status = 'pending'), '[]'::jsonb),
    'registrations', coalesce((select jsonb_agg(jsonb_build_object('id', r.id, 'kind', 'registration', 'name', r.business_name,
                 'email', r.contact_email, 'slug', r.slug, 'duplicate', r.florida_duplicate_state, 'at', r.created_at) order by r.created_at)
          from registered_business r where r.review_state = 'received'), '[]'::jsonb),
    'suspended', coalesce((select jsonb_agg(jsonb_build_object('business_id', b.id, 'slug', b.slug, 'name', b.display_name,
                 'appeals', (select jsonb_agg(jsonb_build_object('explanation', ap.explanation, 'from', ap.submitted_by, 'at', ap.submitted_at) order by ap.submitted_at)
                               from business_appeal ap where ap.business_id = b.id)))
          from businesses b
         where b.id in (select distinct t::uuid from moderation_action m, unnest(m.target_ids) t
                         where m.target_table = 'businesses' and m.action in ('business_suspended', 'business_reinstated'))
           and business_is_suspended(b.id)), '[]'::jsonb),
    'volume', (select jsonb_build_object('uploads_24h', (select count(*) from work_contribution where created_at > now() - interval '24 hours'),
                 'limit', limit_value, 'warn_at', warn_at) from operating_threshold where name = 'photo_uploads_per_day'),
    'generated_at', now())
$f$;

do $m$ declare f text; begin
  foreach f in array array['operator_photo_decision(uuid,boolean,text,text,text,inet)', 'operator_unpublish_field(uuid,text,bigint,text,text,inet)',
                           'operator_flag_ok(bigint,text,text,inet)', 'operator_review(text,uuid,text,text,text,inet)', 'review_queue()'] loop
    execute format('revoke all on function public.%s from public, anon, authenticated', f);
    execute format('grant execute on function public.%s to service_role', f);
  end loop;
end $m$;

-- controls, rolled back: a non-operator is refused on every action; the queue reads.
do $m$ declare q jsonb; begin
  q := review_queue();
  if q->'photos' is null or q->'flags' is null then raise exception '161a: queue shape'; end if;
  begin perform operator_flag_ok(0, 'someone@example.com', 'x basis', null); raise exception 'CONTROL_FAILED';
  exception when others then if sqlerrm = 'CONTROL_FAILED' then raise exception '161a: non-operator passed operator_flag_ok'; end if; end;
  begin perform operator_photo_decision(gen_random_uuid(), false, null, 'someone@example.com', 'x basis', null); raise exception 'CONTROL_FAILED';
  exception when others then if sqlerrm = 'CONTROL_FAILED' then raise exception '161a: non-operator passed operator_photo_decision'; end if; end;
  begin perform operator_review('registration', gen_random_uuid(), 'approved', 'someone@example.com', 'x basis', null); raise exception 'CONTROL_FAILED';
  exception when others then if sqlerrm = 'CONTROL_FAILED' then raise exception '161a: non-operator passed operator_review'; end if; end;
end $m$;
