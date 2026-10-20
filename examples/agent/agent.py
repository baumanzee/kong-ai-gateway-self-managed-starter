#!/usr/bin/env python3
"""A small LLM-driven agent that does all of its work through a Kong AI Gateway.

Given a question, the agent asks a model (through the gateway) what to do. The model can call
tools on an MCP server and delegate to other agents (A2A), both also through the gateway, until it
has an answer. Every request the agent sends and every response it gets is logged.

Standard library only, so there is nothing to install:  python3 agent.py "your question"
"""
import json
import os
import ssl
import sys
import time
import urllib.error
import urllib.request
import uuid

GATEWAY_URL = os.environ.get("GATEWAY_URL", "https://host.docker.internal:8443").rstrip("/")
API_KEY = os.environ.get("GATEWAY_API_KEY", "")
API_KEY_HEADER = os.environ.get("API_KEY_HEADER", "X-API-Key")
AGENT_NAME = os.environ.get("AGENT_NAME", "sample-agent")  # sent as X-Agent-Name; shows up in the gateway's access log
MODEL = os.environ.get("MODEL", "lending-llm")
LLM_PATH = os.environ.get("LLM_PATH", "/v1")
MCP_PATH = os.environ.get("MCP_PATH", "/mcp/underwriting")
A2A_PREFIX = os.environ.get("A2A_PATH_PREFIX", "/agents")
AGENTS = [a.strip() for a in os.environ.get("A2A_AGENTS", "risk-rating,preverification").split(",") if a.strip()]
MAX_STEPS = int(os.environ.get("MAX_STEPS", "6"))
LOG_BODY_CHARS = int(os.environ.get("LOG_BODY_CHARS", "1500"))
# The starter gateway presents a self-signed certificate. true, false, or the path of a CA bundle.
TLS_VERIFY = os.environ.get("GATEWAY_TLS_VERIFY", "false")

SYSTEM_PROMPT = (
    "You are a loan underwriting assistant. Use the available tools to look things up and the "
    "ask_agent tool to consult other agents. Report plainly what each tool or agent returned, "
    "including any errors. If an agent only echoes your request back instead of answering, say it gave no answer. Be concise."
)

DEFAULT_QUESTION = (
    "For applicant APP-1001, pull the credit report, then ask the risk-rating agent for a rating "
    "(income 85000, DTI 32%, credit score 710) and summarize."
)

_run_id = uuid.uuid4().hex[:8]
_request_count = 0
_mcp_session = None


# --- logging -----------------------------------------------------------------------------------

def log(message):
    print(f"{time.strftime('%H:%M:%S')} {message}", flush=True)


def mask(headers):
    """Copy of the headers that is safe to log: the API key is cut short, other credentials hidden."""
    safe = {}
    for name, value in headers.items():
        if name.lower() == API_KEY_HEADER.lower():
            safe[name] = value[:8] + "…" if len(value) > 8 else "***"
        elif name.lower() in ("authorization", "proxy-authorization"):
            safe[name] = "***"
        else:
            safe[name] = value
    return safe


def clip(text, limit):
    return text if len(text) <= limit else f"{text[:limit]}… (+{len(text) - limit} chars)"


# --- one HTTP call through the gateway ---------------------------------------------------------

def _ssl_context():
    if not GATEWAY_URL.startswith("https"):
        return None
    if TLS_VERIFY.lower() in ("true", "1", "yes"):
        return ssl.create_default_context()
    if TLS_VERIFY.lower() in ("false", "0", "no"):
        context = ssl.create_default_context()
        context.check_hostname = False
        context.verify_mode = ssl.CERT_NONE
        return context
    return ssl.create_default_context(cafile=TLS_VERIFY)


def call_gateway(path, body, extra_headers=None):
    """POST a JSON body to the gateway. Returns (status, response headers, response text)."""
    global _request_count
    _request_count += 1
    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json, text/event-stream",
        "User-Agent": f"{AGENT_NAME}/1.0",
        "X-Agent-Name": AGENT_NAME,
        "X-Request-Id": f"{_run_id}-{_request_count}",
        API_KEY_HEADER: API_KEY,
        **(extra_headers or {}),
    }
    url = GATEWAY_URL + path
    payload = json.dumps(body)
    log(f"--> POST {url}")
    log(f"    headers {json.dumps(mask(headers), ensure_ascii=False)}")
    log(f"    body    {clip(payload, LOG_BODY_CHARS)}")
    started = time.monotonic()
    request = urllib.request.Request(url, data=payload.encode(), headers=headers, method="POST")
    try:
        with urllib.request.urlopen(request, timeout=90, context=_ssl_context()) as response:
            status, response_headers, text = response.status, dict(response.headers), response.read().decode()
    except urllib.error.HTTPError as error:  # 4xx/5xx still carry a body worth showing
        status, response_headers, text = error.code, dict(error.headers), error.read().decode(errors="replace")
    except (urllib.error.URLError, OSError) as error:
        log(f"<-- no response from {url}: {error}")
        raise SystemExit(f"cannot reach the gateway at {GATEWAY_URL}: {error}")
    elapsed = int((time.monotonic() - started) * 1000)
    log(f"<-- {status} in {elapsed}ms")
    log(f"    body    {clip(' '.join(text.split()), LOG_BODY_CHARS)}")
    return status, response_headers, text


def parse_body(content_type, text):
    """A JSON-RPC reply is either plain JSON or a server-sent-event stream; return the response message."""
    if "text/event-stream" in content_type:
        found = {}
        for line in text.splitlines():
            if line.startswith("data:"):
                try:
                    message = json.loads(line[5:].strip())
                except ValueError:
                    continue
                if isinstance(message, dict) and ("result" in message or "error" in message):
                    found = message
        return found
    try:
        message = json.loads(text)
    except ValueError:
        return {}
    return message if isinstance(message, dict) else {}


# --- model -------------------------------------------------------------------------------------

def chat(messages, tools):
    body = {"model": MODEL, "messages": messages, "max_tokens": 600}
    if tools:
        body["tools"] = tools
    status, _, text = call_gateway(f"{LLM_PATH}/chat/completions", body)
    if status != 200:
        raise SystemExit(f"model call failed with HTTP {status}")
    return json.loads(text)["choices"][0]["message"]


# --- MCP tools ---------------------------------------------------------------------------------

def mcp_call(method, params=None, notification=False):
    global _mcp_session
    body = {"jsonrpc": "2.0", "method": method}
    if params is not None:
        body["params"] = params
    if not notification:
        body["id"] = _request_count + 1
    extra = {"Mcp-Session-Id": _mcp_session} if _mcp_session else {}
    status, headers, text = call_gateway(MCP_PATH, body, extra)
    if method == "initialize":
        _mcp_session = {k.lower(): v for k, v in headers.items()}.get("mcp-session-id")
    if status not in (200, 202):
        return {"error": {"message": f"HTTP {status}"}}
    return parse_body({k.lower(): v for k, v in headers.items()}.get("content-type", ""), text)


def mcp_tools():
    mcp_call(
        "initialize",
        {"protocolVersion": "2025-03-26", "capabilities": {}, "clientInfo": {"name": AGENT_NAME, "version": "1.0"}},
    )
    mcp_call("notifications/initialized", notification=True)
    reply = mcp_call("tools/list", {})
    return reply.get("result", {}).get("tools", [])


def mcp_tool(name, arguments):
    reply = mcp_call("tools/call", {"name": name, "arguments": arguments})
    if "error" in reply:
        return f"tool error: {reply['error'].get('message', reply['error'])}"
    result = reply.get("result", {})
    text = "\n".join(c.get("text", "") for c in result.get("content", []) if c.get("type") == "text")
    return f"tool error: {text}" if result.get("isError") else text


# --- other agents (A2A) ------------------------------------------------------------------------

def a2a_text(body, raw):
    """The text of an A2A reply. A non-A2A reply (for example an echo service) is returned as received."""
    if "error" in body:
        return f"agent error: {body['error'].get('message', body['error'])}"
    parts = (body.get("result") or {}).get("parts") or []
    text = " ".join(p.get("text", "") for p in parts if isinstance(p, dict) and p.get("text"))
    return text or raw


def ask_agent(agent_name, message):
    body = {
        "jsonrpc": "2.0",
        "id": uuid.uuid4().hex,
        "method": "message/send",
        "params": {
            "message": {
                "kind": "message",
                "messageId": uuid.uuid4().hex,
                "role": "user",
                "parts": [{"kind": "text", "text": message}],
            }
        },
    }
    status, _, text = call_gateway(f"{A2A_PREFIX}/{agent_name}", body)
    if status != 200:
        return f"agent error: HTTP {status}: {clip(text, 300)}"
    try:
        parsed = json.loads(text)
    except ValueError:
        return text
    return a2a_text(parsed if isinstance(parsed, dict) else {}, text)


# --- the agent loop ----------------------------------------------------------------------------

def to_openai_tools(mcp_tool_list, agent_names):
    tools = [
        {
            "type": "function",
            "function": {
                "name": t["name"],
                "description": t.get("description", ""),
                "parameters": t.get("inputSchema") or {"type": "object", "properties": {}},
            },
        }
        for t in mcp_tool_list
    ]
    tools.append(
        {
            "type": "function",
            "function": {
                "name": "ask_agent",
                "description": "Send a message to another agent and get its reply.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "agent": {"type": "string", "enum": agent_names},
                        "message": {"type": "string", "description": "What to ask, with the applicant details it needs."},
                    },
                    "required": ["agent", "message"],
                },
            },
        }
    )
    return tools


def run(question):
    log(f"agent {AGENT_NAME} run={_run_id} gateway={GATEWAY_URL}")
    if GATEWAY_URL.startswith("https") and TLS_VERIFY.lower() in ("false", "0", "no"):
        log("note: TLS certificate verification is off (GATEWAY_TLS_VERIFY=false)")
    log(f"question: {question}")
    tools = to_openai_tools(mcp_tools(), AGENTS)
    log(f"tools visible to this agent: {', '.join(t['function']['name'] for t in tools)}")
    messages = [{"role": "system", "content": SYSTEM_PROMPT}, {"role": "user", "content": question}]
    for step in range(1, MAX_STEPS + 1):
        log(f"--- step {step}: asking the model")
        reply = chat(messages, tools)
        messages.append(reply)
        calls = reply.get("tool_calls") or []
        if not calls:
            return reply.get("content") or ""
        for call in calls:
            name = call["function"]["name"]
            try:
                arguments = json.loads(call["function"].get("arguments") or "{}")
            except ValueError:
                arguments = {}
            log(f"--- model asked for {name}({json.dumps(arguments)})")
            if name == "ask_agent" and arguments.get("agent") in AGENTS:
                result = ask_agent(arguments["agent"], arguments.get("message", ""))
            elif name == "ask_agent":
                result = f"unknown agent {arguments.get('agent')!r}; choose from {AGENTS}"
            else:
                result = mcp_tool(name, arguments)
            messages.append({"role": "tool", "tool_call_id": call["id"], "content": result})
    return f"(stopped after {MAX_STEPS} steps without a final answer)"


def main(argv):
    if not API_KEY:
        raise SystemExit("GATEWAY_API_KEY is not set")
    answer = run(" ".join(argv) or DEFAULT_QUESTION)
    print(f"\nANSWER: {answer}")


if __name__ == "__main__":
    main(sys.argv[1:])
