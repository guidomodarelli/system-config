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
    - Configuración específica por plataforma (ver abajo).

## Configuración por Plataforma

El sistema soporta configuraciones específicas para diferentes plataformas:

- **Plataformas admitidas**:
  - `darwin`: Para sistemas macOS.
  - `linux`: Para sistemas Linux, con soporte específico para:
    - `arch`: Distribución Arch Linux.
    - `debian`: Distribución Debian/Ubuntu.

- **Directivas de Configuración por Plataforma**:
  - `onlyFor`: Define para qué plataformas específicas aplica este enlace.
  - `excludeFor`: Define qué plataformas deben excluir este enlace.
  - `overrides`: Permite modificar el `target` dependiendo de la plataforma.

## Funcionamiento General del Script

1. **Detección del Sistema Operativo**

  Utiliza las funciones `is_darwin` y `get_linux_distro` para determinar en qué
  entorno se está ejecutando y aplicar las configuraciones adecuadas.

2. **Procesamiento de las Configuraciones**

  - El script lee el archivo de configuración YAML y filtra las entradas según
    la plataforma actual.
  - Interpreta las directivas `onlyFor`, `excludeFor` y `overrides` para
    determinar qué enlaces crear.
  - Cuando el "`path`" termina con un asterisco (`*`), el script interpreta
    que se deben enlazar todos los archivos y directorios contenidos en la
    carpeta indicada.

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
  ```

5. **Modificación de Configuraciones**:

  Para agregar o modificar enlaces, simplemente edita el archivo `listfiles.yml`
  siguiendo la estructura definida en `schema.json`. Esto permite controlar con
  precisión qué archivos se enlazan y dónde, facilitando configuraciones
  específicas por plataforma.
