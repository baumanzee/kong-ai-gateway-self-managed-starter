# Offline images

Your environment cannot reach Docker Hub, so the container images are delivered as files.

Files (delivered separately from this repository):

| File | Contents |
|---|---|
| `kong-ai-gateway-2.2.0-distroless-amd64.tar.gz` | `kong/kong-ai-gateway:2.2.0-distroless` (linux/amd64) |
| `postgres-16.4-amd64.tar.gz` | `postgres:16.4` (linux/amd64) |
| `kong-sample-agent-1.0.0-amd64.tar.gz` | Optional: the sample agent image (`examples/agent`). Load it with `gunzip -c <file> \| docker load`; `load.sh` does not load it |
| `deck_<version>_<os>.tar.gz` | decK command-line tool (see `../tools/README.md`) |
| `SHA256SUMS` | checksums for all files above (also committed here) |

Reference image IDs at build time:

- `kong/kong-ai-gateway:2.2.0-distroless` `sha256:d21eba9369580aedc6bebd828cd9cc7b9532d6de43c4737851bb0dc67a2b0549`
- `postgres:16.4` `sha256:6b14e73a48cf2518aeb37e8b758a907473bcc72727297a7353a665afa069ef10`

Load them (verifies checksums and architecture first):

```bash
./images/load.sh /path/to/folder/with/the/tar/files
```

The hosts must be linux/amd64.
