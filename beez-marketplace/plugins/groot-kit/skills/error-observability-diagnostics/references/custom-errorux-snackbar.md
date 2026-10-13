# Regla de uso de CustomErrorUXSnackbar

En aplicaciones Nordic/MELI, `CustomErrorUXSnackbar` (a veces referido como `CustomUXSnackbar`) es un canal de feedback de errores + registro en Failure Studio, no un reemplazo general de `Message`, `Snackbar` o estados de negocio.

## Usar `CustomErrorUXSnackbar` únicamente cuando

- existe un `ErrorUxContext` real generado por el adapter/server de ErrorUX;
- ocurrió un fallo accionable o inesperado que requiere registro, diagnóstico, soporte o seguimiento, por ejemplo dependencia no disponible, request fallida, partial/unresolved operation, fallo terminal o excepción inesperada;
- el mensaje público puede ser breve, localizado y separado del detail técnico;
- `retry` se habilita solo cuando ejecuta una operación segura/idempotente o una reanudación explícita; un error inesperado sin retry sigue pudiendo usar el snackbar para registrar Failure Studio;
- el `detail` técnico puede ser amplio y útil para diagnóstico, pero debe componerse desde una allowlist segura y sanitizada.

Patrón esperado:

```tsx
<CustomErrorUXSnackbar
  show={Boolean(errorMessage && errorContext)}
  message={i18n.gettext('No pudimos completar la operación. Intentá nuevamente.')}
  errorContext={errorContext}
  isRetryEnabled
  retry={retryOperation}
  delay={SnackbarDuration.NORMAL}
/>
```

## No usarlo para

- loading, preflight en curso o progreso (`Message`/`role="status"`);
- estados informativos o warnings esperados del dominio;
- listas vacías, ausencia de resultados o filtros sin coincidencias;
- validación esperable de input antes de ejecutar una operación;
- estados `PROCESSING`, `NO_PROCESS_CHANGE` o `EXTERNAL_REQUIREMENT_PENDING` cuando el resultado es válido y no existe un fallo accionable;
- errores sin `ErrorUxContext` válido: usar fallback visual seguro y log server-side, sin inventar contexto.

## Detail técnico rico, seguro y trazable

El detail de ErrorUX puede incluir tanta información diagnóstica como sea útil, siempre como proyección allowlisted y sanitizada:

- operación, etapa, categoría y outcome;
- código de error público/interno, status HTTP y upstream status;
- dependencia y route template sin query sensible;
- `context_access_key`, engine, atributos allowlisted evaluados y estados `supported/unavailable/unsupported`;
- conteos seguros (`operator_count`, `pending_operator_count`), límites y reintentos;
- `request_id`, `correlation_id`, `trace_id` o `span_id` cuando el contrato real los provea;
- resumen estructurado de la condición solo si elimina secretos, payloads, valores sensibles y PII.

No enviar la condición raw completa, payload upstream, request/response completos, headers, cookies, tokens, secretos, PII completa ni dumps del usuario. Si soporte necesita esos datos, resolverlos server-side usando el `request_id`/Error ID, no publicarlos en el detail.

## Contexto y ciclo de vida

- Obtener `ErrorUxContext` desde response/error normalizado; nunca construirlo con payload raw en el componente.
- Limpiar `errorMessage` y `errorContext` al cambiar de recurso/operación, cerrar modal o iniciar un retry para no mostrar un error viejo sobre una selección nueva.
- Mantener un único evento por fallo: no renderizar múltiples `CustomErrorUXSnackbar` para el mismo error en componentes anidados.
- Mantener `detail` técnico allowlisted y searchable: operación, etapa, categoría, código, dependencia, status, conteos seguros y correlación. No incluir condición completa, request/response, payload upstream, secretos ni datos sensibles del usuario.
- Si Failure Studio/ErrorUX falla, preservar la operación y mostrar fallback `Message`/`Snackbar`; registrar el fallo del sink sin generar un segundo error de negocio.

## Tests obligatorios

- Error accionable con `ErrorUxContext` → muestra `CustomErrorUXSnackbar`, mensaje público seguro y retry esperado.
- Error inesperado con `ErrorUxContext` → muestra `CustomErrorUXSnackbar` con detail rico aunque no exista retry seguro.
- Error sin contexto → muestra fallback visual sin intentar registrar un contexto inventado.
- Loading/informativo/estado de negocio esperado → no renderiza `CustomErrorUXSnackbar`.
- Cambio de selección, cierre y retry → limpia contexto anterior y evita errores stale.
- El response/log no contiene `request`, `response`, headers, tokens, payload raw, condición completa ni PII.
