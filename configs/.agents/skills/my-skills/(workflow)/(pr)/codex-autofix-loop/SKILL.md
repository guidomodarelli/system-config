---
name: codex-autofix-loop
description: "Relanzar y operar el loop local (vía Claude Code) que auto-fixea comentarios de Codex (chatgpt-codex-connector[bot]) en un PR: clone efímero → fix → push → closeout del hilo, con dedup por PR y guard de auto-cancelación. Use when the user asks to relaunch/start the Codex auto-fix loop for a PR, set up Codex comment auto-fixing, or mentions docs/codex-autofix-loop.md, processed-PR.json, or the codex-autofix workflow."
---

# Codex auto-fix loop (local, vía Claude Code)

Loop local que escucha comentarios de **Codex** (`chatgpt-codex-connector[bot]`)
en un PR y **spawnea subagentes en paralelo** (uno por GRUPO de archivo, en lotes
de `{{MAX_PARALLEL}}`) que delegan el fix en la skill
[`fix-in-ephemeral-clone`](../(git)/fix-in-ephemeral-clone/SKILL.md) —invocada vía
la herramienta `Skill` (`/fix-in-ephemeral-clone`)— tratando cada comentario
como la "issue" a resolver (clone efímero depth-1 → fix → validar → push a la rama
del PR). Cada subagente trabaja en su propio clone efímero aislado; como todos
pushean a la misma rama, ante non-fast-forward cada subagente reintegra (rebase
+ resolución de conflictos + revalidación del fix propio y de los cambios
integrados de los otros subagentes) y recién ahí pushea, repitiendo el ciclo
hasta subir.
Después el loop principal hace el closeout en el hilo (reacción 👍 + reply con link
al commit + resolver el hilo inline).

Cubre **tres fuentes** de comentarios de Codex:
1. **Inline** (`pulls/{pr}/comments`): atados a un `path` + `line`; closeout = 👍 + reply en el hilo + resolver el hilo.
2. **Generales** (`issues/{pr}/comments`): comentarios sueltos del PR; closeout = 👍 + reply.
3. **Review-body de primer nivel** (`pulls/{pr}/reviews`, anchor `#pullrequestreview-…`): el resumen que Codex postea al enviar una review. Se procesa **solo cuando el body trae una sugerencia accionable real** (no un mero resumen). Closeout = 👍 + **quote reply** (citando el body). Cuando el review-body **y todos sus comments inline** quedan resueltos, se **minimiza la review con estado `RESOLVED`** (queda oculta/colapsada). `PullRequestReview` implementa `Reactable` y `Minimizable`, así que reacción y minimize van por GraphQL sobre su `node_id`.

> **Por qué delegar en `fix-in-ephemeral-clone`:** esa skill es la dueña del
> contrato de aislamiento (clone efímero, copia de `.env*`, deps por plataforma,
> rebase pre-push, push con retry, cleanup). Este loop NO reimplementa ese flujo:
> solo arma el input (comentarios agrupados por archivo → issue), spawnea un
> subagente por grupo (en lotes de `{{MAX_PARALLEL}}`) que la invoca en paralelo, y
> hace el closeout. Cualquier cambio al mecanismo de clone/fix/push vive en esa skill.

> Es un complemento del workflow de CI `.github/workflows/codex-autofix.yml`.
> El **Action** es la persistencia real 24/7 (webhook, sin sesión). Este **loop local**
> corre solo mientras Claude Code está abierto (el cron es de sesión: `durable: true`
> no se persiste en este entorno, así que el job muere al cerrar Claude).

## Cómo relanzarlo (cualquier PR)

1. Reemplazá los placeholders del prompt de abajo (`{{OWNER}}`, `{{REPO}}`,
   `{{PR}}`, `{{BRANCH}}`) por los del PR objetivo.
2. Inicializá el estado de dedup del PR (vacío procesa todo el backlog; con ids
   ya cargados procesa solo los nuevos):
   ```
   .codex-autofix/processed-{{PR}}.json  ->  {"pr":{{PR}},"processedCommentIds":[]}
   ```
   (`.codex-autofix/` está gitignored: es estado de runtime, no se commitea.)
3. Lanzá el loop pegando el prompt con el intervalo `{{INTERVAL}}`:
   ```
   /loop {{INTERVAL}} <pegá acá el prompt ya completado>
   ```
   O, más simple, decile a Claude: «relanzá el loop de Codex para el PR {{PR}}
   usando el skill codex-autofix-loop» y completa la plantilla por vos.

> **Variables globales del loop** (única fuente de verdad — cambiá SOLO estos
> números y se propagan a todo el documento):
> - `{{INTERVAL_MIN}}` = `8` — minutos entre corridas.
> - `{{MAX_PARALLEL}}` = `4` — máximo de subagentes (grupos de archivo) corriendo a
>   la vez. Cada subagente es un clone efímero + install + tests, así que este cap
>   evita fundir disco/CPU; los grupos restantes se procesan en lotes sucesivos.
>
> Derivados (no los edites a mano; salen de `{{INTERVAL_MIN}}`):
> - `{{INTERVAL}}` = `{{INTERVAL_MIN}}m` (= `8m`) — intervalo de `/loop`.
> - `{{CRON}}` = `*/{{INTERVAL_MIN}} * * * *` (= `*/8 * * * *`) — cron equivalente
>   para identificar el job en `CronList`.

El intervalo es session-only: si cerrás Claude, hay que relanzarlo. El loop se
**auto-cancela** en dos casos: (a) cuando el PR deja de estar `OPEN`
(mergeado/cerrado/borrado), o (b) cuando Codex responde con una **review limpia**
("Codex Review: Didn't find any major issues") para el head actual y no quedan
ítems pendientes — ahí el loop **mergea el PR** y se corta solo.

## Prompt (plantilla parametrizable)

```text
Loop de auto-fix de comentarios de Codex en el PR #{{PR}} de {{OWNER}}/{{REPO}} (rama {{BRANCH}}).

GUARD DE AUTO-CANCELACIÓN (hacelo SIEMPRE primero). Obtené el estado del PR:
  estado=$(gh pr view {{PR}} --repo {{OWNER}}/{{REPO}} --json state -q .state 2>/dev/null)
- "OPEN" -> seguí. - "MERGED"/"CLOSED" -> auto-cancelá. - vacío/falla (404 PR o repo borrado) -> confirmá una vez con `gh api repos/{{OWNER}}/{{REPO}}/pulls/{{PR}} --jq .state 2>&1`; si vuelve a fallar o "closed", auto-cancelá; si "open", seguí (error transitorio).
Auto-cancelar = CronList, identificá el job de ESTE loop (cron `{{CRON}}`, auto-fix de Codex en PR #{{PR}}), borralo con CronDelete por id, PushNotification de una línea avisando el motivo, y terminá sin procesar.

Si OPEN, procesá:
(1) Leé processedCommentIds desde .codex-autofix/processed-{{PR}}.json. Los ids de comentarios (inline/generales) se guardan como número crudo; los ids de review-body se guardan namespaceados como `"review:<id>"` (evita colisión entre espacios de id distintos).

(2) Traé comentarios de chatgpt-codex-connector[bot] de las TRES fuentes:
   - inline: `gh api repos/{{OWNER}}/{{REPO}}/pulls/{{PR}}/comments --paginate` (cada uno trae `id`, `path`, `line`, `body` y `pull_request_review_id` = review padre).
   - generales: `gh api repos/{{OWNER}}/{{REPO}}/issues/{{PR}}/comments --paginate`.
   - review-bodies: `gh api repos/{{OWNER}}/{{REPO}}/pulls/{{PR}}/reviews --paginate --jq '[.[] | select(.user.login=="chatgpt-codex-connector[bot]") | {id, node_id, body, state}]'`.

(2-bis) RE-DISPARO de un `@codex review` que el bot no leyó. Codex reacciona con 👀 (eyes) sobre el comentario apenas lo recibe; si el ÚLTIMO comentario general del PR es un `@codex review` y NO tiene esa reacción 👀 del bot, el trigger se cayó (Codex nunca lo tomó) → reposteá uno nuevo para que arranque la review.
   - Último comentario general (vienen ascendentes por fecha, `last` = el más nuevo): `LAST=$(gh api repos/{{OWNER}}/{{REPO}}/issues/{{PR}}/comments --paginate --jq 'last // empty')`. Si está vacío, salteá este paso.
   - `LAST_ID=$(printf '%s' "$LAST" | jq -r '.id'); LAST_BODY=$(printf '%s' "$LAST" | jq -r '.body')`.
   - Seguí SOLO si `LAST_BODY` es un trigger de review (matchea `^@codex review`); si no, salteá (el último comentario no es un trigger pendiente).
   - Reacción 👀 del bot sobre ese comentario: `HAS_EYES=$(gh api repos/{{OWNER}}/{{REPO}}/issues/comments/$LAST_ID/reactions --jq '[.[] | select(.content=="eyes" and .user.login=="chatgpt-codex-connector[bot]")] | length')`.
   - Si `HAS_EYES == 0` (sin ojitos del bot): reposteá el trigger → `gh pr comment {{PR}} --repo {{OWNER}}/{{REPO}} --body "@codex review"`. Si `HAS_EYES >= 1`, NO hagas nada: Codex ya lo está procesando.
   - Para no duplicar el trigger: si en ESTA misma vuelta vas a fixear ítems nuevos (vas a postear `@codex review` en el paso (6)), salteá el repost acá; ese paso ya re-dispara la review.

(3) FAN-OUT EN PARALELO (por GRUPO de archivo, con cap de concurrencia).

(3a) ARMÁ LOS GRUPOS DE TRABAJO. Tomá los ítems accionables (los que NO están en processedCommentIds; para review-bodies, además, pasá el filtro de accionabilidad de (3b)) y agrupalos así, porque dos fixes sobre el MISMO archivo/zona en clones paralelos se pisan o explotan en el rebase:
   - Los **inline** se agrupan por `path`; si dos inline del mismo `path` tienen `line` solapadas o cercanas, van en el MISMO grupo igual.
   - Cada **general** y cada **review-body accionable** es su propio grupo (no tienen `path`; asumí que pueden tocar cualquier archivo, así que no los mezcles con otros).
   - Un grupo = la unidad que toma UN subagente. Dentro del grupo, el subagente resuelve sus comentarios **secuencialmente en el mismo clone** (un solo push al final). Entre grupos de archivos DISJUNTOS sí hay paralelismo.

(3b) ACCIONABILIDAD DE REVIEW-BODIES (antes de agrupar/spawnear, la decide el LOOP PRINCIPAL). Evaluá si el body trae una **sugerencia accionable real** (un cambio concreto de código). Si es solo un resumen/observación no accionable ("revisé X, ver inline", aprobación, etc.), SALTEALO: no lo metas en ningún grupo, no reacciones, no respondas y NO lo marques como procesado (no ensucia el estado; igual entra en el paso de minimize si corresponde).

(3c) SPAWNEÁ EN LOTES DE `{{MAX_PARALLEL}}`. Lanzá hasta `{{MAX_PARALLEL}}` subagentes a la vez (herramienta `Agent`/`Task`, varios tool-uses en un mismo mensaje); cuando un grupo termina, arrancá el siguiente, hasta agotar la cola. **Etiquetá cada subagente con los comment ids de su grupo** (label), para mapear sin ambigüedad resultado→comentarios al cerrar. Cada subagente:
   - Recibe en su prompt el **path absoluto al `SKILL.md` de `fix-in-ephemeral-clone`** como fuente de verdad del flujo de aislamiento (que lo lea), además de intentar invocarla por nombre vía la herramienta `Skill` (`/fix-in-ephemeral-clone`). NO reimplementa el clone/push a mano.
   - Recibe como "issue(s)" el contexto de los comentarios de su grupo: cuerpo, `path` y `line` (inline) o solo el body (general/review-body), y la rama objetivo {{BRANCH}}.
   - Vía esa skill, hace el clone efímero depth-1, copia `.env*`, instala/linkea deps según plataforma, aplica el/los fix(es) de su grupo, valida, rebasea sobre el último remoto y pushea a {{BRANCH}}, y limpia el clone.

   **Push concurrente**: como varios subagentes pushean a la MISMA rama, ante un rechazo por non-fast-forward el subagente NO repushea a ciegas: corre un ciclo completo de re-integración —re-fetch → rebase sobre el nuevo remoto → resolver conflictos → revalidar que TANTO el fix recién hecho COMO los cambios que integró de los otros subagentes (fixes de otros comentarios que ya cayeron a la rama) siguen pasando sobre la nueva base → recién ahí pushea; si vuelve a rebotar, repite el ciclo entero hasta subir— (esa lógica vive en `fix-in-ephemeral-clone`, paso 9). Cada subagente DEVUELVE el sha COMPLETO del commit pusheado en éxito (uno por grupo), o un fallo explícito + el path del clone que quedó para inspección. Recogé los resultados; por cada comentario fixeado guardá su sha (para el closeout) y sumá 1 al contador de ítems fixeados esta vuelta.

(4) CLOSEOUT en ÉXITO (push hecho). Hacelo por cada comentario cuyo subagente volvió con éxito, usando el sha que ese subagente reportó (no esperes a que terminen todos: a medida que vuelven, cerrás). Las acciones de closeout en GitHub (reacciones, replies, resolver hilos) son independientes por comentario; el ÚNICO recurso compartido es `.codex-autofix/processed-{{PR}}.json`, así que el loop principal es el único escritor y serializa esas escrituras (paso d) para no corromper el JSON cuando varios subagentes terminan casi a la vez. Definí el link al commit: COMMIT_URL=https://github.com/{{OWNER}}/{{REPO}}/commit/<sha>
   a. Reacción 👍:
      - INLINE: `gh api -X POST repos/{{OWNER}}/{{REPO}}/pulls/comments/<id>/reactions -f content=+1`.
      - GENERAL: `gh api -X POST repos/{{OWNER}}/{{REPO}}/issues/comments/<id>/reactions -f content=+1`.
      - REVIEW-BODY (no hay endpoint REST de reactions para reviews; va por GraphQL sobre el `node_id` de la review): `gh api graphql -f query='mutation($id:ID!){addReaction(input:{subjectId:$id,content:THUMBS_UP}){reaction{content}}}' -F id="<review_node_id>"`.
   b. Reply con el **template de cierre** (ver «Plantilla de comentario de cierre» abajo). Definí `<resumen>` = UNA línea de qué cambió y su efecto, y usá el sha corto de 7 chars como texto del link:
      - INLINE: `gh api -X POST repos/{{OWNER}}/{{REPO}}/pulls/{{PR}}/comments/<id>/replies -f body="$(printf '✅ **Resuelto** en [`%s`](%s).\n\n**Qué cambió:** %s\n\n<sub>🤖 Fix automático en respuesta a este comentario de Codex.</sub>' "<sha_corto>" "<COMMIT_URL>" "<resumen>")"`
      - GENERAL: `gh pr comment {{PR}} --repo {{OWNER}}/{{REPO}} --body "$(printf '✅ **Resuelto** en [`%s`](%s) (en respuesta a tu comentario).\n\n**Qué cambió:** %s\n\n<sub>🤖 Fix automático de Codex.</sub>' "<sha_corto>" "<COMMIT_URL>" "<resumen>")"`
      - REVIEW-BODY → **quote reply** (comentario general que CITA el body original). Construí la cita prefijando cada línea del body con `> ` (recortá a la parte saliente si el body es largo); guardala en QUOTED: `QUOTED=$(printf '%s\n' "<body_review>" | sed 's/^/> /')`. Después: `gh pr comment {{PR}} --repo {{OWNER}}/{{REPO}} --body "$(printf '%s\n\n✅ **Resuelto** en [`%s`](%s) (en respuesta a esta review).\n\n**Qué cambió:** %s\n\n<sub>🤖 Fix automático en respuesta a esta review de Codex.</sub>' "$QUOTED" "<sha_corto>" "<COMMIT_URL>" "<resumen>")"`
   c. SOLO INLINE — resolver el hilo vía GraphQL:
      THREAD_ID=$(gh api graphql -f query='query($owner:String!,$repo:String!,$pr:Int!){repository(owner:$owner,name:$repo){pullRequest(number:$pr){reviewThreads(first:100){nodes{id comments(first:100){nodes{databaseId}}}}}}}' -F owner={{OWNER}} -F repo={{REPO}} -F pr={{PR}} --jq "[.data.repository.pullRequest.reviewThreads.nodes[] | select(any(.comments.nodes[]; .databaseId == <id>)) | .id] | first // empty")
      si THREAD_ID no vacío: gh api graphql -f query='mutation($threadId:ID!){resolveReviewThread(input:{threadId:$threadId}){thread{isResolved}}}' -F threadId="$THREAD_ID"
   d. Agregá el id a processedCommentIds en .codex-autofix/processed-{{PR}}.json: número crudo para inline/generales; `"review:<id>"` para review-bodies. **Invariante de idempotencia**: por cada comentario hacé el reply de cierre Y la escritura del id como una sola unidad apenas vuelve su subagente (no batchees al final). Si el loop se cae entre el push y esta escritura, la próxima vuelta re-fixearía el comentario (reply duplicado): cerrar+marcar de inmediato achica esa ventana al mínimo.

(4-bis) MINIMIZE de la review cuando esté COMPLETAMENTE resuelta (estado RESOLVED → queda oculta/colapsada). Para CADA review de Codex que tenga al menos 1 comment inline asociado y que NO esté ya minimizada, chequeá si está fully-resolved:
   - el review-body está cubierto: era no accionable (nada que fixear) O su id `"review:<id>"` ya está en processedCommentIds, **y**
   - TODOS sus threads inline (los que cuelgan de esa review) están `isResolved`.
   Detección en una query (devuelve `true` solo si hay ≥1 thread de esa review y todos resueltos):
     `gh api graphql -f query='query($owner:String!,$repo:String!,$pr:Int!){repository(owner:$owner,name:$repo){pullRequest(number:$pr){reviewThreads(first:100){nodes{isResolved comments(first:1){nodes{pullRequestReview{databaseId}}}}}}}}' -F owner={{OWNER}} -F repo={{REPO}} -F pr={{PR}} --jq '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.comments.nodes[0].pullRequestReview.databaseId == <review_db_id>) | .isResolved] as $r | ($r|length>0) and ($r|all)'`
   Si da `true` (o si la review no tiene inline pero su body accionable ya fue fixeado y resuelto): minimizá la review:
     `gh api graphql -f query='mutation($id:ID!){minimizeComment(input:{subjectId:$id,classifier:RESOLVED}){minimizedComment{isMinimized minimizedReason}}}' -F id="<review_node_id>"`
   NO minimices reviews donde el loop no resolvió nada (sin inline resueltos por el loop y body no accionable): dejalas como están.

(5) Si FALLA (no se pudo aplicar el fix por una falla del loop/agente, no porque la sugerencia sea inválida): NO marques el id, NO resuelvas, y NO cuentes ese comentario como fixeado. NO reacciones 👎 (content=-1): el 👎 es la señal de "sugerencia incorrecta/no útil" que Codex interpreta sobre su comentario, y acá el problema es el loop, no la sugerencia. No agregues reacción final; opcionalmente, dejá un reply con el motivo/link al error. Reservá el 👎 solo para cuando evaluaste la sugerencia y concluiste que no requería cambios.
   - **Clones huérfanos**: en fallo, `fix-in-ephemeral-clone` conserva el clone para inspección y reporta su path. Recolectá esos paths de los subagentes que fallaron y, al cerrar la vuelta, listalos en UNA línea de PushNotification (p. ej. "PR #{{PR}}: 2 fixes fallaron, clones en <paths>"). Si no los vas a inspeccionar, podés limpiarlos vos (`rm -rf <path>`) DESPUÉS de loguear el path, nunca antes. Con varios fallos en paralelo el tempdir se llena: no dejes los paths sin reportar.

(5-bis) TERMINACIÓN POR REVIEW LIMPIA (mergear + cortar). Chequealo cuando NO quedó ningún ítem accionable de Codex sin resolver esta vuelta (ni nuevos sin procesar, ni fallas pendientes del paso 5). Buscá el ÚLTIMO comentario general de Codex que sea una review limpia y de qué commit es:
   CLEAN=$(gh api repos/{{OWNER}}/{{REPO}}/issues/{{PR}}/comments --paginate --jq '[.[] | select(.user.login=="chatgpt-codex-connector[bot]") | select(.body | test("Codex Review:.*([Dd]idn.t find any|[Nn]o (major )?issues|[Ff]ound no issues)"))] | last // empty')
   Si CLEAN está vacío -> no aplica, seguí al paso (6). Si no:
   REVIEWED=$(printf '%s' "$CLEAN" | jq -r '.body' | grep -oiE 'Reviewed commit:\*\* `[0-9a-f]{7,}`' | grep -oiE '[0-9a-f]{7,}' | head -1)
   HEAD=$(gh pr view {{PR}} --repo {{OWNER}}/{{REPO}} --json headRefOid -q .headRefOid)
   Solo continuá si REVIEWED no está vacío y es prefijo de HEAD (la review limpia corresponde al head actual; si no coincide, hay commits posteriores sin re-revisar -> NO mergees, seguí al paso 6 para disparar/esperar la nueva review).
   Si coincide: MERGEÁ el PR (estrategia squash, borrando la rama; ajustá si tu repo usa otra): `gh pr merge {{PR}} --repo {{OWNER}}/{{REPO}} --squash --delete-branch`.
   - Si el merge tiene ÉXITO -> auto-cancelá el loop (mismo procedimiento del guard: CronList, identificá el job de ESTE loop por cron `{{CRON}}` y PR #{{PR}}, CronDelete por id, PushNotification de una línea avisando "PR #{{PR}} mergeado tras review limpia de Codex") y terminá. NO postees `@codex review`.
   - Si el merge FALLA (checks pendientes, no-mergeable, conflicto, branch protection): NO cortes el loop. PushNotification de una línea con el motivo (una sola vez) y dejá el loop vivo para reintentar en la próxima vuelta. No es trabajo del loop resolver conflictos de merge.

(6) AL FINAL: si en esta vuelta fixeaste con éxito al menos 1 ítem nuevo (inline, general o review-body; contador >= 1) y ya no quedan pendientes, posteá UN único comentario general `@codex review` para disparar una nueva revisión de Codex: `gh pr comment {{PR}} --repo {{OWNER}}/{{REPO}} --body "@codex review"`. Si NO fixeaste nada nuevo esta vuelta (contador == 0), NO postees nada (evitá spam).

(7) SIEMPRE que postees `@codex review`, asegurá que el loop siga vivo SIN que el usuario lo pida: si el cron del loop (`{{CRON}}`, este PR) fue cancelado o pausado, relanzalo (mismo prompt parametrizado) y corré una iteración. `@codex review` dispara comentarios nuevos; el loop debe quedar escuchando para auto-procesarlos. Nunca dejes el loop cancelado justo después de disparar una review.
```

## Plantilla de comentario de cierre

Tanto el loop local como el Action (`.github/workflows/codex-autofix.yml`)
cierran el hilo con el **mismo** formato. Placeholders: `{{sha_corto}}` (7 chars),
`{{commit_url}}`, `{{resumen}}` (una línea), `{{run_url}}` (solo el Action).

- **Éxito (fix aplicado) → 👍**
  ```text
  ✅ **Resuelto** en [`{{sha_corto}}`]({{commit_url}}).

  **Qué cambió:** {{resumen}}

  <sub>🤖 Fix automático en respuesta a este comentario de Codex · [run]({{run_url}})</sub>
  ```
  (Si no hay resumen disponible, omitir la línea «Qué cambió».)

- **Éxito sobre un review-body → 👍 + quote reply** (cita el body original; luego se minimiza la review como `RESOLVED` cuando ella y sus inline estén resueltos)
  ```text
  > {{body_review_citado}}

  ✅ **Resuelto** en [`{{sha_corto}}`]({{commit_url}}) (en respuesta a esta review).

  **Qué cambió:** {{resumen}}

  <sub>🤖 Fix automático en respuesta a esta review de Codex · [run]({{run_url}})</sub>
  ```

- **Sin cambios (el agente evaluó y no hacía falta tocar código) → 👎**
  ```text
  ℹ️ **Sin cambios.** Revisé la sugerencia pero no requería cambios de código.

  <sub>🤖 Auto-fix de Codex · [run]({{run_url}})</sub>
  ```

- **Falla del flujo (no se pudo aplicar; problema del Action/loop, no de la sugerencia) → sin reacción final**
  ```text
  ⚠️ **No pude aplicar el fix** (falla del Action, no de la sugerencia).

  <sub>🤖 Auto-fix de Codex · [run]({{run_url}})</sub>
  ```

> Regla de paridad: cualquier cambio a esta plantilla debe reflejarse en ambos
> lados (este skill y el step «Cerrar comentario» del workflow). El soporte de
> **review-bodies** (👍 vía GraphQL + quote reply + minimize `RESOLVED`) por ahora
> vive solo en este loop local; portarlo al Action `.github/workflows/codex-autofix.yml`
> queda como follow-up pendiente.

## Notas

- **Fan-out por grupo de archivo, con cap de concurrencia**: la unidad de trabajo
  no es el comentario suelto sino el GRUPO —inline del mismo `path` (o `line`
  cercanas) juntos; cada general/review-body es su propio grupo—. Un subagente por
  grupo; dentro del grupo resuelve secuencial en el mismo clone (un push). Así dos
  fixes sobre el mismo archivo no se pisan ni chocan en el rebase. Se spawnean en
  lotes de `{{MAX_PARALLEL}}` para no fundir disco/CPU (cada subagente es clone +
  install + tests). Cada subagente lleva como label los comment ids de su grupo, y
  recibe en el prompt el path al `SKILL.md` de `fix-in-ephemeral-clone` como
  fuente de verdad (además de invocarla por nombre).
- **Push con re-integración (clones aislados)**: el cómputo del fix está aislado
  por clone; el único punto compartido es el push a la rama del PR. Ante non-fast-forward,
  cada subagente NO repushea a ciegas: corre un ciclo completo de re-integración
  —fetch → rebase → resolver conflictos → revalidar que tanto el fix propio como
  los cambios integrados de los otros subagentes siguen pasando → push— y lo
  repite hasta subir. Eso evita el clobber y garantiza que ni el fix propio ni los
  fixes de los demás quedaron rotos al combinarse, sin perder el paralelismo del
  trabajo pesado. El closeout (reacciones, replies,
  resolver hilos) corre por comentario a medida que vuelve cada subagente; la
  escritura de `processed-<PR>.json` la serializa el loop principal (único
  escritor).
- **Estado por PR**: un archivo `processed-<PR>.json` por cada PR en seguimiento;
  así un mismo loop o varios loops no reprocesan lo ya hecho. Los review-bodies
  se guardan namespaceados (`"review:<id>"`) para no colisionar con ids de
  comentarios inline/generales (espacios de id distintos).
- **Tres fuentes**: inline (`pulls/{pr}/comments`), generales
  (`issues/{pr}/comments`) y review-bodies (`pulls/{pr}/reviews`). El review-body
  se procesa solo si trae una sugerencia accionable real; igual entra al paso de
  minimize cuando él y sus inline asociados están resueltos.
- **Reacción/minimize en reviews por GraphQL**: no hay endpoint REST de reactions
  ni de minimize para un `PullRequestReview`. Implementa `Reactable` y
  `Minimizable`, así que `addReaction` y `minimizeComment` operan sobre su
  `node_id`. El vínculo review↔inline lo da `pull_request_review_id` en cada
  comment inline (REST) o `comment.pullRequestReview.databaseId` (GraphQL).
- **Terminación por review limpia**: cuando Codex postea "Codex Review: Didn't
  find any major issues" para el **head actual** (se valida con el sha de
  `**Reviewed commit:**` contra `headRefOid`) y no quedan pendientes, el loop
  mergea el PR y se auto-cancela. El check de sha evita mergear con commits
  posteriores aún sin re-revisar. Estrategia de merge por defecto: `--squash
  --delete-branch` (alineado con el historial del repo, `feat: … (#NN)`); cambiá
  el flag si tu repo usa merge-commit o rebase. Si el merge falla (checks
  pendientes, conflicto, branch protection), el loop NO se corta y reintenta.
- **Re-disparo de `@codex review` caído**: Codex pone 👀 (eyes) sobre el comentario
  al recibirlo. Si en una vuelta el último comentario general del PR es un
  `@codex review` sin esa reacción del bot, el trigger no fue leído (caído) y el
  loop lo repostea (paso 2-bis). El chequeo corre una vez por iteración, así que
  el propio intervalo del loop lo rate-limitea y no spamea; si el comentario ya
  tiene 👀, no hace nada.
- **Cancelar a mano**: `CronList` para ver el job y `CronDelete <id>`.
- **Persistencia real**: para correr sin sesión abierta, mergeá el workflow de CI
  a la rama default y usá el Action.
