# Known gaps

- **Example upstreams.** The MCP tools and agent routes call `https://httpbin.org/anything/...`, a
  public echo service, to demonstrate routing and access control. Replace the `url` values in
  `config/ai.yaml` with an internal echo service or real backends on hosts without internet access.
- **Not covered by the checks.** On-behalf-of versus headless identity flows, guardrail policies, and
  audit policies are not configured or exercised here. The MCP tool call path (a permitted tool
  actually reaching a backend) is not asserted by `tests/verify.sh`.
- **MCP server modes.** The `upstream-server` mode of the AI MCP Server has no self-managed
  equivalent. This example uses `conversion-listener`, which does.
- **Data plane certificates.** The managed-service certificate entity does not exist self-managed;
  `gen-certs.sh` creates a standard cluster certificate pair (valid three years) for the
  control plane to data plane connection.
- **HTTPS only, self-signed.** Routes accept HTTPS only and the proxy presents Kong's default
  self-signed certificate. Use your own certificate for anything beyond a local trial.
- **Not production hardened.** Single Postgres, no TLS on the Admin API (bound to localhost), no RBAC.
