# Scheduled data jobs (Windows Task Scheduler → WSL)

These are the deployed copies of the wrappers in `~/` on Murphy's machine, kept here so they are reviewable.

| Task | Wrapper | Runs |
|---|---|---|
| FL-GIS-Monthly-Refresh | run_monthly_refresh.sh → ~/master_refresh.py --stale-days 25 | monthly |
| VolusiaCAMASnapshot | run_cama_snapshot.sh → ~/cama_snapshot.py | weekly |
| DBPRRealEstateSnapshot | run_dbpr_snapshot.sh → ~/dbpr_snapshot.py | weekly |
| (manual) | run_stcm.sh → arcgis_point_load.py ×4 | — |

**2026-10-01 (ruling 887/889).** Every wrapper reported success on failure: `rc=$?` came after `$(date)` in the same
echo (which resets `$?` to 0) and the block was piped through `tee` (which returns 0). Now rc is captured on its own
line and the pipeline returns `${PIPESTATUS[0]}`. Red run: a simulated crash (exit 3) → old wrapper exit 0, new exit 3.

`master_refresh.py` is **not** in the repo: the deployed copy holds the database connection literal. Its 2026-10-01
change adds the collapse guard (`decide` / `quarantine` / `apply_result`): a pull that shrinks more than the threshold
against the LIVE table's row count is kept as `<table>_q<yyyymmdd>` and never swapped in; empty and failed pulls never
touch the live table; the script exits 1 when anything failed or nothing was fetched. `master_refresh_guard_redrun.py`
exercises it on throwaway tables (14/14). Against the old code the same 40%-short case replaced a 100-row table with 60.
Backups of the pre-change files: `~/backups_20261001/`.
