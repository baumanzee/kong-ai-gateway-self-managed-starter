#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
fail() { echo "ERROR: $*" >&2; exit 1; }
[ -f license.json ] || fail "license.json not found in $(pwd). Place your Kong license file here."
python3 -c 'import json; json.load(open("license.json"))' 2>/dev/null || fail "license.json is not valid JSON (check for curly quotes)."
[ -f .env ] || fail ".env not found. Copy .env.example to .env and fill it in."
[ -f certs/cluster.crt ] || ./gen-certs.sh
for img in kong/kong-ai-gateway:2.2.0-distroless postgres:16.4; do
  docker image inspect "$img" >/dev/null 2>&1 || fail "image $img not loaded. Run: ../../images/load.sh <dir with image tars>"
done
docker compose up -d
echo "Waiting for control plane..."
for i in $(seq 1 60); do curl -fsS http://127.0.0.1:8001/status >/dev/null 2>&1 && { echo "CP up."; exit 0; }; sleep 2; done
fail "control plane did not become ready; run: docker compose logs kong-cp"
