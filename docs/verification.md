# Verification

`tests/verify.sh [base-url]` runs seven checks (default base URL `https://localhost:8443`):

| Check | Expectation |
|---|---|
| Model call without a key | rejected (401 or 403) |
| MCP call without a key | rejected (401 or 403) |
| MCP `tools/list` as the credit-and-income stage | exactly `pull-credit-report` and `verify-income` |
| MCP `tools/list` as the risk-rating stage | exactly `score-risk` |
| Final-approval agent route called by the pre-verification stage | 403 |
| Model call by a lending caller | 200 |
| Repeated large model calls by the headless caller | 429 once the hourly token budget is spent |

The last two checks make real calls to your model provider. The token-budget check can send up to
about 40 requests and consumes provider tokens.

## Try it by hand

Keys are in `targets/self-managed/.env` (`KEY_*`).

```bash
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
