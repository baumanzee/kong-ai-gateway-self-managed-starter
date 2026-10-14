#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
docker rmi -f kong/kong-ai-gateway:2.2.0-distroless postgres:16.4 >/dev/null 2>&1 || true
./load.sh ../../dist
for img in kong/kong-ai-gateway:2.2.0-distroless postgres:16.4; do
  [ "$(docker image inspect "$img" --format '{{.Architecture}}')" = amd64 ] || { echo "FAIL arch $img"; exit 1; }
done
# corrupted tar must be rejected before loading anything
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
cp ../../dist/SHA256SUMS ../../dist/*.tar.gz "$t"/
printf 'x' >> "$t/postgres-16.4-amd64.tar.gz"
if ./load.sh "$t" >/dev/null 2>&1; then echo "FAIL: corrupted tar accepted"; exit 1; fi
echo PASS
