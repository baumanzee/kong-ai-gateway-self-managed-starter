# Kong AI Gateway: self-managed starter

A self-managed Kong AI Gateway (Postgres, control plane, hybrid data plane) configured from a single
file, `config/ai.yaml`, with decK. The example is a consumer-lending underwriting flow: one shared LLM
endpoint, per-stage agent identities, tool-level access control over an MCP server, agent-to-agent
routes, and token budgets by caller type.

Everything is delivered for an environment without Docker Hub access: container images and the decK
binary arrive as files (see `images/README.md` and `tools/README.md`).

## Prerequisites

- A linux/amd64 host with Docker and Docker Compose v2
- The downloaded files: the two image archives, the decK archive, and `SHA256SUMS`
- A Kong Enterprise license file (`license.json`)
- A credential for an OpenAI-compatible model provider
- Outbound access from the data plane to the model provider, and to `httpbin.org` if you keep the
  example upstreams (see `docs/known-gaps.md`)

## Quick start

All commands run from the repository root unless noted.

1. Load the images (verifies checksums and architecture):
   `./images/load.sh /path/to/downloaded/files`
2. Install decK (see `tools/README.md`) and check `deck version`.
3. Place your license at `targets/self-managed/license.json`.
4. Create your environment file, then set your provider credential:
   `targets/self-managed/init-env.sh`
   Edit `targets/self-managed/.env` and set `AIGW_OPENAI_AUTH_HEADER` (for example `Bearer sk-...`).
   The script generates the database password and one random API key per consumer.
5. Start the stack: `targets/self-managed/up.sh`
6. Preview, then apply the configuration:
   `targets/self-managed/sync.sh --diff`
   `targets/self-managed/sync.sh`
7. Verify behavior: `tests/verify.sh` (see `docs/verification.md`; it makes real model calls).

The proxy listens on `https://localhost:8443` (self-signed certificate; use `curl -k`). Routes are
HTTPS only, so plain HTTP on port 8000 returns 426. The control plane Admin API listens on
`127.0.0.1:8001`.

## Changing the configuration

Edit `config/ai.yaml`, run `targets/self-managed/sync.sh --diff` to see exactly what will change, then
`targets/self-managed/sync.sh`. Removing an entity from the file deletes it from the gateway. Keep
secrets out of the file: provider credentials are vault references resolved on the data plane from
`AIGW_*` environment variables, and consumer keys come from `KEY_*` entries in `.env`.

## Stopping

`targets/self-managed/down.sh` stops the stack; add `--volumes` to also delete the database.

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| `up.sh`: license.json not found / not valid JSON | Place the file at `targets/self-managed/license.json`; make sure it has straight quotes |
| `up.sh`: image not loaded | Run `images/load.sh` first; Compose never pulls from the internet |
| `images/load.sh`: checksum mismatch | Re-download the archive |
| `images/load.sh`: not amd64 | These images only run on linux/amd64 hosts |
| `sync.sh`: cannot reach the Admin API | The control plane is not up; run `docker compose logs kong-cp` in `targets/self-managed` |
| Data plane never connects | `docker compose logs kong-dp kong-cp`; confirm both containers have the license and the same `certs/` |
| Requests return 426 | Use `https://localhost:8443` |
