-- 128f — Ruling 2026-09-24: D R HORTON INC is a real business (a national builder with divisional
-- offices, structurally the same as Centex and David Weekley). Recorded so the cardinality check
-- stops flagging a decided case and a NEW flag can be seen. A real_business ruling merges nothing
-- beyond the ordinary name+zip+street key.
--
-- Evidence measured by the detection's own method (business_norm, department <> 'none'): 17 rows
-- at 15 addresses, 14 businesses. A prefix match on 'D R HORTON INC%' gives 20, because it also
-- catches "D R HORTON INC - JACKSONVILLE" — a different normalised name, not flagged.

insert into public.business_name_rulings (name_norm, ruling, evidence, ruled_by) values
  ('D R HORTON INC', 'real_business',
   'Measured 2026-09-24 by the detection method (business_norm, department <> none): 17 rows at 15 addresses, 14 businesses. National builder with divisional offices, same shape as Centex and David Weekley. "D R HORTON INC - JACKSONVILLE" normalises to a different name and is not covered by this ruling.',
   'claude ruling 2026-09-24')
on conflict (name_norm) do nothing;
