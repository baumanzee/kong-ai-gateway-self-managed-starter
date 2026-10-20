# Known gaps

- **Example upstreams.** The MCP tools and agent routes call `https://httpbin.org/anything/...`, a
  public echo service, to demonstrate routing and access control. Replace the `url` values in
  `config/ai.yaml` with an internal echo service or real backends on hosts without internet access.
- **Not covered by the checks.** On-behalf-of versus headless identity flows, guardrail policies, and
  audit policies are not configured or exercised here.
- **MCP upstream URL.** `deck file ai2kong` drops each MCP server's `url` and leaves its service at
  `localhost:80`, which made every tool call fail with a 502. `sync.sh` puts the protocol, host, port and
  path back from the `url` in `config/ai.yaml` after the conversion. If you apply the config another way
  (for example `deck ai sync`), the tool calls fail until the service is corrected.
- **MCP server modes.** The `upstream-server` mode of the AI MCP Server has no self-managed
  equivalent. This example uses `conversion-listener`, which does.
- **Data plane certificates.** The managed-service certificate entity does not exist self-managed;
  `gen-certs.sh` creates a standard cluster certificate pair (valid three years) for the
  control plane to data plane connection.
- **HTTPS only, self-signed.** Routes accept HTTPS only and the proxy presents Kong's default
  self-signed certificate. Use your own certificate for anything beyond a local trial.
- **Not production hardened.** Single Postgres, no TLS on the Admin API (bound to localhost), no RBAC.
