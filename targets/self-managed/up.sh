#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
./preflight.sh
docker compose up -d
echo "Waiting for control plane..."
for i in $(seq 1 60); do curl -fsS http://127.0.0.1:8001/status >/dev/null 2>&1 && { echo "CP up."; exit 0; }; sleep 2; done
echo "ERROR: control plane did not become ready. Run: docker compose logs kong-cp (a rejected or expired license shows up there)" >&2
exit 1
