# Descripcion General

## Entrypoints disponibles

- Linux/macOS/WSL: `./scripts/dotfiler/dotfiler.sh`
- Windows: `scripts\dotfiler\dotfiler.bat`

En Windows, `dotfiler.bat` invoca `dotfiler.ps1` y soporta los mismos flags
principales (`--dry-run`, `--no-color`, `--plain`, `--verbose`, `--quiet`,
`--help`) para trabajar contra `symlinks.yml` desde PowerShell nativo.
En ese entorno, `dotfiler.ps1` requiere `yq` y `jq` para interpretar el YAML.
Si alguno no esta disponible, intenta instalarlo automaticamente con `winget`
antes de continuar. Si la instalacion falla o `winget` no existe, el script
termina con error.

El script `dotfiler.sh` se encarga de crear enlaces simbólicos (symlinks) desde
archivos y directorios de la carpeta `configs` hacia ubicaciones definidas en
archivos de configuración, facilitando así la sincronización y gestión de
configuraciones personales. Además, realiza ajustes específicos para diferentes
sistemas operativos como Darwin (macOS) y Linux.

## Archivos de Configuración

- **`symlinks.yml`**:
  - Es un archivo YAML que define las asignaciones entre
    archivos/directorios origen y sus destinos en el sistema.
  - Utiliza un esquema JSON (`schema.json`) para validar la estructura.
  - Cada entrada en `paths` contiene:
    - `path`: La ruta del archivo o directorio de origen.
    - `target` (opcional): El destino donde se creará el enlace simbólico. Si no
      se especifica, el destino por defecto es el directorio del usuario
      `$HOME`.
      - Soporta variables de entorno como `$USER` o `$HOME` que serán expandidas
        al ejecutar el script.
      - Para rutas que comienzan con `/mnt/c/` o utilizan el prefijo `WSL://` en WSL,
        `$USER` será expandido al nombre de usuario de Windows.
      - Para todas las demás rutas, `$USER` será expandido al nombre de usuario de Linux/macOS.
      - También puedes usar `~` como alias para `$HOME`.
      - `target` funciona como directorio contenedor: el enlace final conserva el
        basename de `path`.
      - Regla práctica: usa `target` cuando quieras decir "poné este archivo o
        directorio dentro de esta carpeta".
      - Ejemplo:
        ```yaml
        - path: .codex/AGENTS.md
          target: .codex/
        ```
        Resultado final: `~/.codex/AGENTS.md`.
      - Ejemplo con wildcard:
        ```yaml
        - path: scripts/*
          target: $HOME/bin
        ```
        Si el patrón encuentra `scripts/foo` y `scripts/bar`, se crearán
        `~/bin/foo` y `~/bin/bar`.
    - `exactTarget` (opcional): La ruta final exacta donde se creará el enlace
      simbólico, sin agregar automáticamente el basename del origen.
      - `exactTarget` y `target` son mutuamente excluyentes.
      - `exactTarget` no admite `path` con wildcards porque una sola ruta final
        no puede representar múltiples resultados.
      - Regla práctica: usa `exactTarget` cuando quieras decir "creá el symlink
        exactamente en esta ruta".
      - Ejemplo:
        ```yaml
        - path: .codex/skills/.system
          exactTarget: .agents/.codex/skills/.system
        ```
        Resultado final: `~/.agents/.codex/skills/.system`.
      - Si ese mismo caso usara `target`:
        ```yaml
        - path: .codex/skills/.system
          target: .agents/.codex/skills/.system
        ```
        el resultado sería `~/.agents/.codex/skills/.system/.system`, porque
        `target` siempre agrega el basename del origen.
      - Ejemplo inválido:
        ```yaml
        - path: scripts/*
          exactTarget: $HOME/bin/tool
        ```
        Esto no está permitido porque múltiples archivos no pueden resolverse a
        una única ruta final exacta.

## Configuración por Plataforma

El sistema soporta configuraciones específicas para diferentes plataformas:

- **Plataformas admitidas**:
  - `darwin`: Para sistemas macOS.
  - `linux`: Para sistemas Linux, con soporte específico para:
    - `debian`: Distribución Debian/Ubuntu.
  - `wsl`: Detecta automáticamente si está ejecutándose bajo Windows Subsystem for Linux. Esta opción:
    - Se usa como un especificador de plataforma independiente con `wsl: true`.
    - No puede combinarse con `platform` en la misma especificación (prohibido según schema.json).
    - Debe usarse de forma exclusiva para configuraciones específicas de WSL.
    - Se detecta utilizando métodos específicos como verificar `/proc/version` por patrones de WSL.

- **Directivas de Configuración por Plataforma**:
  - `onlyFor`: Define para qué plataformas específicas aplica este enlace.
  - `excludeFor`: Define qué plataformas deben excluir este enlace.
  - `overrides`: Permite modificar `target` o `exactTarget` dependiendo de la plataforma.

## Soporte para WSL (Windows Subsystem for Linux)

El script incluye soporte especial para entornos WSL con el prefijo `WSL://`:

- **Prefijo `WSL://`**:
  - Cuando se especifica un `target` o `exactTarget` con el prefijo `WSL://`, el script reconoce que el destino debe estar en el sistema de archivos de Windows.
  - El prefijo `WSL://` se convierte automáticamente a la ruta correcta en la estructura de `/mnt/c/`.
  - Este prefijo solo puede usarse cuando la configuración tiene `wsl: true`.
  - **Importante**: Cuando un elemento tiene `onlyFor` con exactamente un objeto que especifica `wsl: true`, el campo `target` o `exactTarget` es obligatorio y debe comenzar con el prefijo `WSL://`. Esta regla asegura que los archivos destinados exclusivamente para WSL utilicen la ruta correcta en Windows.

- **Ejemplo de uso**:
  ```yaml
  - path: .config/espanso
    target: .config
    overrides:
      - target: WSL://AppData/Roaming
        wsl: true

  # Este es un ejemplo donde onlyFor tiene solo un elemento con wsl:true
  # Por lo tanto, target DEBE usar el prefijo WSL://
  - path: windows/app-configs
    target: WSL://AppData/Roaming  # El prefijo WSL:// es obligatorio en este caso
    onlyFor:
      - wsl: true

  - path: .codex/skills/.system
    exactTarget: .agents/.codex/skills/.system
  ```

- **Formato interno**:
  - Cuando se usa `WSL://`, el script formateará la ruta para que sea accesible desde el sistema Windows mediante la estructura `\\wsl$\<distro>\path`.
  - Esto permite que las aplicaciones de Windows accedan a los archivos compartidos a través del sistema de archivos de WSL.

## Funcionamiento General del Script

1. **Detección del Sistema Operativo**

  Utiliza las funciones `is_darwin`, `is_wsl` y `get_linux_distro` para determinar en qué
  entorno se está ejecutando y aplicar las configuraciones adecuadas.

2. **Procesamiento de las Configuraciones**

  - El script lee el archivo de configuración YAML y filtra las entradas según
    la plataforma actual.
  - Interpreta las directivas `onlyFor`, `excludeFor` y `overrides` para
    determinar qué enlaces crear.
  - Si la entrada usa `target`, el basename del origen se agrega al destino.
  - Si la entrada usa `exactTarget`, el enlace se crea exactamente en esa ruta.
  - Cuando el "`path`" termina con un asterisco (`*`), el script interpreta
    que se deben enlazar todos los archivos y directorios contenidos en la
    carpeta indicada (solo el primer nivel). Cada uno de los elementos encontrados
    se enlaza individualmente manteniendo su nombre original en la carpeta destino.

    Por ejemplo, si tenemos:
    ```yaml
    - path: .config/settings/*
      target: .local/share/app-settings
    ```
    Y dentro de `.config/settings/` hay archivos `config.json` y `profile.ini`,
    se crearán dos enlaces:
    - `.local/share/app-settings/config.json` → `/ruta/absoluta/configs/.config/settings/config.json`
    - `.local/share/app-settings/profile.ini` → `/ruta/absoluta/configs/.config/settings/profile.ini`

3. **Creación de Enlaces Simbólicos**

- Para cada destino, verifica su estado actual:
  - Si ya existe como enlace simbólico, lo elimina para reemplazarlo.
  - Si existe como archivo o directorio regular, crea una copia de respaldo
    antes de proceder.
  - Elimina cualquier respaldo anterior que sea un enlace simbólico.
- Crea el enlace simbólico que apunta del origen al destino especificado.
- Comprueba los permisos del directorio destino y, si no es escribible o no
  pertenece al usuario actual, utiliza `sudo` para ejecutar la operación.
- Notifica al usuario cuando se emplean permisos elevados.

4. **Ejemplo de Configuración YAML**

  ```yaml
  paths:
    - path: .zshrc
      target: $HOME
    - path: .config/espanso
      target: .config
    - path: .config/Code/User/*
      target: .config/Code/User
      excludeFor:
        - platform: darwin
    - path: .config/wsl-specific-config
      target: .config
      onlyFor:
        - wsl: true
    - path: .ssh/config
      target: /home/$USER/.ssh  # Expandido al usuario Linux/macOS
    - path: scripts/*
      target: $HOME/bin  # Expandido al directorio home del usuario
    - path: .codex/skills/.system
      exactTarget: .agents/.codex/skills/.system
    - path: windows/app-configs
      target: WSL://AppData/Roaming  # $USER es usuario de Windows en WSL
      onlyFor:
        - wsl: true
  ```

5. **Modificación de Configuraciones**:

  Para agregar o modificar enlaces, simplemente edita el archivo `symlinks.yml`
  siguiendo la estructura definida en `schema.json`. Esto permite controlar con
  precisión qué archivos se enlazan y dónde, facilitando configuraciones
  específicas por plataforma.

## Reglas de validación del esquema

El archivo `schema.json` define las siguientes reglas importantes para la configuración:

1. **Configuraciones de plataforma**:
   - Las propiedades `platform` y `wsl` son mutuamente excluyentes
   - La propiedad `linuxDistro` solo puede utilizarse cuando `platform` es `linux`

2. **Reglas específicas para WSL**:
   - En la sección `overrides`, cuando `wsl: true`, el campo `target` o `exactTarget` debe usar el prefijo `WSL://`
   - Cuando un elemento tiene `onlyFor` con exactamente un objeto que especifica `wsl: true`, el campo `target` o `exactTarget` es obligatorio y debe comenzar con el prefijo `WSL://`
   - Para entornos que no son WSL, el prefijo `WSL://` está prohibido

Estas reglas aseguran que las configuraciones específicas para WSL y otras plataformas se mantengan correctas y consistentes.
