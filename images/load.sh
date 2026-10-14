#!/usr/bin/env bash
# Usage: ./load.sh <dir containing the .tar.gz files and SHA256SUMS>
set -euo pipefail
dir=${1:?usage: load.sh <dir with image tars>}
(cd "$dir" && shasum -a 256 -c SHA256SUMS --ignore-missing) || { echo "Checksum mismatch: re-download the tar files." >&2; exit 1; }
for f in "$dir"/kong-ai-gateway-*-amd64.tar.gz "$dir"/postgres-*-amd64.tar.gz; do
  echo "Loading $f"; gunzip -c "$f" | docker load
done
for img in kong/kong-ai-gateway:2.2.0-distroless postgres:16.4; do
  arch=$(docker image inspect "$img" --format '{{.Architecture}}' 2>/dev/null) || { echo "Image $img not loaded." >&2; exit 1; }
  [ "$arch" = amd64 ] || { echo "Image $img is $arch; this package requires linux/amd64 hosts." >&2; exit 1; }
done
echo "Images loaded OK."
