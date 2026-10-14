#!/usr/bin/env bash
# Creates .env from .env.example with random consumer keys and database password.
# You still set AIGW_OPENAI_AUTH_HEADER yourself. Does nothing if .env already exists.
set -euo pipefail
cd "$(dirname "$0")"
if [ -f .env ]; then echo ".env already exists; leaving it alone."; exit 0; fi
rand() { openssl rand -hex 16; }
while IFS= read -r line; do
  case "$line" in
    PG_PASSWORD=*) echo "PG_PASSWORD=$(rand)" ;;
    KEY_*=*)       echo "${line%%=*}=$(rand)" ;;
    *)             echo "$line" ;;
  esac
done < .env.example > .env
chmod 600 .env
echo "Created .env. Edit AIGW_OPENAI_AUTH_HEADER (your provider credential) before running sync.sh."
