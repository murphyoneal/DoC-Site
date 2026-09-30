-- 168a - ruling 819: when a ruling changes a contract, the comments describing it are part of the change.
-- Applied 2026-09-30. Comments only - no function DDL, so no grants are touched.
comment on table public.work_contribution is
  'Contractor-submitted work against a parcel. HELD PRIVATE against the parcel (ruling 795): a photo becomes public only when the homeowner/occupant has claimed the property and approved that item. Neither the claim nor the approval log exists yet, so nothing publishes; trigger work_contribution_publication_gate (163a) refuses visibility -> public for every writer, and detection work-photo-public-without-owner-approval watches row and bucket. The operator can hold or remove, never publish. Any future public read goes through work_gallery_public, which omits co_no and parcel_id - that omission IS the control, not RLS, because every read in this app uses service_role.';
comment on view public.work_gallery_public is
  'The only public read path for the work gallery - and it returns nothing until the owner-approval store exists (ruling 795, 163a). Omits co_no and parcel_id ENTIRELY - the address cannot leak from a column that is not selected. Serves only images whose EXIF strip actually completed. department comes from trade_code_registry.';
do $$ begin
  if obj_description('public.work_contribution'::regclass) not like '%ruling 795%' or obj_description('public.work_gallery_public'::regclass) not like '%ruling 795%' then
    raise exception '168a: comments not applied'; end if;
end $$;
