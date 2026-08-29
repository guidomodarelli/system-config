# Provider adapters

Leer esta referencia antes de ejecutar provider manualmente o modificar helper.

## Prompt obligatorio

Incluir target exacto, modo read-only, prohibición de editar/commit/push, prohibición de invocar otro reviewer y pedido de findings directos con archivo, línea, escenario, severidad y confianza.

## Claude + Copilot API + Terra high

```bash
env ANTHROPIC_BASE_URL="http://localhost:4141" \
  ANTHROPIC_AUTH_TOKEN="dummy" \
  ANTHROPIC_MODEL="gpt-5.6-terra[1m]" \
  ANTHROPIC_DEFAULT_OPUS_MODEL="gpt-5.6-terra[1m]" \
  ANTHROPIC_DEFAULT_SONNET_MODEL="gpt-5.6-terra[1m]" \
  CLAUDE_CODE_USE_VERTEX=0 \
  CLAUDE_CODE_USE_BEDROCK=0 \
  DISABLE_NON_ESSENTIAL_MODEL_CALLS=1 \
  CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
  CLAUDE_CODE_ATTRIBUTION_HEADER=0 \
  CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION=false \
  CLAUDE_CODE_ENABLE_AWAY_SUMMARY=0 \
  CLAUDE_CODE_TOTAL_TOKENS_REMINDER=off \
  MCP_CONNECT_TIMEOUT_MS=20000 \
  CLAUDE_CODE_SUBAGENT_MODEL="gpt-5.6-terra[1m]" \
  claude \
  --permission-mode plan \
  --tools Read,Grep,Glob,Bash \
  --no-session-persistence \
  --output-format text \
  -p "$REVIEW_PROMPT"
```

Do not inherit Copilot API environment from user settings. This command defines full provider profile. Subagents always use Terra.

## Claude direct

```bash
env -u ANTHROPIC_BASE_URL \
  -u ANTHROPIC_AUTH_TOKEN \
  -u ANTHROPIC_MODEL \
  -u ANTHROPIC_DEFAULT_HAIKU_MODEL \
  -u ANTHROPIC_DEFAULT_OPUS_MODEL \
  -u ANTHROPIC_DEFAULT_SONNET_MODEL \
  -u CLAUDE_CODE_SUBAGENT_MODEL \
  claude --setting-sources project,local \
  --permission-mode plan \
  --tools Read,Grep,Glob,Bash \
  --no-session-persistence \
  --output-format text \
  -p "$REVIEW_PROMPT"
```

This flow intentionally bypasses user-scoped Copilot API settings.

## Codex

```bash
codex review --uncommitted
codex review --base origin/main
codex review --commit HEAD
```

No combinar prompt inline con `codex review --base`.
