-- 148b — the registration check looks in the RIGHT register for each state (148a). Until now every
-- held register was assumed to be Florida's contractors table; with Oregon held, an Oregon number
-- would have been searched for in the Florida file and reported "not found" - a false negative about
-- a real licence. Each held (state, profession) now has its own lookup; a register marked held with
-- no lookup written for it answers not_held rather than guessing. Applied BEFORE Oregon is marked
-- held, so there is no window in which the wrong table answers.
create or replace function public.registration_check_credential(p_kind text, p_state text, p_profession text, p_number text)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_cov   register_coverage%rowtype;
  v_norm  text := _reg_norm_licence(p_number);
  v_prof  text := coalesce(p_profession, 'construction');
  v_state text; v_hit record; v_date text; v_found boolean := false;
begin
  if p_kind <> 'licence' then
    return jsonb_build_object('check_state', 'register_not_held',
      'check_note', 'We do not hold ' || case when p_kind = 'insurance' then 'insurance' else 'certification' end || ' records, so this cannot be checked.');
  end if;
  select name into v_state from geo_reference where geo_id = p_state;
  if p_state = 'US-12' and v_norm ~ '^E[CRF][0-9]' then v_prof := 'electrical'; end if;
  select * into v_cov from register_coverage where state_geo_id = p_state and profession = v_prof;
  if not found or v_cov.coverage_state <> 'held' or v_norm = '' then
    return jsonb_build_object('check_state', 'register_not_held', 'profession', v_prof,
      'check_note', 'Not verified. We don''t yet hold ' || coalesce(v_state, 'this state') || '''s '
        || case when v_prof = 'electrical' then 'electrical ' else '' end
        || 'licence records, so we can''t check this against the state register.');
  end if;
  v_date := to_char(coalesce(v_cov.posted_date, v_cov.retrieved_date), 'FMDD Mon YYYY');

  -- ---- Florida construction: the DBPR copy (unchanged from 141c) ----
  if p_state = 'US-12' and v_prof = 'construction' then
    select c.id, c.license_number, c.register_file_state, b.slug into v_hit
      from contractors c
      left join business_licences bl on bl.contractor_id = c.id
      left join businesses b on b.id = bl.business_id
     where _reg_norm_licence(c.license_number) = v_norm
     order by (c.register_file_state = 'in_latest_file') desc
     limit 1;
    if not found then
      return jsonb_build_object('check_state', 'register_held_no_match', 'profession', v_prof,
        'checked_against', v_cov.source || ', retrieved ' || to_char(v_cov.retrieved_date, 'FMDD Mon YYYY'),
        'check_note', 'Not found in the ' || v_state || ' licence file retrieved ' || to_char(v_cov.retrieved_date, 'FMDD Mon YYYY') || '.');
    end if;
    return jsonb_build_object('check_state', 'register_held_matched', 'profession', v_prof,
      'checked_against', v_cov.source || ', retrieved ' || to_char(v_cov.retrieved_date, 'FMDD Mon YYYY'),
      'matched_contractor_id', v_hit.id, 'matched_slug', v_hit.slug,
      'check_note', 'Matches the ' || v_state || ' licence file retrieved ' || to_char(v_cov.retrieved_date, 'FMDD Mon YYYY')
        || case when v_hit.register_file_state = 'absent_from_latest_file' then ' (the licence was in an earlier file and is not in the latest one)' else '' end || '.');
  end if;

  -- ---- Oregon construction: CCB active licences (148a). The file lists ACTIVE licences only. ----
  if p_state = 'US-41' and v_prof = 'construction' then
    select o.license_number, o.register_file_state,
           string_agg(coalesce(o.endorsement_text, o.license_type), '; ' order by o.license_type) as types
      into v_hit
      from reg_us_or.ccb_active_license o
     where _reg_norm_licence(o.license_number) = v_norm
     group by o.license_number, o.register_file_state
     order by (o.register_file_state = 'in_latest_file') desc
     limit 1;
    if not found then
      return jsonb_build_object('check_state', 'register_held_no_match', 'profession', v_prof,
        'checked_against', v_cov.source || ', dated ' || v_date,
        'check_note', 'Not found in the Oregon CCB active-licence file dated ' || v_date
          || '. That file lists active licences only, so a lapsed or inactive licence would not appear in it.');
    end if;
    return jsonb_build_object('check_state', 'register_held_matched', 'profession', v_prof,
      'checked_against', v_cov.source || ', dated ' || v_date,
      'check_note', case when v_hit.register_file_state = 'in_latest_file'
          then 'Matches the Oregon CCB active-licence file dated ' || v_date || ' (' || v_hit.types || ').'
          else 'Was in an earlier Oregon CCB active-licence file and is not in the one dated ' || v_date || ' (' || v_hit.types || ').' end);
  end if;

  -- held, but no lookup written for this register: do not guess
  return jsonb_build_object('check_state', 'register_not_held', 'profession', v_prof,
    'check_note', 'Not verified. We hold ' || coalesce(v_state, 'this state') || '''s register but cannot check this licence against it yet.');
end $$;
revoke all on function public.registration_check_credential(text, text, text, text) from public, anon, authenticated;
grant execute on function public.registration_check_credential(text, text, text, text) to service_role;
