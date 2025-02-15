# Setup Script

Este script `setup.sh` está diseñado para automatizar la instalación y
configuración de varias herramientas y dependencias en un sistema basado en Arch
Linux.

## Uso en Linux

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
- `install_VsCode`: Instala Visual Studio Code.
- `install_fonts`: Instala varias fuentes.
- `install_vlc`: Instala VLC Media Player.
- `install_wezterm`: Instala WezTerm.
- `install_rofi`: Instala Rofi.
- `install_obs_studio`: Instala OBS Studio.
- `install_peek`: Instala Peek.
- `install_user_interface_apps`: Instala varias aplicaciones de interfaz de usuario.
- `install_exa`: Instala Exa.
- `install_homebrew`: Instala Homebrew.
- `install_fd_find`: Instala fd (find alternative).
- `install_lazygit`: Instala LazyGit.
- `install_btop`: Instala Btop.
- `install_xclip`: Instala Xclip.
- `install_git_delta`: Instala Git Delta.
- `install_git_filter_repo`: Instala Git Filter Repo.
- `install_git`: Instala Git.
- `install_git_dependencies`: Instala dependencias de Git.
- `install_zsh`: Instala Zsh.
- `install_essencials`: Instala herramientas esenciales.
- `install_utilities`: Instala utilidades varias.
- `install_all_dependencies`: Instala todas las dependencias del sistema.
- `main`: Punto de entrada de la aplicación.

### Notas

- Algunas funciones pueden requerir un reinicio del sistema para que los cambios
  surtan efecto, como `install_docker`.
- Asegúrate de tener permisos de ejecución para el script:

```bash
chmod +x setup.sh
```

### Autocompletado

El script incluye soporte para autocompletado en `zsh`. Para habilitar el
autocompletado, asegúrate de que el archivo de autocompletado se genera y se
carga correctamente en tu configuración de `zsh`.

```bash
# Añade esto a tu ~/.zshrc
fpath+=~/.zsh/completions
autoload -Uz compinit && compinit
```

## Instrucciones para Windows

Para los usuarios de Windows, se proporciona un script `setup.ps1` que automatiza la instalación de varias herramientas y dependencias utilizando Chocolatey.

### Ejecutar el script completo

Para ejecutar el script completo, abre PowerShell como Administrador y ejecuta:

```ps1
.\setup.bat
```

### Ejecutar una función específica

Para ejecutar una función específica, usa el nombre de la función como
argumento. Por ejemplo, para instalar Chocolatey, ejecuta:

```ps1
.\setup.ps1 Install-Choco
```

### Funciones Disponibles

El script incluye las siguientes funciones:

- `Install-Choco`: Instala Chocolatey.
- `Install-ChocoPackages`: Instala paquetes de Chocolatey.
- `Install-Fonts`: Instala varias fuentes.
- `Install-Espanso`: Instala Espanso, un expansor de texto.
- `Main`: Función principal que llama a las funciones de instalación personalizadas.
