-- 156a: get_parcel_attestations stops serving disputes (ruling 746).
--
-- attestation_register.disputes_finding is a LICENSED ATTESTER's statement that our own sourced
-- finding is wrong. get_parcel_attestations served it as field_status 'discrepancy' plus a DISPUTE
-- note, through get_parcel_env_findings, to Roz (roz_payload_reader) and the paid consumer report
-- (consumer_report_readonly). No attestation flow exists that authenticates the attester or checks
-- their licence at the moment of statement, so that contradiction would publish unverified. 0 rows
-- today; 0 rows is not a control, no path is.
--
-- The served entry encoded the bit twice - field_status and the note. The function now serves ONLY rows
-- where the attester stated no dispute (disputes_finding = false; the column is NOT NULL with no default
-- since 136f, so every row states it one way or the other). Disputing rows are withheld. No new
-- field_status value is introduced (Roz's prompt reads field_status vocabulary). Everything else in the
-- entry is unchanged. Restore the dispute branch only with an authenticated attestation flow.
-- Proven in a rolled-back tx on golden parcel Volusia 371300000020 through get_parcel_env_findings:
-- agreeing row served; disputing row, is_test row, DISPUTE note and 'discrepancy' all absent.
--
-- Also: column_writer records disputes_finding as 'subject' (author: the named attester). Its
-- sanctioned_writers is EMPTY, which now means "no path is sanctioned to write it yet" - so the
-- CHECK is relaxed from cardinality > 0 to NOT NULL: an explicit empty list, never a missing one.

do $m$
declare d text; n text;
  g_roz boolean := has_function_privilege('roz_payload_reader', 'public.get_parcel_attestations(numeric,text)', 'execute');
  g_cr  boolean := has_function_privilege('consumer_report_readonly', 'public.get_parcel_attestations(numeric,text)', 'execute');
begin
  d := pg_get_functiondef('public.get_parcel_attestations(numeric,text)'::regprocedure);

  n := replace(d, $a$is_test=false order by attested_at desc loop$a$,
                  $a$is_test=false and disputes_finding = false order by attested_at desc loop$a$);
  if n = d then raise exception '156a: row-filter anchor not found'; end if; d := n;

  n := replace(d, $a$'field_status', case when r.disputes_finding then 'discrepancy' else 'present' end,$a$,
                  $a$'field_status', 'present',$a$);
  if n = d then raise exception '156a: field_status anchor not found'; end if; d := n;

  n := replace(d, $a$'note', case when r.disputes_finding then
        'DISPUTE recorded ALONGSIDE the sourced finding ('||coalesce(r.disputed_finding_ref,'')||') — the original is intact, this does not suppress it. A dispute against an authority argues value upward and carries higher risk than an added defect; treat with caution and attribute.'
        else 'An attestation is a person''s statement, never promoted to a county fact. Attribute it ('||r.source_class||': '||r.attester_name||'); a contractor/inspector claim is verifiable, an owner claim is not.' end);$a$,
                  $a$'note', 'An attestation is a person''s statement, never promoted to a county fact. Attribute it ('||r.source_class||': '||r.attester_name||'); a contractor/inspector claim is verifiable, an owner claim is not.');$a$);
  if n = d then raise exception '156a: note anchor not found'; end if; d := n;

  execute d;

  if position('disputes_finding' in pg_get_functiondef('public.get_parcel_attestations(numeric,text)'::regprocedure))
     <> position('disputes_finding = false' in pg_get_functiondef('public.get_parcel_attestations(numeric,text)'::regprocedure)) then
    raise exception '156a: disputes_finding is read somewhere other than the row filter'; end if;
  if position('discrepancy' in pg_get_functiondef('public.get_parcel_attestations(numeric,text)'::regprocedure)) > 0 then
    raise exception '156a: discrepancy still emitted'; end if;
  if g_roz and not has_function_privilege('roz_payload_reader', 'public.get_parcel_attestations(numeric,text)', 'execute') then
    raise exception '156a: roz_payload_reader lost EXECUTE'; end if;
  if g_cr and not has_function_privilege('consumer_report_readonly', 'public.get_parcel_attestations(numeric,text)', 'execute') then
    raise exception '156a: consumer_report_readonly lost EXECUTE'; end if;
end $m$;

alter table public.column_writer drop constraint column_writer_subject_has_writer;
alter table public.column_writer add constraint column_writer_subject_has_writer
  check (writer_class <> 'subject' or sanctioned_writers is not null);

insert into public.column_writer (table_name, column_name, writer_class, sanctioned_writers, reason, classified_by) values
('attestation_register', 'disputes_finding', 'subject', '{}',
 'AUTHOR: the named, licensed attester (attester_name, attester_license, license_status_at_statement) - a party outside us. EMPTY sanctioned_writers: no attestation flow yet authenticates the attester, so nothing may write a value; get_parcel_attestations does not serve disputes (156a, ruling 746).',
 'cc');
