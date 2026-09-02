# Simulación read-only: inline thread y issue closeout

## Resultado de la validación de la entrada

La URL tiene el formato inline admitido por la skill:

- repositorio: `acme/widgets`
- PR fuente: `#42`
- comentario objetivo: `discussion_r123456807`
- host: `github.com`

El body contiene una sola referencia explícita y canónica a `https://github.com/acme/widgets/issues/901`. La referencia candidata se normaliza como `acme/widgets#901`, pero no se considera validada solamente por aparecer en el texto.

Antes de mutar cualquier destino, el flujo real debe leer el issue y sus comentarios y comprobar conjuntamente:

1. `number == 901`.
2. `html_url == https://github.com/acme/widgets/issues/901`.
3. `repository_url` pertenece exactamente a `acme/widgets`.
4. La respuesta representa un issue y no una pull request (`pull_request == null`).
5. `state` y `title` fueron leídos; si ya está cerrado, nunca se lo reabre.
6. No existe un comentario de closeout verificable con el marker `inline-thread-autofix: issue:acme/widgets#901:comment:123456807`.

La misma identidad estricta aplica al comentario: el comentario REST debe corresponder al `databaseId == 123456807` de exactamente un nodo GraphQL `ReviewThread`. También deben quedar capturados body, path, rango, side, commit de origen y estado del thread. No se debe elegir el thread por posición, review ID, PR ID o proximidad. `isOutdated` se evalúa, pero no invalida automáticamente el hallazgo.

En esta evaluación no se hicieron llamadas a GitHub, por lo que no puedo afirmar que `#901` exista, que pertenezca al repositorio, que el thread siga abierto, que haya ownership inequívoco ni que el fix haya sido aplicado. La salida correcta de la simulación es describir esas precondiciones, no declarar un cierre exitoso.

## Flujo del fix validado

Si el snapshot read-only confirma el PR, el ownership de la capa y la referencia del issue, `inline-thread-autofix` debe delegar una sola vez a `fix-in-ephemeral-clone`. El handoff debe llevar, entre otros datos, el PR/branch destino, `expected_head_oid`, `expected_base_oid`, el ancla del comentario, los criterios de aceptación, el issue validado y el plan de stack.

El closeout queda bloqueado hasta recibir un `HANDOFF_RESULT` completo con:

- commit SHA completo;
- head remoto coincidente con ese SHA;
- diff, typecheck, lint, tests focales/globales y build disponibles exitosos;
- estado de backups explícito;
- clone eliminado, o una señal de fallo que bloquee el cierre.

Un `TARGET_STALE`, validación fallida, clone retenido, backup preservado o resultado incompleto detiene el flujo y no permite responder, resolver ni cerrar el issue. Si existe un stack, el rebase de descendants es bottom-up, con backups scoped y `--force-with-lease`; no se paralelizan rebases o pushes dependientes ni se usan recuperaciones destructivas.

## Orden de closeout para todos los destinos

Asumiendo que el handoff ya devolvió éxito y que una relectura confirma que el SHA sigue siendo el head de la PR de implementación:

1. **Releer el target inmediatamente antes de mutar.** Confirmar PR, branch, repo, head/base OID, permisos y ausencia de closeout duplicado. Un cambio de OID produce `TARGET_STALE`.
2. **Responder el comentario inline.** Crear un reply en el endpoint de comments con `in_reply_to == 123456807`. El body debe estar en español, enlazar el comentario original, el issue `#901` y el commit final, e incluir `### Qué cambió`. No usar `Resuelto` antes de verificar el reply y la resolución.
3. **Verificar el reply.** Comprobar `html_url`, `in_reply_to_id == 123456807` y que el body contiene el link al SHA final. La metadata `commit_id` heredada del ancla no justifica duplicar el reply si el body enlaza el SHA nuevo.
4. **Resolver únicamente el thread exacto.** Llamar a `resolveReviewThread` con el `target_thread_id` derivado del comentario, nunca con un ID inferido. Releer GraphQL y exigir el mismo ID, `isResolved == true`, el `isOutdated` esperado y ausencia de cambios en threads ajenos.
5. **Publicar el comentario del issue.** Solo después de verificar reply y thread, publicar en `acme/widgets#901` un comentario con el PR de implementación, SHA completo, URL del comentario original, resumen de `Qué cambió` y el marker estable `inline-thread-autofix: issue:acme/widgets#901:comment:123456807`. Releer y verificar URLs, marker y SHA.
6. **Completar el destino PR alternativo, si aplica.** Si `implementation_pr != 42`, publicar además un comentario general en `issues/<implementation_pr>/comments`, sin `in_reply_to`, que enlace el PR de implementación, el issue y el comentario original, con el marker `pr:<implementation_pr>:issue:901:comment:123456807`. Verificar que `html_url` pertenece a esa PR. Si la implementación ocurrió en `#42`, este destino no existe y no se agrega comentario redundante.
7. **Cerrar el issue al final.** Solo después de verificar el comentario del issue (y el comentario de PR alternativo, cuando corresponda), ejecutar el PATCH de estado a `closed` si todavía está abierto. Releer y exigir `state == closed`; nunca reabrirlo ni afirmar cierre si el PATCH o la relectura fallan.
8. **Verificar el estado integral y limpiar al último.** Releer de forma independiente head remoto/API de cada PR, reply por `in_reply_to`, thread exacto, markers y URLs de issue/PR alternativo, estado del issue y la cadena `PR destino → issue → comment`. El cleanup de `backup/*` es el último paso local y solo puede reportar `BACKUPS_CLEANED` si las refs propias desaparecieron con el OID esperado y las preexistentes permanecieron intactas.

Si falla cualquier etapa posterior, se conservan las publicaciones ya verificadas y los backups necesarios, se informa el destino pendiente y no se utiliza la salida de éxito integral. Si un marker o reply ya está verificado, se continúa desde el primer destino faltante sin duplicar mutaciones.

## Paralelismo seguro

- **Snapshot inicial:** después de validar la URL localmente, pueden ejecutarse en paralelo las lecturas independientes de usuario autenticado, metadata/direct API de la PR, repositorio/default branch, grafo paginado de PRs, comentario REST y `reviewThreads`. La barrera de snapshot debe preceder al análisis de ownership, stack y finding.
- **Issue asociada:** una vez extraída la única URL explícita, la lectura del issue y la búsqueda de sus comentarios/markers son independientes y pueden formar otra fan-out read-only; ambas deben completarse antes de seleccionar closeout.
- **Closeout posterior a la resolución:** tras confirmar `isResolved == true`, el comentario del issue y el comentario general de la PR de implementación alternativa son destinos independientes y pueden publicarse en paralelo. Si uno falla, no se cierra el issue.
- **Verificación final:** las relecturas independientes de heads, reply, thread, markers, URLs y estado pueden ejecutarse en paralelo, pero todas deben terminar antes del cleanup local.

No deben paralelizarse el reply y la resolución (la resolución depende del reply verificado), ningún comentario y el PATCH de cierre del issue, rebases/pushes de capas dependientes, ni comandos que escriban el mismo checkout. El cleanup de backups siempre queda fuera de las fan-outs y al final de la transacción.

## Estado de esta simulación

No se ejecutaron comandos, GitHub API, clone, fix, commit, push ni mutaciones de comentarios/thread/issue. Por tanto, no corresponde afirmar `Fix aplicado`, `Thread: resuelto` ni `Issue: resuelta y cerrada`; esos estados solo serían válidos después de todas las verificaciones anteriores.

## Métricas aproximadas

Son estimaciones del flujo, no métricas observadas en ejecución:

- **Lecturas iniciales:** aproximadamente 9 consultas read-only mínimas: 5 comunes (usuario, metadata de PR, API directa de PR, repositorio y grafo paginado), 2 del destino inline (comentario y threads) y 2 de la issue (issue y comentarios/markers), más relecturas de frescura y closeout.
- **Mutaciones mínimas:** 4 si la implementación queda en `#42` (reply, resolve, comentario de issue y cierre); 5 si hay una PR de implementación alternativa (se suma su comentario general).
- **Ventanas de paralelismo:** hasta 6–7 lecturas independientes en el snapshot, 2 publicaciones independientes después de resolver el thread cuando aplica PR alternativa y unas 4–6 verificaciones finales independientes.
- **Barreras de dependencia principales:** aproximadamente 7–8 rondas: parseo, snapshot, validación de issue/ownership, handoff validado, reply, resolución, comentarios paralelos, cierre y verificación/cleanup.
- **Criterio de éxito:** 0 destinos pendientes, SHA remoto verificado, thread exacto resuelto, issue en `closed`, markers y URLs canónicas comprobados y backups limpiados de forma condicional.
