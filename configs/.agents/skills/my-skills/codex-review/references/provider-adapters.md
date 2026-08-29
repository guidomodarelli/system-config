# Provider adapters

Leer esta referencia antes de ejecutar provider manualmente o modificar helper.

## Prompt obligatorio

Incluir target exacto, modo read-only, prohibición de editar/commit/push, prohibición de invocar otro reviewer y pedido de findings directos con archivo, línea, escenario, severidad y confianza.

## Claude Code

```bash
claude --permission-mode plan \
  --tools Read,Grep,Glob,Bash \
  --no-session-persistence \
  --output-format text \
  -p "$REVIEW_PROMPT"
```

## GitHub Copilot

```bash
copilot --mode plan \
  --no-ask-user \
  --allow-all-tools \
  --deny-tool=write \
  --silent \
  -p "$REVIEW_PROMPT"
```

## Codex

```bash
codex review --uncommitted
codex review --base origin/main
codex review --commit HEAD
```

No combinar prompt inline con `codex review --base`.
