# 🛒 Beez Marketplace

> Multi-provider marketplace de skills y plugins para agentes AI.  
> Soporta **Claude Code** y **Codex** 🤖

---

## 📁 Estructura del repositorio

```
├── .claude-plugin/
│   └── marketplace.json        # Registro de plugins para Claude Code
├── .agents/plugins/
│   └── marketplace.json        # Registro de plugins para Codex
├── plugins/
│   └── <plugin-name>/
│       ├── .claude-plugin/
│       │   └── plugin.json     # Manifiesto del plugin para Claude Code
│       ├── .codex-plugin/
│       │   └── plugin.json     # Manifiesto del plugin para Codex (si es compatible)
│       └── skills/
│           └── <skill-name>/
│               ├── SKILL.md    # Definición del skill — requerido para cada skill
│               └── evals/
│                   └── eval-config.json
└── skill-eval-runner/          # CLI para correr evals localmente
```

### 🔀 Implementaciones por proveedor (opcional)

Cuando un plugin requiere una implementación diferente por proveedor, usá subdirectorios en lugar de un `skills/` compartido:

```
plugins/<plugin-name>/
├── claude/
│   ├── .claude-plugin/plugin.json
│   └── skills/
└── codex/
    ├── .codex-plugin/plugin.json
    └── skills/
```

Cada registro luego referencia la ruta del subdirectorio de su proveedor (ej. `./plugins/<name>/codex`).

---

## 🤖 Agent Ready multi-provider

`plugins/beez-kit/skills/agent-ready-setup` prepara siempre los tres planos sin acoplar assets compartidos a un provider:

```text
AGENTS.md                  # instrucciones canónicas
CLAUDE.md                  # raíz y subdirectorios: proxy exacto + regla
.claude/                   # Agent Ready Score y configuración Claude
.agents/hooks/             # scripts de hooks compartidos por ambos providers
.agents/skills/            # skills compartidas y descubribles por Codex
.agents/rules/             # reglas compartidas
.codex/hooks/hooks.json    # configuración de hooks específica Codex
.codex/.mcp.json           # MCP específico Codex
```

Si `CLAUDE.md` ya contiene instrucciones, el setup las promueve a un `AGENTS.md` hermano y deja `CLAUDE.md` como copia exacta de `assets/claude-proxy.md`. Esto también aplica a `.claude/CLAUDE.md` y cualquier subnivel. Si ambos archivos existen y difieren, no sobrescribe ninguno y reporta conflicto para resolución manual. La normalización recursiva parte de la raíz Git y omite paths ignorados no trackeados, incluidos `node_modules/` y worktrees, sin perder archivos trackeados bajo esas rutas; los destinos explícitos `.claude/`, `.agents/` y `.codex/` se siguen preparando aunque estén ignorados. El bootstrap requiere ejecutarse dentro de un worktree Git y actualiza automáticamente `beez-marketplace` para provider activo antes de proyectar assets.

Después de `marketplace upgrade`, la actualización global no reproyecta assets sobre proyectos ya preparados. La ejecución directa de `agent-ready-setup` y el hook canónico `.agents/hooks/sync-marketplace.sh` seleccionan la versión cacheada semver más nueva y actualizan los assets gestionados bajo `.claude/`, `.agents/` y `.codex/`; ambos providers usan el mismo comportamiento con sus caches respectivas. La proyección recorre `assets/common/` y `assets/stacks/<stack>/`, incluyendo rules, agents, commands, skills, MCP y hooks; los hooks permanecen canónicos bajo `.agents/hooks/`, mientras `.claude/` recibe symlinks para assets no-hook. El hook normaliza instrucciones mediante `bootstrap.sh --normalize-only` cuando la versión instalada lo soporta y ejecuta el merge semántico de `AGENTS.md`. La normalización ocurre desde la raíz Git e incluye `.claude/CLAUDE.md`; conflictos, symlinks y destinos inseguros se preservan y reportan. Muestra diffs, aplica templates sobre archivos regulares modificados y conserva su versión local en un directorio temporal externo al proyecto; output muestra path exacto para revisión o diff. También migra referencias legacy de hooks en settings JSON y normaliza sus flags al comando `.agents/hooks/...` sin flags de fase; hooks custom bajo `.claude/hooks/` se preservan. El merge IA de `AGENTS.md` conserva cambios compatibles; si falla o queda sin resolución, aplica template y guarda backup temporal. `CLAUDE.md` nunca se modifica directamente por el merge IA.

El flujo manual y `SessionStart` usan el hook sin flags de confirmación. La resolución IA trata documentos como datos no confiables, aplica cambios compatibles automáticamente y usa fallback template + backup ante salida inválida o conflicto irresoluble. `CLAUDE.md` permanece como proxy.

---

## 📦 Instalar este marketplace

Los nombres disponibles viven en `.claude-plugin/marketplace.json` y `.agents/plugins/marketplace.json`. Instalá el marketplace y reemplazá `<plugin-name>` por el plugin elegido:

```bash
# Desde la raíz de system-config
# Claude Code
claude plugin marketplace add --scope user "$PWD/beez-marketplace"
claude plugin install --scope user <plugin-name>@beez-marketplace

# Codex
codex plugin marketplace add "$PWD/beez-marketplace"
codex plugin add <plugin-name>@beez-marketplace
```

---

## 🔧 Probar plugins y skills localmente

Usá esta guía para probar cualquier skill standalone, plugin o marketplace sin
publicarlo. Definí variables según el árbol que quieras probar:

```bash
MARKETPLACE_NAME="beez-marketplace"
PLUGIN_NAME="<plugin-name>"
SKILL_NAME="<skill-name>"
PLUGIN_SRC="$PWD/plugins/$PLUGIN_NAME"
SKILL_SRC="$PLUGIN_SRC/skills/$SKILL_NAME"
```

Para una skill standalone, reemplazá `SKILL_SRC` por:

```bash
SKILL_SRC="$PWD/skills/$SKILL_NAME"
```

### 1. Cargar una skill directamente con symlink

Este método valida `SKILL.md`, recursos bundled y ejecución de la skill. No valida
manifests ni discovery del marketplace.

```bash
ln -sfn "$SKILL_SRC" "$HOME/.claude/skills/$SKILL_NAME"   # Claude Code
ln -sfn "$SKILL_SRC" "$HOME/.codex/skills/$SKILL_NAME"    # Codex
```

Reiniciá cada cliente después de crear el symlink. Las ediciones posteriores a
`SKILL.md`, `subcommands/*`, `knowledge/*`, `assets/*` o `scripts/*` quedan
reflejadas desde el repositorio.

### 2. Cargar un plugin en una sesión de Claude Code

Este método valida el plugin Claude sin instalarlo persistentemente:

```bash
claude --plugin-dir "$PLUGIN_SRC"
```

`--plugin-dir` no valida la instalación del marketplace Codex ni el registro de
`marketplace.json`.

### 3. Probar marketplace local completo

Ejecutá estos comandos desde raíz del marketplace, no desde `PLUGIN_SRC`:

```bash
# Claude Code
claude plugin marketplace add --scope local "$PWD"
claude plugin install --scope local "$PLUGIN_NAME@$MARKETPLACE_NAME"

# Codex
codex plugin marketplace add "$PWD"
codex plugin add "$PLUGIN_NAME@$MARKETPLACE_NAME"
```

Verificá instalación y discovery:

```bash
claude plugin list
codex plugin marketplace list
codex plugin list --json
```

Para probar cambios posteriores sin publicar el marketplace, actualizá la fuente
local cuando corresponda. En proyectos preparados con Agent Ready, el hook
SessionStart ejecuta siempre proyección local y merge de instrucciones:

```bash
claude plugin marketplace update "$MARKETPLACE_NAME"
codex plugin marketplace upgrade "$MARKETPLACE_NAME"

# Flujo completo desde hook canónico
bash .agents/hooks/sync-marketplace.sh --provider claude
bash .agents/hooks/sync-marketplace.sh --provider codex
```

### 4. Ejecutar evals de una skill

```bash
run-evals "$SKILL_SRC"
run-evals "$SKILL_SRC" --provider codex
```

Usá `--pretty` para un reporte legible. Las evals validan comportamiento de la
skill; no reemplazan la prueba de instalación del plugin o marketplace.

### ✅ Qué valida cada método

| Método | Valida | No valida |
|---|---|---|
| Symlink en `~/.claude/skills` o `~/.codex/skills` | Carga directa y cambios live de una skill | Manifests y registro del marketplace |
| `claude --plugin-dir` | Plugin Claude en una sesión | Instalación Codex y marketplace persistente |
| Marketplace local + `plugin install` / `plugin add` | Registry, manifests, plugin y skills del provider | Publicación remota |
| `run-evals` | Contrato y comportamiento declarado de una skill | Discovery del plugin instalado |

### 🗑️ Cleanup local

```bash
# Symlinks directos
rm -f "$HOME/.claude/skills/$SKILL_NAME" "$HOME/.codex/skills/$SKILL_NAME"

# Plugins instalados
claude plugin uninstall --scope local "$PLUGIN_NAME@$MARKETPLACE_NAME"
codex plugin remove "$PLUGIN_NAME@$MARKETPLACE_NAME"

# Marketplaces configurados
claude plugin marketplace remove "$MARKETPLACE_NAME"
codex plugin marketplace remove "$MARKETPLACE_NAME"
```

Solo los comandos de cleanup modifican la configuración local de los clientes;
el repositorio no cambia.

---

## ➕ Agregar un plugin

1. 🌿 Creá una feature branch: `feature/<plugin-name>`
2. 📂 Agregá tu plugin en `plugins/<plugin-name>/` siguiendo la estructura de arriba
3. 📋 Registralo en los archivos de registro correspondientes:
   - `.claude-plugin/marketplace.json` para Claude Code
   - `.agents/plugins/marketplace.json` para Codex
4. 🔍 Abrí un PR

> 📌 Un plugin debe aparecer en al menos un registro. Un plugin solo se instala para un proveedor si está listado en el `marketplace.json` de ese proveedor.
>
> 🔒 Todos los archivos `plugin.json` dentro del mismo plugin (`.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`) deben compartir la misma versión. Si cambia cualquier skill, todos los manifiestos de proveedor deben hacer bump juntos.

**Formato de commit:** `feat(marketplace): add <name>`

---

## 🔖 Bumping de versión de un plugin

Usá el script `create-version` para hacer bump a la versión de un plugin. Actualiza el campo `version` en **ambos** manifiestos de proveedor (`.claude-plugin/plugin.json` y `.codex-plugin/plugin.json`) a la vez, manteniéndolos sincronizados.

```bash
npm run create-version              # auto-detecta el único plugin cambiado sin bump en la branch; si no, muestra menú
npm run create-version beez-kit    # apuntá a un plugin directamente por nombre
npm run create-version -- --dry-run  # preview sin escribir, commitear ni pushear (shorthand: -n)
npm run create-version -- beez-kit --bump minor  # sin prompts (patch | minor | major)
npm run create-version -- --set 2.0.0  # versión exacta sin prompts
npm run create-version -- --help     # ayuda (shorthand: -h)
```

El script compara branch actual contra primera base remota disponible (`origin/develop`, `origin/master` u `origin/main`) y suma cambios locales para detectar qué plugin cambió. Ignora archivos fuera de `plugins/` para esa decisión. Luego pregunta cómo establecer la nueva versión — un semver bump (`patch` / `minor` / `major`) calculado desde la versión actual, o una versión exacta personalizada — crea un commit que incluye **solo** los dos `plugin.json` actualizados (el resto de cambios staged, unstaged o untracked queda intacto) y hace `push` automático de la rama (con `-u origin HEAD` si todavía no tiene upstream). Nunca hace force-push y omite el push en ramas default (`develop`, `master`, `main`); si el push falla, el commit local se conserva y el script termina con error. Con `--dry-run` (o `-n`) recorre los mismos prompts y muestra qué archivos actualizaría, el commit y el push planeados, sin modificar nada. `--bump <kind>` o `--set <version>` evitan el prompt de versión (no se pueden combinar) y `--help` (`-h`) muestra el uso.

> ⚠️ Antes de escribir, valida que ambos manifiestos ya compartan la misma versión y aborta si difieren — nunca vas a hacer bump desde un estado inconsistente.

---

## 🧪 Correr tests shell localmente

Las suites shell usan [bats-core](https://github.com/bats-core/bats-core) con versión y dependencias fijadas en `package-lock.json`.

```bash
# Instalación reproducible
npm ci

# Preparación explícita de tests browser (Python 3.11+, instala tomlkit en venv local)
npm run setup:browser-tests

# Suites aisladas: Agent Ready, create-version y contrato del eval runner
npm test
```

`npm run test:browser` ejecuta pruebas de registro browser desde el venv local,
sin descargar dependencias. La prueba de lanzamiento real es opt-in mediante
`AGENT_READY_SETUP_BROWSER_SMOKE_ROOT` (directorio administrado de herramientas)
y `AGENT_READY_SETUP_BROWSER_SMOKE_EXECUTABLE` (path de Chromium instalado).
Los tests comunes usan parser TOML real; instalación de paquetes y browsers queda
fuera de la suite aislada.

---

## 🧪 Correr evals localmente

```bash
# Configuración inicial (una sola vez)
cd skill-eval-runner && ./install.sh

# Correr evals para un skill específico (JSONL por defecto)
run-evals plugins/<plugin-name>/skills/<skill-name>

# Reporte legible con colores (opcional)
run-evals plugins/<plugin-name>/skills/<skill-name> --pretty

# Override de proveedor (por defecto: auto-detecta Codex o Claude)
run-evals plugins/<plugin-name>/skills/<skill-name> --provider codex

# Comparar contra una corrida sin skill (opcional; no se evalúa y duplica llamadas)
run-evals plugins/<plugin-name>/skills/<skill-name> --baseline

# Override persistente de proveedor
export BEEZ_MARKETPLACE_EVAL_PROVIDER=codex
```
