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

Estas validaciones aplican únicamente a archivos Bash o scripts invocados mediante Bash:

- Ejecutar `/bin/bash -n <script>` para validar sintaxis.
- Ejecutar el script (o su modo `--dry-run` cuando exista) con `/bin/bash` en macOS, no con `bash` 4+ del sistema.
- Reportar explícitamente en la respuesta final:
  - `Verificado bash 3.2: <sí/no + evidencia>`

Los archivos PowerShell, Batch, Python y otros runtimes deben validarse con sus herramientas nativas cuando corresponda.

## Salida Solo ASCII En `setup` Y `dotfiler` (Mandatorio)

- `scripts/setup/` (`setup.sh`, `setup.ps1`) y `scripts/dotfiler/` (`dotfiler.sh`, `dotfiler.ps1`) DEBEN usar siempre y únicamente caracteres ASCII en toda su decoración: íconos, cajas, bordes, barras de progreso, spinners, flechas, separadores, marcas de selección y puntos suspensivos.
- No usar emojis ni símbolos Unicode decorativos (por ejemplo `✅`, `📁`, `╭─│`, `▰`, `⠋`, `→`, `·`, `…`, `★`), aunque la terminal los soporte. No agregar modos, flags ni variables para activarlos.
- Equivalencias de referencia: cajas `+ - |`, flecha `->`, separador `-`, puntos suspensivos `...`, barra `#` y `.`, spinner `| / - \`, selección `[x]` / `[ ]`, cursor `>`, recomendado `*`.
- Los textos visibles en español conservan sus tildes y eñes: la regla aplica a la decoración, no al contenido.
- Los colores ANSI están permitidos: no son glifos.
- Todo cambio en estos scripts debe mantener tests que verifiquen que la salida decorativa es ASCII.
