-- 157b: record WHETHER an address was established, not only the address (ruling 768).
--
-- A forged IP in a custody log is worse than an empty one: it is a value the submitter chose, recorded
-- as if we had measured it, in the field an appeal relies on. clientIp now trusts only headers Vercel's
-- edge sets. ip_basis says what the ip column means:
--   vercel_edge      - taken from a Vercel-set header
--   not_established  - no trusted header was present; ip is NULL. That is the honest record.
-- (This CHECK alone still passed a row with ip_basis NULL; 157c makes the basis required.)

alter table public.submission_event add column if not exists ip_basis text
  check (ip_basis in ('vercel_edge', 'not_established'));
alter table public.submission_event add constraint submission_event_ip_basis_consistent
  check ((ip_basis = 'vercel_edge' and ip is not null) or (ip_basis = 'not_established' and ip is null)) not valid;

insert into public.column_writer (table_name, column_name, writer_class, reason, classified_by) values
('submission_event', 'ip_basis', 'ours', 'what the ip column means: vercel_edge (trusted header) or not_established (ip NULL, never a caller-chosen value) - 157b, ruling 768', 'cc');

do $m$ begin
  if (select count(*) from public.submission_event) > 0 then
    raise exception '157b: submission_event has rows - validate the constraint deliberately rather than leave it NOT VALID'; end if;
  alter table public.submission_event validate constraint submission_event_ip_basis_consistent;
end $m$;
