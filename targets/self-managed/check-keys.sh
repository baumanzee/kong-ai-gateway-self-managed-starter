#!/usr/bin/env bash
# Every DECK_KEY_<NAME> that config/ai.yaml references needs a non-empty KEY_<NAME> line in .env.
# Usage: ./check-keys.sh [config-file]   (exits 1 and names each missing key)
set -euo pipefail
cd "$(dirname "$0")"
CFG=${1:-${AI_CONFIG:-../../config/ai.yaml}}
[ -f .env ] || { echo "ERROR: .env not found. Run ./init-env.sh to create it." >&2; exit 1; }
missing=
for k in $(grep -o 'DECK_KEY_[A-Z0-9_]*' "$CFG" | sort -u | sed 's/^DECK_//'); do
  grep -Eq "^${k}=.+" .env || missing="$missing $k"
done
if [ -n "$missing" ]; then
  echo "ERROR: .env has no value for:$missing" >&2
  echo "Each consumer in config/ai.yaml needs a KEY_<NAME> line. Add one with a random value (for example: openssl rand -hex 16), or re-run ./init-env.sh on a new .env." >&2
  exit 1
fi
