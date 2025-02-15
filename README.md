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

En Linux y Windows:

1. **Lee `SETUP.md`** _(ubicado en `scripts/setup`)_: Antes de proceder con la
   instalación, asegúrate de leer el archivo `SETUP.md`. Contiene instrucciones
   detalladas sobre cómo usar el script de configuración, incluyendo cómo
   ejecutar el script completo o funciones específicas.

2. **Ejecuta el script de configuración**: Ejecuta el script `setup.py`. Este script
   detectará automáticamente si estás en un sistema Linux o Windows y procederá
   con la instalación y configuración de las herramientas y dependencias
   necesarias. En sistemas Linux, también ejecutará `dotfiler.sh` para
   configurar tus dotfiles y otras configuraciones.

	```sh
	python3 setup.py
	```

3. **Revisa la configuración**: Asegúrate de que todas las herramientas y
   configuraciones se hayan instalado correctamente. Puedes revisar los archivos
   de configuración generados y probar las herramientas instaladas para
   verificar su funcionamiento.
