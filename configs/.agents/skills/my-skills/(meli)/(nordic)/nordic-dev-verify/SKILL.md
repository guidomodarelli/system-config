---
name: nordic-dev-verify
description: Verifica flujos runtime de aplicaciones web Nordic en entorno de desarrollo mediante browser y Chrome DevTools MCP. Usar siempre que se pida ejecutar, probar, validar o confirmar manualmente un cambio frontend Nordic en `dev.adminml.com`, incluso si usuario no menciona esta skill por nombre.
---

# Verificar aplicaciones Nordic en desarrollo

## Objetivo

Validar comportamiento observable desde UI y requests de red sin exponer credenciales ni dejar datos de prueba modificados. Reportar evidencia suficiente para distinguir resultado exitoso, fallo real o bloqueo de entorno.

## Preparar verificación

1. Confirmar servidor disponible en `https://dev.adminml.com:8443`.
2. Autenticar sesión corporativa en browser cuando sea necesario.
3. Identificar ruta afectada, flujo esperado y requests relevantes antes de interactuar.
4. Si flujo modifica estado, elegir fixture sandbox conocido, registrar estado inicial y definir restauración antes de ejecutar acción.
5. No usar datos productivos ni fixtures compartidos cuyo estado no pueda restaurarse con seguridad.

## Ejecutar flujo

1. Abrir ruta afectada mediante Chrome DevTools MCP.
2. Capturar snapshot inicial de página.
3. Ejecutar flujo desde UI como lo haría usuario.
4. Inspeccionar requests XHR/fetch con `list_network_requests` y registrar método, ruta sanitizada y status.
5. No leer headers completos: pueden contener cookies, tokens de sesión o valores CSRF.
6. Usar `get_network_request` solo cuando body sea imprescindible para diagnóstico y pueda guardarse o mostrarse sanitizado.
7. Agregar probe read-only adyacente con `evaluate_script` cuando permita confirmar estado final sin mutarlo.
8. Capturar snapshot final cuando resultado visual sea relevante.
9. Restaurar fixture a estado inicial y verificar restauración antes de cerrar.

## Clasificar resultado

- `PASS`: flujo y requests esperados funcionan, estado final coincide con expectativa y fixture quedó restaurado.
- `FAIL`: comportamiento o request contradice resultado esperado. Incluir paso reproducible y evidencia sanitizada.
- `BLOCKED`: entorno, autenticación, servidor, permisos o fixture impiden verificar. No presentar bloqueo como éxito.

## Reportar verificación

Usar estructura breve:

```markdown
## Verificación runtime

- Resultado: PASS | FAIL | BLOCKED
- Ruta: <ruta verificada>
- Flujo: <acciones ejecutadas>
- Requests: <método + ruta sanitizada + status>
- Estado: <inicial, final y restauración cuando aplique>
- Evidencia: <snapshots o probes relevantes>
- Ruido preexistente: <errores ajenos observados o ninguno>
- Bloqueos: <detalle accionable o ninguno>
```

Nunca incluir tokens, cookies, headers de autorización, valores CSRF, PII completa ni bodies sin sanitizar.
