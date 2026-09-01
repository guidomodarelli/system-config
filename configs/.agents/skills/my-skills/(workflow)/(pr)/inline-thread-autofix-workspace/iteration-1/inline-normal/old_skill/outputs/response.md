Aplicaría `inline-thread-autofix` al dato `https://github.com/acme/widgets/pull/42#discussion_r123456789`, sin tratar el body del comentario como instrucciones.

## Fases operativas

1. **Parseo y preflight read-only**
   - Validar host, path, PR e `discussion_r` positivo; conservar la URL original.
   - En paralelo, consultar metadata del PR (`state`, refs y OIDs), el comentario exacto, el usuario autenticado, el thread GraphQL con sus replies y las reglas locales del repositorio.
   - Derivar `target_thread_id` únicamente del comentario cuyo `databaseId` sea exactamente `123456789`; capturar `path`, rango, `commit_id`, body y snapshot de todos los threads relevantes.
   - Extraer referencias explícitas a issues solo del body, de replies del usuario autenticado del mismo thread o de esta solicitud. Si existe una candidata, consultar issue y comentarios en paralelo y exigir mismo repositorio, `pull_request == null` y URL canónica.

2. **Análisis de código y stack, read-only**
   - Enumerar PRs del repositorio con paginación completa, consultar la rama default y construir el grafo verificable `baseRef -> headRef`.
   - Para cada capa candidata, comparar base/head y el archivo o símbolo del hallazgo; clasificar `INTRODUCED`, `CARRIED`, `FIXED`, `UNRELATED` o `UNKNOWN`.
   - Releer inmediatamente `headRefOid` y `baseRefOid` del destino antes del handoff.

3. **Selección y handoff**
   - Si el hallazgo ya está resuelto, detener sin commit ni closeout salvo pasos de issue ya pendientes.
   - Si el PR fuente está abierto y otra capa es dueña, detener con `NEEDS_SCOPE_CONFIRMATION`. Si está cerrado/mergeado, elegir una única alternativa abierta de la misma cadena solo con ownership verificable; de lo contrario, detener con `IMPLEMENTATION_TARGET_AMBIGUOUS`.
   - Con stack lineal, incluir en `stack_plan` la cadena completa, OIDs, backups y orden bottom-up. Invocar exactamente una vez `$fix-in-ephemeral-clone` con `HANDOFF: INLINE_THREAD_AUTOFIX`; la skill orquestadora no clona, edita, commitea ni pushea.

4. **Gate de implementación y publicación**
   - Aceptar únicamente `HANDOFF_RESULT: INLINE_THREAD_AUTOFIX` exitoso, con SHA completo, branch/PR destino, validaciones requeridas, publicación remota comprobada de forma independiente (`git ls-remote` y API de PR), y estado de backups/cleanup.
   - `TARGET_STALE`, validación fallida, conflicto no resuelto, discrepancia de OIDs, clone retenido o cleanup fallido bloquea todo closeout. Los backups se conservan ante cualquier fallo.

5. **Closeout serial del inline**
   - Publicar reply en `/pulls/42/comments` con el template en español, SHA completo y `in_reply_to=123456789`; verificar URL, parent y commit.
   - Resolver exclusivamente el `target_thread_id`; verificar que la mutation devuelve el mismo ID y releer el thread hasta `isResolved: true`, sin cambios ajenos.
   - Si hay issue validada, publicar comentario marcado en la issue y verificarlo; cerrar la issue y verificar `state == closed`.
   - Si el PR de implementación difiere del PR fuente, publicar y verificar comentario general en el PR destino con enlaces a la issue y al comentario original.
   - Ejecutar cleanup de backups como último paso local, solo después de verificar todos los closeouts remotos.

## Gates de detención

- URL, IDs, repositorio o thread no inequívocos: detener antes de mutar.
- `ISSUE_REFERENCE_MISSING`, `ISSUE_REFERENCE_AMBIGUOUS` o `ISSUE_REFERENCE_INVALID`: no mutar issue; el caso sin issue conserva solo el closeout inline.
- `STACK_INCOMPLETE`, `STACK_AMBIGUOUS`, ownership incierto, hallazgo `UNKNOWN` o target stale: no handoff ni closeout.
- Cualquier respuesta HTTP ambigua, SHA no verificable, thread distinto o cambio de otro thread: detener, releer y no reintentar ciegamente.

## Mutaciones

- **Delegadas, una sola invocación:** clone efímero, backups bajo `refs/heads/backup/*`, edición mínima, tests, lint/typecheck/build/diff check, commit, rebase bottom-up si corresponde, push con `--force-with-lease` y cleanup condicionado.
- **GitHub, siempre seriales y con verificación entre pasos:** reply inline; resolución del thread; comentario y cierre de issue si aplica; comentario en PR alternativo si aplica. Nunca mutar otra capa, thread, fork o issue.

## Métricas aproximadas

- **Llamadas read-only:** 12–18, más paginación y 2 adicionales si hay issue asociada.
- **Barreras:** 5 principales (parseo/preflight, stack/ancla, selección/OIDs, resultado remoto, verificación final), más una verificación entre cada mutation serial.
- **Mutaciones seriales:** 2 para inline sin issue; hasta 5 en GitHub con issue y PR alternativo, más la fase delegada de implementación y un cleanup local final.