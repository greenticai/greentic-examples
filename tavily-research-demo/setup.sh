#!/usr/bin/env bash
#
# One-time setup for the Tavily research demo. Installs the Tavily design
# extension and the agent config where the runner looks for them, then checks
# the secrets/services the agentic worker needs at run time.
#
# Run from anywhere:  bash tavily-research-demo/setup.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

# Where the runner discovers tool extensions and agent configs (CLAUDE.md /
# greentic-runner conventions). Override via env if you keep them elsewhere.
EXT_DIR="${GREENTIC_EXTENSIONS_DIR:-$HOME/.greentic/extensions}"
AGENTS_DIR="${GREENTIC_AGENT_MANIFESTS_DIR:-$HOME/.greentic/agents}"

# The prebuilt Tavily extension (.gtxpack = zip of extension.wasm + describe.json).
# Defaults to the sibling component-tavily-ext repo; override with TAVILY_GTXPACK.
TAVILY_GTXPACK="${TAVILY_GTXPACK:-$HERE/../component-tavily-ext/greentic.tavily-0.1.0.gtxpack}"

echo "==> Installing Tavily extension"
if [ ! -f "$TAVILY_GTXPACK" ]; then
  echo "    ERROR: tavily gtxpack not found at: $TAVILY_GTXPACK" >&2
  echo "    Set TAVILY_GTXPACK=/path/to/greentic.tavily-*.gtxpack and re-run." >&2
  exit 1
fi
DEST="$EXT_DIR/design/greentic.tavily"
mkdir -p "$DEST"
unzip -o "$TAVILY_GTXPACK" -d "$DEST" >/dev/null   # → describe.json + extension.wasm
echo "    installed → $DEST"

echo "==> Installing agent config"
mkdir -p "$AGENTS_DIR"
cp "$HERE/agents/tavily_researcher.json" "$AGENTS_DIR/tavily_researcher.json"
echo "    installed → $AGENTS_DIR/tavily_researcher.json"

echo "==> Checking required secrets / services"
warn() { echo "    [!] $*"; }

# LLM key (the agent's brain)
if [ -n "${GREENTIC_LLM_API_KEY:-}" ] || [ -n "${OPENAI_API_KEY:-}" ]; then
  echo "    [ok] LLM key present (GREENTIC_LLM_API_KEY / OPENAI_API_KEY)"
else
  warn "no LLM key — export OPENAI_API_KEY=sk-... (or GREENTIC_LLM_API_KEY)"
fi

# Tavily key — the extension requests secret `tavily/api_key`. The runner
# canonicalizes secret refs (non-alnum -> '_'), so the raw ref is not a plain
# bash identifier you can `export`. Provision it the bundle-native way during
# `gtc setup` (it prompts for required secrets). We only remind here.
echo "    [i] Tavily key (secret 'tavily/api_key') is provisioned during 'gtc setup'."
echo "        Get a key at https://tavily.com and paste it when setup prompts."

# Redis — required by the agentic-worker runtime under gtc start.
if [ -z "${GREENTIC_AW_REDIS_URL:-}" ]; then
  warn "GREENTIC_AW_REDIS_URL unset — export GREENTIC_AW_REDIS_URL=redis://localhost:6379 and run a Redis (e.g. 'docker run -p 6379:6379 redis')"
elif command -v redis-cli >/dev/null 2>&1; then
  if redis-cli -u "$GREENTIC_AW_REDIS_URL" ping >/dev/null 2>&1; then
    echo "    [ok] Redis reachable at $GREENTIC_AW_REDIS_URL"
  else
    warn "Redis not reachable at $GREENTIC_AW_REDIS_URL — start one before 'gtc start'"
  fi
else
  echo "    [ok] GREENTIC_AW_REDIS_URL set (redis-cli not installed; skipping ping)"
fi

echo
echo "Setup done. Next:"
echo "  gtc setup ./tavily-research-demo     # materialize the bundle"
echo "  gtc start ./tavily-research-demo     # then open http://127.0.0.1:8080/webchat"
