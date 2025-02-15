# Configuración del sistema

Este repositorio está diseñado para configurar tu sistema sin esfuerzo, gracias
a nuestra completa colección de recursos que simplifican todo el proceso de
configuración.

## Requisitos

Antes de comenzar con la instalación, asegúrate de cumplir con los siguientes
requisitos:

- **Sistema operativo**: Linux (basado en Arch o en Ubuntu) o Windows.
- **Privilegios de administrador**: Necesarios para ejecutar ciertos comandos y
  scripts.
- **Conexión a Internet**: Para descargar dependencias y herramientas
  necesarias.
- **Git**: Asegúrate de tener Git instalado para clonar el repositorio y
  actualizar los submódulos.

Para asegurarte de que todos los submódulos estén inicializados y actualizados,
ejecuta el siguiente comando:

```sh
git submodule update --init --recursive
```

## Instalación

En Linux:

1. Lee `SETUP.md`: Antes de proceder con la instalación, asegúrate de leer el
   archivo `SETUP.md`. Contiene instrucciones detalladas sobre cómo usar el
   script de configuración, incluyendo cómo ejecutar el script completo o
   funciones específicas.

2. Ejecuta el script de configuración: Ejecuta el script de configuración para
   instalar y configurar varias herramientas y dependencias. Este script está
   diseñado para sistemas basados en Arch Linux o Ubuntu.

	```bash
	./setup.sh
	```

3. Ejecuta `dotfiler.sh`: Después de ejecutar el script de configuración,
   ejecuta el script `dotfiler.sh` para configurar tus dotfiles y otras
   configuraciones.

	```sh
	./dotfiler.sh
	```

En Windows:

1. Lee `SETUP.md`: Antes de proceder con la instalación, asegúrate de leer el
   archivo `SETUP.md`. Contiene instrucciones detalladas sobre cómo usar el
   script de configuración, incluyendo cómo ejecutar el script completo o
   funciones específicas.

2. Ejecuta el script de configuración: Abre PowerShell como Administrador y
   ejecuta el script `setup.bat` para instalar y configurar varias herramientas
   y dependencias usando Chocolatey.

	```ps1
	.\setup.bat
	```
