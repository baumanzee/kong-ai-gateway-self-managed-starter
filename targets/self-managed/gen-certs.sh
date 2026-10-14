#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p certs
if [ -f certs/cluster.crt ] && [ "${1:-}" != "--force" ]; then echo "certs exist (use --force to regenerate)"; exit 0; fi
openssl req -new -x509 -nodes -newkey ec:<(openssl ecparam -name secp384r1) \
  -keyout certs/cluster.key -out certs/cluster.crt -days 1095 -subj "/CN=kong_clustering"
chmod 600 certs/cluster.key
echo "wrote certs/cluster.crt and certs/cluster.key"
