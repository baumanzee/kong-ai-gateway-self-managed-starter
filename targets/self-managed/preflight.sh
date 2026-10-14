#!/usr/bin/env bash
# Everything up.sh needs to be true before it starts containers. Safe to run on its own.
# (SKIP_IMAGE_CHECK=1 skips the docker image check.)
set -euo pipefail
cd "$(dirname "$0")"
fail() { echo "ERROR: $*" >&2; exit 1; }

[ -f license.json ] || fail "license.json not found in $(pwd). Place your Kong license file here."
for key in license signature payload; do
  grep -q "\"$key\"" license.json || fail "license.json does not look like a Kong license file (expected a JSON document with license, signature and payload). Re-download it; quotes must be straight, not curly."
done
if command -v python3 >/dev/null 2>&1; then
  python3 -c 'import json; json.load(open("license.json"))' 2>/dev/null || fail "license.json is not valid JSON (check for curly quotes)."
fi

[ -f .env ] || fail ".env not found. Run ./init-env.sh to create it, then set AIGW_OPENAI_AUTH_HEADER."
grep -Eq '^AIGW_OPENAI_AUTH_HEADER=.+' .env && ! grep -Eq '^AIGW_OPENAI_AUTH_HEADER=.*REPLACE' .env \
  || fail "AIGW_OPENAI_AUTH_HEADER in .env is empty or still the placeholder. Set it to your model provider credential (for example: Bearer sk-...)."

if [ ! -f certs/cluster.crt ] || [ ! -f certs/cluster.key ]; then
  rm -rf certs/cluster.crt certs/cluster.key   # a half-present pair (or a directory Docker created) breaks the mounts
  ./gen-certs.sh --force
fi
# The Kong containers run as an unprivileged user and bind-mount these files: they must be readable.
chmod a+rx certs
chmod a+r license.json certs/cluster.crt certs/cluster.key

if [ "${SKIP_IMAGE_CHECK:-0}" != 1 ]; then
  for img in kong/kong-ai-gateway:2.2.0-distroless postgres:16.4; do
    docker image inspect "$img" >/dev/null 2>&1 || fail "image $img not loaded. Run: ../../images/load.sh <dir with image tars>"
  done
fi

if grep -q 'httpbin.org' ../../config/ai.yaml 2>/dev/null; then
  echo "WARNING: config/ai.yaml sends tool and agent requests to https://httpbin.org, a PUBLIC echo service. Replace those urls with internal services before using real data (see docs/known-gaps.md)." >&2
fi
