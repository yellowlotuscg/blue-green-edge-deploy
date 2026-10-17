#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
local=0
for arg in "$@"; do [[ "$arg" == "--local" ]] && local=1; done
[[ "${DRY_RUN:-0}" == "1" ]] && local=1
python3 "$root/scripts/seed.py"
python3 "$root/scripts/build.py" >/dev/null
version="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$root/dist/build-manifest.json")"
manifest_path="${DEPLOYMENTS_MANIFEST:-$root/deployments/manifest.json}"
mkdir -p "$(dirname "$manifest_path")"

if [[ "$local" != 1 ]]; then
  : "${S3_BUCKET:?S3_BUCKET is required for AWS mode}"
  : "${KVS_ARN:?KVS_ARN is required for AWS mode}"
  : "${SMOKE_URL:?SMOKE_URL is required for AWS mode smoke testing}"
  active="${ACTIVE_COLOR:-blue}"
  [[ "$active" == blue || "$active" == green ]] || { echo "invalid active color: $active" >&2; exit 1; }
  if [[ "$active" == blue ]]; then inactive=green; else inactive=blue; fi
  aws s3 sync "$root/dist/$version" "s3://$S3_BUCKET/$inactive/" --no-progress
  aws s3 sync "$root/dist/$version" "s3://$S3_BUCKET/$inactive/versions/$version/" --no-progress
  python3 "$root/scripts/smoke_test.py" --url "$SMOKE_URL"
  etag="$(aws cloudfront-keyvaluestore describe-key-value-store --kvs-arn "$KVS_ARN" --query ETag --output text)"
  aws cloudfront-keyvaluestore put-key --kvs-arn "$KVS_ARN" --key active_color --value "$inactive" --if-match "$etag"
  python3 - "$manifest_path" "$version" "$inactive" <<'PY'
import json, pathlib, sys
path = pathlib.Path(sys.argv[1])
data = {"active": {}, "deployments": []}
if path.exists(): data = json.loads(path.read_text())
data.setdefault("deployments", []).append({"version": sys.argv[2], "color": sys.argv[3]})
data["active"] = {"version": sys.argv[2], "color": sys.argv[3]}
path.write_text(json.dumps(data, indent=2) + "\n")
PY
  printf 'deployed version=%s color=%s (AWS)\n' "$version" "$inactive"
  exit 0
fi

store="${STATUS_DEPLOY_ROOT:-$root/.local_s3}"
state="${STATUS_STATE_ROOT:-$root/.local_state}"
mkdir -p "$store" "$state"
alias_file="$state/active_color"
active="blue"
[[ -f "$alias_file" ]] && active="$(tr -d '[:space:]' < "$alias_file")"
[[ "$active" == blue || "$active" == green ]] || { echo "invalid active color: $active" >&2; exit 1; }
if [[ "$active" == blue ]]; then inactive=green; else inactive=blue; fi
mkdir -p "$store/$inactive/versions/$version"
cp -R "$root/dist/$version/." "$store/$inactive/"
cp -R "$root/dist/$version/." "$store/$inactive/versions/$version/"
python3 "$root/scripts/smoke_test.py" --root "$store" --color "$inactive"
printf '%s\n' "$inactive" > "$alias_file.tmp"
mv "$alias_file.tmp" "$alias_file"
python3 - "$manifest_path" "$version" "$inactive" <<'PY'
import json, pathlib, sys
path = pathlib.Path(sys.argv[1])
data = {"active": {}, "deployments": []}
if path.exists(): data = json.loads(path.read_text())
data.setdefault("deployments", []).append({"version": sys.argv[2], "color": sys.argv[3]})
data["active"] = {"version": sys.argv[2], "color": sys.argv[3]}
path.write_text(json.dumps(data, indent=2) + "\n")
PY
printf 'deployed version=%s color=%s\n' "$version" "$inactive"
