#!/usr/bin/env bash
# Usage: ./load.sh <dir containing the .tar.gz files and SHA256SUMS>
set -euo pipefail
dir=${1:?usage: load.sh <dir with image tars>}
hash_file() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1
  elif command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | cut -d' ' -f1
  else echo "ERROR: need sha256sum or shasum to verify the archives." >&2; exit 1; fi
}
[ -f "$dir/SHA256SUMS" ] || { echo "ERROR: $dir/SHA256SUMS not found." >&2; exit 1; }
archives=("$dir"/kong-ai-gateway-*-amd64.tar.gz "$dir"/postgres-*-amd64.tar.gz)
# Verify every archive before loading any of them.
for f in "${archives[@]}"; do
  [ -f "$f" ] || { echo "ERROR: missing archive $f" >&2; exit 1; }
  name=$(basename "$f")
  want=$(awk -v n="$name" '$2 == n {print $1}' "$dir/SHA256SUMS")
  [ -n "$want" ] || { echo "ERROR: $name is not listed in SHA256SUMS." >&2; exit 1; }
  [ "$(hash_file "$f")" = "$want" ] || { echo "ERROR: checksum mismatch for $name: re-download it." >&2; exit 1; }
done
for f in "${archives[@]}"; do
  echo "Loading $f"; gunzip -c "$f" | docker load
done
for img in kong/kong-ai-gateway:2.2.0-distroless postgres:16.4; do
  arch=$(docker image inspect "$img" --format '{{.Architecture}}' 2>/dev/null) || { echo "Image $img not loaded." >&2; exit 1; }
  [ "$arch" = amd64 ] || { echo "Image $img is $arch; this package requires linux/amd64 hosts." >&2; exit 1; }
done
echo "Images loaded OK."
