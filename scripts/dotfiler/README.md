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
    - `hardLink` (opcional): Si vale `true`, crea un hard link en lugar de un
      enlace simbólico. Solo admite archivos regulares; los directorios y los
      archivos ubicados en otro filesystem se rechazan durante la ejecución.
      Si se omite o vale `false`, se conserva el comportamiento de symlink.
      - Un hard link no es una copia: todos sus nombres apuntan al mismo inode
        y comparten el mismo contenido.
      - Si un archivo tiene dos hard links y se elimina uno, el contenido sigue
        disponible mediante el otro.
      - El contenido se libera únicamente cuando se elimina el último hard link
        y ningún proceso mantiene el archivo abierto.
      - Por eso, eliminar la ruta original no elimina el contenido mientras
        exista otro hard link.
    - `target` (opcional): El destino donde se creará el enlace. Si no
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

  ### Filtrado de globs con `descendInto` / `markerFile` / `exclude`

  Cuando el `path` termina con `/*`, se pueden agregar tres campos opcionales
  para refinar qué hijos se enlazan, atravesar agrupadores anidados y enlazar
  unidades terminales con un archivo marcador.

  | Campo | Tipo | Aplica a | Significado |
  | --- | --- | --- | --- |
  | `descendInto` | string (regex con `/.../` opcional) | folders | Las carpetas cuyo basename matchee son **agrupadores**: se desciende dentro recursivamente sin enlazarlas. |
  | `markerFile` | string (basename) | folders hoja | Sólo se enlazan carpetas que contengan este archivo al raíz. No aplica a archivos. |
  | `exclude` | string (regex con `/.../` opcional) | folders y archivos | Lo matcheado se descarta totalmente (sin enlazar y sin descender). Gana sobre `descendInto` y `markerFile`. |

  **Ejemplo (caso skills)**:

  ```yaml
  - path: .agents/skills/my-skills/*
    target: .claude/skills
    descendInto: /^\(.*\)$/        # agrupadores con paréntesis (recursivos)
    markerFile: SKILL.md            # solo carpetas con SKILL.md se enlazan
    exclude: /^(dist|\.dist)$/      # descartar build outputs
  ```

  Árbol fuente:

  ```text
  my-skills/
  ├── enforce-naming-conventions/SKILL.md
  ├── (javascript)/
  │   ├── react-best/SKILL.md
  │   └── (otro)/(otromas)/deep-skill/SKILL.md
  ├── (meli)/nordic-rules/SKILL.md
  └── dist/                          # descartado
  ```

  Symlinks producidos (aplanados al basename bajo `target`):

  - `~/.claude/skills/enforce-naming-conventions`
  - `~/.claude/skills/react-best`
  - `~/.claude/skills/deep-skill`
  - `~/.claude/skills/nordic-rules`

  **Reglas**:

  - `exclude` gana sobre `descendInto` y `markerFile`.
  - `descendInto` siempre es recursivo, sin flag adicional.
  - Los slashes en `/pattern/` son decorativos y se descartan si están presentes en ambos extremos.
  - `descendInto` aplica sólo a carpetas; `exclude` aplica a carpetas y archivos; `markerFile` nombra un archivo dentro de una carpeta hoja.
  - El destino siempre se aplana al basename, incluso en carpetas profundas.
  - Los archivos siempre se enlazan en cualquier nivel del recorrido, sujetos a `exclude`. `markerFile` no aplica a archivos.
  - Los tres campos requieren `path` con `/*` final. Si no, se ignoran con una advertencia.
  - Si dos hojas terminan con el mismo basename al aplanar el destino, gana la primera (orden alfabético por path absoluto); la segunda se descarta con advertencia y se cuenta como error.
  - `exactTarget` no acepta patrones wildcard, por lo que tampoco acepta estos filtros.

  ### Exclusiones dependientes de la máquina con `conditionalExcludes`

  `conditionalExcludes` agrega patrones a `exclude` solo cuando existe una ruta
  en la máquina actual. Sirve para omitir enlaces según el entorno, por ejemplo
  en la máquina de trabajo.

  | Campo | Tipo | Significado |
  | --- | --- | --- |
  | `pattern` | string (regex con `/.../` opcional) | Misma semántica que `exclude`: aplica a basenames de carpetas y archivos. |
  | `whenPathExists` | string | Archivo o carpeta cuya existencia activa la regla. Admite `~`, `$HOME` y `$USER`; las rutas relativas se resuelven desde `$HOME`. |

  ```yaml
  - path: .agents/skills/my-skills/*
    target: .claude/skills
    descendInto: /^\(.*\)$/
    markerFile: SKILL.md
    exclude: /^(dist|\.dist)$/
    conditionalExcludes:
      - pattern: /^constants-refactor$/
        whenPathExists: ~/.fury   # solo en la máquina de trabajo
  ```

  **Reglas**:

  - Requiere `path` con `/*` final, igual que `exclude`. No aplica con `exactTarget`.
  - Si la regla está activa y en el destino quedó un symlink de una ejecución
    anterior que apunta exactamente a la fuente ahora excluida, se elimina.
    Con `--dry-run` solo se informa. Se cuenta en la fila `Eliminados` del resumen.
  - Nunca se eliminan archivos o carpetas reales, ni symlinks que apunten a otro origen.
  - Un regex inválido en `pattern` se reporta como error y omite la entrada completa.

  ### Migración de un symlink de carpeta a enlaces individuales

  Al pasar de enlazar una carpeta completa (`path: carpeta`) a enlazar sus hijos
  (`path: carpeta/*`) hacia el mismo destino, el destino suele seguir siendo el
  symlink viejo que apunta al repositorio. Crear enlaces "dentro" escribiría en
  el repositorio, por eso:

  - Si el directorio destino es un symlink que resuelve dentro de `configs/`, se
    elimina solo el symlink (nunca su contenido) y se crea una carpeta real.
    Con `--dry-run` solo se informa. Se cuenta en `Eliminados`.
  - Si el directorio destino sigue resolviendo dentro de `configs/` (por ejemplo,
    por un ancestro que es symlink al repositorio), la operación falla con error
    sin escribir nada.

  **Portabilidad regex (PowerShell .NET ↔ bash ERE)**: usar el subconjunto seguro
  para que ambos motores produzcan el mismo resultado: anclas (`^`, `$`),
  clases de caracteres (`[...]`), cuantificadores (`*`, `+`, `?`, `{}`),
  grupos `(...)` y alternancia `|`. Evitar lookaheads/lookbehinds (`(?=...)`,
  `(?!...)`) y backreferences.

3. **Creación de Enlaces**

- Para cada destino, verifica su estado actual:
  - Si ya existe como enlace, lo elimina para reemplazarlo.
  - Si existe como archivo o directorio regular, crea una copia de respaldo
    antes de proceder.
  - Elimina cualquier respaldo anterior que sea un enlace simbólico.
- Crea un symlink por defecto. Cuando la entrada tiene `hardLink: true`, crea
  un hard link con el mismo contenido/inode; el origen debe ser un archivo
  regular y origen y destino deben pertenecer al mismo filesystem.
- Los hard links no admiten directorios. El script informa el error antes de
  crear respaldos o modificar el destino.
- Comprueba los permisos del directorio destino y, si no es escribible o no
  pertenece al usuario actual, utiliza `sudo` para ejecutar la operación.
- Notifica al usuario cuando se emplean permisos elevados.
- En PowerShell, intenta crear los enlaces sin elevacion primero. Los que
  requieren permisos de administrador se agrupan al final en una sola solicitud
  UAC por ejecucion. Si se cancela, informa los enlaces pendientes como errores
  sin volver a solicitar permisos. `--dry-run` no solicita elevacion.
- El lote elevado conserva los resultados individuales y no sobrescribe destinos
  que hayan aparecido mientras se esperaba la autorizacion.

### Ciclo de vida del contenido de un hard link

Un hard link agrega otro nombre de directorio para el mismo inode. No duplica el
contenido ni mantiene una relación de "origen" y "copia": ambas rutas son
referencias equivalentes al mismo archivo.

```text
configs/shared.json       ─┐
~/.config/shared.json      ├─ mismo inode y mismo contenido
~/.config/shared.backup    ─┘
```

Si se elimina una de esas rutas, las demás continúan permitiendo acceder al
contenido. El sistema libera los bloques únicamente cuando se cumple todo esto:

1. Ya no queda ningún hard link apuntando al inode.
2. Ningún proceso mantiene abierto el archivo.

En consecuencia, eliminar la ruta que se usó como `path` no elimina el archivo
mientras exista otro hard link. La última ruta eliminada sí vuelve el contenido
inaccesible y permite que el sistema recupere su espacio.

4. **Ejemplo de Configuración YAML**

  ```yaml
  paths:
    - path: .zshrc
      target: $HOME
    - path: shared/editor-settings.json
      target: .config/editor
      hardLink: true
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

## Salida en consola

La salida usa solo ASCII (ver `scripts/AGENTS.md`), así funciona en cualquier
terminal y fuente. Agrupa las operaciones por carpeta destino y muestra una
línea por enlace con un ícono, la acción, el nombre y el origen relativo a
`configs/`.

```text
> ~/.claude/skills
| + creado       new-skill                  -> .agents/skills/my-skills/(meli)/new-skill
| ~ reemplazado  simplify                   -> .agents/skills/my-skills/(code-quality)/(refactor)/simplify
| x eliminado    constants-refactor         (excluido por ~/.fury)
+- 3 cambios - = 38 sin cambios

+- Resumen -----------------------------------------------------
| + creados           1     ~ reemplazados      1
| = sin cambios      38     x eliminados        1
| < respaldos         0     x errores           0
+----------------------------------------------------------------
| > aplicación real - 12s - = Sin errores.
+----------------------------------------------------------------
```

- Los enlaces que ya apuntan al origen correcto no se recrean: se cuentan como
  `sin cambios`. Los grupos sin cambios se ocultan y, si nada cambió, se muestra
  `Todos los enlaces están al día`. En PowerShell, los hard links se recrean
  siempre porque Windows no permite comparar inodes a bajo costo.
- En el resumen, cada contador mayor a cero se muestra en su color (creados
  verde, reemplazados azul, sin cambios cian, eliminados magenta, respaldos
  amarillo, errores rojo) y los ceros en gris.
- `--verbose` lista también cada enlace sin cambios y el tiempo por operación.
- `--quiet` oculta banner y grupos; deja resumen, avisos y errores.
- `--plain` quita íconos y colores, pero conserva cajas y etiquetas.
- Las cajas quedan abiertas a la derecha a propósito, para que cada fila pueda
  tener cualquier ancho.
- Los errores se detallan al final en una caja `Diagnóstico` con destino y causa.
- Mientras resuelve rutas muestra un loader con spinner `| / - \`, mensajes
  rotativos, barra `###...`, entrada actual y segundos; al enlazar muestra
  `> Enlazando N/total - nombre`. En PowerShell usa `Write-Progress`. Solo
  aparece en terminales interactivas y sin `--quiet`; se controla con
  `DOTFILER_PROGRESS=auto|always|never`.

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
