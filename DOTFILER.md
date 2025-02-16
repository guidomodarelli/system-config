# Descripción General

El script `dotfiler.sh` se encarga de crear enlaces simbólicos (symlinks) desde
archivos y directorios de la carpeta `files` hacia ubicaciones definidas en
archivos de configuración, facilitando así la sincronización y gestión de
configuraciones personales. Además, realiza ajustes específicos para sistemas
Darwin (macOS).

## Archivos de Configuración

- **listfiles**:
  - Es un archivo de texto que define las asignaciones entre
    archivos/directorios origen y sus destinos en el sistema.
  - Cada línea tiene el formato `origen=destino`.
  - Si no se especifica un destino (es decir, la parte después del `=` está
    vacía), el destino por defecto es el directorio del usuario `$HOME`.
  - Se admiten comodines (como en `*.ext`), que se procesan y resuelven para
    generar los enlaces a los archivos correspondientes.

- **`listfiles.darwin`**:
  - Es similar a `listfiles` pero se utiliza específicamente en sistemas Darwin
    (macOS).
  - Permite definir rutas que se adapten a la estructura y convenciones de
    macOS.
  - El script verifica si se ejecuta en Darwin (usando la función `isDarwin`) y,
    de ser así, usa este archivo en lugar de `listfiles`.

## Funcionamiento General del Script

1. **Detección del Sistema Operativo**

  Utiliza la función `isDarwin` para determinar si se está en un entorno Darwin
  (macOS). Si es así, se carga la configuración desde `listfiles.darwin`; de lo
  contrario, se utiliza `listfiles`.

2. **Procesamiento de las Asignaciones**

  - Por cada línea del archivo de configuración, se interpreta la ruta origen
    (en la carpeta files) y el destino asignado.
  - Si el destino definido no es una ruta absoluta (no comienza por `/`), se le
    antepone el directorio del usuario (`$HOME`).
  - Cuando el "`origen`" termina con un asterisco (`*`), el script interpreta
    que se deben enlazar todos los archivos y directorios contenidos en la
    carpeta indicada. Para ello, elimina el asterisco del valor original y
    utiliza el comando `find` para obtener la lista de elementos, generando
    enlaces simbólicos para cada uno.

3. **Creación de Enlaces Simbólicos**

  La función `create_symbolic_link` se encarga de:
  - Comprobar que el destino no tenga un enlace ya existente y realizar una
    copia de seguridad (con la extensión `.bak`) en caso de existir.
  - Crear el enlace simbólico desde el archivo origen a la ruta de destino.
  - Utilizar `sudo` en caso de que el directorio de destino no pertenezca al
    usuario actual.

4. **Modificación de Configuraciones**:

  Con esta infraestructura, modificar el archivo `listfiles` (o
  `listfiles.darwin` según corresponda) te permite controlar qué archivos y
  directorios serán enlazados y a qué ubicaciones del sistema se llevarán,
  facilitando la transferencia y sincronización de configuraciones entre
  distintas máquinas o entornos.
