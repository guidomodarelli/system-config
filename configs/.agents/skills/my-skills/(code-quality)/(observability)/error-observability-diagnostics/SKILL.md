---
name: error-observability-diagnostics
description: "Diseña, implementa y revisa trazabilidad operativa de errores relevantes mediante logs estructurados, métricas, tracing y, cuando el repositorio Meli lo soporte, Failure Studio/ErrorUX. Usar cuando una operación importante agregue o revise logging de errores, mensajes diagnósticos detallados, error contexts, Grafana/Loki, Datadog/StatsD, request/correlation/trace IDs, severidad, cardinalidad, sampling, deduplicación, redaction o fallos de sinks. Detectar primero los observability sinks reales del repositorio: no asumir Failure Studio fuera de Meli ni Grafana como backend universal. Coordinar con async-operation-error-handling para partial success/polling/retry y con typed-errors-refactor para contratos tipados."
---

# Error Observability Diagnostics

## Objetivo

Hacer que cada error importante o relevante pueda rastrearse de extremo a extremo sin confundir tres salidas:

1. mensaje público/UI: breve, seguro, accionable y localizado;
2. diagnóstico de soporte: detallado, estable y searchable;
3. telemetría operativa: estructurada, correlacionable y agregable.

La skill es vendor-neutral. Failure Studio/ErrorUX es opcional y solo se aplica si el proyecto pertenece al ecosistema Meli y tiene integración real disponible. Grafana/Loki, Datadog, StatsD, OpenTelemetry u otro sink dependen del repositorio; detectar y reutilizar la integración existente, sin inventar cliente, dashboard o configuración.

Leer [`references/diagnostic-contract.md`](references/diagnostic-contract.md) para el contrato por sink y [`references/observability-testing.md`](references/observability-testing.md) para validación.

## Cuándo aplicar

Activar cuando se agregue, corrija o revise cualquiera de estos comportamientos:

- un error relevante no deja registro operativo suficiente;
- se necesita seguir una falla desde request hasta job/run/retry;
- se agregan mensajes detallados para soporte o Failure Studio;
- logs actuales usan `error`, `request`, `response` o payloads completos;
- métricas incluyen IDs de usuario, run, request o mensajes libres;
- falta correlación entre retries, polling, workers o dependencias;
- se requiere distinguir fallo esperado, degradación, partial success y fallo terminal;
- falla un sink de observabilidad y puede afectar el flujo de negocio;
- se solicita instrumentar errores para Grafana, Loki, Datadog, StatsD o tracing.

No activar solo para cambiar copy UI sin necesidad de diagnóstico operativo, salvo que también se deba separar mensaje público de detalle técnico.

## Preflight y detección de sinks

1. Leer instrucciones del repositorio, `package.json`, logger existente, métricas, tracing, middleware de request IDs y adapters de error.
2. Determinar si repo pertenece a Meli y si existe integración ErrorUX/Failure Studio real. Si no existe, marcar Failure Studio como `No aplica`; no simularlo.
3. Detectar backend real de logs y métricas. Grafana puede consumir logs desde Loki, un agregador interno u otra fuente; no asumir API de Grafana.
4. Inventariar errores relevantes por operación, boundary y frecuencia: input, autorización, dependencia, partial, timeout, terminal item failure, retry, reconciliation, cancelación y sink failure.
5. Identificar quién clasifica el error, quién responde al usuario y quién tiene ownership de emitir observabilidad. Evitar duplicar el mismo evento en cada `catch`/rethrow.
6. Capturar baseline: eventos actuales, campos, severidad, métricas, tags, correlación y tests.

## Política de cobertura

Cada error relevante debe producir observabilidad suficiente en el boundary que conoce su significado final:

- error esperado por input o validación: log/métrica agregada cuando aporte valor; no Failure Studio por defecto;
- rechazo de autorización o negocio: log estructurado y Failure Studio solo si usuario/soporte necesita acción;
- dependencia unavailable, respuesta inválida o timeout: log detallado, métrica y Failure Studio si integración Meli existe y el flujo tiene código asociado;
- partial success, unresolved o terminal failure: log por operación y métrica; detalle por item solo si es necesario y acotado;
- retry/reconciliation: registrar intento, outcome y correlación, sin crear un evento duplicado del error original;
- cancelación intencional: `info`/métrica si aporta trazabilidad, nunca `error` ni Failure Studio;
- fallo de logger, métricas o Failure Studio: observabilidad degradada aislada, nunca nuevo error de negocio ni retry accidental.

“Cada error importante” no significa registrar cada excepción en cada capa. Emitir un evento dueño por fase; agregar contexto al mismo evento o crear evento nuevo solo cuando cambie etapa, outcome o acción operativa.

## Contrato diagnóstico común

Construir contexto desde allowlist, no desde `error`, `request`, `response` o payload completos. Campos posibles, solo cuando estén aprobados:

- `schema_version`;
- `service`, `environment`/`scope`;
- `operation`, `stage`, `outcome`, `error_code`, `error_category`;
- `dependency`, `route_template`, `http_method`;
- `status_code`, `upstream_status`, `retryable`, `attempt`;
- `request_id`, `correlation_id`, `trace_id`, `span_id`;
- `operation_id`, `run_id`, `job_id`, `chunk_counts` seguros;
- `duration_ms`, contadores y límites;
- `error_class` y mensaje técnico sanitizado/truncado.

Cada campo debe declarar tipo, longitud, allowlist y sinks permitidos. No usar `Record<string, unknown>` libre. Separar `request_id` —petición— de `operation_id`/`run_id` —trabajo— y `trace_id` —traza—.

## Logs detallados para el sink del repositorio

Usar logger oficial del repo; coordinar con `use-nordic-logger` cuando corresponda. El mensaje debe responder: qué operación falló, en qué etapa, con qué código, contra qué dependencia, con qué outcome y qué acción sigue.

Formato recomendado:

```text
[operation] stage failed: error_code; outcome=...; dependency=...; status=...; retryable=...
```

Adjuntar contexto estructurado con valores seguros. Preferir route templates y categorías estables. Truncar mensajes técnicos, escapar saltos de línea y eliminar patrones de secretos antes de emitir. No registrar `Error` raw, `request`, `response`, headers, cookies, tokens, passwords, payloads completos ni PII.

Si el repositorio envía logs a Grafana/Loki, mantener IDs dinámicos dentro del evento estructurado o mensaje controlado, nunca como labels de alta cardinalidad. Si usa otro backend, aplicar el mismo contrato sin nombrar Grafana en código o configuración.

## Failure Studio/ErrorUX para proyectos Meli

Aplicar solo tras verificar dependencia y adapter reales. Crear contexto para fallos relevantes que requieren seguimiento de soporte o acción de usuario:

- usar team/código ErrorUX allowlisted del proyecto;
- generar `detail` técnico corto, searchable y accionable;
- incluir operación, etapa, código, razón, dependencia, status y contadores seguros;
- incluir request/correlation ID solo si contrato y SDK lo permiten;
- incluir IDs de job/run únicamente si están aprobados y no son PII expuesta;
- mantener mensaje público separado, localizado y sin detalle interno;
- si generación de ErrorUX falla, responder DTO seguro, emitir log estructurado de fallback y conservar el resultado HTTP original.

No copiar logs completos a Failure Studio. No enviar `cause`, stack, headers, request/response, tokens, secretos, payloads, PII ni mensaje upstream sin sanitizar. No generar Failure Studio para abort intencional, cada fallo esperado por item o errores sin acción operativa, salvo contrato explícito.

## Severidad y métricas

Severidad aplica a logs, no como tag de métrica:

- `trace`: diagnóstico muy detallado y controlado;
- `debug`: troubleshooting de bajo volumen;
- `info`: transición o resultado esperado;
- `warn`: degradación recuperable, partial, unresolved, retry diferido o input rechazado;
- `error`: operación fallida, dependencia no disponible, payload inválido o sink fallido relevante;
- `fatal`: proceso no puede continuar; no usar para timeout recuperable, 4xx esperado o partial success.

Métricas deben usar counters/histograms con dimensiones finitas: operación, etapa, outcome, categoría, dependencia, status family y scope. Nunca usar como tags: request ID, trace ID, run/job ID, user ID, Groot ID, LDAP, QR, URL completa, mensaje, stack o error raw. Registrar métricas de éxito, rechazo, partial, unresolved, timeout, retry, reconciliation, terminal failure y emisión fallida cuando tengan consumer operativo.

## Correlación, sampling y deduplicación

Resolver correlación con esta precedencia: tracing existente → request ID confiable → correlation ID confiable → ID server-side generado según convención del repo. Validar formato, longitud y caracteres.

Propagar la correlación a adapters, chunks, retries, jobs y polling. Mantener separados request/operation/run/trace IDs. No crear tracing nuevo si repo no tiene tracer.

- No samplear métricas agregadas.
- No descartar silenciosamente eventos Failure Studio accionables.
- Permitir sampling de `trace`/`debug`.
- Deduplicar bursts por fingerprint estable basada en service, operation, stage, error code, dependency y status family.
- Nunca incluir IDs, mensaje raw o payload en fingerprint.
- Conservar count/suppressed_count o señal equivalente cuando se supriman logs.
- Sampling/deduplicación no debe alterar HTTP, retry, UI, idempotencia ni estado de negocio.

## Sanitización y fallback de sinks

Construir proyección nueva; no mutar error original. Sanitizar `unknown` con allowlist, escape de controles, redaction de secretos, límite de longitud y fallback estable. Prevenir log injection eliminando o escapando saltos de línea y separadores peligrosos.

Cada sink es best-effort:

- ErrorUX fallido: respuesta segura + log fallback;
- métricas fallidas: operación intacta + log rate-limited;
- logger primario fallido: fallback oficial configurado, nunca `console.*` agregado por defecto;
- evitar recursión de sink failure;
- nunca convertir falla de observabilidad en `500`, retry, cancelación o error visible.

## Tests de comportamiento

Cubrir por sink y por operación relevante:

- evento detallado emitido en boundary correcto;
- no duplicación al rethrow o atravesar capas;
- separación mensaje público / Failure Studio / log;
- Failure Studio solo cuando integración Meli está disponible;
- absence de `request`, `response`, headers, cookies, tokens, passwords, stack, cause, PII y payload raw;
- route template y método presentes; URL/query sensible ausente;
- correlation IDs propagados y formatos inválidos descartados;
- IDs dinámicos ausentes de tags de métricas;
- severidad correcta para input, partial, terminal, dependency, cancelación y fatal;
- sampling/deduplicación conserva métricas y eventos accionables;
- logger, métricas y Failure Studio fallan sin afectar resultado de negocio;
- truncado, escape de controles y redaction deterministas.

Usar integración real del logger/métrica cuando el repo la permita. No mockear plataforma innecesariamente. Tests deben validar comportamiento observable, no strings internos del archivo fuente.

## Formato de salida

```markdown
## Alcance y sinks detectados
## Errores relevantes y ownership de eventos
## Contrato de diagnóstico
## Logs detallados y Failure Studio aplicable
## Métricas, severidad y cardinalidad
## Correlación, sampling y deduplicación
## Sanitización y fallback
## Cambios y migración
## Tests y validación
## Riesgos y pendientes
```

Ser explícito cuando Failure Studio no aplica, cuando Grafana no es sink confirmado o cuando una integración no puede validarse.
