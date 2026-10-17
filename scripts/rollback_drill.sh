#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manifest="${DEPLOYMENTS_MANIFEST:-$root/deployments/manifest.json}"
mkdir -p "$root/.local_s3" "$root/.local_state" "$(dirname "$manifest")"
if [[ ! -f "$manifest" ]]; then
  DEPLOYMENTS_MANIFEST="$manifest" DRY_RUN=1 "$root/scripts/deploy.sh" --local >/dev/null
fi
version="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["active"]["version"])' "$manifest")"
start="$(python3 -c 'import time; print(time.time_ns())')"
DEPLOYMENTS_MANIFEST="$manifest" DRY_RUN=1 "$root/scripts/rollback.sh" --local "$version" >/dev/null
end="$(python3 -c 'import time; print(time.time_ns())')"
python3 - "$start" "$end" <<'PY'
import sys
seconds = (int(sys.argv[2]) - int(sys.argv[1])) / 1_000_000_000
print(f"rollback_seconds={seconds:.6f}")
PY
