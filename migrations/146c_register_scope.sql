-- 146c — what a state's contractor register actually covers (work order 717 survey). The survey found
-- "no state general-contractor licence" means different things: Maryland licenses home-improvement
-- contractors, Pennsylvania and Vermont register residential/home-improvement contractors, Texas and
-- Illinois license only trades, New York licenses none. register_scope records which, so
-- no_register_exists is set only where the state keeps NO state register of general, building,
-- residential or home-improvement contractors at all.
alter table public.register_coverage add column if not exists register_scope text
  check (register_scope in ('licence', 'registration', 'home_improvement_only', 'residential_only', 'trades_only', 'none', 'not_established'));
comment on column public.register_coverage.register_scope is
  'For construction: licence (competency licence for general/building contractors), registration (a register without a competency exam), home_improvement_only, residential_only, trades_only (only specific trades such as electrical/plumbing/roofing are state-licensed), none. no_register_exists is used only for trades_only or none. 146c.';
