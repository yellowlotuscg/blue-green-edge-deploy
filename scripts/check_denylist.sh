#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
list="$root/.github/denylist.txt"
if [[ ! -f "$list" ]]; then
  echo "denylist file is not present; nothing to scan"
  exit 0
fi

found=0
while IFS= read -r term || [[ -n "$term" ]]; do
  [[ -z "$term" ]] && continue
  while IFS= read -r -d '' file; do
    [[ "$file" == ".github/denylist.txt" ]] && continue
    if grep -aFni -- "$term" "$root/$file" >/dev/null; then
      echo "denylist hit: $file"
      found=1
    fi
  done < <(cd "$root" && git ls-files -z)
done < "$list"
exit "$found"
