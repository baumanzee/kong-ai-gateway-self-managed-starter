#!/usr/bin/env bash
# Needs a real license.json for part 3. Parts 1-2 use a throwaway placeholder if none exists.
set -euo pipefail
cd "$(dirname "$0")"
[ -f .env ] || cp .env.example .env
placeholder=0
cleanup() { [ "$placeholder" = 1 ] && rm -f license.json; rm -f err.txt; }
trap cleanup EXIT
# 1. refuses without license
[ -f license.json ] && mv license.json license.json.bak
if ./up.sh 2>err.txt; then echo "FAIL: started without license"; exit 1; fi
grep -qi license err.txt || { echo "FAIL: no license message"; cat err.txt; exit 1; }
[ -f license.json.bak ] && mv license.json.bak license.json
# 2. refuses when images are not loaded
if [ ! -f license.json ]; then echo '{"placeholder":true}' > license.json; placeholder=1; fi
docker rmi -f postgres:16.4 >/dev/null 2>&1 || true
if ./up.sh 2>err.txt; then echo "FAIL: started without images"; exit 1; fi
grep -qi 'load.sh' err.txt || { echo "FAIL: no load hint"; cat err.txt; exit 1; }
../../images/load.sh ../../../dist >/dev/null
echo "PASS parts 1-2"
[ "$placeholder" = 1 ] && { echo "SKIP part 3: no real license.json"; exit 0; }
# 3. healthy stack
./up.sh
curl -fsS http://127.0.0.1:8001/status >/dev/null || { echo FAIL cp; exit 1; }
n=0
for i in $(seq 1 30); do
  n=$(curl -fsS http://127.0.0.1:8001/clustering/data-planes | python3 -c 'import sys,json;print(len(json.load(sys.stdin)["data"]))' 2>/dev/null || echo 0)
  [ "$n" -ge 1 ] && break; sleep 2
done
[ "$n" -ge 1 ] || { echo "FAIL: no DP connected"; exit 1; }
echo PASS
