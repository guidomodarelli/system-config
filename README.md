# Configuración del sistema

Este repositorio está diseñado para configurar tu sistema sin esfuerzo, gracias
a nuestra completa colección de recursos que simplifican todo el proceso de
configuración.

## Requisitos

Antes de comenzar con la instalación, asegúrate de cumplir con los siguientes
requisitos:

- **Privilegios de administrador**: Necesarios para ejecutar ciertos comandos y
  scripts.
- **Conexión a Internet**: Para descargar dependencias y herramientas
  necesarias.
- **Git**: Asegúrate de tener Git instalado para clonar el repositorio y
  mantenerlo actualizado.

## Instalación

1. **Lee [`README.md`](./scripts/setup/README.md)**: Antes de proceder con la
   instalación, asegúrate de leer el archivo `README.md`. Contiene instrucciones
   detalladas sobre cómo usar el script de configuración, incluyendo cómo
   ejecutar el script completo o funciones específicas.

2. **Ejecuta el script de configuración**: Ejecuta el script `scripts/setup/setup.sh`.

  ```sh
  ./scripts/setup/setup.sh
  ./scripts/dotfiler/dotfiler.sh
  ```

3. **Revisa la configuración**: Asegúrate de que todas las herramientas y
   configuraciones se hayan instalado correctamente. Puedes revisar los archivos
   de configuración generados y probar las herramientas instaladas para
   verificar su funcionamiento.

## Completions dinámicos en Zsh

La carga de completions está configurada para descubrir automáticamente
directorios que contengan archivos de completion válidos.

¿Cómo funciona?

1. Se toma como raíz de búsqueda `~/.zsh` (o `ZDOTDIR/.zsh` si aplica).
2. Se buscan archivos que empiecen con `_`.
3. Si el archivo contiene una línea que comience con `#compdef` o `compdef`,
   se considera un completion válido.
4. El directorio de ese archivo se agrega a `fpath` automáticamente.

Esto permite organizar completions en cualquier subcarpeta, por ejemplo:

- `~/.zsh/completions`
- `~/.zsh/settings/meli/completions`

Además:

- Se siguen symlinks durante la búsqueda.
- `~/.zsh/completions` sigue siendo la carpeta base para completions generados
  localmente.
- Si se hace `source ~/.zsh/completions.zsh` en una shell ya abierta, se
  refresca `compinit` para tomar cambios sin reiniciar terminal.

### Relación con zsh-autosuggestions

La estrategia de completions de autosuggestions está en
[third-party/zsh-autosuggestions/src/strategies/completion.zsh](third-party/zsh-autosuggestions/src/strategies/completion.zsh).

Puntos importantes:

- Ahí se valida `whence compdef >/dev/null || return` dentro de la estrategia.
- Esa validación ocurre cuando se intenta capturar sugerencias por completion,
  no solo durante el arranque de la shell.
- En paralelo, el discover de [configs/zsh/.zsh/completions.zsh](configs/zsh/.zsh/completions.zsh)
  vuelve a ejecutarse cada vez que ese archivo se sourcea.

En resumen: no depende solo del inicio. Si agregas/mueves completions en una
shell ya abierta, puedes recargar para que se redescubran y se reconstruya
`compinit`.

Comando rápido para validar:

```sh
zsh -ic 'cmd="setup.sh"; echo "$cmd comp: ${_comps[$cmd]-<none>}"'
```

Si está correcto, debería mostrar un valor distinto de `<none>`, por ejemplo:

```text
setup.sh comp: _setup_sh_completions
```
