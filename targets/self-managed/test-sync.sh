#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
count() { echo "$1" | grep -E "^\s*$2:" | head -1 | grep -oE '[0-9]+' | head -1; }
./sync.sh --diff >/dev/null || { echo "FAIL: diff step errored"; exit 1; }
./sync.sh >/dev/null || { echo "FAIL: sync errored"; exit 1; }
out=$(./sync.sh --diff 2>&1)
for k in Created Updated Deleted; do
  [ "$(count "$out" $k)" = 0 ] || { echo "FAIL: not idempotent ($k)"; echo "$out" | tail -15; exit 1; }
done
# removal is honored: a config without one consumer plans a delete, without applying it
tmp=$(mktemp); trap 'rm -f "$tmp"' EXIT
../../../internal/.venv/bin/python -I - "$tmp" <<'PY'
import sys, yaml
d = yaml.safe_load(open("../../config/ai.yaml"))
d["consumers"] = [c for c in d["consumers"] if c["name"] != "agent-intake-headless"]
yaml.safe_dump(d, open(sys.argv[1], "w"), sort_keys=False)
PY
rm_out=$(AI_CONFIG="$tmp" ./sync.sh --diff 2>&1)
[ "$(count "$rm_out" Deleted)" -ge 1 ] || { echo "FAIL: removal not planned"; echo "$rm_out" | tail -15; exit 1; }
out2=$(./sync.sh --diff 2>&1); [ "$(count "$out2" Deleted)" = 0 ] || { echo "FAIL: preview mutated live state"; exit 1; }
echo PASS
