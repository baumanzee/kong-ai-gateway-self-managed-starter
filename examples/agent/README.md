# Sample agent

A small agent, in one Python file (`agent.py`, standard library only), that does all of its work through
your gateway. Read it as a template for building your own. Given a question, it asks the model what to do;
the model can call tools on the MCP server and consult other agents, until it has an answer. Each of those
calls is a request to the gateway:

| Path | What it is |
|---|---|
| `/v1/chat/completions` | Model call (`lending-llm`) |
| `/mcp/underwriting` | MCP: initialize, tool list, tool calls |
| `/agents/<name>` | Agent-to-agent (A2A) call |

It authenticates as the `agent-credit-income` consumer, so it sees only that stage's tools.

## Run it

The gateway stack from the main README must be up and `config/ai.yaml` synced. From the repository root:

```bash
docker run --rm --add-host host.docker.internal:host-gateway \
  -e GATEWAY_API_KEY="$(grep '^KEY_AGENT_CREDIT_INCOME=' targets/self-managed/.env | cut -d= -f2-)" \
  kong-sample-agent:1.0.0 "Ask the risk-rating agent to rate applicant APP-1001"
```

With no question it runs a default one that uses a tool and another agent. Without internet access, load the
image first: `gunzip -c kong-sample-agent-1.0.0-amd64.tar.gz | docker load` (checksum in `SHA256SUMS`). With
internet access, build it: `docker build -t kong-sample-agent:1.0.0 examples/agent`. You can also skip Docker:
set `GATEWAY_URL=https://localhost:8443` and `GATEWAY_API_KEY`, then `python3 examples/agent/agent.py "..."`.

The model calls use your provider credential and consume tokens.

## What you see

**In the agent's output**, every request it sends (`-->`: URL, headers with the key shortened, body) and
every response it gets (`<--`: status, time, body), plus each step the model takes and the final `ANSWER:`.
Each request carries `X-Agent-Name: sample-agent` and a unique `X-Request-Id` (`<run>-<n>`).

**In the data plane's log**, in a second terminal while the agent runs:

```bash
cd targets/self-managed
docker compose logs -f kong-dp | grep -v 'patched method'
```

- One access line per request, naming the agent and its request ID, for example
  `"POST /v1/chat/completions HTTP/1.1" status=200 agent=sample-agent request_id=a592d0c8-4 ...`.
  Search for the agent's `request_id` to match a line to a request in the agent's output.
- The gateway's and plugins' own messages at the default `info` level, such as
  `[ai-mcp-proxy] received rpc request: tools/call`. A denied call shows as `status=403` on its access line.
  The `tools/call` access line shows `agent=-` and no request ID, because the gateway makes that upstream
  call itself.
- For per-request plugin detail (`[ai-proxy-advanced] using model alias: lending-llm`, rate-limit counters,
  `[acl] exiting with status code: 403`), set `KONG_LOG_LEVEL=debug` in `targets/self-managed/.env` and run
  `targets/self-managed/up.sh` again. That is about 40 lines per request; the `grep -v` above hides the
  repetitive ones.

## Things to try

| Try | Expect |
|---|---|
| The default question | tool list shows only `pull-credit-report` and `verify-income`; the credit-report call returns the upstream's reply (an httpbin echo of the request, since the example upstream is an echo service); `risk-rating` is also the httpbin stub, so the agent says it gave no answer |
| `-e A2A_AGENTS=risk-rating,preverification,final-approval` and ask for final approval | the gateway answers 403 (`status=403` in the data plane log) and the agent reports it |
| A wrong `GATEWAY_API_KEY` | 401 from the gateway, shown in the agent's output |

## Settings (environment variables)

`GATEWAY_URL` (default `https://host.docker.internal:8443`), `GATEWAY_API_KEY` (required),
`GATEWAY_TLS_VERIFY` (`false` by default because the starter certificate is self-signed; `true` or a CA bundle
path to verify), `AGENT_NAME`, `MODEL` (`lending-llm`), `MCP_PATH`, `LLM_PATH`, `A2A_PATH_PREFIX`,
`A2A_AGENTS` (agents the model may call), `MAX_STEPS`, `LOG_BODY_CHARS` (1500).
