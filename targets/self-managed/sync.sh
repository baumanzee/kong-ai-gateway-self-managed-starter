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
deck gateway ping >/dev/null 2>&1 || { echo "ERROR: cannot reach the control plane Admin API at $DECK_KONG_ADDR" >&2; exit 1; }
# Convert first, then diff/sync the converted file. 'deck ai sync' does the same two steps but does not
# substitute the ${{ env }} placeholders, which would store the placeholder text as the consumer keys.
tmp=$(mktemp); trap 'rm -f "$tmp"' EXIT
deck file ai2kong -s "$CFG" -o "$tmp"
if [ "${1:-}" = "--diff" ]; then
  deck gateway diff "$tmp"
else
  deck gateway sync --yes "$tmp"
fi
