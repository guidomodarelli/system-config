# Descripción General

El script `dotfiler.sh` se encarga de crear enlaces simbólicos (symlinks) desde
archivos y directorios de la carpeta `files` hacia ubicaciones definidas en
archivos de configuración, facilitando así la sincronización y gestión de
configuraciones personales. Además, realiza ajustes específicos para diferentes
sistemas operativos como Darwin (macOS) y Linux.

## Archivos de Configuración

- **`listfiles.yml`**:
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

## Configuración por Plataforma

El sistema soporta configuraciones específicas para diferentes plataformas:

- **Plataformas admitidas**:
  - `darwin`: Para sistemas macOS.
  - `linux`: Para sistemas Linux, con soporte específico para:
    - `arch`: Distribución Arch Linux.
    - `debian`: Distribución Debian/Ubuntu.
    - `wsl`: Detecta si Linux está ejecutándose bajo Windows Subsystem for Linux.

- **Directivas de Configuración por Plataforma**:
  - `onlyFor`: Define para qué plataformas específicas aplica este enlace.
  - `excludeFor`: Define qué plataformas deben excluir este enlace.
  - `overrides`: Permite modificar el `target` dependiendo de la plataforma.

## Soporte para WSL (Windows Subsystem for Linux)

El script incluye soporte especial para entornos WSL con el prefijo `WSL://`:

- **Prefijo `WSL://`**:
  - Cuando se especifica un `target` con el prefijo `WSL://`, el script reconoce que el destino debe estar en el sistema de archivos de Windows.
  - El prefijo `WSL://` se convierte automáticamente a la ruta correcta en la estructura de `/mnt/c/`.
  - Este prefijo solo puede usarse cuando la configuración tiene `platform: linux` y `wsl: true`.

- **Ejemplo de uso**:
  ```yaml
  - path: .config/espanso
    target: .config
    overrides:
      - target: WSL://AppData/Roaming
        platform: linux
        wsl: true
  ```
  En este ejemplo, en un entorno WSL, el directorio `.config/espanso` se enlazará a `/mnt/c/Users/<windows_username>/AppData/Roaming/espanso`.

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
    - `.local/share/app-settings/config.json` → `/ruta/absoluta/files/.config/settings/config.json`
    - `.local/share/app-settings/profile.ini` → `/ruta/absoluta/files/.config/settings/profile.ini`

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
    - path: .config/nvim
      target: .config
    - path: .config/lazygit
      target: .config
      overrides:
        - platform: darwin
          target: Library/Application Support/lazygit
    - path: .config/Code/User/*
      target: .config/Code/User
      excludeFor:
        - platform: darwin
    - path: root/etc/pacman.conf
      target: /etc
      onlyFor:
        - platform: linux
          linuxDistro: arch
    - path: .config/wsl-specific-config
      target: .config
      onlyFor:
        - platform: linux
          wsl: true
    - path: .ssh/config
      target: /home/$USER/.ssh  # Expandido al usuario Linux/macOS
    - path: scripts/*
      target: $HOME/bin  # Expandido al directorio home del usuario
    - path: windows/app-configs
      target: /mnt/c/Users/$USER/AppData/Roaming  # $USER es usuario de Windows en WSL
      onlyFor:
        - platform: linux
          wsl: true
  ```

5. **Modificación de Configuraciones**:

  Para agregar o modificar enlaces, simplemente edita el archivo `listfiles.yml`
  siguiendo la estructura definida en `schema.json`. Esto permite controlar con
  precisión qué archivos se enlazan y dónde, facilitando configuraciones
  específicas por plataforma.
