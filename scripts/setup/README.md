# Script de Configuración

Estos scripts están diseñados para automatizar la instalación y configuración de
diversas herramientas y dependencias del sistema, facilitando así el proceso de
configuración inicial y asegurando que todas las aplicaciones necesarias estén
disponibles y correctamente configuradas.

## Uso en macOS

Este script automatiza la instalación de herramientas y la configuración del
entorno usando Homebrew. Java se instala y administra con `SDKMAN`, y el JDK
por defecto queda fijado a Temurin 21.

### Requisitos

- Homebrew instalado en `/opt/homebrew`.
- Permisos de administrador para cambiar el shell por defecto.
- Conexión a Internet.
- `SDKMAN` se instala automáticamente si no existe.

Si Homebrew está en otra ruta, ajusta la función `_brew` en
`scripts/setup/setup.sh`.

### Java y `JAVA_HOME`

- El repo ya no define `JAVA_HOME` con una ruta fija del sistema.
- `JAVA_HOME` se resuelve desde la versión activa de Java en `SDKMAN`.
- El setup instala Temurin 21 usando el identificador configurado en
  `scripts/setup/setup.sh` y lo deja como default.
- Si cambias la versión por defecto con `sdk default java ...`, `JAVA_HOME`
  reflejará esa selección en nuevas shells.

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
```

La ejecución directa está limitada a funciones presentes en
`scripts/setup/setup.bash.catalog.csv`.

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
```

La ejecución directa está limitada a funciones presentes en
`scripts/setup/setup.bash.catalog.csv`.

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

# or

powershell -ExecutionPolicy Bypass -File .\setup.ps1 Install-Choco
```

La ejecución directa está limitada a funciones presentes en
`scripts/setup/setup.pwsh.catalog.csv`.

## Catálogos y validación

- `setup.sh` construye su menú desde `scripts/setup/setup.bash.catalog.csv`.
- `setup.ps1` construye su menú desde `scripts/setup/setup.pwsh.catalog.csv`.
- Para agregar o quitar ítems, actualiza el catálogo del shell correspondiente
  y la función instaladora asociada.
- Validaciones recomendadas:

```bash
bash -n scripts/setup/setup.sh
bash scripts/setup/setup.sh.spec.sh
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup\setup.ps1.spec.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup\setup.ps1.spec.ps1
```
