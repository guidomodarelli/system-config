---
name: worktree-hermano
description: "Gestiona worktrees hermanos persistentes reutilizando ramas existentes, locales o remotas, sin crear ramas derivadas. Usar cuando pidan crear, listar o remover un worktree hermano, mantener misma rama en otro checkout, resolver conflictos de rama ya checkout o mover principal a develop con confirmación explícita. No usar para clones efímeros, commits, pushes ni fixes aislados."
---

# Worktree hermano

Gestiona worktrees Git persistentes en rutas hermanas. Helper bundled contiene lógica determinista y validaciones; no reimplementar comandos Git manualmente.

## Helper

Invocar siempre:

```bash
/Users/gmodarelli/system-config/configs/.agents/skills/my-skills/worktree-hermano/scripts/worktree-hermano
```

Si runtime expone skill mediante `~/.claude/skills`, usar ruta equivalente:

```bash
~/.claude/skills/worktree-hermano/scripts/worktree-hermano
```

## Ubicación obligatoria

Todo worktree nuevo debe quedar como hermano inmediato del repo principal, nunca dentro del repo principal ni dentro de cualquier directorio de worktrees.

- Resolver `primary_path` desde primer registro de `git worktree list --porcelain`; resolver `source_parent` como `dirname` de ruta canónica de `primary_path`.
- Destino válido: `${source_parent}/${repository_name}-${suffix}`. `dirname` de destino debe ser exactamente `source_parent`.
- Destinos inválidos: `${repository_root}/.worktrees/...`, `${repository_root}/.git/worktrees/...`, `${repository_root}/.claude/worktrees/...`, `${repository_root}/worktrees/...`, cualquier subdirectorio anidado, cualquier ruta bajo otro repo y cualquier ruta fuera de `source_parent`.
- `--name` y destino automático siempre deben generar ruta hermana inmediata. `--path` solo puede aceptar ruta absoluta o relativa que resuelva a esa misma ubicación hermana.
- Si `--path` no cumple esta regla, bloquear operación antes de ejecutar `git worktree add`; no corregir, reinterpretar ni mover ruta silenciosamente.
- Ejemplo válido: repo principal `/workspace/app` y worktree `/workspace/app-feature`. Ejemplo inválido: `/workspace/app/.claude/worktrees/feature`.

## Flujo

1. Identificar intención: `create`, `list` o `remove`.
2. Ejecutar primero `--dry-run` para `create` o `remove`.
3. Mostrar al usuario ruta, rama, tracking, operación y bloqueos detectados.
4. Si helper termina con código `3`, tratarlo como bloqueo de seguridad; no repetir operación cambiando flags por iniciativa propia.
5. Si rama solicitada está checkout en worktree principal, explicar que misma rama no puede estar checkout dos veces. Pedir confirmación explícita para mover principal a `develop`.
6. Solo después de confirmación afirmativa, repetir `create` agregando `--confirm-primary-switch-to-develop`.
7. Informar resultado final con ruta, rama, commit y estado.

## Operaciones

### Crear

```bash
SCRIPT=/Users/gmodarelli/system-config/configs/.agents/skills/my-skills/worktree-hermano/scripts/worktree-hermano
"$SCRIPT" create --branch feature/example --dry-run
"$SCRIPT" create --branch feature/example
```

Opciones:

- `--branch BRANCH`: obligatorio. Acepta rama local, `origin/branch` o ref completa.
- `--name NAME`: nombre seguro para ruta hermana; mutuamente excluyente con `--path`.
- `--path PATH`: ruta hermana explícita.
- `--dry-run`: valida sin modificar Git ni filesystem.
- `--confirm-primary-switch-to-develop`: autoriza mover worktree principal limpio a rama local `develop` cuando rama solicitada está ocupada allí.

Rama remota se materializa como rama local con mismo nombre y upstream. No ejecutar `fetch` automáticamente; informar si remote-tracking puede estar desactualizada.

### Listar

```bash
"$SCRIPT" list
```

Operación solo lectura. Mostrar worktree principal, hermanos, ramas, HEAD y registros stale si existen.

### Remover

```bash
"$SCRIPT" remove --branch feature/example --dry-run
"$SCRIPT" remove --branch feature/example
```

Usar exactamente uno de `--branch BRANCH` o `--path PATH`. Solo remover worktree no principal y completamente limpio. No borrar rama local.

## Invariantes

- Reutilizar rama solicitada; nunca crear rama derivada para resolver conflicto.
- No usar `--force`.
- No ejecutar `fetch`, `pull`, `push`, `commit`, `reset`, `clean`, `stash` ni `prune`.
- No sobrescribir rutas existentes, symlinks, rutas registradas, rutas anidadas o rutas fuera del directorio hermano.
- No borrar worktree principal ni worktree con archivos trackeados, no trackeados o ignorados.
- No modificar archivos del proyecto fuera de operaciones propias de Git worktree.
- Helper mantiene compatibilidad Bash 3.2 y usa argumentos quoted; no usar `eval`.

## Códigos de salida

- `0`: éxito, ayuda o dry-run válido.
- `1`: error Git/runtime.
- `2`: argumentos inválidos.
- `3`: bloqueo de seguridad o confirmación requerida.

## Cierre

Reportar siempre:

- operación ejecutada;
- ruta absoluta del worktree;
- rama checkout y upstream cuando exista;
- HEAD inicial/final;
- si principal fue movido a `develop`;
- validaciones omitidas o errores literales de Git.

No afirmar creación o remoción si helper no terminó exitosamente.
