# Sincronización posterior al upgrade


`fury ai assets marketplace upgrade` actualiza la copia global del marketplace;
no vuelve a proyectar por sí mismo los templates sobre un proyecto ya preparado.
`bootstrap.sh` ejecuta ese upgrade automáticamente para el provider activo antes
de proyectar assets o adquirir lock local. En `frontend`, también ejecuta el helper
que consulta la última versión disponible de `groot-ui` sin instalarla ni modificar el
lockfile, compara la versión efectiva, elimina `kraken-translations` de `package.json`
y configura los scripts.
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
la revisión de redundancias de `scripts/merge-instructions.sh` y, en `frontend`,
`scripts/refresh-groot-ui-version.sh`, que guarda la última versión de `groot-ui` en
`groot-ui-latest-version` como máximo una vez por hora. El aviso con
`npm install --save groot-ui@<version>` usa esa versión cacheada, sin instalar ni
actualizar la dependencia, y aparece desde la sesión siguiente a la primera consulta. La normalización incluye `CLAUDE.md` bajo `.claude/` y conserva
conflictos, symlinks y archivos no regulares. El usuario debe decidir y ejecutar el
comando mostrado (o `npm install` si `groot-ui` ya está al día) para actualizar
`package-lock.json` y quitar `kraken-translations` del lockfile.
El upgrade solo refresca el snapshot del marketplace del provider (Claude:
`installLocation` de `~/.claude/plugins/known_marketplaces.json`, por defecto
`~/.claude/plugins/marketplaces/groot-marketplace`; Codex: `source` local de
`~/.codex/config.toml` o `~/.codex/.tmp/marketplaces/groot-marketplace`); el cache
versionado del plugin avanza recién con `/plugin` update. Por eso el hook resuelve
la fuente desde ese snapshot salvo que el cache tenga una versión semver mayor, y
proyecta la última versión publicada sin depender de la versión instalada del plugin.
`bootstrap.sh` aplica el mismo criterio y reporta la fuente elegida en `Resolved agent-ready-setup source: <path>`.
Si la fuente resuelta no contiene `scripts/asset-sync-common.sh`, el hook ejecuta un
refresh adicional de `groot-marketplace`, vuelve a resolver la fuente y carga helper
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

- Cada upgrade necesita CLI `fury`, autenticación y red; si upgrade falla,
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
  de Fury entre procesos distintos.
- En `frontend`, la consulta `npm view groot-ui version` requiere registry,
  autenticación y red (en el sync corre en segundo plano); el helper no instala dependencias ni actualiza
  `package-lock.json`, aunque elimina `kraken-translations` de `package.json`.
  El usuario controla el cambio de versión y ejecuta `npm install` cuando decide
  sincronizar el lockfile.

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
