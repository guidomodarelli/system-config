---
description: Reglas específicas para repositorios bajo ~/ghq/work/ (plataforma Nordic/MELI). Leer y aplicar solo si el directorio de trabajo actual está dentro de esa ruta.
alwaysApply: false
---

# Reglas Para Repositorios Bajo `~/ghq/work/`

> Condición de carga: leer y aplicar este archivo **solo** cuando el directorio de trabajo actual esté ubicado dentro de `~/ghq/work/` (en Windows, `C:\Users\guido\ghq\work\`). Para cualquier otro repositorio, ignorarlo por completo.

## Contexto De Proyecto Y Tooling Obligatorio

- Tratar el proyecto como una aplicación Nordic.
- Asumir runtime Node.js.
- Asumir extensión Odin.
- Mantener en inglés todos los términos de código:
  - comentarios
  - string literals
  - nombres de funciones
  - nombres de clases
  - nombres de métodos
  - nombres de variables
  - nombres de constantes
  - nombres de enums
  - otros términos técnicos o de implementación

## Verificación Runtime De Aplicaciones Nordic

- Si `package.json` declara una dependencia cuyo nombre contiene `nordic` (sin distinguir mayúsculas/minúsculas) en `dependencies`, `devDependencies`, `optionalDependencies` o `peerDependencies`, leer y aplicar `@/Users/gmodarelli/.claude/skills/nordic-dev-verify/SKILL.md` antes de verificar manualmente flujos runtime o cambios frontend en `dev.adminml.com`.

## Reglas De Testing Específicas De Plataforma (MELI/Nordic)

- Los paquetes `@andes/*`, `@meli/*`, `nordic/*` y `@kraken/*` son ejemplos concretos de las "librerías internas o de plataforma" que la regla global de testing prohíbe mockear; no es una lista exhaustiva.
- Nunca mockear componentes importados desde `@andes` en tests (`andes-no-mock-components`, severidad error). Solo se permite por pedido explícito del usuario o imposibilidad técnica justificada; en esos casos, explicar por qué el mock es necesario y mantenerlo lo más acotado posible.
- No usar `jest.mock`, `jest.doMock`, `jest.unmock` ni `jest.dontMock` sobre estas dependencias: los tests deben ejercer la integración real o aislarse en un borde propio del proyecto.

## Validación Centralizada Con Schema Middleware

- Validar request params/query/body una sola vez por ruta en un schema validation middleware (p. ej. `schemaValidationMiddleware`); no duplicar esa validación dentro de los handlers.
- En los handlers, usar los valores ya validados directamente y dejar solo los chequeos de reglas de negocio que el schema no puede expresar.
- Aplicar el mismo enfoque de validación de forma consistente en todas las rutas del módulo.

## Validación Mínima Para Repositorios En `~/ghq/work/`

Antes de cerrar una respuesta o cambio, confirmar que:
- Los comentarios, nombres y strings de implementación agregados o modificados están en inglés.
