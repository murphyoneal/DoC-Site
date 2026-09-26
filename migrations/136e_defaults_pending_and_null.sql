-- 136e — Three rulings of 2026-09-26 on the 136d review list.
--
-- 1. pir_purchases.status: DEFAULT 'paid' -> 'pending'. "paid is the only value a payment should
--    ever acquire by evidence." COUPLED, and in ONE transaction for that reason: record_pir_purchase
--    (the Stripe webhook's only write path, called after the signature and payment_status=paid are
--    verified) did NOT name status — it relied on the default. Changing the default alone would
--    have left every real purchase 'pending' and pir_is_unlocked (status='paid') false: a paying
--    customer locked out. So the function now writes 'paid' explicitly, and the default changes in
--    the same migration. 0 rows today. SECURITY DEFINER, service_role-only; grant re-asserted.
-- 2. contractors certifications / service_categories / classifications / lbp_classes (and
--    personnel_names, same test, not served): DEFAULT '{}' -> no default, all rows NULL. Empty
--    array = "we asked and there are none"; NULL = "not stated". 0 non-empty rows; no writer in
--    the repo, pg_proc or WSL; readers are the contractors_public passthrough and nullable types.
-- 3. county_export_survey.export_capability / vendor_fingerprint: DEFAULT 'none found' ->
--    'pending'. The default collapsed the table's own none-found vs pending distinction. Existing
--    rows are already correct ('none found' only on 2 rows with survey_status='surveyed').

-- 1 -------------------------------------------------------------------------------------------
do $f$
declare def text; new_def text;
begin
  def := pg_get_functiondef('public.record_pir_purchase(text,numeric,text,text,integer,text,text,uuid,text)'::regprocedure);
  new_def := replace(def,
    'INSERT INTO public.pir_purchases(session_id, co_no, parcel_id, email, amount_cents, currency, address, consumer_id, payment_intent)',
    'INSERT INTO public.pir_purchases(session_id, co_no, parcel_id, email, amount_cents, currency, address, consumer_id, payment_intent, status)');
  new_def := replace(new_def,
    'nullif(p_address,''''), p_consumer_id, nullif(p_payment_intent,''''))',
    'nullif(p_address,''''), p_consumer_id, nullif(p_payment_intent,''''), ''paid'')');
  if new_def = def or position('payment_intent, status)' in new_def) = 0 or position(', ''paid'')' in new_def) = 0 then
    raise exception '136e: record_pir_purchase anchor not found - nothing applied';
  end if;
  execute new_def;
end $f$;

grant execute on function public.record_pir_purchase(text,numeric,text,text,integer,text,text,uuid,text) to service_role;

alter table public.pir_purchases alter column status set default 'pending';
comment on column public.pir_purchases.status is
  'pending by default; ''paid'' is written ONLY by record_pir_purchase, which the Stripe webhook calls after verifying the signature and payment_status=paid. pir_is_unlocked requires paid. Default was ''paid'' until 136e (2026-09-26).';

-- 2 -------------------------------------------------------------------------------------------
do $m$
declare col text; n bigint;
begin
  foreach col in array array['certifications','service_categories','classifications','lbp_classes','personnel_names'] loop
    execute format('select count(*) from public.contractors where cardinality(%I) > 0', col) into n;
    if n <> 0 then raise exception '136e: contractors.% has % non-empty rows - not a default-only column', col, n; end if;
    execute format('alter table public.contractors alter column %I drop default', col);
    execute format('comment on column public.contractors.%I is %L', col,
      'NULL = NOT STATED by the business. An empty array would mean "asked, and there are none". Was DEFAULT ''{}'' on every row until 136e (2026-09-26).');
  end loop;
  update public.contractors set certifications = null, service_categories = null, classifications = null,
         lbp_classes = null, personnel_names = null
   where certifications is not null or service_categories is not null or classifications is not null
      or lbp_classes is not null or personnel_names is not null;
end $m$;

-- 3 -------------------------------------------------------------------------------------------
alter table public.county_export_survey alter column export_capability set default 'pending';
alter table public.county_export_survey alter column vendor_fingerprint set default 'pending';

-- The judgement table follows the rulings.
update public.column_default_authorship set authorship = 'ours', classified_on = current_date,
       reason = 'pending by default; paid is set only by evidence (record_pir_purchase after a verified Stripe payment). Ruling 2026-09-26, 136e.'
 where table_name = 'pir_purchases' and column_name = 'status';
update public.column_default_authorship set authorship = 'theirs_unknown_sentinel', classified_on = current_date,
       reason = '''pending'' - not yet surveyed. Was ''none found'' (a finding by default) until 136e.'
 where table_name = 'county_export_survey' and column_name in ('export_capability','vendor_fingerprint');

-- Assertions: the coupled pair, exercised and rolled back.
do $a$
declare unlocked_via_fn boolean; raw_status text; unlocked_raw boolean; n bigint;
begin
  begin
    perform public.record_pir_purchase('cs_136e_probe_fn', 99, '136E-PROBE-FN', null, 500, 'usd', null, null, null);
    select public.pir_is_unlocked(99, '136E-PROBE-FN') into unlocked_via_fn;
    insert into public.pir_purchases(session_id, co_no, parcel_id) values ('cs_136e_probe_raw', 99, '136E-PROBE-RAW');
    select status into raw_status from public.pir_purchases where session_id = 'cs_136e_probe_raw';
    select public.pir_is_unlocked(99, '136E-PROBE-RAW') into unlocked_raw;
    raise exception using errcode = 'P0136', message = 'probe rollback';
  exception when sqlstate 'P0136' then null;
  end;
  if unlocked_via_fn is distinct from true then raise exception '136e: a webhook-recorded purchase does not unlock'; end if;
  if raw_status is distinct from 'pending' then raise exception '136e: a status-less row is %, not pending', raw_status; end if;
  if unlocked_raw is distinct from false then raise exception '136e: a status-less row unlocks the report'; end if;
  if not has_function_privilege('service_role', 'public.record_pir_purchase(text,numeric,text,text,integer,text,text,uuid,text)', 'EXECUTE') then
    raise exception '136e: service_role lost EXECUTE on record_pir_purchase';
  end if;
  select count(*) into n from public.pir_purchases where session_id like 'cs_136e_probe%';
  if n <> 0 then raise exception '136e: probe rows leaked'; end if;
  select count(*) into n from public.contractors where certifications is not null or lbp_classes is not null
     or service_categories is not null or classifications is not null or personnel_names is not null;
  if n <> 0 then raise exception '136e: % contractor rows still hold an array', n; end if;
end $a$;
