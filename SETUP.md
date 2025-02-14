# Setup Script

Este script `setup.sh` está diseñado para automatizar la instalación y
configuración de varias herramientas y dependencias en un sistema basado en Arch
Linux.

## Uso

Puedes ejecutar el script completo o llamar a funciones específicas desde la terminal.

### Ejecutar el script completo

Para ejecutar el script completo, simplemente ejecuta:

```bash
./setup.sh
```

### Ejecutar una función específica

Para ejecutar una función específica, usa el nombre de la función como
argumento. Por ejemplo, para instalar LazyVim, ejecuta:

```bash
./setup.sh install_LazyVim
```

### Funciones Disponibles

El script incluye las siguientes funciones:

- `install_LazyVim`: Instala y configura LazyVim.
- `install_oh_my_zsh`: Instala Oh My Zsh.
- `install_docker`: Instala Docker y Docker Compose.
- `install_antigen`: Instala Antigen para la gestión de plugins de Zsh.
- `install_nvm`: Instala Node Version Manager (NVM).
- `install_aicommits`: Instala AI Commits.
- `install_npm_dependencies`: Instala dependencias globales de NPM.
- `install_font`: Función genérica para instalar fuentes.
- `install_font_IosevkaTermCurly`: Instala la fuente IosevkaTermCurly.
- `install_espanso`: Instala Espanso, un expansor de texto.
- `install_golang`: Instala Go (Golang).
- `install_ghq`: Instala GHQ, una herramienta de gestión de repositorios.
- `install_go_dependencies`: Instala dependencias de Go.
- `install_dependencies`: Instala todas las dependencias del sistema.
- `main`: Función principal que llama a install_dependencies y otras funciones
  de instalación personalizadas.

## Notas

- Algunas funciones pueden requerir un reinicio del sistema para que los cambios
surtan efecto, como `install_docker`.
- Asegúrate de tener permisos de ejecución para el script:

```bash
chmod +x setup.sh
```

## Autocompletado

El script incluye soporte para autocompletado en `zsh`. Para habilitar el
autocompletado, asegúrate de que el archivo de autocompletado se genera y se
carga correctamente en tu configuración de `zsh`.

```bash
# Añade esto a tu ~/.zshrc
fpath+=~/.zsh/completions
autoload -Uz compinit && compinit
```
