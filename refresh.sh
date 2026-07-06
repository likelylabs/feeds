#!/usr/bin/env bash
# Refresh all five backup feeds byte-exact from live Remote Config
# (SETUP.md step 1). Pure pull: reads RC, writes only files in this repo.
# Delegates to the RC toolkit (auth via gcloud) — see
# radioapp-firebase-rest/CLAUDE.md for the full station-update routine.
set -euo pipefail
rc="$(cd "$(dirname "$0")/.." && pwd)/radioapp-firebase-rest/rc.py"
[ -f "$rc" ] || { echo "missing $rc — clone radioapp-firebase-rest next to this repo" >&2; exit 1; }

# hksamsung is named explicitly on purpose: it shares hk's RC project
# (dormant flavor) and rc.py only overwrites its files when asked by name.
for m in hk hktw sg my hksamsung; do
  python3 "$rc" sync "$m" --targets backup
done

echo
echo "Sanity-check 'git diff' (should look like recent station edits),"
echo "then commit and push — an unpushed backup feed is a stale fallback."
