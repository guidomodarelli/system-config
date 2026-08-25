# Matriz de verificación

## Verificaciones comunes

| Verificación | Resultado requerido |
|---|---|
| URL | host, owner, repo, PR y fragment válidos |
| PR | estado `OPEN`, branch y head conocidos |
| Identidad | usuario autenticado leído con `gh api user` |
| Duplicados | no existe closeout previo del destino |
| Árbol | limpio o aislado antes de editar |
| Push | head remoto coincide con SHA completo del fix |
| Código | diff focal, typecheck/lint/tests/build según repo |
| Seguridad | sin secrets, tokens, cookies, headers, payloads raw, stack, `cause` o PII |

## Destino inline (`#discussion_r<comment_id>`)

| Verificación | Resultado requerido |
|---|---|
| Comentario | body, path, line y commit de origen leídos |
| Saltos de línea | `\\n` de JSON serializado interpretado una sola vez; secuencias literales del autor preservadas |
| Thread | `thread.id`, `isResolved: false` antes del trabajo |
| Estado | `isOutdated` evaluado sin invalidación automática |
| Duplicados | no existe reply previo del usuario para comment ID |
| Reply | creado en endpoint de comments con `in_reply_to` y SHA del PR |
| Resolve | `resolveReviewThread` confirma `isResolved: true` |
| Salida | `Thread: resuelto` y URL de reply |

## Destino review-body (`#pullrequestreview-<review_id>`)

| Verificación | Resultado requerido |
|---|---|
| Review | `id`, `node_id`, `user`, `body`, `state`, `html_url` leídos |
| Pertenencia | `pull_request_url` pertenece a PR/repo indicado |
| Estado | review publicada y accionable; no `PENDING`/`DISMISSED` |
| Inline asociado | comentarios con `pull_request_review_id == review_id` quedan intactos y no se toman como target |
| Duplicados | body y comentarios generales no contienen marker `review:<review_id>` |
| Edición | body original completo preservado y template agregado |
| Edición verificada | body actualizado contiene commit, `Qué cambió` y marker |
| Fallback | comentario en `issues/<PR>/comments` contiene review URL, commit, template y marker |
| Resolución | no usar `resolveReviewThread` ni afirmar review resuelta |
| Salida | `Review body: actualizada` o `Comentario fallback: publicado` |

## Reglas de parada

Detener sin commit/push/closeout si:

- URL no coincide con formato inline o review-body válido;
- PR está cerrado/mergeado;
- destino no pertenece a PR/repo indicado;
- feedback accionable solo aparece en comentario inline hijo y falta enlace `discussion_r` específico;
- review no es publicada, body está vacío o feedback no es accionable;
- árbol contiene cambios ajenos y no hay aislamiento seguro;
- sugerencia no es reproducible o exige decisión funcional no dada;
- typecheck, tests o build fallan sin causa preexistente demostrada;
- SHA publicado no coincide con head remoto;
- comentario, review, reply o fallback no pueden dirigirse inequívocamente;
- PUT de review tiene resultado ambiguo tras relectura;
- body actualizado no conserva body original completo;
- fallback no contiene URL inequívoca a review y marker estable;
- se intenta `resolveReviewThread` sobre review-body.

No usar `git reset --hard`, `git clean -fd`, `git push --force`, `--force` en uploads ni desactivar tests como recuperación.
