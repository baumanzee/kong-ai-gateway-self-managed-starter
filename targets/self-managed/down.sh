#!/usr/bin/env bash
# Usage: ./down.sh [--volumes]   (--volumes also deletes the database)
cd "$(dirname "$0")" && docker compose down "$@"
