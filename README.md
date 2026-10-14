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

> **Before using real data:** the example tools and agents call `https://httpbin.org`, a public echo
> service. Replace those `url` values in `config/ai.yaml` with internal services first
> (`up.sh` prints a warning while they are still there; see `docs/known-gaps.md`).

The proxy listens on `https://localhost:8443` (self-signed certificate; use `curl -k`). Routes are
HTTPS only, so plain HTTP on port 8000 returns 426. The control plane Admin API listens on
`127.0.0.1:8001`.

## Changing the configuration

Edit `config/ai.yaml`, run `targets/self-managed/sync.sh --diff` to see exactly what will change, then
`targets/self-managed/sync.sh`. The file is authoritative: removing an entity from it deletes that
entity, and anything created by hand through the Admin API that is not in the file is deleted on the
next sync. To add a new consumer, add it to `config/ai.yaml` and also add a matching `KEY_<NAME>=` line to
`.env` (use a random value, for example `openssl rand -hex 16`). Keep
secrets out of the file: provider credentials are vault references resolved on the data plane from
`AIGW_*` environment variables, and consumer keys come from `KEY_*` entries in `.env`.

## Egress proxy or TLS interception

The gateway calls your model provider (and any upstreams) from the data plane. If outbound traffic goes
through a proxy or a TLS-intercepting device, trust your CA: mount the CA bundle into the data plane
(add a volume to `kong-dp` in `targets/self-managed/docker-compose.yml`, for example
`./extra-ca.pem:/certs/extra-ca.pem:ro`) and add this line to `.env`:

`KONG_LUA_SSL_TRUSTED_CERTIFICATE=system,/certs/extra-ca.pem`

Kong's anonymous usage reports are switched off in the Compose file.

## Values in `.env`

Compose reads `.env`, so a literal `$` in a value must be written as `$$` (otherwise it is interpreted
as a variable and the provider credential is silently mangled). Do not `source` the file; values such as
`Bearer sk-...` contain spaces.

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
| Control plane never becomes healthy | `docker compose logs kong-cp`; a rejected or expired license is reported there. Get a current `license.json` |
| Data plane never connects | `docker compose logs kong-dp kong-cp`; confirm both containers have the license and the same `certs/` |
| Requests return 426 | Use `https://localhost:8443` |
