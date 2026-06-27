# Tavily Research Bot — flow + Agentic Worker demo

A minimal demo that **combines a flow with an Agentic Worker**. Every chat
message is handed to a single `dw.agent` node — an LLM Plan-Act-Observe agent
that uses the **Tavily** design extension (`tavily_search` / `tavily_extract`)
to research the web and answer the user in chat.

```
WebChat  ──message──▶  flow on_message
                         │
                         ▼
                   research  (dw.agent → "tavily_researcher")
                         │     • reads the message as user_text
                         │     • calls tavily_search / tavily_extract
                         │     • synthesizes an answer + sources
                         ▼
                   send_reply (messaging.emit)  ──▶ reply in WebChat
```

> **New pattern:** this is the first bundle in the repo to wire a `dw.agent`
> node + a tool extension into a `gtc start` bundle. The flow/agent/provider
> files are authored to match runner conventions, but the agentic-worker path
> needs live keys + Redis to actually run, so it cannot be fully pre-tested
> here. If the first run trips on a path detail, it'll be in the agent-config
> discovery or secret provisioning (notes below).

## Layout

```
tavily-research-demo/
├── greentic.demo.yaml                 # bundle config: tenant + webchat provider
├── apps/tavily-bot/
│   ├── pack.yaml                      # app pack manifest (flow reference)
│   └── flows/on_message.ygtc          # flow: message → dw.agent → reply
├── agents/tavily_researcher.json      # the AgentConfig (system_prompt + tools + llm)
├── providers/messaging-webchat.gtpack # webchat provider (copied from demo-bundle)
├── setup.sh                           # installs the tavily ext + agent config, checks env
└── README.md
```

The `agent_id` `tavily_researcher` in `agents/tavily_researcher.json` must match
the `operation:` field of the `dw.agent` node in `flows/on_message.ygtc`.

## Prerequisites

- The `gtc` CLI built from this workspace (`greentic/greentic`).
- **Redis** — the agentic-worker runtime needs it for state:
  `docker run -p 6379:6379 redis` (or any local Redis).
- An **LLM key** (the agent's brain). The agent is configured for DeepSeek
  (`agents/tavily_researcher.json` → `provider: deepseek`, `model: deepseek-chat`).
  Provide it via `GREENTIC_LLM_API_KEY` + `GREENTIC_LLM_PROVIDER=deepseek`
  (`GREENTIC_LLM_MODEL=deepseek-chat`). For OpenAI instead, set
  `provider: openai` in the agent config and export `OPENAI_API_KEY`.
- A **Tavily API key** (web search): get one at https://tavily.com — provisioned
  during `gtc setup` (see below).

## Run

```bash
# 1. Install the Tavily extension + agent config and sanity-check env.
export GREENTIC_AW_REDIS_URL=redis://localhost:6379
export GREENTIC_LLM_PROVIDER=deepseek
export GREENTIC_LLM_MODEL=deepseek-chat
export GREENTIC_LLM_API_KEY=sk-...        # your DeepSeek key
bash tavily-research-demo/setup.sh

# 2. Provision bundle secrets (prompts for the Tavily key, etc.).
gtc setup ./tavily-research-demo

# 3. Start the demo (embedded NATS + webchat + runner).
gtc start ./tavily-research-demo
#    → open http://127.0.0.1:8080/webchat
```

Then in the webchat, ask something that needs fresh info, e.g.
*"What did Anthropic announce most recently?"* or
*"Berita terbaru soal harga Bitcoin?"* — the agent will call Tavily and reply
with a synthesized answer and source links.

## How the pieces connect (reference)

| Piece | Where | Note |
|-------|-------|------|
| Flow node kind | `flows/on_message.ygtc` → `dw.agent:` | `operation:` = agent_id |
| Agent input | `user_text: "{{in.text}}"` | the only key the agent reads |
| Agent output | `{{research.reply}}` | also `.trail`, `.terminated_by` |
| Agent definition | `agents/tavily_researcher.json` | `system_prompt` is the agent's prompt |
| Agent tools | `greentic.tavily` / `tavily_search`,`tavily_extract` | from the installed design extension |
| Where the runner finds the agent | `GREENTIC_AGENT_MANIFESTS_DIR` (default `~/.greentic/agents`) | `setup.sh` copies it there |
| Where the runner finds the tool ext | `GREENTIC_EXTENSIONS_DIR/design/greentic.tavily/` | `setup.sh` unzips it there |
| Tavily secret | ref `secret://tavily/api_key` (ext) | runner canonicalizes; provision via `gtc setup` |

## Tuning the agent

Edit `agents/tavily_researcher.json` and re-run `bash tavily-research-demo/setup.sh`
(it re-copies the config). Useful knobs:

- `system_prompt` — the persona / instructions (when to search, how to cite, language).
- `llm.model` — e.g. `gpt-4o-mini` (cheap) → `gpt-4o` (stronger).
- `limits` — left `{}` (defaults: `max_iter` 8, `timeout` 60s). Raise `max_iter`
  if the agent needs more research/tool rounds.

## Troubleshooting

- **Agent node errors with "AgentNotFound"** → the `<agent_id>.json` isn't in
  `GREENTIC_AGENT_MANIFESTS_DIR`; re-run `setup.sh` or set the env var to where
  you put it. The `operation:` in the flow must equal the `agent_id`.
- **Tool not found / Tavily errors** → the ext isn't under
  `GREENTIC_EXTENSIONS_DIR/design/greentic.tavily/` (needs `describe.json` +
  `extension.wasm`), or the Tavily secret wasn't provisioned in `gtc setup`.
- **dw.agent does nothing / disabled** → `GREENTIC_AW_REDIS_URL` unset or Redis
  unreachable. The agentic worker needs Redis under `gtc start`.
- **No LLM** → set `OPENAI_API_KEY` (or `GREENTIC_LLM_API_KEY`).
