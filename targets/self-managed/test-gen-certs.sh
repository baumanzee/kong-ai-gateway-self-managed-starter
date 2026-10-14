#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
rm -rf certs
./gen-certs.sh
openssl x509 -in certs/cluster.crt -noout -subject | grep -q kong_clustering || { echo FAIL subject; exit 1; }
[ "$(stat -f %Lp certs/cluster.key 2>/dev/null || stat -c %a certs/cluster.key)" = 600 ] || { echo FAIL mode; exit 1; }
before=$(shasum certs/cluster.crt); ./gen-certs.sh; [ "$before" = "$(shasum certs/cluster.crt)" ] || { echo FAIL not-idempotent; exit 1; }
echo PASS
