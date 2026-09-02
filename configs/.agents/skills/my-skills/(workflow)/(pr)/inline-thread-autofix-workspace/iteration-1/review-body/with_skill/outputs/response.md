## Simulación read-only

La URL cumple la forma permitida para un review body:

`https://github.com/acme/widgets/pull/42#pullrequestreview-987654321`

El parseo local produciría `source=review_body`, `owner=acme`, `repo=widgets`, `pullRequestNumber=42` y `reviewId=987654321`. No ejecuté comandos ni llamadas a GitHub por la restricción de esta evaluación; por tanto no afirmo que el PR, la review, el repositorio, la rama, el finding ni los permisos existan. No se aplicó fix, no se validó código, no se creó commit, no se hizo push y no se publicó ni editó nada.

## Flujo operativo y gates

1. **Gate de entrada:** validar host exacto, path, fragmento exacto e IDs positivos. Si falla, detener antes de GitHub.
2. **Snapshot read-only, en paralelo:** consultar identidad (`user`), metadata del PR (`pr view`), PR directo (`pulls/42`), default branch (`repo view`), grafo completo de PRs paginado (`pulls?state=all`), review (`pulls/42/reviews/987654321`) y comentarios del PR paginados (`pulls/42/comments`). Los hijos con `pull_request_review_id=987654321` solo se reconocen para duplicados; no se procesan como comentarios inline ni se mutan.
3. **Barrera de snapshot:** exigir identidad exacta de la review (`id`, `node_id`, `pull_request_url`, `html_url`, autor, body no vacío y estado publicado) y que el body contenga un anchor inequívoco: path, símbolo, expresión o comportamiento. En caso contrario, detener con `FINDING_ANCHOR_AMBIGUOUS` u otro código específico, sin handoff.
4. **Issue opcional, sin inferencias:** si el body contiene una referencia explícita, única y válida a una issue del mismo repositorio, consultar la issue y sus comentarios en paralelo y verificar que no sea un pull request. Si hay cero referencias cuando la issue es requerida, varias o una referencia inválida, detener con `ISSUE_REFERENCE_MISSING`, `ISSUE_REFERENCE_AMBIGUOUS` o `ISSUE_REFERENCE_INVALID`; nunca deducirla por título, labels o similitud.
5. **Stack/ownership:** comparar OIDs, repositorios y ramas de toda la cadena. Clasificar el finding (`INTRODUCED`, `CARRIED`, `FIXED`, `UNRELATED` o `UNKNOWN`) y elegir la primera capa que introduce el defecto. Si la capa dueña no es el PR indicado, detener con `NEEDS_SCOPE_CONFIRMATION`; si el PR fuente está cerrado, solo usar una alternativa abierta, inequívoca y de la misma cadena. Más de una alternativa produce `IMPLEMENTATION_TARGET_AMBIGUOUS`.
6. **Gate de stale state:** releer inmediatamente head/base y la entidad objetivo antes del handoff. Si cambió cualquier OID relacionado, detener con `TARGET_STALE` y rehacer el análisis; no parchear evidencia vieja.
7. **Único handoff:** invocar exactamente una vez a `$fix-in-ephemeral-clone` con `HANDOFF: INLINE_THREAD_AUTOFIX`, incluyendo URL original canónica, PR/rama de implementación, OIDs esperados, anchor, resumen sanitizado, criterios de aceptación, plan de stack bottom-up e issue validada o `none`. El executor trabaja solo en un clone depth-1 efímero; no se edita el checkout actual.
8. **Validación del executor:** ejecutar diff check, lint, typecheck, tests focales y globales y build disponibles, usando comandos reales del repositorio. Revisar que `.env*` y `node_modules` no se commiteen. Commitear con mensaje conciso terminado en `Co-Authored-By: Claude <noreply@anthropic.com>`, refrescar/rebasear de forma segura y pushear solo ramas autorizadas. Un conflicto, validación fallida, `TARGET_STALE`, clone retenido o backup preservado bloquea el closeout.
9. **Gate pre-mutation:** verificar el `HANDOFF_RESULT`, el commit completo y el head remoto; releer la review justo antes de mutarla. Si el backend no devuelve éxito verificable, no publicar nada.

## Mutaciones seriales de closeout

- **Primera opción:** editar la review mediante PUT, agregando al body original completo el separador y el bloque de `Review body editada`, incluyendo link al SHA corto, `### Qué cambió` y marker `<!-- inline-thread-autofix: review:987654321 -->`. Nunca reemplazar ni normalizar el body original. Verificar body preservado, marker y SHA.
- **Fallback:** solo si el PUT devuelve un `403`, `405` o `422` definitivo y, tras releer, el marker no existe, publicar un comentario general en `issues/42/comments` enlazando `#pullrequestreview-987654321`, con el mismo bloque y marker. No usar fallback para timeout, red, `404`, `5xx` o resultado ambiguo.
- No llamar `resolveReviewThread`, no crear reply `in_reply_to` y no usar la palabra `Resuelto`: este destino es un review body, no un thread inline.
- Ejecutar una sola de las dos publicaciones anteriores; son mutaciones alternativas y seriales. Luego verificar independientemente head remoto, body o comentario, URLs, SHA y ausencia de duplicados. El cleanup de backups es el último paso local y solo puede reportar `BACKUPS_CLEANED` tras verificar OIDs y worktrees.

## Barreras y métricas aproximadas

- Llamadas externas simuladas: **7 familias read-only** en el snapshot; la paginación puede añadir requests HTTP. Si corresponde issue: **2 familias read-only** adicionales en paralelo.
- Delegación: **1 handoff** a `fix-in-ephemeral-clone`; sus comandos locales no fueron ejecutados en esta evaluación.
- Mutaciones GitHub: **1 PUT** de review, o **1 POST** de fallback, nunca ambas; en esta evaluación: **0**.
- Verificación final: aproximadamente **3–5 lecturas paralelas** y una barrera; cleanup local posterior, sin borrar ni alterar recursos en modo read-only.
- Barreras principales: **3** (snapshot, resultado del executor y verificación final), o **4** si se valida una issue por separado.

Estado de esta evaluación: **detenido de forma segura antes del preflight remoto y antes de cualquier mutation**. No sería válido emitir `Fix aplicado`, reportar validaciones exitosas, commit, push, review actualizada o fallback publicado sin esa evidencia.