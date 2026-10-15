---
name: codex-autofix-loop
description: "Relanzar y operar el loop local (vía Claude Code) que auto-fixea comentarios de Codex (chatgpt-codex-connector[bot]) en un PR: clone efímero → fix → push → closeout del hilo, o delegación a Codex con `@codex fix` en el propio hilo (modo `codex`/`auto` con fallback local), con dedup por PR y guard de auto-cancelación. Es también la fuente de verdad de la plantilla de cierre: cargarla SIEMPRE antes de responder, reaccionar o resolver cualquier comentario, hilo inline o review de Codex, en cualquier flujo (este loop, el Action, el Auto-fix de la app de escritorio con `<ci-monitor-event>`, o un fix manual), aunque el usuario no mencione la skill. Use when the user asks to relaunch/start the Codex auto-fix loop for a PR, set up Codex comment auto-fixing, mentions docs/codex-autofix-loop.md, processed-PR.json, or the codex-autofix workflow, or whenever you are about to reply to / close out a chatgpt-codex-connector[bot] comment."
---

# Codex auto-fix loop (local, vía Claude Code)

Loop local que escucha comentarios de **Codex** (`chatgpt-codex-connector[bot]`)
en un PR y **spawnea subagentes en paralelo** (uno por GRUPO de archivo, tantos
como permitan la CPU, la RAM y el disco libres en cada vuelta) que delegan el fix en la skill
[`fix-in-ephemeral-clone`](../../(git)/fix-in-ephemeral-clone/SKILL.md) —invocada vía
la herramienta `Skill` (`/fix-in-ephemeral-clone`)— tratando cada comentario
como la "issue" a resolver (clone efímero depth-1 → fix → validar → push a la rama
del PR). Cada subagente trabaja en su propio clone efímero aislado; como todos
pushean a la misma rama, ante non-fast-forward cada subagente reintegra (rebase
+ resolución de conflictos + revalidación del fix propio y de los cambios
integrados de los otros subagentes) y recién ahí pushea, repitiendo el ciclo
hasta el límite de `fix-in-ephemeral-clone` (máximo 3 ciclos non-fast-forward;
al agotarlo reporta `CONCURRENT_PUSH_RETRY_EXHAUSTED`).
Después el loop principal hace el closeout en el hilo (reacción 👍 + reply con link
al commit + resolver el hilo inline).

Además del subagente local, el loop puede **delegar el fix al propio Codex**
([Act on review findings](https://learn.chatgpt.com/docs/third-party/github#act-on-review-findings)):
deja un comentario `@codex fix …` en el propio hilo del hallazgo (o en el PR cuando
no hay hilo), Codex abre una tarea cloud con el PR como contexto y pushea el fix a la
rama si tiene permiso. Qué camino se usa lo decide `{{FIX_MODE}}` (ver «Modo de fix»).

Cubre **tres fuentes** de comentarios de Codex:
1. **Inline** (`pulls/{pr}/comments`): atados a un `path` + `line`; closeout = 👍 + reply en el hilo + resolver el hilo.
2. **Generales** (`issues/{pr}/comments`): comentarios sueltos del PR; closeout = 👍 + reply.
3. **Review-body de primer nivel** (`pulls/{pr}/reviews`, anchor `#pullrequestreview-…`): el resumen que Codex postea al enviar una review. Se procesa **solo cuando el body trae una sugerencia accionable real** (no un mero resumen). Closeout = 👍 + **quote reply** (citando el body). Cuando el review-body **y todos sus comments inline** quedan resueltos, se **minimiza la review con estado `RESOLVED`** (queda oculta/colapsada). `PullRequestReview` implementa `Reactable` y `Minimizable`, así que reacción y minimize van por GraphQL sobre su `node_id`.

## Regla obligatoria: toda respuesta a Codex usa la plantilla de cierre

Esta regla aplica a **cualquier** respuesta a un comentario de `chatgpt-codex-connector[bot]`,
no solo a las de este loop: el Action, el Auto-fix de la app de escritorio (eventos
`<ci-monitor-event>` que piden responder y resolver hilos), un fix manual pedido en la
conversación u otra skill que cierre hilos de Codex. Nunca escribas una respuesta libre
("Corregido en …", "Fixed in …") a un comentario de Codex.

Antes de publicar, completá este checklist por comentario:

1. **Variante correcta** de «Plantilla de comentario de cierre» (abajo): `✅ Resuelto` si
   hubo fix pusheado (también cuando la sugerencia era válida solo en parte: decilo en
   «Qué cambió»), `ℹ️ Sin cambios` si evaluaste y no hacía falta o si es un caso de
   borde rebuscado (ver «Regla de alcance»; decilo en «Motivo»), `⚠️ No pude aplicar`
   si falló el flujo. Review-body → quote reply.
2. **Link al commit** con sha corto de 7 chars y URL al sha completo, verificado en el
   head remoto del PR (`git ls-remote` o `gh pr view --json headRefOid`) antes de publicar.
3. **`Qué cambió`** en UNA línea, en español, describiendo el efecto observable.
4. **Pie `<sub>🤖 …</sub>`** de la variante. Fuera del Action no hay run: omití
   ` · [run]({{run_url}})`. Si el host exige una línea extra (por ejemplo, el Auto-fix de
   la app pide `_🤖 Addressed by [Claude Code](https://claude.com/claude-code)_`), agregala
   como **última línea, después del pie**, sin reemplazar ninguna parte de la plantilla.
5. **Reacción** del paso (4a): 👍 en éxito, 👎 solo en «Sin cambios», ninguna en falla.
6. **Resolver** el hilo inline (paso 4c) solo en éxito o «Sin cambios».
7. **Verificar** después de publicar: releé el body publicado
   (`gh api repos/{{OWNER}}/{{REPO}}/pulls/comments/<reply_id> --jq .body`) y confirmá que
   empieza con el encabezado de la variante (`✅ **Resuelto** en [`…) y contiene el pie;
   si no, editalo con `gh api -X PATCH …/pulls/comments/<reply_id> -f body=…` en lugar de
   publicar otro reply.

Si ya publicaste una respuesta libre, corregila editándola (PATCH) con la plantilla y
agregá la reacción que falte; no publiques un segundo reply.

## Regla de alcance: casos de borde rebuscados

El loop tiene que **converger y terminar**. Cada fix de un caso muy rebuscado agrega
complejidad y dispara más comentarios de borde en la siguiente `@codex review`, y el
loop no termina nunca. Por eso el LOOP PRINCIPAL clasifica cada comentario antes de
agrupar o spawnear (paso 3-pre del prompt):

- **Realista** (puede pasar en el uso normal, o es un bug, un riesgo de seguridad o una
  pérdida de datos plausible): se fixea.
- **Borde razonable** (poco frecuente pero creíble, con un fix acotado y testeable):
  se fixea, con el diff mínimo.
- **Borde rebuscado** (exige combinaciones improbables o entornos exóticos, por ejemplo
  una ruta de checkout con `%VAR%` pasando por un shim `.cmd`, o rediseñar un subsistema
  para cubrir algo hipotético): NO se fixea. Se cierra con «ℹ️ Sin cambios» y un
  `**Motivo:**` de una línea que explica por qué no aplica, se resuelve el hilo y se
  marca como procesado.

Ante la duda entre «borde razonable» y «rebuscado», mirá el costo: si el fix es chico,
local y testeable, hacelo; si exige rediseño, dependencias nuevas o tocar varios
módulos por un caso hipotético, es rebuscado. En un riesgo de seguridad sin solución
simple, aplicá la mitigación razonable, documentá el riesgo residual y cerrá con
«✅ Resuelto» aclarando en «Qué cambió» que quedó resuelto en parte, sin sobre-diseñar.
Si Codex repite en una review posterior un hallazgo ya cerrado como «Sin cambios», volvé
a cerrarlo igual, con el mismo motivo, sin spawnear subagente.

**Corte por convergencia:** si en una vuelta todos los hallazgos de la última review de
Codex se cerraron como «Sin cambios» (rebuscados o repetidos) y no hubo ningún commit
nuevo, el head no cambió y Codex no va a publicar una review limpia. En ese caso NO
postees otro `@codex review` y **mergeá sin preguntar**, igual que en la terminación por
review limpia (paso 5-bis), siempre después de su gate de CI (checks en verde): `gh pr merge {{PR}} --repo {{OWNER}}/{{REPO}} --squash
--delete-branch`. Si el merge tiene éxito, auto-cancelá el loop y mandá una
PushNotification de una línea («PR #N mergeado: solo quedaban hallazgos de borde
cerrados como Sin cambios»). Si el merge falla (checks pendientes, conflicto, branch
protection), dejá el loop vivo para reintentar en la próxima vuelta y avisá el motivo una
sola vez.

## Modo de fix: subagente local o `@codex fix`

`{{FIX_MODE}}` decide quién aplica el fix de cada grupo (el triage, la agrupación y el
closeout son los mismos en todos los modos):

- **`local`** (default): solo subagentes locales con `fix-in-ephemeral-clone`. Es el
  default porque el entorno cloud de Codex no tiene credenciales para pushear a la rama:
  sus `@codex fix` preparan un commit que nunca llega al PR (ver `ae2d994` en el PR #111
  de TuTribu) y solo suman una vuelta de espera.
- **`codex`**: solo delegación a Codex con `@codex fix`. Si Codex no pushea, el
  comentario queda como falla (paso 5) y se reintenta hasta `{{CODEX_FIX_MAX_ATTEMPTS}}`
  veces; después queda pendiente y se avisa.
- **`auto`**: primero `@codex fix`; si Codex no toma el pedido, responde sin
  pushear (por ejemplo, sin permiso de escritura) o vence `{{CODEX_FIX_TTL_MIN}}`, el
  grupo cae a un subagente local en la vuelta siguiente.

Reglas del pedido a Codex:

- **Dónde se comenta**: si el grupo es inline, el `@codex fix` va como **reply en el
  hilo del primer comentario del grupo** (`pulls/{pr}/comments/<id>/replies`), así el
  pedido queda en el propio thread. Los generales y los review-bodies no tienen hilo:
  el pedido va como comentario general del PR, con link al comentario o review original.
- **Un pedido por grupo**: como los demás grupos, nunca dos tareas sobre el mismo `path`
  en paralelo. Si el grupo tiene varios inline, el reply del primer hilo lista los links
  de los otros comentarios del grupo; en esos otros hilos no se comenta hasta el closeout.
- **Nunca incluir la palabra `review`** en el texto del pedido: cualquier comentario
  `@codex` que la contenga dispara una review en lugar de una tarea de fix. Referenciá
  los review-bodies como «resumen de Codex» o por link.
- **Texto del pedido** (en español, una sola línea de instrucción + contexto):
  `@codex fix este hallazgo con el diff mínimo, sin ampliar el alcance a casos vecinos, y pusheá el commit a la rama {{BRANCH}}.`
  Para generales y review-bodies, agregá el link al comentario o resumen original.
- **No es un cierre**: el pedido no usa la plantilla de cierre ni reacciona. El cierre
  (👍 + reply con plantilla + resolver hilo) lo hace el loop recién cuando verifica el
  commit de Codex en el head del PR (paso 4).
- **Respuestas de Codex al pedido**: Codex reacciona 👀 al pedido y suele contestar en el
  mismo hilo o en el PR. Esas respuestas NO son hallazgos nuevos: se registran en
  `delegationReplyIds` y no se fixean.
- **Fallas de CI** (gate del paso 5-bis): en `codex`/`auto` se delegan con un comentario
  general `@codex fix las fallas de CI del run <run_url> con el diff mínimo` antes de usar un
  subagente local.

> **Por qué delegar en `fix-in-ephemeral-clone`:** esa skill es la dueña del
> contrato de aislamiento (clone efímero, copia de `.env*`, deps por plataforma,
> rebase pre-push, push con retry, cleanup). Este loop NO reimplementa ese flujo:
> solo arma el input (comentarios agrupados por archivo → issue), spawnea un
> subagente por grupo (con concurrencia según recursos libres) que la invoca en paralelo, y
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
   .codex-autofix/processed-{{PR}}.json  ->  {"pr":{{PR}},"processedCommentIds":[],"inFlight":{},"codexAttempts":{},"delegationReplyIds":[]}
   ```
   (`inFlight` registra los comentarios que tienen un subagente o un pedido
   `@codex fix` trabajando; `codexAttempts` cuenta los pedidos a Codex por comment id;
   `delegationReplyIds` guarda los ids de los pedidos `@codex fix` y de las respuestas
   de Codex a esos pedidos. Si falta alguna clave, el loop la trata como vacía.)
   (`.codex-autofix/` está gitignored: es estado de runtime, no se commitea.)
3. Lanzá el loop pegando el prompt con el intervalo `{{INTERVAL}}`:
   ```
   /loop {{INTERVAL}} <pegá acá el prompt ya completado>
   ```
   O, más simple, decile a Claude: «relanzá el loop de Codex para el PR {{PR}}
   usando el skill codex-autofix-loop» y completa la plantilla por vos.

> **Variables globales del loop** (única fuente de verdad — cambiá SOLO estos
> números y se propagan a todo el documento):
> - `{{INTERVAL_MIN}}` = `3` — minutos entre corridas del cron de respaldo (el disparador principal es el Monitor del PR).
> - Costo estimado de UN subagente (clone efímero + install + tests), usado para
>   calcular cuántos caben en paralelo según recursos libres:
>   - `{{CPU_PER_AGENT}}` = `1` — cores lógicos libres por subagente.
>   - `{{RAM_PER_AGENT_GB}}` = `2` — GB de RAM disponible por subagente.
>   - `{{DISK_PER_AGENT_GB}}` = `3` — GB de disco libre (en el tempdir) por subagente.
> - Reserva que nunca se reparte entre subagentes (queda para el sistema y la sesión):
>   - `{{RAM_RESERVE_GB}}` = `2`.
>   - `{{DISK_RESERVE_GB}}` = `5`.
> - `{{INFLIGHT_TTL_MIN}}` = `60` — minutos tras los cuales una entrada de
>   `inFlight` sin subagente vivo se considera huérfana y se libera.
> - `{{FIX_MODE}}` = `local` — `local`, `codex` o `auto` (ver «Modo de fix»). Usá
>   `codex` o `auto` solo si Codex tiene permiso de escritura en la rama del PR.
> - `{{CODEX_FIX_TTL_MIN}}` = `30` — minutos que se espera el commit de un pedido
>   `@codex fix` antes de darlo por fallido.
> - `{{CODEX_ACK_TIMEOUT_MIN}}` = `10` — minutos que se espera la reacción 👀 de Codex
>   sobre el pedido antes de darlo por no tomado.
> - `{{CODEX_FIX_MAX_ATTEMPTS}}` = `2` — pedidos `@codex fix` por comentario en modo
>   `codex` (en `auto` es siempre 1 antes de caer a local).
> - `{{CODEX_MAX_PARALLEL}}` = `2` — pedidos `@codex fix` simultáneos (no consumen
>   recursos locales, pero sí pushes concurrentes a la rama).
> - `{{MONITOR_POLL_SEC}}` = `30` — segundos entre consultas del `Monitor` que vigila
>   el PR mientras está abierto (30 s o más por rate limit).
>
> Derivados (no los edites a mano; salen de `{{INTERVAL_MIN}}`):
> - `{{INTERVAL}}` = `{{INTERVAL_MIN}}m` (= `3m`) — intervalo de `/loop`.
> - `{{CRON}}` = `*/{{INTERVAL_MIN}} * * * *` (= `*/3 * * * *`) — cron equivalente
>   para identificar el job en `CronList`.

El disparador principal es un `Monitor` del PR (paso 0 del prompt): consulta GitHub cada
`{{MONITOR_POLL_SEC}}` s y corre una vuelta apenas hay un head nuevo, un comentario o review
de Codex o un cambio en los checks. El cron de `{{INTERVAL}}` queda como respaldo para los
timeouts y para rearmar el monitor si murió. Monitor y cron son session-only: si cerrás
Claude, hay que relanzarlo. El loop se
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
Auto-cancelar = CronList, identificá el job de ESTE loop (cron `{{CRON}}`, auto-fix de Codex en PR #{{PR}}), borralo con CronDelete por id, detené con TaskStop el Monitor `Monitor codex-autofix PR #{{PR}}` si está vivo, PushNotification de una línea avisando el motivo, y terminá sin procesar.

Si OPEN, procesá:
(0) MONITOR DEL PR (disparador principal; el cron `{{CRON}}` es solo respaldo para timeouts y por si el monitor muere). Mientras el PR esté `OPEN` tiene que haber UN `Monitor` vivo con `description` = `Monitor codex-autofix PR #{{PR}}` (así lo reconocés entre tus tareas en background y no armás dos). Si no existe, armalo con `timeout_ms: 1800000` (el máximo) y este `command`:
   ```bash
   pr={{PR}}; repo={{OWNER}}/{{REPO}}; bot='chatgpt-codex-connector[bot]'
   count_bot_reviews() { gh api "repos/$repo/pulls/$pr/reviews" --paginate --jq "[.[] | select(.user.login==\"$bot\")] | length" 2>/dev/null | awk '{total+=$1} END{print total+0}'; }
   checks_signature() { gh pr checks "$pr" --repo "$repo" --json bucket -q 'group_by(.bucket) | map("\(.[0].bucket)=\(length)") | join(",")' 2>/dev/null || true; }
   head=$(gh pr view "$pr" --repo "$repo" --json headRefOid -q .headRefOid 2>/dev/null)
   reviews=$(count_bot_reviews); checks=$(checks_signature)
   since=$(date -u +%Y-%m-%dT%H:%M:%SZ)
   while true; do
     sleep {{MONITOR_POLL_SEC}}
     now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
     snapshot=$(gh pr view "$pr" --repo "$repo" --json state,headRefOid -q '.state + " " + .headRefOid' 2>/dev/null) || continue
     state=${snapshot%% *}; current=${snapshot#* }
     if [ "$state" != "OPEN" ]; then echo "PR #$pr $state"; exit 0; fi
     if [ -n "$current" ] && [ "$current" != "$head" ]; then echo "PR #$pr head nuevo ${current:0:7}"; head=$current; fi
     for endpoint in "issues/$pr/comments" "pulls/$pr/comments"; do
       gh api "repos/$repo/$endpoint?since=$since" --jq ".[] | select(.user.login==\"$bot\") | \"PR #$pr comentario de Codex \(.id)\"" 2>/dev/null || true
     done
     current_reviews=$(count_bot_reviews)
     if [ "$current_reviews" -gt "$reviews" ]; then echo "PR #$pr review nueva de Codex"; fi
     reviews=$current_reviews
     current_checks=$(checks_signature)
     if [ -n "$current_checks" ] && [ "$current_checks" != "$checks" ]; then echo "PR #$pr checks $current_checks"; checks=$current_checks; fi
     since=$now
   done
   ```
   Cada línea que emite (head nuevo, comentario o review de Codex, cambio en los checks o PR que dejó de estar `OPEN`) es un evento: corré **una iteración inmediata** de este mismo prompt, sin esperar al cron. Si ya hay una iteración en curso, no lances otra: esa vuelta, o la siguiente, reconcilia el evento. El monitor no evalúa timeouts: los de ack (`{{CODEX_ACK_TIMEOUT_MIN}}`), commit (`{{CODEX_FIX_TTL_MIN}}`) e `inFlight` huérfano (`{{INFLIGHT_TTL_MIN}}`), los reintentos de merge y el re-disparo de `@codex review` los resuelve el cron.
   - Al vencer (aviso de expiración), rearmalo con el mismo `command` si el PR sigue `OPEN`. Si al empezar una vuelta del cron no está vivo (se perdió el aviso o falló el rearme), rearmalo en ese momento.
   - Cuando el PR deja de estar `OPEN` el script termina solo; si el loop se auto-cancela por otro motivo, detenelo con `TaskStop` (ver «Auto-cancelar»).

(1) Leé `processedCommentIds` desde `.codex-autofix/processed-{{PR}}.json`. Los ids de comentarios (inline/generales) se guardan como número crudo; los ids de review-body se guardan namespaceados como `"review:<id>"` (evita colisión entre espacios de id distintos). `processedCommentIds` representa comentarios cerrados: fixes aplicados y los cerrados como «Sin cambios» (incluidos los bordes rebuscados del paso 3-pre). Leé también `inFlight` (mapa `id -> {label, startedAt}` con el mismo formato de id; si falta, tratalo como `{}`): son los comentarios que YA tienen un subagente trabajando, lanzado en esta vuelta o en una anterior. Las entradas delegadas a Codex llevan además `via: "codex"`, `triggerId` (id del comentario `@codex fix`), `triggerKind` (`inline` o `general`), `baseSha` (head del PR al pedir) y `groupIds` (todos los ids del grupo). Leé también `codexAttempts` y `delegationReplyIds` (si faltan, `{}` y `[]`). Modo de fix de esta corrida: `{{FIX_MODE}}`.

(1-bis) NO RELANCES COMENTARIOS CON UN SUBAGENTE TRABAJANDO. Una vuelta puede empezar mientras siguen corriendo subagentes de vueltas anteriores. Antes de armar grupos, reconciliá `inFlight`:
   - Si el subagente de una entrada sigue vivo (lo ves corriendo en tus tareas/agentes en background con ese label), el id queda BLOQUEADO: no lo agrupes, no lo spawnees de nuevo, no reacciones ni respondas. Esperá su resultado; el closeout lo hace el paso (4) cuando vuelva.
   - Si el subagente ya no existe (murió sin devolver resultado, la sesión se reinició) Y pasaron más de `{{INFLIGHT_TTL_MIN}}` min desde `startedAt`, sacá la entrada de `inFlight`: el comentario vuelve a ser elegible en esta vuelta. Si no pasó ese tiempo, dejalo bloqueado por las dudas.
   - Si un comentario nuevo cae en el mismo `path` (o zona) que un grupo en curso, tampoco lo spawnees en paralelo: esperá a que ese grupo termine y tomalo en una vuelta siguiente (evita dos clones pisando el mismo archivo).
   - Entradas con `via: "codex"` (no hay subagente local que mirar; se reconcilian contra GitHub):
     - **Ack**: `gh api repos/{{OWNER}}/{{REPO}}/pulls/comments/<triggerId>/reactions` (inline) o `issues/comments/<triggerId>/reactions` (general) con `select(.content=="eyes" and .user.login=="chatgpt-codex-connector[bot]")`. Sin 👀 pasados `{{CODEX_ACK_TIMEOUT_MIN}}` min desde `startedAt` → pedido no tomado: FALLA de delegación.
     - **Commit de Codex**: `gh api repos/{{OWNER}}/{{REPO}}/pulls/{{PR}}/commits --paginate --jq '[.[] | {sha, date: .commit.committer.date, files_url: .url}]'` y tomá los commits posteriores a `baseSha` con fecha posterior a `startedAt` que NO sean shas reportados por subagentes locales. Para un grupo inline, verificá con `gh api repos/{{OWNER}}/{{REPO}}/commits/<sha> --jq '[.files[].filename]'` que el commit toca el `path` del grupo. Si hay uno que cumple → ÉXITO con ese sha: closeout del paso (4) para todos los `groupIds` (en el resumen, describí el efecto a partir del diff del commit).
     - **Respuestas de Codex**: los comentarios del bot posteriores al pedido en ese hilo (inline con `in_reply_to_id` = primer comentario del grupo) o en el PR (general que no sea una review con `Codex Review:`) son respuestas a la delegación: agregá sus ids a `delegationReplyIds`. Si Codex respondió y pasaron 5 min sin commit que cumpla (típico cuando no tiene permiso para pushear o solo contestó), es FALLA de delegación.
     - Sin commit pasados `{{CODEX_FIX_TTL_MIN}}` min desde `startedAt` → FALLA de delegación.
     - **FALLA de delegación**: sacá la entrada de `inFlight` y sumá 1 a `codexAttempts[<id>]` de cada id del grupo. En `auto`, el grupo queda elegible y en la próxima armada de grupos va a subagente local. En `codex`, si `codexAttempts < {{CODEX_FIX_MAX_ATTEMPTS}}` se vuelve a pedir; si no, aplicá el paso (5) (reply `⚠️ No pude aplicar` en el hilo, sin reacción, sin marcar) y no lo pidas más en este loop. No borres el comentario `@codex fix`.

(2) Traé comentarios de chatgpt-codex-connector[bot] de las TRES fuentes:
   - inline: `gh api repos/{{OWNER}}/{{REPO}}/pulls/{{PR}}/comments --paginate` (cada uno trae `id`, `path`, `line`, `body` y `pull_request_review_id` = review padre).
   - generales: `gh api repos/{{OWNER}}/{{REPO}}/issues/{{PR}}/comments --paginate`.
   - review-bodies: `gh api repos/{{OWNER}}/{{REPO}}/pulls/{{PR}}/reviews --paginate --jq '[.[] | select(.user.login=="chatgpt-codex-connector[bot]") | {id, node_id, body, state}]'`.
   - Descartá como hallazgos: los inline del bot con `in_reply_to_id` no nulo (los hallazgos de Codex siempre abren el hilo; un reply suyo es respuesta a un `@codex fix`), y cualquier id que esté en `delegationReplyIds`. No los marques en `processedCommentIds`.

(2-bis) RE-DISPARO de un `@codex review` que el bot no leyó. Codex reacciona con 👀 (eyes) sobre el comentario apenas lo recibe; si el ÚLTIMO comentario general del PR es un `@codex review` y NO tiene esa reacción 👀 del bot, el trigger se cayó (Codex nunca lo tomó) → reposteá uno nuevo para que arranque la review.
   - Último comentario general (vienen ascendentes por fecha, `last` = el más nuevo): `LAST=$(gh api repos/{{OWNER}}/{{REPO}}/issues/{{PR}}/comments --paginate --jq 'last // empty')`. Si está vacío, salteá este paso.
   - `LAST_ID=$(printf '%s' "$LAST" | jq -r '.id'); LAST_BODY=$(printf '%s' "$LAST" | jq -r '.body')`.
   - Seguí SOLO si `LAST_BODY` es un trigger de review (matchea `^@codex review`); si no, salteá (el último comentario no es un trigger pendiente).
   - Reacción 👀 del bot sobre ese comentario: `HAS_EYES=$(gh api repos/{{OWNER}}/{{REPO}}/issues/comments/$LAST_ID/reactions --jq '[.[] | select(.content=="eyes" and .user.login=="chatgpt-codex-connector[bot]")] | length')`.
   - Si `HAS_EYES == 0` (sin ojitos del bot): reposteá el trigger → `gh pr comment {{PR}} --repo {{OWNER}}/{{REPO}} --body "@codex review"`. Si `HAS_EYES >= 1`, NO hagas nada: Codex ya lo está procesando.
   - Para no duplicar el trigger: si en ESTA misma vuelta vas a fixear ítems nuevos (vas a postear `@codex review` en el paso (6)), salteá el repost acá; ese paso ya re-dispara la review.

(3) FAN-OUT EN PARALELO (por GRUPO de archivo, con concurrencia según recursos libres).

(3-pre) TRIAGE DE ALCANCE (lo decide el LOOP PRINCIPAL, antes de agrupar). Clasificá cada ítem elegible según la «Regla de alcance» del skill: realista, borde razonable o borde rebuscado. Los **rebuscados** NO van a ningún grupo: cerralos directamente con la variante «ℹ️ Sin cambios» de la plantilla, con `**Motivo:**` de una línea (👎, reply, resolver el hilo inline y marcar el id en processedCommentIds). Si un hallazgo repite uno ya cerrado como «Sin cambios», cerralo igual con el mismo motivo. En el prompt de cada subagente pedí el **diff mínimo** que resuelva el comentario, sin ampliar el alcance a casos de borde vecinos; si el subagente concluye que el fix exige un rediseño, que devuelva «rebuscado» con el motivo en lugar de implementarlo, y cerralo como «Sin cambios».

(3a) ARMÁ LOS GRUPOS DE TRABAJO. Tomá los ítems accionables y elegibles (los que NO están en `processedCommentIds` NI en `inFlight`; para review-bodies, además, pasá el filtro de accionabilidad de (3b)) y agrupalos así, porque dos fixes sobre el MISMO archivo/zona en clones paralelos se pisan o explotan en el rebase:
   - Los **inline** se agrupan por `path`; si dos inline del mismo `path` tienen `line` solapadas o cercanas, van en el MISMO grupo igual.
   - Cada **general** y cada **review-body accionable** es su propio grupo (no tienen `path`; asumí que pueden tocar cualquier archivo, así que no los mezcles con otros).
   - Un grupo = la unidad que toma UN subagente. Dentro del grupo, el subagente resuelve sus comentarios **secuencialmente en el mismo clone** (un solo push al final). Entre grupos de archivos DISJUNTOS sí hay paralelismo.

(3b) ACCIONABILIDAD DE REVIEW-BODIES (antes de agrupar/spawnear, la decide el LOOP PRINCIPAL). Evaluá si el body trae una **sugerencia accionable real** (un cambio concreto de código). Si es solo un resumen/observación no accionable ("revisé X, ver inline", aprobación, etc.), SALTEALO: no lo metas en ningún grupo, no reacciones, no respondas y NO lo marques como procesado (no ensucia el estado; igual entra en el paso de minimize si corresponde).

(3b-bis) RUTEO SEGÚN `{{FIX_MODE}}` (ver «Modo de fix» del skill). Por cada grupo:
   - `local` → cola local (pasos 3c y 3d).
   - `codex` → cola Codex, salvo que algún id del grupo ya agotó `{{CODEX_FIX_MAX_ATTEMPTS}}` (queda pendiente, no se rutea).
   - `auto` → cola Codex si ningún id del grupo tiene `codexAttempts >= 1`; si no, cola local.
   Cola Codex, hasta `{{CODEX_MAX_PARALLEL}}` pedidos vivos (contá las entradas `via: "codex"` de `inFlight`); el resto espera a la próxima vuelta:
   - Armá el texto según «Reglas del pedido a Codex» (sin la palabra `review`, diff mínimo, rama {{BRANCH}}; links a los otros comentarios del grupo o al comentario/resumen original).
   - INLINE → reply en el hilo del primer comentario del grupo: `TRIGGER_ID=$(gh api -X POST repos/{{OWNER}}/{{REPO}}/pulls/{{PR}}/comments/<id>/replies -f body="<pedido>" --jq .id)`.
   - GENERAL / REVIEW-BODY → comentario general: `TRIGGER_ID=$(gh api -X POST repos/{{OWNER}}/{{REPO}}/issues/{{PR}}/comments -f body="<pedido>" --jq .id)`.
   - En la misma unidad, registrá en `inFlight` cada id del grupo con `{label, startedAt, via: "codex", triggerId: TRIGGER_ID, triggerKind, baseSha: <headRefOid actual>, groupIds}`, agregá `TRIGGER_ID` a `delegationReplyIds` y persistí el JSON. El resultado se reconcilia en el paso (1-bis) de las vueltas siguientes.

(3c) CALCULÁ CUÁNTOS SUBAGENTES CABEN (`SLOTS`) según CPU, RAM y disco libres AHORA. Solo aplica a la cola local: los pedidos a Codex no consumen recursos locales. Los subagentes que ya corren están incluidos en la medición, así que no los restes aparte.
   - Medí (usá el bloque de tu plataforma; disco = unidad del tempdir donde se crean los clones):
     - Windows (PowerShell):
       `$cores = (Get-CimInstance Win32_Processor | Measure-Object NumberOfLogicalProcessors -Sum).Sum; $loadPct = (Get-CimInstance Win32_Processor | Measure-Object LoadPercentage -Average).Average; $busyCores = $cores * $loadPct / 100; $freeRamGb = (Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1MB; $freeDiskGb = (Get-PSDrive ((Split-Path $env:TEMP -Qualifier).TrimEnd(':'))).Free / 1GB`
     - Linux: `cores=$(nproc); busy_cores=$(cut -d' ' -f1 /proc/loadavg); free_ram_gb=$(awk '/MemAvailable/{print $2/1048576}' /proc/meminfo); free_disk_gb=$(df -Pk "${TMPDIR:-/tmp}" | awk 'NR==2{print $4/1048576}')`
     - macOS: `cores=$(sysctl -n hw.ncpu); busy_cores=$(sysctl -n vm.loadavg | awk '{print $2}'); free_ram_gb=$(vm_stat | awk -v ps=$(pagesize) '/Pages (free|inactive|speculative)/{gsub(/\./,"",$NF); sum+=$NF} END{print sum*ps/1073741824}'); free_disk_gb=$(df -Pk "${TMPDIR:-/tmp}" | awk 'NR==2{print $4/1048576}')`
   - Calculá (redondeando hacia abajo):
     - `cpu_slots  = floor((cores - busy_cores) / {{CPU_PER_AGENT}})`
     - `ram_slots  = floor((free_ram_gb - {{RAM_RESERVE_GB}}) / {{RAM_PER_AGENT_GB}})`
     - `disk_slots = floor((free_disk_gb - {{DISK_RESERVE_GB}}) / {{DISK_PER_AGENT_GB}})`
     - `SLOTS = max(0, min(cpu_slots, ram_slots, disk_slots, cantidad_de_grupos_pendientes))`
   - Si `SLOTS == 0` y NO hay ningún subagente en curso, usá `SLOTS = 1` para garantizar progreso. Si `SLOTS == 0` y SÍ hay subagentes en curso, no lances nada nuevo: los grupos pendientes esperan a que se liberen recursos.
   - Si la medición falla, usá `SLOTS = 1` y mencioná el fallo en la PushNotification de la vuelta.
   - Reportá en una línea del resumen de la vuelta qué recurso limitó (`cpu`, `ram` o `disk`) y el valor de `SLOTS`.

(3d) SPAWNEÁ HASTA `SLOTS` SUBAGENTES a la vez (herramienta `Agent`/`Task` en background, varios tool-uses en un mismo mensaje). **Antes de lanzar cada uno, registrá en `inFlight` todos los comment ids de su grupo** (`{label, startedAt: <ISO-8601 UTC>}`) y persistí el JSON: así la próxima vuelta, aunque este subagente siga trabajando, no vuelve a lanzar esos comentarios. Cuando un grupo termina, recalculá `SLOTS` (paso 3c) y arrancá los siguientes que quepan, hasta agotar la cola. **Etiquetá cada subagente con los comment ids de su grupo** (label), para mapear sin ambigüedad resultado→comentarios al cerrar y para reconocerlo como vivo en el paso (1-bis). Cada subagente:
   - Recibe en su prompt el **path absoluto al `SKILL.md` de `fix-in-ephemeral-clone`** como fuente de verdad del flujo de aislamiento (que lo lea), además de intentar invocarla por nombre vía la herramienta `Skill` (`/fix-in-ephemeral-clone`). NO reimplementa el clone/push a mano.
   - Recibe como "issue(s)" el contexto de los comentarios de su grupo: cuerpo, `path` y `line` (inline) o solo el body (general/review-body), y la rama objetivo {{BRANCH}}. No envíes un URL `#discussion_r...` o `#pullrequestreview-...` como target: este loop ya posee preflight y closeout agrupado; esos links pueden viajar solo como metadata no accionable.
   - Vía esa skill, hace el clone efímero depth-1, copia `.env*`, instala/linkea deps según plataforma, aplica el/los fix(es) de su grupo, valida, rebasea sobre el último remoto y pushea a {{BRANCH}}, y limpia el clone.

   **Push concurrente**: como varios subagentes pushean a la MISMA rama, ante un rechazo por non-fast-forward el subagente NO repushea a ciegas: corre un ciclo completo de re-integración —re-fetch → rebase sobre el nuevo remoto → resolver conflictos → revalidar que TANTO el fix recién hecho COMO los cambios que integró de los otros subagentes (fixes de otros comentarios que ya cayeron a la rama) siguen pasando sobre la nueva base → recién ahí pushea; si vuelve a rebotar, repite el ciclo entero hasta un máximo de 3 ciclos; al agotarlos devuelve fallo `CONCURRENT_PUSH_RETRY_EXHAUSTED`— (esa lógica y ese límite viven en `fix-in-ephemeral-clone`). Cada subagente DEVUELVE el sha COMPLETO del commit pusheado en éxito (uno por grupo), o un fallo explícito + el path del clone que quedó para inspección. Recogé los resultados; por cada comentario fixeado guardá su sha (para el closeout) y sumá 1 al contador de ítems fixeados esta vuelta.

(4) CLOSEOUT en ÉXITO (push hecho). Hacelo por cada comentario cuyo subagente volvió con éxito, usando el sha que ese subagente reportó (no esperes a que terminen todos: a medida que vuelven, cerrás), y por cada comentario cuyo pedido `@codex fix` se verificó como ÉXITO en el paso (1-bis), usando el sha del commit de Codex (cuenta como ítem fixeado de esta vuelta). El closeout es idéntico en ambos caminos: misma plantilla, mismo reply en el hilo del comentario original (no en el pedido `@codex fix`), misma reacción y resolución. Las acciones de closeout en GitHub (reacciones, replies, resolver hilos) son independientes por comentario; el ÚNICO recurso compartido es `.codex-autofix/processed-{{PR}}.json`, así que el loop principal es el único escritor y serializa esas escrituras (paso d) para no corromper el JSON cuando varios subagentes terminan casi a la vez. Definí el link al commit: COMMIT_URL=https://github.com/{{OWNER}}/{{REPO}}/commit/<sha>
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
   d. Agregá el id a processedCommentIds en .codex-autofix/processed-{{PR}}.json: número crudo para inline/generales; `"review:<id>"` para review-bodies. En la misma escritura, sacá el id de `inFlight`. **Invariante de idempotencia**: por cada comentario hacé el reply de cierre Y la escritura del id como una sola unidad apenas vuelve su subagente (no batchees al final). Si el loop se cae entre el push y esta escritura, la próxima vuelta re-fixearía el comentario (reply duplicado): cerrar+marcar de inmediato achica esa ventana al mínimo.

(4-bis) MINIMIZE de la review cuando esté COMPLETAMENTE resuelta (estado RESOLVED → queda oculta/colapsada). Para CADA review de Codex que tenga al menos 1 comment inline asociado y que NO esté ya minimizada, chequeá si está fully-resolved:
   - el review-body está cubierto: era no accionable (nada que fixear) O su id `"review:<id>"` ya está en processedCommentIds, **y**
   - TODOS sus threads inline (los que cuelgan de esa review) están `isResolved`.
   Detección en una query (devuelve `true` solo si hay ≥1 thread de esa review y todos resueltos):
     `gh api graphql -f query='query($owner:String!,$repo:String!,$pr:Int!){repository(owner:$owner,name:$repo){pullRequest(number:$pr){reviewThreads(first:100){nodes{isResolved comments(first:1){nodes{pullRequestReview{databaseId}}}}}}}}' -F owner={{OWNER}} -F repo={{REPO}} -F pr={{PR}} --jq '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.comments.nodes[0].pullRequestReview.databaseId == <review_db_id>) | .isResolved] as $r | ($r|length>0) and ($r|all)'`
   Si da `true` (o si la review no tiene inline pero su body accionable ya fue fixeado y resuelto): minimizá la review:
     `gh api graphql -f query='mutation($id:ID!){minimizeComment(input:{subjectId:$id,classifier:RESOLVED}){minimizedComment{isMinimized minimizedReason}}}' -F id="<review_node_id>"`
   NO minimices reviews donde el loop no resolvió nada (sin inline resueltos por el loop y body no accionable): dejalas como están.

(5) Si FALLA (no se pudo aplicar el fix por una falla del loop/agente o de la delegación a Codex que ya no tiene reintento según `{{FIX_MODE}}`, no porque la sugerencia sea inválida; una falla de delegación en `auto` NO llega acá, cae a subagente local): NO marques el id, NO resuelvas, y NO cuentes ese comentario como fixeado. SÍ sacá sus ids de `inFlight` (el subagente ya terminó), para que la próxima vuelta pueda reintentarlo. NO reacciones 👎 (content=-1): el 👎 es la señal de "sugerencia incorrecta/no útil" que Codex interpreta sobre su comentario, y acá el problema es el loop, no la sugerencia. No agregues reacción final; opcionalmente, dejá un reply con el motivo/link al error. Reservá el 👎 solo para cuando evaluaste la sugerencia y concluiste que no requería cambios.
   - **Clones huérfanos**: en fallo, `fix-in-ephemeral-clone` conserva el clone para inspección y reporta su path. Recolectá esos paths de los subagentes que fallaron y, al cerrar la vuelta, listalos en UNA línea de PushNotification (p. ej. "PR #{{PR}}: 2 fixes fallaron, clones en <paths>"). Si no los vas a inspeccionar, podés limpiarlos vos (`rm -rf <path>`) DESPUÉS de loguear el path, nunca antes. Con varios fallos en paralelo el tempdir se llena: no dejes los paths sin reportar.

(5-bis) TERMINACIÓN POR REVIEW LIMPIA (mergear + cortar). Chequealo cuando NO quedó ningún ítem accionable de Codex sin resolver esta vuelta (ni nuevos sin procesar, ni ids en `inFlight`, ni fallas pendientes del paso 5). Buscá el ÚLTIMO comentario general de Codex que sea una review limpia y de qué commit es:
   CLEAN=$(gh api repos/{{OWNER}}/{{REPO}}/issues/{{PR}}/comments --paginate --jq '[.[] | select(.user.login=="chatgpt-codex-connector[bot]") | select(.body | test("Codex Review:.*([Dd]idn.t find any|[Nn]o (major )?issues|[Ff]ound no issues)"))] | last // empty')
   Si CLEAN está vacío -> no aplica, seguí al paso (6). Si no:
   REVIEWED=$(printf '%s' "$CLEAN" | jq -r '.body' | grep -oiE 'Reviewed commit:\*\* `[0-9a-f]{7,}`' | grep -oiE '[0-9a-f]{7,}' | head -1)
   HEAD=$(gh pr view {{PR}} --repo {{OWNER}}/{{REPO}} --json headRefOid -q .headRefOid)
   Solo continuá si REVIEWED no está vacío y es prefijo de HEAD (la review limpia corresponde al head actual; si no coincide, hay commits posteriores sin re-revisar -> NO mergees, seguí al paso 6 para disparar/esperar la nueva review).
   **GATE DE CI (obligatorio antes de CUALQUIER merge, también en el corte por convergencia).** Una review limpia de Codex no prueba que la CI pase, y un repo sin branch protection deja mergear con checks en rojo. Leé los checks del head: `gh pr checks {{PR}} --repo {{OWNER}}/{{REPO}}` (exit 0 = todos verdes; exit 8 = pendientes; otro = alguno falló).
   - Pendientes -> NO mergees; dejá el loop vivo y reintentá en la próxima vuelta.
   - Alguno falló -> NO mergees. Tratá el fallo como un hallazgo realista más: en `codex`/`auto`, delegalo primero con un comentario general `@codex fix las fallas de CI del run <run_url> con el diff mínimo` (registrado en `inFlight` con id `"ci:<run_id>"` y `via: "codex"`, mismo reconcile del paso 1-bis); en `local`, o si esa delegación falla en `auto`, leé el log (`gh run view <run_id> --repo {{OWNER}}/{{REPO}} --log-failed`), lanzá un subagente con `fix-in-ephemeral-clone` y el diff mínimo (registrado en `inFlight` con id `"ci:<run_id>"`), y cuando pushee, posteá `@codex review` como en el paso 6. Mandá una PushNotification de una línea con el check que falló (una sola vez por run).
   - Sin checks configurados -> seguí, pero mencionalo en la PushNotification del merge.
   Solo con todos los checks verdes: MERGEÁ el PR (estrategia squash, borrando la rama; ajustá si tu repo usa otra): `gh pr merge {{PR}} --repo {{OWNER}}/{{REPO}} --squash --delete-branch`.
   - Si el merge tiene ÉXITO -> auto-cancelá el loop (mismo procedimiento del guard: CronList, identificá el job de ESTE loop por cron `{{CRON}}` y PR #{{PR}}, CronDelete por id, PushNotification de una línea avisando "PR #{{PR}} mergeado tras review limpia de Codex") y terminá. NO postees `@codex review`.
   - Si el merge FALLA (checks pendientes, no-mergeable, conflicto, branch protection): NO cortes el loop. PushNotification de una línea con el motivo (una sola vez) y dejá el loop vivo para reintentar en la próxima vuelta. No es trabajo del loop resolver conflictos de merge.

(6) AL FINAL: si en esta vuelta fixeaste con éxito al menos 1 ítem nuevo (inline, general o review-body, por subagente local o por commit de Codex verificado; contador >= 1) y ya no quedan pendientes (ni ids en `inFlight`), posteá UN único comentario general `@codex review` para disparar una nueva revisión de Codex: `gh pr comment {{PR}} --repo {{OWNER}}/{{REPO}} --body "@codex review"`. Si NO fixeaste nada nuevo esta vuelta (contador == 0), NO postees nada (evitá spam). Si los únicos cierres de la vuelta fueron «Sin cambios», aplicá el «Corte por convergencia» de la «Regla de alcance»: sin `@codex review`, mergeá el PR sin preguntar (pasando antes el GATE DE CI del paso 5-bis) y auto-cancelá el loop.

(7) SIEMPRE que postees `@codex review`, asegurá que el loop siga vivo SIN que el usuario lo pida: si el cron del loop (`{{CRON}}`, este PR) fue cancelado o pausado, relanzalo (mismo prompt parametrizado) y corré una iteración; si el `Monitor` del PR (paso 0) no está vivo, rearmalo. `@codex review` dispara comentarios nuevos; el loop debe quedar escuchando para auto-procesarlos. Nunca dejes el loop cancelado justo después de disparar una review.
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

- **Sin cambios (el agente evaluó y no hacía falta tocar código, o es un borde rebuscado) → 👎**
  ```text
  ℹ️ **Sin cambios.** Revisé la sugerencia pero no requería cambios de código.

  **Motivo:** {{motivo}}

  <sub>🤖 Auto-fix de Codex · [run]({{run_url}})</sub>
  ```
  (`{{motivo}}` es UNA línea en español. Es obligatorio cuando el cierre es por borde
  rebuscado, por ejemplo: «caso de borde poco realista: requiere una ruta de checkout con
  `%VAR%` y un shim `.cmd`». Si no hay motivo disponible, como en el Action, omití la línea.)

- **Falla del flujo (no se pudo aplicar; problema del Action/loop, no de la sugerencia) → sin reacción final**
  ```text
  ⚠️ **No pude aplicar el fix** (falla del Action, no de la sugerencia).

  <sub>🤖 Auto-fix de Codex · [run]({{run_url}})</sub>
  ```

> Regla de paridad: cualquier cambio a esta plantilla debe reflejarse en ambos
> lados (este skill y el step «Cerrar comentario» del workflow). La línea
> `**Motivo:**` de «Sin cambios» es opcional, así que el Action sigue siendo compatible
> aunque no la emita; agregarla allí queda como follow-up. El soporte de
> **review-bodies** (👍 vía GraphQL + quote reply + minimize `RESOLVED`) por ahora
> vive solo en este loop local; portarlo al Action `.github/workflows/codex-autofix.yml`
> queda como follow-up pendiente.

## Notas

- **Fan-out por grupo de archivo, con cap de concurrencia**: la unidad de trabajo
  no es el comentario suelto sino el GRUPO —inline del mismo `path` (o `line`
  cercanas) juntos; cada general/review-body es su propio grupo—. Un subagente por
  grupo; dentro del grupo resuelve secuencial en el mismo clone (un push). Así dos
  fixes sobre el mismo archivo no se pisan ni chocan en el rebase. La cantidad
  de subagentes simultáneos se calcula en cada vuelta (y al liberarse cada slot)
  como el mínimo entre lo que permiten los cores libres, la RAM disponible y el
  disco libre del tempdir, descontando una reserva (cada subagente es clone +
  install + tests). Cada subagente lleva como label los comment ids de su grupo, y
  recibe en el prompt el path al `SKILL.md` de `fix-in-ephemeral-clone` como
  fuente de verdad (además de invocarla por nombre).
- **Push con re-integración (clones aislados)**: el cómputo del fix está aislado
  por clone; el único punto compartido es el push a la rama del PR. Ante non-fast-forward,
  cada subagente NO repushea a ciegas: corre un ciclo completo de re-integración
  —fetch → rebase → resolver conflictos → revalidar que tanto el fix propio como
  los cambios integrados de los otros subagentes siguen pasando → push— y lo
  repite hasta el tope de ciclos de `fix-in-ephemeral-clone` (al agotarlo
  reporta `CONCURRENT_PUSH_RETRY_EXHAUSTED`). Eso evita el clobber y garantiza que ni el fix propio ni los
  fixes de los demás quedaron rotos al combinarse, sin perder el paralelismo del
  trabajo pesado. El closeout (reacciones, replies,
  resolver hilos) corre por comentario a medida que vuelve cada subagente; la
  escritura de `processed-<PR>.json` la serializa el loop principal (único
  escritor).
- **Sin relanzar trabajo en curso**: como el loop dispara cada `{{INTERVAL}}` y
  un subagente puede tardar más, `inFlight` marca los comentarios con un
  subagente trabajando. Se registran antes de spawnear y se liberan al volver
  (éxito o fallo); una vuelta nueva los saltea. Las entradas sin subagente vivo
  por más de `{{INFLIGHT_TTL_MIN}}` min se liberan para no bloquear para siempre.
- **Estado por PR**: un archivo `processed-<PR>.json` por cada PR en seguimiento;
  así un mismo loop o varios loops no reprocesan lo ya hecho. `processedCommentIds`
  contiene únicamente fixes aplicados/cerrados. Los review-bodies se guardan
  namespaceados (`"review:<id>"`) para no colisionar con ids de comentarios
  inline/generales (espacios de id distintos).
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
  `**Reviewed commit:**` contra `headRefOid`), no quedan pendientes y todos los
  checks de CI del head están en verde, el loop mergea el PR y se auto-cancela.
  El check de sha evita mergear con commits posteriores aún sin re-revisar, y el
  gate de CI evita mergear en rojo cuando el repo no tiene branch protection (una
  review limpia de Codex no prueba que la CI pase); un check fallido se trata
  como un hallazgo más y se fixea. Estrategia de merge por defecto: `--squash
  --delete-branch` (alineado con el historial del repo, `feat: … (#NN)`); cambiá
  el flag si tu repo usa merge-commit o rebase. Si el merge falla (checks
  pendientes, conflicto, branch protection), el loop NO se corta y reintenta.
- **Re-disparo de `@codex review` caído**: Codex pone 👀 (eyes) sobre el comentario
  al recibirlo. Si en una vuelta el último comentario general del PR es un
  `@codex review` sin esa reacción del bot, el trigger no fue leído (caído) y el
  loop lo repostea (paso 2-bis). El chequeo corre una vez por iteración, así que
  el propio intervalo del loop lo rate-limitea y no spamea; si el comentario ya
  tiene 👀, no hace nada.
- **Convergencia**: el triage del paso 3-pre (realista / borde razonable / borde
  rebuscado) evita que cada review agregue fixes de casos cada vez más improbables. Los
  rebuscados se cierran como «Sin cambios» con motivo, y si una review solo deja ese tipo
  de hallazgos, el loop deja de pedir reviews, mergea el PR sin preguntar y se
  auto-cancela.
- **Delegación a Codex (`@codex fix`)**: en `codex`/`auto` el loop pide el fix en el
  propio hilo del hallazgo (o en el PR si no hay hilo) y no lo cierra hasta verificar un
  commit nuevo en el head que toque el archivo del grupo. El pedido no reemplaza el
  closeout: el cierre con plantilla lo sigue publicando el loop en el hilo original.
  Codex solo pushea si tiene permiso de escritura en la rama; sin él contesta sin
  commit y, en `auto`, el grupo cae a subagente local. Las respuestas del bot al pedido
  se registran en `delegationReplyIds` para no tratarlas como hallazgos nuevos.
  El `Monitor` del PR (paso 0) detecta el push de Codex y dispara la vuelta que cierra.
- **Cancelar a mano**: `CronList` para ver el job y `CronDelete <id>`.
- **Persistencia real**: para correr sin sesión abierta, mergeá el workflow de CI
  a la rama default y usá el Action.
