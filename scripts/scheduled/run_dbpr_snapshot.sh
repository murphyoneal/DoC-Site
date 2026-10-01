#!/bin/bash
# DBPR real-estate snapshot. Invoked by Windows Task Scheduler.
# EXIT CODE (ruling 887, 2026-10-01): the previous form printed `rc=$?` AFTER `$(date)` in the same echo, which
# resets $? to 0, and the whole block was piped through tee, which also returns 0 - so every failure, including a crash,
# was logged and reported to Task Scheduler as success for three months. rc is captured on its own line, and the
# pipeline returns the block's status, not tee's.
mkdir -p "$HOME/dbpr_snapshot_logs"
LOG="$HOME/dbpr_snapshot_logs/snap_$(date +%Y%m%d_%H%M).log"
{
  echo "=== DBPR real-estate snapshot started $(date) ==="
  python3 "$HOME/dbpr_snapshot.py"
  rc=$?
  echo "=== finished $(date) rc=$rc ==="
  exit $rc
} 2>&1 | tee -a "$LOG"
exit "${PIPESTATUS[0]}"
