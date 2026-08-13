# PIR Entitlement Model — Specification v1

**Drafted 2026-08-09.** Supersedes the ad-hoc shape in handoff ruling 81. Basis: Drupal's `node_access` realm/gid model, adapted. This is a **spec for CC to report against, not a migration.** Rule 6 stands — no payload-shape change ahead of the consuming front end.

---

## 1. The defect this fixes

`pir_is_unlocked(p_co_no numeric, p_parcel_id text)` returns

```sql
EXISTS (SELECT 1 FROM pir_purchases WHERE co_no = p_co_no AND parcel_id = p_parcel_id AND status = 'paid')
```

There is no subject in the signature. **One person paying $5 unlocks that parcel's report for everyone, permanently.** Parcel ids are enumerable, so unlock state is discoverable.

This is not primarily a security bug. It is a revenue defect under the load-bearing assumption of the consumer model — that several different people research the same property.

**Murphy's ruling:** the purchaser registers and gets a **30-day open window on the searched property only**. Containerised per buyer, per parcel, per window. Re-reads inside the window are free, because a person searches the same property repeatedly.

---

## 2. Why a borrowed model rather than a bespoke one

Drupal core has stored access this way for two decades: one table — `nid, gid, realm, grant_view, grant_update, grant_delete`. A **realm** is a string naming a *kind* of access. The subject presents the gids it holds per realm; the resource declares which (realm, gid) pairs may reach it; access is the intersection.

The same shape appears independently in Google's Zanzibar and its open implementations as `(subject, relation, object)` tuples. Three unrelated designs converging is the argument for adopting it rather than inventing one.

### Adopted

- **realm / gid separation.** Every access class becomes a row, never a branch in a predicate.
- **Wildcard scope.** Drupal's `nid = 0` means "view all *within that realm*." That is Pro tier as a single row.
- **Union semantics.** Multiple grants may match; the broadest wins.

### Deliberately rejected

- **Materialisation.** Drupal writes access records per node on save and needs `node_access_rebuild()` when rules change; the table is well known for drifting and needing repair. It does that because it filters large *listings*. We do **point checks on one parcel**. Materialising against 10.7M parcels manufactures a rebuild problem we do not have. **Grants stay sparse** — a row exists only where access was actually granted — and are evaluated at read time.
- **Perpetuity.** `node_access` has **no expiry column at all**. The 30-day window is our addition, not something the borrowed model provides.

### The trap we inherit, and must instrument

Drupal ships a default row — `nid=0, gid=0, realm=all, grant_view=1` — and its own documentation warns that this single row **turns the entire grants system off**, making everything viewable.

That is structurally identical to the bug being fixed. One over-broad grant silently makes the product public. Adopting the model means adopting the countermeasure (§7).

---

## 3. Schema

```sql
create table pir_access_grant (
  id           bigint generated always as identity primary key,
  realm        text        not null references pir_access_realm(realm),
  gid          text        not null,   -- subject id, interpreted per realm
  co_no        numeric,                -- null = all counties
  parcel_id    text,                   -- null = all parcels within co_no
  grant_view   boolean     not null default true,
  grant_update boolean     not null default false,
  grant_delete boolean     not null default false,
  granted_at   timestamptz not null default now(),
  expires_at   timestamptz,            -- null = perpetual; legal only where declared
  revoked_at   timestamptz,
  source_ref   text,                   -- session_id / subscription id / claim id
  granted_by   text        not null,   -- what caused this grant (audit)
  note         text,
  constraint parcel_requires_county
    check (parcel_id is null or co_no is not null)
);
```

**Scope is expressed by nullity**, mirroring `nid = 0`:

| co_no | parcel_id | meaning |
|---|---|---|
| set | set | one parcel |
| set | null | one county |
| null | null | statewide |

`pir_access_realm` is a vocabulary table, not a CHECK constraint — realms are data, and adding one must not require a migration.

---

## 4. Realm vocabulary

| realm | gid is | scope | expiry |
|---|---|---|---|
| `purchase` | `consumer_accounts.id` | one parcel | **required** — 30 days |
| `share` | share-token id | one parcel | **required** — never outlives its parent purchase |
| `subscription` | `b2b_accounts.id` | county (Basic) or statewide (Pro) | **required** — billing period end |
| `owner_claim` | `consumer_accounts.id` | one parcel | perpetual permitted |
| `internal_verify` | operator identifier | one parcel | **required**, short |

**`owner_claim` is the only realm where a null `expires_at` is legal**, and it is revocable on a recorded ownership change. Everything else must carry an expiry. That asymmetry is what the detection predicate keys on.

`internal_verify` exists so fixtures like the render-order golden parcel are a first-class, expiring, auditable row rather than a bypass.

---

## 5. The check function

Replace the boolean with a reason. The present function is opaque, and the UI cannot distinguish states it needs to act on differently.

```sql
pir_check_access(
  p_subject  jsonb,      -- {consumer_id, b2b_account_id, share_token}
  p_co_no    numeric,
  p_parcel_id text,
  p_op       text default 'view'
) returns table (
  granted    boolean,
  realm      text,
  expires_at timestamptz,
  reason     text          -- granted | expired | not_purchased | revoked | no_subject
)
```

**Three-state discipline applies here as everywhere else.** `expired` and `not_purchased` are different facts and must not collapse into one denial:

- `not_purchased` → offer the $5 checkout
- `expired` → offer renewal, and say when it lapsed
- `granted` via `share` → render read-only, and fire the read receipt
- `no_subject` → prompt for the email/link, **never** fall through to public

A denial must never render as "this property has no findings."

---

## 6. Share, and why it is designed now

A non-purchaser reading a report is not always a leak — sometimes it is the product. The $4 shared PIR, doorway C3 (a forwarded report), P2 (an agent's client), and read-receipt intelligence all require a legitimate reader who did not pay.

**There is currently no share table in the database.** If share is built later as an afterthought it will be built as "make the parcel public again," and we land back at the present bug.

- A share is a `share` realm grant whose `source_ref` names the parent `purchase` grant.
- The token is stored **hashed**; the signed URL carries the plaintext.
- A share **cannot outlive its parent**: `expires_at = least(parent.expires_at, issued_at + share_window)`.
- Re-sharing is **off** by default. A share grant cannot itself issue a share.

The read receipt is only possible because the read is gated. You cannot observe a read you did not mediate.

---

## 7. Detection predicates — register with the 07:00 run

1. **Wildcard outside `subscription`** — any grant with null `parcel_id` in a realm other than `subscription`. This is the Drupal `realm=all` trap. Expected state: **clean**.
2. **Null `expires_at` outside `owner_claim`** — expected state: **clean**.
3. **Orphan share** — a `share` grant whose parent purchase has expired or is missing.
4. **Revoked-but-granting** — `revoked_at` in the past on a row still returned by the check.
5. **Sharing-abuse signal** — distinct active `share` grants per parent purchase above a threshold. Amber, not red; it is a signal, not a defect.

Predicate 1 is the important one. A wildcard must never be able to appear quietly.

---

## 8. Relationship to the service-role boundary finding

WO 75 found that the retail surface runs on the service-role key and therefore bypasses RLS on 2,156 tables, making the DoP/PIRFL boundary nominal.

**These are one problem, but be precise about how.** RLS across 2,156 raw county tables keyed by parcel is neither feasible nor the point. The consumer report path is already RPC-only (`get_pir_report`, `pir_is_unlocked`, `get_pir_purchase`, `record_pir_purchase`). So:

- The retail role gets `EXECUTE` on `get_pir_report` **and nothing else**.
- `get_pir_report` is `SECURITY DEFINER` and calls `pir_check_access` internally.
- RLS is the **backstop** for anything that escapes the RPC path, not the mechanism.
- Service-role is confined to webhook, ingest and admin.

Stated plainly: the grants table does not by itself close the boundary. It makes closing it possible, because there is finally something for a least-privilege role to be checked against.

---

## 9. Telemetry

The access check is the natural write point for two things already in the plan — the permanent per-property activity ledger (vehicle-history principle) and read receipts.

Log **every** decision to `pir_access_event`: subject, parcel, realm, outcome, timestamp. Granted *and* denied. Denials are the demand signal — a parcel repeatedly hitting `not_purchased` is interest, and it is the input to the "are you selling?" mechanic.

One code path, at the check. Not a second one added later.

---

## 10. Rollout — shadow mode first

Matches the house pattern already used for numeric-provenance validation.

| phase | action | gate |
|---|---|---|
| 0 | Build table, realms, function. **Do not switch the gate.** | — |
| 1 | Dual-run: compute `pir_check_access` alongside the live `pir_is_unlocked`, log both, diff. | Divergence understood, not merely small |
| 2 | Backfill `purchase` grants from `pir_purchases`; populate `consumer_id` in `record_pir_purchase`. | Grant count reconciles to paid rows |
| 3 | Front end sends subject and handles all five `reason` values. | Ships **with** the backend cutover, not after |
| 4 | Cut over. Revoke old function. | Golden-parcel suite green |

Phase 2 also closes an existing gap: `pir_purchases.consumer_id` is NULL on the only row in the ledger, so purchases are not currently linked to accounts at all.

---

## 11. Open questions — Murphy rules, not CC

1. **Does the 30 days run from purchase or from first view?** Purchase is simpler and auditable; first view is friendlier to someone who buys and reads a week later.
2. **Does an agent's share consume one of their 30 monthly PIRs?** This decides whether the $4 shared tier is a discount or a separate SKU.
3. **What does expiry offer?** Full $5 again, or a cheaper renewal? A renewal price implies a second Stripe product.
4. **Is `owner_claim` genuinely perpetual,** and what revokes it — a recorded deed, or a manual review?
5. **Does a Pro subscriber's statewide wildcard survive their billing lapse by any grace period,** or cut at period end?

---

## 12. What is deliberately not here

- **No new authorisation dependency.** Zanzibar-family services (OpenFGA, SpiceDB) solve this well and are worth reading for vocabulary, but a separate authorisation service is not justified at a ~$250/month run rate when the model is one table and one function in Postgres.
- **No `grant_update` / `grant_delete` use.** The columns are carried because AddressFolder will need them when an owner annotates their own record. They stay unused until then.
- **No change to any rendered `as_of` or payload shape** in this work.

---

## Instruction to the builder

Bring back: the grant table as you would actually create it, the realm vocabulary as rows, the `pir_check_access` signature and return shape, the share token issue/redeem flow, the RLS merge assessment from §8, and **the front-end changes each one forces**.

Report before implementing. The 14-county flood emission test (ruling 80) comes first, and the `run_defect_detections` anon revoke is still one line and still now.
