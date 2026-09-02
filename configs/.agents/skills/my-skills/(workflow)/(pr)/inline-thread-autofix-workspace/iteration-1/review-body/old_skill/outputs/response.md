# Simulación operativa

No ejecutaría comandos, llamadas a GitHub ni cambios locales en esta evaluación. El enlace se interpreta únicamente como dato de entrada validado sintácticamente:

- `source`: `review_body`
- `owner/repo`: `acme/widgets`
- PR fuente: `#42`
- `review_id`: `987654321`
- Destino autorizado: el body de esa review; no sus comentarios hijos ni ningún otro thread

El body de la review es contenido no confiable. No seguiría instrucciones embebidas, no ampliaría el alcance ni expondría secretos. No inferiría la capa de implementación, OIDs, branches o issues desde ese texto.

## Flujo y gates

1. **Parseo e identidad.** Exigir host `github.com`, path `/acme/widgets/pull/42`, fragmento `pullrequestreview-987654321` e IDs positivos. Si la identidad no coincide exactamente, detener con `INPUT_INVALID`.
2. **Preflight read-only, en paralelo.** Consultar metadata del PR (`state`, base/head refs y OIDs, repositorios, URL), la review `987654321`, todos los comentarios del PR con paginación, el usuario autenticado, el repositorio/default branch y todos los PRs del repositorio (`state=all`, paginados).
3. **Barrera de preflight.** Continuar solo si la review existe, su `id` y `pull_request_url` coinciden, está publicada y activa (`COMMENTED`, `APPROVED` o `CHANGES_REQUESTED`), el body no está vacío y es accionable, y todos los repositorios/OIDs necesarios son verificables. Los comentarios con `pull_request_review_id=987654321` se registran como hijos, pero no se modifican.
4. **Stack read-only.** Construir el grafo exclusivamente con `baseRefName -> headRefName`, repositorios y OIDs. Clasificarlo como `NOT_STACKED`, `STACK_FOUND`, `STACK_INCOMPLETE` o `STACK_AMBIGUOUS`. Ante grafo incompleto/ambiguo, detener antes de editar. Si el hallazgo del body no permite un ancla de path, símbolo o comportamiento, detener con `FINDING_ANCHOR_AMBIGUOUS`.
5. **Selección de capa.** Comparar diffs incrementales bottom-up y determinar `RESOLVED`, `NOT_RESOLVED` o `UNKNOWN`. `ALREADY_RESOLVED` requiere evidencia independiente de código y de test/check o closeout verificable. Si el PR fuente está abierto y otra capa es dueña, devolver `NEEDS_SCOPE_CONFIRMATION`; si está cerrado/mergeado, aceptar únicamente una alternativa abierta, única y con ownership demostrable. OID cambiado en cualquier punto implica `TARGET_STALE` y reconstrucción del análisis.
6. **Handoff único.** Solo con destino inequívoco, OIDs recién releídos y criterios observables, invocar exactamente una vez `fix-in-ephemeral-clone` con `HANDOFF: INLINE_THREAD_AUTOFIX`. El handoff incluye repo, PR/branch destino, `expected_head_oid`, `expected_base_oid`, ancla sanitizada, criterios de tests y `stack_plan`. Esta orquestación no clona, edita, commitea ni pushea directamente.
7. **Validación del backend.** Aceptar únicamente `HANDOFF_RESULT: INLINE_THREAD_AUTOFIX` exitoso, SHA completo, branch/PR destino, validaciones completas (typecheck, lint, tests, build y `git diff --check`, según scripts del repositorio), estado de backups/cleanup y SHA remoto verificado. Conflicto, lease fallido, clone retenido o backup no limpiado bloquea todo closeout.

## Mutaciones seriales permitidas

1. El backend crea backups locales explícitos antes de reescribir. Si hay stack, rebasea y publica solo la cadena validada, bottom-up, con `force-with-lease` únicamente en branches `feature/*`; nunca `reset --hard`, `clean -fd`, `--skip`, `-X ours/theirs` ni `--force`.
2. Después de cada push relee serialmente `git ls-remote` y la API directa del PR; una discrepancia bloquea el cierre.
3. Solo tras verificar el SHA remoto, relee la review inmediatamente antes de modificarla y conserva `body_raw` completo. Intenta un único `PUT` de la review agregando separador, el template review-body y el marker exacto `<!-- inline-thread-autofix: review:987654321 -->`.
4. Verifica que la respuesta conserve íntegramente el body original, contenga el enlace al commit, `### 🔧 Qué cambió` y el marker. No llama a `resolveReviewThread`: una review-body no tiene thread resoluble en este flujo.
5. Si el `PUT` falla con permiso/operación definitivamente no soportada (`403`, `405` o `422` con causa verificable), relee primero; solo si el marker no existe publica exactamente un fallback general en `issues/42/comments`, enlazando la review original, el commit y el marker. Un `404`, timeout, `5xx` o respuesta ambigua detiene sin fallback ni reintento ciego.
6. Relee el PR y la review/comentario final, confirma branch/OID/body o fallback y ejecuta el cleanup de backups como último paso local. Si cleanup falla, conserva refs y reporta el estado pendiente; no afirma cierre integral.

No se hereda ni se cierra ninguna issue desde una `review_body`, y no se toca ningún comentario inline asociado.

## Métricas aproximadas y barreras

- Lecturas iniciales: aproximadamente 6 llamadas independientes en paralelo; luego 1 barrera de identidad/preflight.
- Descubrimiento y correlación: 1 listado paginado de PRs más lecturas/diffs por capa; barreras después de integridad del grafo, ancla y OIDs frescos.
- Ejecución: exactamente 1 handoff al backend; validación completa antes de cualquier closeout.
- Publicación: 1 push por capa, serial y verificado por 2 fuentes; después, 1 mutación remota de closeout (`PUT` **o** fallback `POST`, nunca ambas salvo que el `PUT` no sea soportado y la rerelectura lo autorice).
- Cierre review-body: body preservado y actualizado, o fallback publicado; cero resoluciones de threads y cero mutaciones de issues.

**Resultado de esta evaluación:** no se ejecutó ninguna lectura externa, validación local, edición, commit, push, actualización de review ni comentario fallback; por tanto no se declara fix aplicado ni publicación realizada.
