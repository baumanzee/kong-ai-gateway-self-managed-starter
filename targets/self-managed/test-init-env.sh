#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
cp .env.example "$t/.env.example"; cp init-env.sh "$t/" 2>/dev/null || true
(cd "$t" && ./init-env.sh >/dev/null)
[ -f "$t/.env" ] || { echo "FAIL: .env not created"; exit 1; }
keys=$(grep '^KEY_' "$t/.env" | cut -d= -f2)
[ "$(echo "$keys" | wc -l | tr -d ' ')" = 7 ] || { echo "FAIL: expected 7 keys"; exit 1; }
[ "$(echo "$keys" | sort -u | wc -l | tr -d ' ')" = 7 ] || { echo "FAIL: keys not unique"; exit 1; }
echo "$keys" | grep -q REPLACE && { echo "FAIL: placeholder key left"; exit 1; }
grep -q '^PG_PASSWORD=change-me' "$t/.env" && { echo "FAIL: default pg password"; exit 1; }
grep -q '^AIGW_OPENAI_AUTH_HEADER=Bearer sk-REPLACE' "$t/.env" || { echo "FAIL: provider header must stay a placeholder"; exit 1; }
before=$(shasum "$t/.env"); (cd "$t" && ./init-env.sh >/dev/null); [ "$before" = "$(shasum "$t/.env")" ] || { echo "FAIL: overwrote existing .env"; exit 1; }
echo PASS
