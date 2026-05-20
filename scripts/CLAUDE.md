# Reglas De Agentes Para `scripts/`

## Compatibilidad Bash 3.2 (Mandatorio)

- Todo script `bash` dentro de `scripts/` DEBE ejecutarse correctamente con `bash` 3.2 (el `/bin/bash` que provee macOS).
- No es aceptable cerrar un cambio si el script falla con `bash` 3.2, aunque funcione con `bash` 4+ o `zsh`.
- Aplica a archivos con shebang `#!/bin/bash`, `#!/usr/bin/env bash`, o cualquier script invocado vía `bash <archivo>`.

### Features Prohibidas (Requieren Bash 4+)

No usar ninguna de las siguientes construcciones, ya que rompen en `bash` 3.2:

- `declare -A` / `local -A` (arrays asociativos / hashmaps).
- `mapfile` / `readarray`.
- `${var,,}`, `${var^^}`, `${var^}`, `${var,}` (case conversion).
- `&>>` (append redirection combinado).
- `coproc`.
- `printf -v` con arrays asociativos.
- `${!prefix@}` y `${!prefix*}` con expansiones de bash 4+.
- `wait -n`.

### Alternativas Compatibles

- Hashmap → string delimitado por `\n` con chequeo `[[ "$seen" == *$'\n'"$key"$'\n'* ]]`, o array indexado + búsqueda lineal.
- `mapfile -t arr < <(cmd)` → `arr=(); while IFS= read -r line; do arr+=("$line"); done < <(cmd)`.
- Case conversion → `tr '[:lower:]' '[:upper:]'` o `awk`.

### Validación Mínima Antes De Cerrar

- Ejecutar `bash -n <script>` para validar sintaxis.
- Ejecutar el script (o su modo `--dry-run` cuando exista) con `/bin/bash` en macOS, no con `bash` 4+ del sistema.
- Reportar explícitamente en la respuesta final:
  - `Verificado bash 3.2: <sí/no + evidencia>`

## Idioma

- Aplican las reglas del [`CLAUDE.md`](../CLAUDE.md) raíz: salida visible en español, identificadores y flags en inglés.
