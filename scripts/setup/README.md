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
- En WSL, el selector recomienda `win32yank` y no recomienda `Espanso`.
- `wget` y Java 21 ya no forman parte de los paquetes recomendados.

### Ejecutar el script completo

Desde la raíz del repo:

```bash
chmod +x scripts/setup/setup.sh
./scripts/setup/setup.sh
```

### Selector interactivo

- El setup abre un selector clásico con selección múltiple y búsqueda incremental.
- Los ítems seleccionados por defecto se muestran con la marca `@`.
- `ENTER` confirma solo los ítems realmente marcados.
- Usa `ESPACIO` para alternar un ítem, `a` para alternar toda la selección y `r` para restaurar defaults.
- Usa `/` para buscar, `j/k` o flechas para navegar y `q`, `ESC` o `Ctrl+C` para cancelar.

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
- `--list` muestra `Id`, función y etiqueta disponibles.
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

- Asegúrate de ejecutar PowerShell como Administrador.

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
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup\setup.ps1.spec.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup\setup.ps1.spec.ps1
```
