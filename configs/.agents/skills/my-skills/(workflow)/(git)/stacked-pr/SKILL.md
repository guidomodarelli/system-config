---
name: stacked-pr
description: "Gestiona stacked Pull Requests de GitHub con ramas feature/*: divide PRs grandes por responsabilidad, crea un stack desde un PR normal, agrega capas a un stack existente, preserva un golden diff, resuelve dependencias y valida CI por capa. Usar siempre cuando el usuario mencione stacked PRs, stacked pull requests, dividir un PR, crear un stack, agregar un PR al stack, cambiar la base de un PR dependiente o reordenar capas."
allowed-tools: Bash(git:*) Bash(gh:*) Read Write Edit
---

# Stacked PRs por responsabilidad

Divide cambios grandes en PRs pequeños y dependientes, manteniendo una cadena GitHub revisable. Prioriza árbol final correcto, CI por capa y trazabilidad sobre velocidad de cherry-pick.

## Reglas de seguridad y alcance

- Ejecuta acciones remotas solo si el usuario pidió crear, actualizar, cerrar o publicar PRs.
- Antes de force-push, cerrar/recrear PRs o cambiar bases, confirma la acción si no fue autorizada explícitamente.
- Nunca modifiques branch original sin crear primero una referencia de backup.
- Nunca uses `git reset --hard`, `git checkout -- .` o `git clean` sin backup y alcance explícito.
- No uses `git push --force`; usa `git push --force-with-lease` únicamente en branches `feature/*` reconstruidos.
- No uses `git cherry-pick -X ours`, `-X theirs`, `--skip`, tests deshabilitados ni mocks artificiales para ocultar fallos.
- No declares CI verde si algún check está `pending`, `skipping` o no disponible.
- Mantén cuerpos, títulos y reportes visibles en español; conserva nombres técnicos, branches, comandos, paths y mensajes literales en inglés.

## Modos de operación

### A. Dividir un PR grande no stacked

Usa cuando el usuario pasa una URL/número de PR o pide dividir un PR existente.

1. Obtén PR, repositorio, base, head y SHA:

   ```bash
   gh pr view <PR> --json number,url,title,baseRefName,baseRefOid,headRefName,headRefOid,state
   git fetch origin --prune
   git status --short --branch
   ```

2. Exige árbol limpio. Guarda el head original:

   ```bash
   git branch backup/stacked-pr-<slug> <head-sha>
   ```

3. Usa `base-sha` y `head-sha` como oráculos. Calcula el alcance sin confiar solo en commits:

   ```bash
   git diff --name-status <base-sha> <head-sha>
   git diff --stat <base-sha> <head-sha>
   ```

4. Define manifests explícitos por responsabilidad. Default recomendado:

   ```text
   contracts-dependencies: package*.json, constants/**, interfaces/**,
                           schemas compartidos, utils compartidas
   backend:                api/**, middlewares/**, hooks server, tests API/services
   frontend:               app/**, componentes, páginas, client services, estilos,
                           assets y tests UI
   mocks-tests:            mocks/**, setup de Jest, fixtures y tests que dependan
                           exclusivamente de esos fixtures
   i18n:                   i18n/**/*.po, app/translations/**, .i18nkeep
   cleanup:                shims legacy, renames finales, .gitignore y paths obsoletos
   ```

   Ajusta categorías al grafo real. Un path compartido va con su consumer o en la capa fundacional; nunca lo dupliques sin explicarlo.

5. Reconstruye cada branch desde la base inmediata, aplicando solo su manifest. Puedes usar un patch acotado:

   ```bash
   git diff --binary <base-sha> <golden-sha> -- <manifest> | git apply --index
   git diff --cached --check
   git commit -m "<type>(<scope>): <summary>"
   ```

   Si un rename o conflicto exige contexto completo, usa `git cherry-pick --no-commit` y resuelve semánticamente. Crea commit nuevo con hashes fuente en el body.

6. Crea branches con nombres `feature/<slug>-<layer>` y PRs donde cada `base` sea el branch inmediatamente inferior.

### B. Crear stack desde un PR normal

Usa cuando existe un PR normal y el usuario quiere agregarle stacked layers.

1. Trata su `head` como primera capa y no lo reescribas sin autorización.
2. Crea child branch desde el head del PR:

   ```bash
   git switch -c feature/<slug>-<layer> <pr-head-sha>
   ```

3. Publica el child y crea PR con:

   ```bash
   git push --set-upstream origin feature/<slug>-<layer>
   gh pr create --base <pr-head-branch> --head feature/<slug>-<layer>
   ```

4. Repite usando siempre el head de la última capa como base de la siguiente.
5. Si hay cambios ya mezclados en el child, calcula diff contra la base inmediata; no uses diff contra `develop` para juzgar tamaño de capa.

### C. Agregar un PR/capa a stack existente

Usa cuando el usuario pide agregar otro PR a un stack.

1. Inspecciona cada PR abierto y construye cadena `baseRefName -> headRefName`:

   ```bash
   gh pr list --state open --json number,title,baseRefName,headRefName,headRefOid,url
   gh pr view <PR> --json baseRefName,headRefName,baseRefOid,headRefOid
   ```

2. Verifica que branches estén en el mismo repositorio y que no haya ciclos.
3. Identifica top layer (head que no es base de otro PR).
4. Crea la nueva branch desde top layer y el PR con top branch como base:

   ```bash
   git switch -c feature/<slug>-<new-layer> <top-head-sha>
   git push --set-upstream origin feature/<slug>-<new-layer>
   gh pr create --base <top-head-branch> --head feature/<slug>-<new-layer>
   ```

5. Para agregar un PR existente, cambia su base solo si GitHub conserva el diff esperado; captura antes/después de `baseRefName`, `headRefName` y `git diff --stat`.

## Dependencias y CI

- Contracts/dependencies precede consumers backend/frontend.
- Un import nuevo exige que módulo, tipos, configuración y dependencia estén presentes en la misma capa o en una anterior.
- Tests y fixtures necesarios para ejecutar una capa viajan con esa capa; fixtures puramente adicionales pueden ir en `mocks-tests`.
- Catálogos generados nunca se editan manualmente. Usa `npm run i18n` y no aceptes locales ajenos o churn accidental.
- Si una capa falla porque depende de una capa posterior, mueve el consumer/contrato hacia arriba o agrega un bridge temporal documentado que cleanup eliminará. No debilites assertions.
- Valida cada branch con comandos del repositorio. Como mínimo:

  ```bash
  npm ci
  npx tsc --noEmit
  npx eslint . --quiet
  npx stylelint '**/*.scss'
  NODE_ENV=test npx jest --runInBand --coverage=false
  npm run build
  git diff --check
  ```

- Consulta checks reales:

  ```bash
  gh pr checks <PR>
  ```

  Espera a que termine CI externo. Reporta por PR `pass`, `fail`, `pending` o `logs unavailable`; nunca confundas `workflow` verde con CI completo.

## Golden diff y cierre

Antes de publicar cada capa, verifica diff incremental:

```bash
git diff --name-status <base-branch>...<head-branch>
git diff --stat <base-branch>...<head-branch>
git status --short --untracked-files=all
```

Después de la última capa, si existe golden, usa esta forma segura:

```bash
golden_tree=$(git rev-parse '<golden-sha>^{tree}')
stack_tree=$(git rev-parse '<last-stack-branch>^{tree}')
test "$golden_tree" = "$stack_tree"
```

El último PR debe contener todo el cambio intencional y ningún archivo fuera del golden. Si se excluye churn generado, documenta la exclusión y no la llames equivalencia exacta.

## Merge y rebase posterior

- Fusiona bottom-up: primera capa, segunda capa, hasta top.
- No fusiones child antes de su parent.
- Tras squash-merge del parent, actualiza base del child:

  ```bash
  old_parent_tip=<sha-before-squash>
  git fetch origin develop
  git switch <child-branch>
  git rebase --onto origin/develop "$old_parent_tip"
  git push --force-with-lease origin <child-branch>
  gh pr edit <child-pr> --base develop
  ```

- Revalida CI, conflictos y golden después de cada squash.
- Elimina branches solo cuando todos los PRs estén fusionados y el golden final haya sido verificado.

## Reporte final

Entrega una tabla:

| Orden | PR | Branch | Base | Scope | Archivos | CI |
|---|---|---|---|---:|---:|---|

Incluye:

- URLs de PRs.
- Cadena de bases.
- SHA original/golden y SHA final.
- Resultado de comparación de árbol/patch.
- Tests, build y lint ejecutados.
- Checks remotos aún pending o con logs unavailable.
- Branch original preservado y cualquier backup creado.
