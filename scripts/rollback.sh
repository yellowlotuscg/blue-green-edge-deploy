#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
local=0
version=""
for arg in "$@"; do
  case "$arg" in
    --local) local=1 ;;
    --*) ;;
    *) version="$arg" ;;
  esac
done
[[ "${DRY_RUN:-0}" == "1" ]] && local=1
manifest="${DEPLOYMENTS_MANIFEST:-$root/deployments/manifest.json}"
[[ -f "$manifest" ]] || { echo "no deployment manifest" >&2; exit 1; }
if [[ -z "$version" ]]; then version="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["active"]["version"])' "$manifest")"; fi
read -r color < <(python3 - "$manifest" "$version" <<'PY'
import json, sys
for item in json.load(open(sys.argv[1])).get("deployments", []):
    if item["version"] == sys.argv[2]:
        print(item["color"])
        break
else:
    raise SystemExit(f"version not found: {sys.argv[2]}")
PY
)

if [[ "$local" != 1 ]]; then
  : "${S3_BUCKET:?S3_BUCKET is required for AWS mode}"
  : "${KVS_ARN:?KVS_ARN is required for AWS mode}"
  aws s3 sync "s3://$S3_BUCKET/$color/versions/$version/" "s3://$S3_BUCKET/$color/" --no-progress
  etag="$(aws cloudfront-keyvaluestore describe-key-value-store --kvs-arn "$KVS_ARN" --query ETag --output text)"
  aws cloudfront-keyvaluestore put-key --kvs-arn "$KVS_ARN" --key active_color --value "$color" --if-match "$etag"
  python3 - "$manifest" "$version" "$color" <<'PY'
import json, pathlib, sys
path = pathlib.Path(sys.argv[1])
data = json.loads(path.read_text())
data["active"] = {"version": sys.argv[2], "color": sys.argv[3]}
path.write_text(json.dumps(data, indent=2) + "\n")
PY
  printf 'rolled back version=%s color=%s (AWS)\n' "$version" "$color"
  exit 0
fi

store="${STATUS_DEPLOY_ROOT:-$root/.local_s3}"
state="${STATUS_STATE_ROOT:-$root/.local_state}"
archive="$store/$color/versions/$version"
[[ -d "$archive" ]] || { echo "artifact archive missing: $archive" >&2; exit 1; }
mkdir -p "$store/$color" "$state"
cp -R "$archive/." "$store/$color/"
printf '%s\n' "$color" > "$state/active_color.tmp"
mv "$state/active_color.tmp" "$state/active_color"
python3 - "$manifest" "$version" "$color" <<'PY'
import json, pathlib, sys
path = pathlib.Path(sys.argv[1])
data = json.loads(path.read_text())
data["active"] = {"version": sys.argv[2], "color": sys.argv[3]}
path.write_text(json.dumps(data, indent=2) + "\n")
PY
python3 "$root/scripts/smoke_test.py" --root "$store" --color "$color"
printf 'rolled back version=%s color=%s\n' "$version" "$color"
