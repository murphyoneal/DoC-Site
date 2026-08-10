-- =============================================================================
-- Ruling 98: the versioning fix (111a) went forward but not back. Run 4 (v2) computed `changed`
-- under the OLD, pre-versioning rule — comparing a v2 hash to a v1 predecessor across the version
-- boundary. ~244 of those rows have NO same-version (v2) predecessor, so under within-version
-- comparison their `changed` must be NULL (a version boundary is an absence of comparison), yet they
-- read TRUE. Left as-is, a derivation query filtering on v2 would count 242 artifact "changes" toward
-- the >=3 threshold and derive a faster-than-real cadence.
--
-- TWO MECHANISMS (one is never enough tonight):
-- (a) ONE-TIME RECOMPUTE below. `changed` is a DERIVED convenience, not an observation — append-only
--     protects observations; recomputing a derived field under the corrected rule, documented here, is
--     the same move as the version backfill in 111a, not a silent edit.
-- (b) DERIVATION MUST COMPUTE, NOT TRUST (contract, for when derivation is built, weeks out): a source's
--     change count is established by requiring a same-version predecessor and diffing content_hash
--     directly — never by summing the stored `changed` flag, so a stale/wrong flag cannot reach the
--     threshold. Trigger prevents, predicate verifies; same shape as the security work.
-- =============================================================================
UPDATE source_observation so
   SET changed = NULL
 WHERE so.hash_basis_version = 2
   AND so.changed IS TRUE
   AND NOT EXISTS (
     SELECT 1 FROM source_observation p
      WHERE p.source_id = so.source_id
        AND p.hash_basis_version = so.hash_basis_version
        AND p.observed_at < so.observed_at
   );
