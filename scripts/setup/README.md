# Script de Configuración

Estos scripts están diseñados para automatizar la instalación y configuración de
diversas herramientas y dependencias del sistema, facilitando así el proceso de
configuración inicial y asegurando que todas las aplicaciones necesarias estén
disponibles y correctamente configuradas.

## Uso en macOS

Este script automatiza la instalación de herramientas y la configuración del
entorno usando Homebrew. `SDKMAN` puede instalarse como herramienta base, pero
el setup recomendado ya no instala ni fija Java 21 por defecto. La política
general del setup es instalar o actualizar siempre a la última versión estable
disponible desde la fuente oficial de cada herramienta.

En Windows, la actualización de Chocolatey se ejecuta desde una copia temporal
del binario principal para permitir que el instalador reemplace `choco.exe`.
La copia se elimina al terminar, incluso si la actualización falla.

Las instalaciones y actualizaciones de paquetes con Chocolatey reintentan hasta
tres veces los errores HTTP transitorios, con esperas de 2 y 4 segundos. Un error
de resolución del paquete se informa como fallo aunque el CLI devuelva código 0
o muestre un resumen exitoso. La política está en `constants/chocolatey.psd1`.

Si `hunk` necesita preparar Node.js en Windows, el setup activa el entorno de
fnm, instala y activa la última versión estable con `fnm install --latest --use`
y configura como default el número de versión que devuelve `fnm current`.

### Requisitos

- Homebrew instalado en `/opt/homebrew`.
- Permisos de administrador para cambiar el shell por defecto.
- Conexión a Internet.
- `SDKMAN` se instala automáticamente si no existe.

Si Homebrew está en otra ruta, ajusta la función `_brew` en
`scripts/setup/setup.sh`.

### Recomendaciones por plataforma

- En macOS, el selector recomienda `ggrep` y no recomienda `xclip`.
- En Linux nativo, el selector recomienda `xclip` y no recomienda `ggrep` ni
  `win32yank`.
- En macOS y Linux nativo, el selector recomienda `Ghostty`.
- En WSL, el selector recomienda `win32yank` y no recomienda `Espanso` ni
  `Ghostty`.
- En Windows, `Ghostty` queda disponible como ítem opcional y muestra un aviso
  porque aún no hay instalador oficial para esa plataforma.
- `Codex` y `Claude Code` se recomiendan en todas las plataformas. El mismo
  ítem instala la herramienta o la actualiza si ya existe:
  - Codex en macOS/Linux: `brew install --cask codex` o, si ya está,
    `brew upgrade --cask codex`.
  - Claude Code en macOS/Linux: instalador oficial `https://claude.ai/install.sh`
    (se descarga a un temporal y se ejecuta con `bash`).
  - En Windows, ambos usan su instalador oficial `irm <url> | iex` en un Windows
    PowerShell hijo con `-ExecutionPolicy Bypass`. Codex corre con
    `CODEX_NON_INTERACTIVE=1` para que no haga preguntas. Las URLs están en
    `constants/official-installers.psd1`.
  - Fuera del setup, `cx upgrade` usa el mismo método (instalador oficial en
    Windows, `brew upgrade --cask codex` en macOS/Linux).
- En Windows, `WSL`, `Bitwarden` y `7-Zip` se seleccionan por defecto;
  `Espanso`, `Scoop`, `Ghostty`, `AutoHotkey`, `VLC` y `WhatsApp` son opcionales.
- En Windows, `ripgrep` prepara Scoop como dependencia aunque no se seleccione
  por separado. Si la política efectiva ya permite scripts, se conserva;
  en una sesión elevada se pasa `-RunAsAdmin` al instalador oficial de Scoop.
- `wget` y Java 21 ya no forman parte de los paquetes recomendados.

### Ejecutar el script completo

Desde la raíz del repo:

```bash
chmod +x scripts/setup/setup.sh
./scripts/setup/setup.sh
```

### Selector interactivo

- El setup abre un selector clásico con selección múltiple y búsqueda incremental.
- La salida usa solo ASCII (ver `scripts/AGENTS.md`), así funciona en cualquier
  terminal y fuente, incluida la consola clásica de Windows.
- Arriba, una caja muestra cuántos ítems hay seleccionados, una barra de
  selección (`######......`) y el rango visible.
- La lista ocupa todo el alto disponible de la terminal y se recalcula al
  redimensionar. Si no entra, aparece una barra de scroll a la izquierda
  (`#` indica la posición).
- Cada fila muestra `[x]` / `[ ]`, `*` si es recomendado (seleccionado por
  defecto) y, alineadas a la derecha, las etiquetas `# sudo` (o `# admin` en
  Windows) y `^ reinicio`. Los ítems no seleccionados se atenúan.
- La fila bajo el cursor (`>`) se resalta completa con un fondo gris, y debajo
  de la lista se muestra el detalle del ítem: id, función, plataformas y si es
  recomendado u opcional.
- `ENTER` confirma solo los ítems realmente marcados.
- Usa `ESPACIO` para alternar un ítem, `a` para alternar toda la selección y `d` para restaurar defaults.
- Usa `/` para buscar, `j/k` o flechas para navegar y `q`, `ESC`, `Ctrl+C` o `Ctrl+D` para cancelar.
- Antes de ejecutar muestra una caja con lo que se va a procesar. Cada
  instalación se enmarca (`+- > [2/5] fzf` ... `+- + fzf listo - 12s`) sin
  ocultar la salida real del instalador, y al final hay una caja `Resumen`
  con estado y duración por ítem.
- Compatible con `/bin/bash` 3.2 de macOS: flechas, PgUp/PgDn y Home/End
  funcionan aunque esa versión no admite timeouts fraccionales en `read`.

### Ejecutar una función específica

```bash
./scripts/setup/setup.sh --yes install_zsh
./scripts/setup/setup.sh --dry-run --yes git fd_find
```

La ejecución directa está limitada a ítems presentes para la plataforma actual
en `scripts/setup/setup.catalog.csv`. Se puede usar el `Id` o el nombre de la
función del shell correspondiente.

### Opciones CLI

```bash
./scripts/setup/setup.sh --help
./scripts/setup/setup.sh --list
./scripts/setup/setup.sh --dry-run git
```

- `--dry-run` puede ir antes o después de los ítems.
- `--list` muestra `Id`, función y etiqueta disponibles: como tabla en una
  terminal y como TSV (`Id<TAB>función<TAB>etiqueta`) al redirigir la salida.
- `--yes` omite la pantalla de confirmación previa a la ejecución.

## Uso en Linux

Puedes ejecutar el script completo o llamar a funciones específicas desde la
terminal.

### Consideraciones

- Algunas funciones pueden requerir un reinicio del sistema para que los cambios
  surtan efecto, como `install_docker`.
- Asegúrate de tener permisos de ejecución para el script:

```bash
chmod +x setup.sh
```

### Ejecutar el script completo

Para ejecutar el script completo, simplemente ejecuta:

```bash
./setup.sh
```

### Ejecutar una función específica

Para ejecutar una función específica, usa el nombre de la función como
argumento. Por ejemplo, para instalar Docker, ejecuta:

```bash
./setup.sh --yes install_docker
./setup.sh --dry-run --yes docker
```

La ejecución directa está limitada a ítems presentes para la plataforma actual
en `scripts/setup/setup.catalog.csv`. Se puede usar el `Id` o el nombre de la
función del shell correspondiente.

### Autocompletado

El script incluye soporte para autocompletado en `zsh`. Para habilitar el
autocompletado, asegúrate de que el archivo de autocompletado se genera y se
carga correctamente en tu configuración de `zsh`.

```bash
# Añade esto a tu ~/.zshrc
fpath+=~/.zsh/completions
autoload -Uz compinit && compinit
```

## Uso en Windows

Para los usuarios de Windows, se proporciona un script `setup.ps1` que
automatiza la instalación de varias herramientas y dependencias utilizando
Chocolatey.

### Consideraciones

- No hace falta abrir PowerShell como Administrador. Si la selección incluye
  ítems marcados `# admin` (Chocolatey, Fuentes, WSL, Hyper-V), el script pide
  elevación (UAC) una sola vez y los ejecuta juntos en una ventana elevada. El
  resto sigue en la sesión actual para que winget y Scoop instalen en el
  contexto del usuario, y el resumen final reúne ambos resultados.

### Ejecutar el script completo

Para ejecutar el script completo, simplemente ejecuta:

```bat
.\setup.bat

# o

powershell -ExecutionPolicy Bypass -File .\setup.ps1
```

### Ejecutar una función específica

Para ejecutar una función específica, usa el nombre de la función como
argumento. Por ejemplo, para instalar Chocolatey, ejecuta:

```bat
.\setup.bat --yes Install-Choco
.\setup.bat --dry-run --yes git

# o

powershell -ExecutionPolicy Bypass -File .\setup.ps1 --yes Install-Choco
powershell -ExecutionPolicy Bypass -File .\setup.ps1 --dry-run --yes git
```

La ejecución directa está limitada a ítems presentes para Windows en
`scripts/setup/setup.catalog.csv`. Se puede usar el `Id` o el nombre de la
función de PowerShell.

Opciones útiles:

```powershell
powershell -ExecutionPolicy Bypass -File .\setup.ps1 --help
powershell -ExecutionPolicy Bypass -File .\setup.ps1 --list
```

## Catálogo, versiones y validación

- `setup.sh` y `setup.ps1` construyen su menú desde
  `scripts/setup/setup.catalog.csv`.
- Para agregar o quitar ítems, actualiza el catálogo común y la función
  instaladora asociada al shell correspondiente.
- El catálogo común declara `BashFunctionName`, `PowerShellFunctionName`,
  `RequiresAdmin`, `Platforms` y `RequiresRestart`, para que cada script cargue
  solo los ítems compatibles con la plataforma actual y avise sobre privilegios
  o reinicios.
- La política explícita es instalar o actualizar siempre a la última versión
  estable oficial. Si una herramienta se instala con `brew`, `winget`, `choco`
  o `apt`, se confía en el resolver del package manager. Si se instala desde un
  endpoint oficial, el script resuelve la versión estable más reciente cuando
  existe un endpoint o redirección de `latest`.
- Las descargas directas usan directorios temporales y limpieza posterior para
  no dejar artefactos en el repo ni en el directorio actual.
- Validaciones recomendadas:

```bash
bash -n scripts/setup/setup.sh
bash scripts/setup/setup.sh.spec.sh
```

```powershell
Invoke-Pester -Path .\scripts\setup\setup.ps1.Tests.ps1
```

Los tests de PowerShell usan Pester (última versión estable, compatible con 5.x);
ver "Tests De PowerShell Con Pester" en el `AGENTS.md` raíz.
