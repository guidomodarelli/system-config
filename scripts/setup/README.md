# Script de Configuración

Estos scripts están diseñados para automatizar la instalación y configuración de
diversas herramientas y dependencias del sistema, facilitando así el proceso de
configuración inicial y asegurando que todas las aplicaciones necesarias estén
disponibles y correctamente configuradas.

## Uso en macOS

Este script automatiza la instalación de herramientas y la configuración del
entorno usando Homebrew. `SDKMAN` puede instalarse como herramienta base, pero
el setup recomendado ya no instala ni fija Java 21 por defecto.

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
./scripts/setup/setup.sh install_zsh
./scripts/setup/setup.sh --dry-run git fd_find
```

La ejecución directa está limitada a ítems presentes en
`scripts/setup/setup.bash.catalog.csv`. Se puede usar el `Id` o el nombre de la
función.

### Opciones CLI

```bash
./scripts/setup/setup.sh --help
./scripts/setup/setup.sh --list
./scripts/setup/setup.sh --dry-run git
```

- `--dry-run` puede ir antes o después de los ítems.
- `--list` muestra `Id`, función y etiqueta disponibles.
- `--yes` queda reservado para ejecuciones directas no interactivas.

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
./setup.sh install_docker
./setup.sh --dry-run docker
```

La ejecución directa está limitada a ítems presentes en
`scripts/setup/setup.bash.catalog.csv`. Se puede usar el `Id` o el nombre de la
función.

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

# or

powershell -ExecutionPolicy Bypass -File .\setup.ps1
```

### Ejecutar una función específica

Para ejecutar una función específica, usa el nombre de la función como
argumento. Por ejemplo, para instalar Chocolatey, ejecuta:

```bat
.\setup.bat Install-Choco
.\setup.bat --dry-run git

# or

powershell -ExecutionPolicy Bypass -File .\setup.ps1 Install-Choco
powershell -ExecutionPolicy Bypass -File .\setup.ps1 --dry-run git
```

La ejecución directa está limitada a ítems presentes en
`scripts/setup/setup.pwsh.catalog.csv`. Se puede usar el `Id` o el nombre de la
función.

Opciones útiles:

```powershell
powershell -ExecutionPolicy Bypass -File .\setup.ps1 --help
powershell -ExecutionPolicy Bypass -File .\setup.ps1 --list
```

## Catálogos y validación

- `setup.sh` construye su menú desde `scripts/setup/setup.bash.catalog.csv`.
- `setup.ps1` construye su menú desde `scripts/setup/setup.pwsh.catalog.csv`.
- Para agregar o quitar ítems, actualiza el catálogo del shell correspondiente
  y la función instaladora asociada.
- Los catálogos declaran `RequiresAdmin`, `Platforms` y `RequiresRestart`, para
  que cada script pueda pedir privilegios solo cuando corresponde y avisar sobre
  reinicios.
- Validaciones recomendadas:

```bash
bash -n scripts/setup/setup.sh
bash scripts/setup/setup.sh.spec.sh
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup\setup.ps1.spec.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup\setup.ps1.spec.ps1
```
