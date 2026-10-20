# Third-party notices

This repository's own files are under the Apache License 2.0 (see `LICENSE`). The
release assets are archives of third-party software. They are **not** covered by
that license and are provided only so that environments that cannot reach Docker Hub
or GitHub can obtain the same files.

## What the release assets are

| Asset | Contents | Changes made |
|---|---|---|
| `kong-ai-gateway-2.2.0-distroless-amd64.tar.gz` | `kong/kong-ai-gateway:2.2.0-distroless` (linux/amd64) from Docker Hub | None. Saved with `docker save`, then gzip. |
| `postgres-16.4-amd64.tar.gz` | `postgres:16.4` (linux/amd64) from Docker Hub | None. Saved with `docker save`, then gzip. |
| `kong-sample-agent-1.0.0-amd64.tar.gz` | `kong-sample-agent:1.0.0` (linux/amd64), built from `examples/agent` on the Docker Official Image `python:3.12-slim` | The image adds this repository's `agent.py` (Apache License 2.0) to the unmodified Python base image. Saved with `docker save`, then gzip. |
| `deck_<version>_linux_amd64.tar.gz`, `deck_<version>_darwin_all.tar.gz` | decK release archives from the Kong/deck GitHub releases | None. Unmodified upstream files. |

The checksums in `images/SHA256SUMS` let you confirm the files were not altered. Image IDs are listed in `images/README.md`.

## Terms for each component

- **Kong AI Gateway image.** Owned by Kong Inc. and governed by Kong's own terms,
  not by this repository. Running it needs a valid Kong license (`license.json`) issued
  by Kong. Nothing here grants any right to use, copy, or redistribute it. The
  archive is a convenience copy of an image that Kong publishes publicly. Use of the
  software is subject to your agreement with Kong. For authoritative terms, see
  <https://konghq.com/legal> or contact your Kong representative.
- **PostgreSQL image.** The Docker Official Image `postgres:16.4`. PostgreSQL is
  released under the PostgreSQL License. The image also contains other open source
  packages, each under its own license. See <https://www.postgresql.org/about/licence/>
  and the image's own package metadata.
- **Python base image.** The Docker Official Image `python:3.12-slim` (Debian with Python). Python
  is released under the Python Software Foundation License, and the image contains other open source
  packages, each under its own license. See <https://docs.python.org/3/license.html>.
- **decK.** Released by Kong under the Apache License 2.0. See
  <https://github.com/Kong/deck/blob/main/LICENSE>.

## No warranty, no affiliation

The archives are provided as-is, with no warranty. This repository is a community
starter kit. It is not an official Kong product release and is not supported as one.
Use a copy from the original publisher whenever you can reach it. If you are a rights
holder and want an asset removed, open an issue and it will be taken down.
