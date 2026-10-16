#!/usr/bin/env bash
# Usage: ./sync.sh            apply ../../config/ai.yaml to the control plane
#        ./sync.sh --diff     preview only, no changes
set -euo pipefail
cd "$(dirname "$0")"
[ -f .env ] || { echo "ERROR: .env not found (run ./init-env.sh)" >&2; exit 1; }
./check-keys.sh "${AI_CONFIG:-../../config/ai.yaml}"
command -v deck >/dev/null || { echo "ERROR: deck not on PATH; see ../../tools/README.md" >&2; exit 1; }
# Export only the consumer keys (as DECK_KEY_*); .env is not sourced because values may contain spaces.
while IFS='=' read -r name value; do export "DECK_${name}=${value}"; done < <(grep -E '^KEY_[A-Z_]+=' .env)
CFG=${AI_CONFIG:-../../config/ai.yaml}
export DECK_KONG_ADDR=${DECK_KONG_ADDR:-http://127.0.0.1:8001}
deck() { env -u HTTPS_PROXY deck "$@"; }
# decK waits 10s per request by default; a small or emulated host can need longer ("context deadline exceeded").
# Raise SYNC_TIMEOUT (seconds) if you still see that error. Fewer parallel requests keep a slow control plane from timing out.
TIMEOUT=${SYNC_TIMEOUT:-120}
PARALLELISM=${SYNC_PARALLELISM:-1}
if ! ping_out=$(deck gateway ping --timeout "$TIMEOUT" 2>&1); then
  echo "ERROR: the control plane Admin API at $DECK_KONG_ADDR did not answer: $ping_out" >&2
  echo "If it is not running, check 'docker compose ps' and 'docker compose logs kong-cp' in targets/self-managed." >&2
  echo "If it is running but slow, wait until every container shows healthy, or raise SYNC_TIMEOUT (seconds)." >&2
  exit 1
fi
# Convert first, then diff/sync the converted file. 'deck ai sync' does the same two steps but does not
# substitute the ${{ env }} placeholders, which would store the placeholder text as the consumer keys.
tmp=$(mktemp); trap 'rm -f "$tmp"' EXIT
deck file ai2kong -s "$CFG" -o "$tmp"
if [ "${1:-}" = "--diff" ]; then
  deck gateway diff --timeout "$TIMEOUT" --parallelism "$PARALLELISM" "$tmp"
else
  deck gateway sync --yes --timeout "$TIMEOUT" --parallelism "$PARALLELISM" "$tmp"
fi
