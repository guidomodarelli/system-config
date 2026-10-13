# Sincronización posterior al upgrade


El upgrade del marketplace usa la CLI del provider activo
(`claude plugin marketplace update beez-marketplace` o
`codex plugin marketplace upgrade beez-marketplace`) y actualiza la copia global
del marketplace; no vuelve a proyectar por sí mismo los templates sobre un proyecto
ya preparado. `bootstrap.sh` ejecuta ese upgrade automáticamente para el provider
activo antes de proyectar assets o adquirir lock local.
`codex plugin marketplace upgrade` solo refresca marketplaces Git: si
`~/.codex/config.toml` declara `source_type = "local"` para `beez-marketplace`
(lo que registra `codex plugin marketplace add "$PWD/beez-marketplace"`),
`bootstrap.sh` y el hook omiten el upgrade y resuelven assets desde ese `source`.
El hook canónico `.agents/hooks/sync-marketplace.sh` ejecuta el upgrade salvo que
haya uno exitoso de menos de 60 minutos para el mismo provider (marca en
`${XDG_CACHE_HOME:-~/.cache}/agent-ready-setup/marketplace-upgrade-<provider>.stamp`,
escrita solo tras un upgrade exitoso); `AGENT_READY_SETUP_FORCE_UPGRADE=1` lo
fuerza y `bootstrap.sh` lo ejecuta siempre. El upgrade es lo único sincrónico que
usa red: proyecta todos los assets gestionados, ejecuta la normalización recursiva de
instrucciones mediante `scripts/normalize-instructions.sh` y aplica el bloque gestionado
literal de `AGENTS.md` con `scripts/apply-managed-block.sh`, todo local, para que la
sesión que arranca ya los vea. Lo que usa red o un LLM corre desacoplado mediante
`scripts/run-detached.py`, con log en `${XDG_CACHE_HOME:-~/.cache}/agent-ready-setup/`:
la revisión de redundancias de `scripts/merge-instructions.sh`. La normalización
incluye `CLAUDE.md` bajo `.claude/` y conserva conflictos, symlinks y archivos no
regulares.
El upgrade solo refresca el snapshot del marketplace del provider (Claude:
`installLocation` de `~/.claude/plugins/known_marketplaces.json`, por defecto
`~/.claude/plugins/marketplaces/beez-marketplace`; Codex: `source` local de
`~/.codex/config.toml` o `~/.codex/.tmp/marketplaces/beez-marketplace`); el cache
versionado del plugin avanza recién con `/plugin` update. Por eso el hook resuelve
la fuente desde ese snapshot salvo que el cache tenga una versión semver mayor, y
proyecta la última versión publicada sin depender de la versión instalada del plugin.
`bootstrap.sh` aplica el mismo criterio y reporta la fuente elegida en `Resolved agent-ready-setup source: <path>`.
Si la fuente resuelta no contiene `scripts/asset-sync-common.sh`, el hook ejecuta un
refresh adicional de `beez-marketplace`, vuelve a resolver la fuente y carga helper
mediante `source` antes de proyectar cualquier asset. Si refresh no entrega helper,
conserva hook local, omite proyección y muestra diagnóstico; no instala un
`sync-marketplace.sh` que no pueda arrancar.
Si la copia instalada del hook cambió, se reejecuta con el mismo provider y stack
antes de proyectar el resto. La reejecución conserva el lock de assets y usa una
guarda interna para no repetir el upgrade inicial; refresh por helper faltante solo
se intenta antes de cargar helper. `normalize-instructions.sh` no repite proyección
ni upgrade.

El hook compara cada asset gestionado con el template actualizado y muestra
`diff -u` antes de reemplazar un archivo existente. Los archivos regulares
modificados se reemplazan automáticamente y su contenido local se guarda en un
directorio temporal externo al proyecto; el output muestra path exacto para
revisarlo o compararlo. Los symlinks en paths gestionados se reemplazan sin
seguirlos; directorios en paths gestionados, padres inseguros y cambios
concurrentes se preservan y se reportan como conflictos estructurales.

#### Riesgos del upgrade automático

- Cada upgrade necesita la CLI del provider (`claude` o `codex`) y red; si upgrade falla,
  bootstrap y hook terminan antes de modificar assets locales y no registran la
  ventana de 60 minutos.
- Dentro de esa ventana, una versión recién publicada del marketplace puede
  tardar hasta 60 minutos en llegar por SessionStart; usar
  `AGENT_READY_SETUP_FORCE_UPGRADE=1` o `bootstrap.sh` para aplicarla antes.
- Upgrade global no tiene rollback en este script; la versión descargada puede
  cambiar aunque proyección local quede bloqueada.
- El hook aplica templates nuevos sobre assets gestionados y conserva cada
  versión local modificada en un backup temporal externo al proyecto; reglas,
  symlinks, conflictos estructurales y reemplazos atómicos siguen evitando
  seguir o sobrescribir destinos inseguros.
- Lock protege proyección local concurrente, pero no serializa upgrades globales
  del marketplace entre procesos distintos.

La proyección automática de assets:

- Actualiza assets gestionados bajo `.agents/`, settings específicos de
  `.claude/`, y bridge/configuración bajo `.codex/`.
- Copia adapters `SKILL.md` bajo `.agents/skills/` byte a byte desde su
  template, sin reescribir frontmatter: providers eligen skills según
  `description`, por lo que el template es la única fuente.
- En `.claude/`, agents y commands se registran una sola vez (`.claude/agents/`,
  `.claude/commands/`); su adapter en `.agents/skills/` queda solo para Codex.
  El sync elimina vistas `.claude/skills/<nombre>/` gestionadas que dupliquen un
  agent o command y preserva y reporta contenido custom.
- Claude Code carga `.claude/rules/` automáticamente; el bloque gestionado de
  `AGENTS.md` le indica no volver a leerlas y deja las referencias para Codex.
- Reemplaza symlinks en paths gestionados sin seguirlos: borra el link y escribe
  el template, así nunca modifica el destino del link.
- Elimina symlinks administrados stale bajo `.claude/` y limpia `.claude/hooks/`
  legacy solo cuando queda vacío.
- Migra referencias `.claude/hooks/` dentro de `.claude/settings.json` como JSON
  y normaliza el comando administrado a `.agents/hooks/` sin flags de fase,
  preservando campos custom y reportando settings inválidos.
- Normaliza `CLAUDE.md` raíz y anidados, incluido `.claude/CLAUDE.md`, mediante
  `scripts/normalize-instructions.sh`; crea o actualiza únicamente el `AGENTS.md`
  hermano cuando puede preservar el contenido sin ambigüedad.
- No elimina assets desconocidos (rules, skills o archivos propios del
  proyecto); solo sobrescribe paths que publica agent-ready-setup.

El paso posterior sobre instrucciones actualiza únicamente `AGENTS.md`; nunca
modifica `CLAUDE.md` directamente.

Para sincronizar manualmente desde un hook existente:

```bash
bash .agents/hooks/sync-marketplace.sh --provider claude
# o
bash .agents/hooks/sync-marketplace.sh --provider codex
```

Si la fuente instalada no se puede resolver o el stack no se detecta, el hook
conserva el upgrade global y muestra cómo indicar `AGENT_READY_SETUP_SKILL_DIR`
o `--stack frontend|node|java|go`. `AGENT_READY_SETUP_STACK=<stack>` equivale a
`--stack` (la flag tiene precedencia) y sirve para fijar el stack sin editar el
comando del hook en `settings.json` o `hooks.json`.
