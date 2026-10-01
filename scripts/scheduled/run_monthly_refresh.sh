#!/bin/bash
# FL GIS refresh. Invoked by Windows Task Scheduler.
# Args are hardcoded here on purpose - passing them through the wsl.exe boundary mangles them.
# EXIT CODE (ruling 887, 2026-10-01): the previous form printed `rc=$?` AFTER `$(date)` in the same echo, which
# resets $? to 0, and the whole block was piped through tee, which also returns 0 - so every failure, including a crash,
# was logged and reported to Task Scheduler as success for three months. rc is captured on its own line, and the
# pipeline returns the block's status, not tee's.
mkdir -p "$HOME/refresh_logs"
LOG="$HOME/refresh_logs/refresh_$(date +%Y%m%d_%H%M).log"
{
  echo "=== FL GIS refresh started $(date) ==="
  python3 "$HOME/master_refresh.py" --stale-days 25
  rc=$?
  echo "=== finished $(date) rc=$rc ==="
  exit $rc
} 2>&1 | tee -a "$LOG"
exit "${PIPESTATUS[0]}"
