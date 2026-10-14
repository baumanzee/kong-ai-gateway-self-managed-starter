#!/usr/bin/env bash
# Usage: tests/verify.sh [base-url]     default https://localhost:8443 (self-signed certificate, so -k is used)
# Reads consumer keys (KEY_*) from targets/self-managed/.env, or from $ENVFILE.
# NOTE: the token-budget check sends real model calls and consumes provider tokens.
set -uo pipefail
BASE=${1:-https://localhost:8443}
ENVFILE=${ENVFILE:-$(dirname "$0")/../targets/self-managed/.env}
while IFS='=' read -r n v; do export "$n=$v"; done < <(grep -E '^KEY_[A-Z_]+=' "$ENVFILE")
pass=0; failn=0
check() { # name expected actual
  if [ "$2" = "$3" ]; then echo "PASS $1"; pass=$((pass+1)); else echo "FAIL $1 (expected [$2], got [$3])"; failn=$((failn+1)); fi
}
rejected() { case "$2" in 401|403) echo "PASS $1 ($2)"; pass=$((pass+1));; *) echo "FAIL $1 (expected 401 or 403, got $2)"; failn=$((failn+1));; esac; }
code() { curl -sk -o /dev/null -w '%{http_code}' "$@"; }
mcp_list() { curl -sk -X POST "$BASE/mcp/underwriting" -H "X-API-Key: $1" -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | grep -o '"name":"[a-z-]*"' | sort | tr '\n' ' '; }
chat() { curl -sk -o /dev/null -w '%{http_code}' -X POST "$BASE/v1/chat/completions" -H "X-API-Key: $1" -H 'Content-Type: application/json' -d "$2"; }

# The data plane receives config from the control plane a few seconds after sync; wait for the routes to exist.
printf 'Waiting for the data plane to receive the configuration'
ready=0
for i in $(seq 1 45); do
  c=$(curl -sk -o /dev/null -w '%{http_code}' -X POST "$BASE/v1/chat/completions" -H 'Content-Type: application/json' -d '{}')
  [ "$c" != 404 ] && [ "$c" != 000 ] && { ready=1; break; }
  printf '.'; sleep 2
done
echo
[ "$ready" = 1 ] || { echo "FAIL: no routes at $BASE after 90s (has sync.sh finished? is the data plane connected? docker compose logs kong-dp)"; exit 1; }

rejected "no key rejected on model" "$(code -X POST "$BASE/v1/chat/completions" -H 'Content-Type: application/json' -d '{"model":"lending-llm","messages":[{"role":"user","content":"hi"}]}')"
rejected "no key rejected on MCP" "$(code -X POST "$BASE/mcp/underwriting" -H 'Content-Type: application/json' -d '{}')"
check "credit stage sees only its tools" '"name":"pull-credit-report" "name":"verify-income" ' "$(mcp_list "$KEY_AGENT_CREDIT_INCOME")"
check "risk stage sees only its tool" '"name":"score-risk" ' "$(mcp_list "$KEY_AGENT_RISK_RATING")"
check "agent route rejects out-of-group caller" 403 "$(code "$BASE/agents/final-approval" -H "X-API-Key: $KEY_AGENT_PREVERIFICATION")"
check "model call allowed for lending caller" 200 "$(chat "$KEY_LOAN_OFFICER_APP" '{"model":"lending-llm","max_tokens":5,"messages":[{"role":"user","content":"Say OK"}]}')"
big='{"model":"lending-llm","max_tokens":4000,"messages":[{"role":"user","content":"Write 3000 words about lending."}]}'
last=""
for i in $(seq 1 40); do last=$(chat "$KEY_AGENT_INTAKE_HEADLESS" "$big"); [ "$last" = 429 ] && break; done
check "token budget enforced for headless callers" 429 "$last"
echo "passed=$pass failed=$failn"; [ "$failn" -eq 0 ]
