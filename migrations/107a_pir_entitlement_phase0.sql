-- =============================================================================
-- PIR entitlement — Phase 0 (docs/PIR_ENTITLEMENT_SPEC_v1.md §10, ruling 93). Build the table,
-- realms and function. DO NOT switch the gate — pir_is_unlocked stays live. Drupal node_access
-- realm/gid model, adapted: grants sparse + evaluated at read time (no materialisation), with an
-- expiry the borrowed model lacks. Nothing here reads any consuming front-end payload.
-- =============================================================================

-- realms are DATA, not a CHECK — adding one must not need a migration (§3)
CREATE TABLE IF NOT EXISTS pir_access_realm (
  realm             text PRIMARY KEY,
  gid_meaning       text NOT NULL,
  scope             text NOT NULL,
  expiry_required   boolean NOT NULL,
  null_expiry_legal boolean NOT NULL DEFAULT false,
  note              text
);
INSERT INTO pir_access_realm (realm, gid_meaning, scope, expiry_required, null_expiry_legal, note) VALUES
 ('purchase',        'consumer_accounts.id', 'one parcel',            true,  false, '30-day open window on the searched property (Murphy''s ruling).'),
 ('share',           'share-token id (sha256)', 'one parcel',         true,  false, 'Cannot outlive its parent purchase; re-sharing off by default.'),
 ('subscription',    'b2b_accounts.id', 'county (Basic) or statewide (Pro)', true, false, 'Wildcard scope lives HERE only; billing-period expiry.'),
 ('owner_claim',     'consumer_accounts.id', 'one parcel',            false, true,  'The ONLY realm where null expires_at is legal; revocable on recorded ownership change.'),
 ('internal_verify', 'operator identifier', 'one parcel',             true,  false, 'Fixtures (e.g. render-order golden parcel) become a first-class expiring auditable row, never a bypass.')
ON CONFLICT (realm) DO NOTHING;

-- the grant table, exactly as §3. Scope by nullity mirrors Drupal nid=0.
CREATE TABLE IF NOT EXISTS pir_access_grant (
  id           bigint generated always as identity primary key,
  realm        text        not null references pir_access_realm(realm),
  gid          text        not null,
  co_no        numeric,
  parcel_id    text,
  grant_view   boolean     not null default true,
  grant_update boolean     not null default false,
  grant_delete boolean     not null default false,
  granted_at   timestamptz not null default now(),
  expires_at   timestamptz,
  revoked_at   timestamptz,
  source_ref   text,
  granted_by   text        not null,
  note         text,
  constraint parcel_requires_county check (parcel_id is null or co_no is not null)
);
CREATE INDEX IF NOT EXISTS pir_access_grant_lookup ON pir_access_grant (realm, gid, co_no, parcel_id) WHERE revoked_at IS NULL;

-- telemetry: EVERY decision, granted and denied (§9). Denials are the demand signal.
CREATE TABLE IF NOT EXISTS pir_access_event (
  id          bigint generated always as identity primary key,
  occurred_at timestamptz not null default now(),
  subject     jsonb,
  co_no       numeric,
  parcel_id   text,
  op          text not null default 'view',
  granted     boolean not null,
  realm       text,
  reason      text not null,
  emitted_by  text                 -- 'shadow' during phase 1, 'live' after cutover
);
CREATE INDEX IF NOT EXISTS pir_access_event_parcel ON pir_access_event (co_no, parcel_id, occurred_at DESC);

-- the check: a REASON, not a boolean (§5). Three-state discipline: expired != not_purchased.
CREATE OR REPLACE FUNCTION public.pir_check_access(p_subject jsonb, p_co_no numeric, p_parcel_id text, p_op text DEFAULT 'view')
 RETURNS TABLE(granted boolean, realm text, expires_at timestamptz, reason text)
 LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public','extensions','pg_temp'
AS $fn$
#variable_conflict use_column
DECLARE
  v_consumer text := p_subject->>'consumer_id';
  v_b2b      text := p_subject->>'b2b_account_id';
  v_share    text := p_subject->>'share_token';
BEGIN
  IF v_consumer IS NULL AND v_b2b IS NULL AND v_share IS NULL THEN
    RETURN QUERY SELECT false, NULL::text, NULL::timestamptz, 'no_subject'::text; RETURN;
  END IF;
  RETURN QUERY
  WITH matching AS (
    SELECT g.realm AS m_realm, g.expires_at AS m_expires,
           (g.revoked_at IS NOT NULL AND g.revoked_at <= now()) AS is_revoked,
           (g.expires_at IS NOT NULL AND g.expires_at <= now()) AS is_expired
    FROM pir_access_grant g
    WHERE g.grant_view
      AND (g.co_no IS NULL OR g.co_no = p_co_no)
      AND (g.parcel_id IS NULL OR g.parcel_id = p_parcel_id)
      AND (
           (g.realm IN ('purchase','owner_claim','internal_verify') AND v_consumer IS NOT NULL AND g.gid = v_consumer)
        OR (g.realm = 'subscription' AND v_b2b IS NOT NULL AND g.gid = v_b2b)
        OR (g.realm = 'share' AND v_share IS NOT NULL AND g.gid = encode(digest(v_share,'sha256'),'hex'))
      )
  ),
  ranked AS (
    SELECT m_realm, m_expires,
           CASE WHEN NOT is_revoked AND NOT is_expired THEN 0 WHEN is_expired THEN 1 ELSE 2 END AS rank
    FROM matching
    ORDER BY 3, m_expires DESC NULLS LAST  -- broadest/most-valid wins (union semantics)
    LIMIT 1
  )
  SELECT COALESCE((SELECT rank=0 FROM ranked), false),
         (SELECT m_realm FROM ranked),
         (SELECT m_expires FROM ranked),
         COALESCE((SELECT CASE rank WHEN 0 THEN 'granted' WHEN 1 THEN 'expired' ELSE 'revoked' END FROM ranked), 'not_purchased');
END
$fn$;

-- §7 detection predicates (register with the 07:00 run). All read 0 grants now -> clean.
INSERT INTO data_defect_registry (defect_id, name, class, severity, detection_sql, status, disposition, attribution, expected_state, magnitude_semantics, false_positive_notes) VALUES
 ('entitlement-wildcard-outside-subscription','Entitlement: wildcard grant outside subscription realm','access_control','blocking',
  $d$SELECT (NOT EXISTS (SELECT 1 FROM pir_access_grant WHERE parcel_id IS NULL AND realm <> 'subscription' AND revoked_at IS NULL)) AS ok$d$,
  'active','repair','ours','clean','binary','Spec §7.1 — the Drupal realm=all trap. A null-parcel grant outside subscription silently makes the product public. The important one; must never appear quietly.'),
 ('entitlement-null-expiry-outside-owner-claim','Entitlement: null expires_at outside owner_claim','access_control','blocking',
  $d$SELECT (NOT EXISTS (SELECT 1 FROM pir_access_grant WHERE expires_at IS NULL AND realm <> 'owner_claim' AND revoked_at IS NULL)) AS ok$d$,
  'active','repair','ours','clean','binary','Spec §7.2 / §4 — owner_claim is the only realm where a perpetual grant is legal.'),
 ('entitlement-orphan-share','Entitlement: share grant whose parent purchase is gone/expired','access_control','material',
  $d$SELECT (NOT EXISTS (SELECT 1 FROM pir_access_grant s WHERE s.realm='share' AND s.revoked_at IS NULL AND (s.expires_at IS NULL OR s.expires_at>now()) AND NOT EXISTS (SELECT 1 FROM pir_access_grant p WHERE p.id::text = s.source_ref AND p.revoked_at IS NULL AND (p.expires_at IS NULL OR p.expires_at>now())))) AS ok$d$,
  'active','repair','ours','clean','binary','Spec §7.3 — a share cannot outlive its parent (§6).'),
 ('entitlement-sharing-abuse-signal','Entitlement: many active shares per parent purchase (signal)','access_control','cosmetic',
  $d$SELECT (NOT EXISTS (SELECT source_ref FROM pir_access_grant WHERE realm='share' AND revoked_at IS NULL AND (expires_at IS NULL OR expires_at>now()) AND source_ref IS NOT NULL GROUP BY source_ref HAVING count(*) > 10)) AS ok$d$,
  'active','disclose','ours','clean','binary','Spec §7.5 — a SIGNAL not a defect (should render amber when it fires, a dashboard refinement). Threshold 10 active shares per parent.')
ON CONFLICT (defect_id) DO UPDATE SET detection_sql=EXCLUDED.detection_sql, expected_state='clean', status='active';
