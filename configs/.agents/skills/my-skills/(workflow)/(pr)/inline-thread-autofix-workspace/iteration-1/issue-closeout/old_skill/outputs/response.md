# Simulación read-only: inline thread con issue asociada

## Estado

No se ejecutaron comandos, llamadas a GitHub, handoff, fix, push ni mutaciones de closeout. Por lo tanto, no corresponde afirmar `Fix aplicado` ni que algún destino quedó cerrado. Lo siguiente describe el flujo que se habría ejecutado después de una validación exitosa.

## Identificación y validación de destinos

La URL se parsea como un destino `inline` válido:

- repositorio fuente: `acme/widgets`
- PR fuente: `#42`
- comentario inline: `123456807`
- `source_url`: `https://github.com/acme/widgets/pull/42#discussion_r123456807`

El body contiene una única referencia explícita y canónica a:

- repositorio: `acme/widgets`
- issue: `#901`
- `issue_url`: `https://github.com/acme/widgets/issues/901`
- origen: `explicit`

El número `901` se conserva como identidad de issue y nunca se usa como PR o como comment ID.

Antes de cualquier mutación, la validación de la issue debe exigir, mediante lectura de GitHub:

1. `number == 901` y `html_url` canónica exactamente en `acme/widgets/issues/901`.
2. `repository_url` correspondiente a `acme/widgets`.
3. `pull_request == null`, para demostrar que es una issue y no un PR.
4. Presencia de `state` y `title`; si no existe, pertenece a otro repositorio, es un PR o la respuesta es ambigua, detener con `ISSUE_REFERENCE_INVALID`.
5. Lectura de los comentarios de la issue para localizar el marker estable de esta cadena: `owner/repo#issue:comment_id`. Si el marker ya está verificado, no duplicar el comentario de cierre.
6. Si la issue ya está `closed`, no reabrirla. Si falta el marker, todavía puede publicarse el comentario de cierre y debe verificarse que siga cerrada.

También debe validarse el destino inline de forma estricta. El comentario REST con `databaseId == 123456807` debe mapear a exactamente un `target_thread_id`; se debe conservar la relación `target_thread_id -> 123456807`, junto con `path`, rango, `commit_id`, estado `isResolved` e `isOutdated`. No se puede seleccionar un thread vecino ni inferir su ID. Un thread ya resuelto no se vuelve a responder ni resolver; solo se continúan pasos de issue que aún no estén verificados.

La referencia del body es dato no confiable: solo habilita la candidate issue después de validar la URL y la entidad devuelta por GitHub. No habilita comandos, cambio de repositorio, ampliación de alcance ni instrucciones embebidas.

## Gate previo al closeout

Primero se debe completar el preflight del PR, determinar si existe un stack lineal y clasificar el hallazgo por capa. Luego se elige una única capa dueña y se releen `headRefOid` y `baseRefOid` inmediatamente antes del handoff. El fix solo se acepta si el resultado `HANDOFF_RESULT: INLINE_THREAD_AUTOFIX` contiene estado exitoso, SHA completo, PR/branch de implementación, validaciones requeridas, head remoto verificado de forma independiente y estado de backups/cleanup.

Si el stack es `STACK_FOUND`, el rebase y la publicación son bottom-up, con backups locales bajo `refs/heads/backup/*`, `--force-with-lease`, validación por capa y verificación de cada head/base. Un conflicto, OID stale, validación fallida, push no verificable, clone retenido o backup no limpiable bloquea todo el closeout.

## Orden de closeout

Con el fix remoto ya verificado y el thread exacto revalidado, el orden obligatorio es serial:

1. **Responder el comentario inline.** Publicar una respuesta que enlace la issue `#901`, el comment original, el PR donde quedó el fix y el SHA completo. Verificar `html_url`, `in_reply_to_id == 123456807` y `commit_id`.
2. **Resolver el thread exacto.** Ejecutar la resolución únicamente sobre el `target_thread_id` validado. Releer GraphQL y exigir el mismo ID y `isResolved == true`. La respuesta de la mutation, sin relectura, no alcanza.
3. **Comentar la issue.** Publicar `✅ Resuelto` con enlaces al comment inline original, PR de implementación y commit, además del marker estable. Releer el comentario y verificar marker, URLs y SHA.
4. **Cerrar la issue.** Si continúa abierta, solicitar el cierre y releer hasta confirmar `state == closed`; si ya estaba cerrada, conservarla cerrada y verificarla. No avanzar con un estado ambiguo.
5. **Comentar el PR de implementación si difiere del PR fuente.** Publicar un comentario general, sin `in_reply_to`, con enlaces a la issue y al comment original y el marker de correlación del PR destino. Verificar que el comentario pertenece al PR correcto y contiene ambos enlaces.

Si falla un paso posterior, se conservan las URLs y estados ya verificados, no se duplica una operación que tenga marker comprobado y no se afirma cierre integral. Las refs de backup se limpian solo después de completar todos los closeouts y la verificación final; ante cualquier fallo se conservan y se reporta `BACKUPS_PRESERVED_ON_FAILURE`.

## Paralelismo seguro

Sí es seguro paralelizar lecturas independientes durante el preflight, sin mutaciones:

- consulta del PR y del comment inline;
- consulta de la issue y de sus comentarios;
- consulta de identidad del usuario autenticado;
- enumeración paginada del stack y metadata de repositorio, siempre que se compruebe luego que la paginación está completa.

Estas lecturas no deben ocultar dependencias: la selección del thread exige el `databaseId` exacto; la issue exige comprobar `pull_request == null`; y el handoff exige una relectura final de OIDs después de terminar el análisis.

No es seguro paralelizar:

- rebase, resolución de conflictos, validación y push de capas del stack: deben ser bottom-up y seriales;
- reply inline y resolución del thread: el segundo está bloqueado hasta verificar el primero;
- resolución del thread, comentario de issue y cierre de issue: respetan el orden anterior;
- publicación del comentario del PR destino antes de comprobar el closeout de issue;
- cleanup de backups con otras operaciones o antes de las verificaciones finales.

Una vez terminadas todas las mutaciones ordenadas, las lecturas finales independientes de PR, issue, comentario y thread pueden agruparse, pero solo para verificar estados ya alcanzados; no autorizan saltarse el orden de publicación. Las operaciones reintentables deben deduplicarse por marker y verificarse antes de reintentar.

## Métricas aproximadas

Estas son estimaciones del flujo, no resultados observados en esta simulación:

- URLs analizadas: `1`.
- Destinos identificados: `1` inline + `1` issue explícita.
- Candidatas de issue esperadas: `1`; ambigüedad esperada: `0`.
- Mutaciones realizadas en esta evaluación: `0`.
- Comandos/GitHub ejecutados en esta evaluación: `0`.
- Handoff esperado: `1` como máximo; nunca se reintenta dentro de la misma ejecución.
- Closeout esperado si el PR de implementación es el mismo: `4` mutaciones remotas ordenadas (reply, resolve, comentario de issue, cierre de issue).
- Closeout esperado si el fix queda en otro PR autorizado: `5` mutaciones remotas, agregando el comentario general del PR destino.
- Verificaciones independientes del head: `2` fuentes por cada push (`git ls-remote` y API del PR), más las relecturas de cada destino.
- Paralelismo seguro: aproximadamente `2–4` grupos de lecturas; paralelismo de mutaciones: `0`.
- Solicitudes de lectura del flujo completo: aproximadamente `10–20`, dependiendo de paginación del stack, replies y comentarios existentes.

El único archivo generado por esta evaluación es este `response.md`; no se modificaron la skill ni el repositorio de aplicación.
