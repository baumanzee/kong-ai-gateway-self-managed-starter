# Verification

`tests/verify.sh [base-url]` runs eight checks (default base URL `https://localhost:8443`):

| Check | Expectation |
|---|---|
| Model call without a key | rejected (401 or 403) |
| MCP call without a key | rejected (401 or 403) |
| MCP `tools/list` as the credit-and-income stage | exactly `pull-credit-report` and `verify-income` |
| MCP `tools/list` as the risk-rating stage | exactly `score-risk` |
| A permitted MCP tool call (`pull-credit-report` as the credit-and-income stage) | content returned from the upstream, no error |
| Final-approval agent route called by the pre-verification stage | 403 |
| Model call by a lending caller | 200 |
| Repeated large model calls by the headless caller | 429 once the hourly token budget is spent |

The last two checks make real calls to your model provider. The token-budget check can send up to
about 40 requests and consumes provider tokens.

If the last two checks return 401, the gateway itself is working: the model provider rejected the
provider credential in `AIGW_OPENAI_AUTH_HEADER`. A 401 from the provider looks the same as a 401 from
the gateway, so the five checks before them are the ones that prove the gateway's own behavior.

## Try it by hand

Keys are in `targets/self-managed/.env` (`KEY_*`). Read them with `grep`; do not `source` the file.

```bash
KEY_LOAN_OFFICER_APP=$(grep '^KEY_LOAN_OFFICER_APP=' targets/self-managed/.env | cut -d= -f2-)
KEY_AGENT_CREDIT_INCOME=$(grep '^KEY_AGENT_CREDIT_INCOME=' targets/self-managed/.env | cut -d= -f2-)

# Model call (OpenAI-compatible)
curl -sk https://localhost:8443/v1/chat/completions \
  -H "X-API-Key: $KEY_LOAN_OFFICER_APP" -H 'Content-Type: application/json' \
  -d '{"model":"lending-llm","messages":[{"role":"user","content":"Say OK"}]}'

# Tools visible to one stage
curl -sk https://localhost:8443/mcp/underwriting \
  -H "X-API-Key: $KEY_AGENT_CREDIT_INCOME" -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
```

Change the key to another stage's key to see a different tool list. Agent routes live under
`/agents/<name>` and are limited by the same consumer groups.

## Sample agent

`examples/agent/` shows the same gateway from the agent side, and what the data plane logs for each request. See `examples/agent/README.md`.
