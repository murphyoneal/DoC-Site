#!/usr/bin/env python3
"""
Build the STATEWIDE trigram index that powers address autocomplete
(public.search_parcel_address). This is the one step that cannot run through the
Supabase pooler / MCP: a GIN trigram build over parcels_staging.phy_addr1
(~9.46M address-shaped rows of 10.33M total) takes far longer than the pooler's
2-minute statement_timeout, and CREATE INDEX CONCURRENTLY cannot run inside a
transaction. So: a session-mode connection, autocommit ON, statement_timeout = 0,
and CONCURRENTLY so parcels_staging (the table that serves live reports) is never
write-locked during the build.

Run from WSL where the DB scripts live (see memory wsl-data-pull-scripts /
pooler-statement-timeout):

    DATABASE_URL="postgresql://...session-mode-conn..." python3 build_address_autocomplete_index.py

Pre-req already applied via MCP: pg_trgm extension, the search/log RPCs, and the
Volusia-only pilot index idx_ps_v74_addr_trgm. This adds the statewide sibling.
Idempotent: IF NOT EXISTS, and CONCURRENTLY leaves a valid index or an INVALID one
you can DROP and re-run.
"""
import os
import sys
import time
import psycopg2

DDL = """
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_parcels_staging_addr_trgm
  ON public.parcels_staging USING gin (phy_addr1 gin_trgm_ops);
"""

# If a prior run was interrupted, the index can be left INVALID. Detect + drop it
# so the rebuild is clean rather than silently useless.
CHECK_INVALID = """
SELECT c.relname
FROM pg_class c
JOIN pg_index i ON i.indexrelid = c.oid
WHERE c.relname = 'idx_parcels_staging_addr_trgm' AND i.indisvalid = false;
"""


def main() -> int:
    dsn = os.environ.get("DATABASE_URL")
    if not dsn:
        print("ERROR: set DATABASE_URL to a SESSION-mode connection (not the "
              "transaction pooler) so statement_timeout=0 persists.", file=sys.stderr)
        return 2

    conn = psycopg2.connect(dsn)
    conn.autocommit = True  # required: CONCURRENTLY cannot run in a transaction
    cur = conn.cursor()

    cur.execute("SET statement_timeout = 0;")  # in-session override the pooler honors

    cur.execute(CHECK_INVALID)
    if cur.fetchone():
        print("Found an INVALID leftover index from a prior run — dropping it first.")
        cur.execute("DROP INDEX CONCURRENTLY IF EXISTS public.idx_parcels_staging_addr_trgm;")

    print("Building idx_parcels_staging_addr_trgm (CONCURRENTLY, statewide). "
          "This can take many minutes; parcels_staging stays readable/writable throughout.")
    t0 = time.time()
    cur.execute(DDL)
    print(f"Done in {time.time() - t0:.0f}s.")

    # Assert the index exists AND is valid — empty != done.
    cur.execute(CHECK_INVALID)
    if cur.fetchone():
        print("ERROR: index built but is INVALID. Drop and re-run.", file=sys.stderr)
        return 1
    cur.execute("""SELECT indexname FROM pg_indexes
                   WHERE tablename='parcels_staging' AND indexname='idx_parcels_staging_addr_trgm';""")
    if not cur.fetchone():
        print("ERROR: index missing after build.", file=sys.stderr)
        return 1

    print("VALID. Statewide address autocomplete is now index-backed. "
          "Verify: SELECT public.search_parcel_address('12485 HOMELAND DR, DADE CITY');  -- expect held=false")
    cur.close()
    conn.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
