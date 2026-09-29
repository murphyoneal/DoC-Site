-- 157c: 157b's CHECK passed a row with ip_basis NULL (a CHECK that evaluates to NULL passes). Found by the
-- negative control run after 157b. A basis is now required on every row. The table was empty; nothing
-- was back-filled. Controls after: forged-ip-as-not_established refused; null-ip-as-edge refused;
-- no basis refused; honest null accepted; edge ip accepted.
do $m$ begin
  if (select count(*) from public.submission_event) > 0 then raise exception '157c: rows exist; backfill deliberately first'; end if;
end $m$;
alter table public.submission_event alter column ip_basis set not null;
