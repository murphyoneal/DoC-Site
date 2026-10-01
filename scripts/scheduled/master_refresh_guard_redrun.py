"""Red run for the master_refresh collapse guard (ruling 887). Uses ONLY throwaway tables _guardtest_*; drops them."""
import importlib.util, os, sys
spec = importlib.util.spec_from_file_location("mr", os.path.expanduser("~/master_refresh.py"))
mr = importlib.util.module_from_spec(spec); spec.loader.exec_module(mr)

fails = []
def check(name, cond):
    print(("PASS " if cond else "FAIL ") + name)
    if not cond: fails.append(name)

# pure decisions
check("decide: handler failed -> UNAVAILABLE", mr.decide(100, None, False, 15) == "UNAVAILABLE")
check("decide: 0 rows -> EMPTY_AT_SOURCE", mr.decide(100, 0, True, 15) == "EMPTY_AT_SOURCE")
check("decide: 60 of 100 -> QUARANTINED", mr.decide(100, 60, True, 15) == "QUARANTINED")
check("decide: 90 of 100 -> OK", mr.decide(100, 90, True, 15) == "OK")
check("decide: 130 of 100 -> FLAG_GROWTH", mr.decide(100, 130, True, 15) == "FLAG_GROWTH")
check("decide: no live table -> OK", mr.decide(None, 50, True, 15) == "OK")

c = mr.db(); cur = c.cursor()
T, S = "_guardtest_live", "_guardtest_live_stg"
def reset(live_n, stg_n):
    for t in (T, S): cur.execute(f'drop table if exists "{t}"')
    cur.execute(f'drop table if exists "{T[:52]}_q" || \'\'') if False else None
    cur.execute(f'create table "{T}" (id int primary key)'); cur.execute(f'insert into "{T}" select generate_series(1,{live_n})')
    cur.execute(f'create table "{S}" (id int primary key)'); cur.execute(f'insert into "{S}" select generate_series(1,{stg_n})')
def n(t): return mr.count(cur, t)
def exists(t):
    cur.execute("select to_regclass(%s) is not null", ('public."' + t + '"',)); return cur.fetchone()[0]

# 1. a source that comes back 40% short must NOT replace the live table
reset(100, 60)
status, msg = mr.apply_result(cur, T, S, n(T), n(S), True, "ok", 15, False)
qname = (T[:52] + "_q" + __import__("datetime").date.today().strftime("%Y%m%d"))[:63]
check("shrink: status QUARANTINED", status == "QUARANTINED")
check("shrink: live table still 100 rows", n(T) == 100)
check("shrink: quarantine table kept with 60 rows", exists(qname) and n(qname) == 60)
check("shrink: staging name freed", not exists(S))
cur.execute("select count(*) from pg_indexes where tablename=%s and indexname not like %s", (qname, qname + "%"))
check("shrink: quarantine indexes renamed (invariant 3)", cur.fetchone()[0] == 0)

# 2. zero rows must not touch live
reset(100, 0)
status, _ = mr.apply_result(cur, T, S, n(T), n(S), True, "ok", 15, False)
check("empty: status EMPTY_AT_SOURCE and live 100", status == "EMPTY_AT_SOURCE" and n(T) == 100)

# 3. a failed handler must not touch live
reset(100, 100)
status, _ = mr.apply_result(cur, T, S, n(T), None, False, "403", 15, False)
check("unavailable: status UNAVAILABLE and live 100", status == "UNAVAILABLE" and n(T) == 100)

# 4. the normal case still swaps (the guard must not block real refreshes)
reset(100, 95)
status, _ = mr.apply_result(cur, T, S, n(T), n(S), True, "ok", 15, False)
check("normal: status OK and live now 95", status == "OK" and n(T) == 95)

for t in (T, S, qname): cur.execute(f'drop table if exists "{t}"')
c.close()
print("ALL PASS" if not fails else f"{len(fails)} FAILED")
sys.exit(1 if fails else 0)
