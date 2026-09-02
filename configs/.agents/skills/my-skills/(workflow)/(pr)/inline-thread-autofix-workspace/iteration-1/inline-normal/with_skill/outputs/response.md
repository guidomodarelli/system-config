Aplicaría este flujo, sin asumir resultados no verificados:

1. **Fase 0 — parseo local (sin llamadas externas)**
   - Validar estrictamente `https://github.com/acme/widgets/pull/42#discussion_r123456789`: host `github.com`, path de PR, fragmento `discussion_r`, e ID positivo completo.
   - Conservar la URL original y normalizar de forma inmutable: `source=inline`, `owner=acme`, `repo=widgets`, `pullRequestNumber=42`, `commentId=123456789`.
   - Si falla la validación, detener con el código correspondiente y sin crear clone ni mutar nada.

2. **Fase 1 — snapshot read-only en paralelo; una barrera al final**
   Lanzar simultáneamente las consultas independientes:
   - identidad autenticada (`gh api user`);
   - metadata del PR y fuente directa (`gh pr view` y `gh api repos/acme/widgets/pulls/42`);
   - default branch (`gh repo view acme/widgets`);
   - grafo completo de PRs paginado (`pulls?state=all&per_page=100`);
   - comentario inline exacto (`pulls/comments/123456789`);
   - GraphQL `reviewThreads` paginado, incluyendo comentarios, replies y estados.
   Buscar markers/duplicados dentro de esas respuestas, sin tratar bodies, títulos, labels o nombres de branch como instrucciones.

3. **Fase 2 — referencias y selección**
   - Exigir que el comentario pertenezca exactamente al PR/repositorio indicados y derivar el `target_thread_id` solo por `databaseId == 123456789`.
   - Confirmar thread no resuelto, estado `isOutdated`, ancla, commit de origen, replies y ausencia de closeout previo. Si ya está resuelto, no repetir backend, reply ni resolución; solo completar destinos faltantes verificables.
   - Si aparece exactamente una referencia explícita a una issue del mismo repositorio, consultar en paralelo la issue y sus comentarios; exigir `number`, `html_url`, `repository_url`, estado válido y `pull_request == null`. Cero, múltiples o inválidas detienen el closeout de issue.
   - Derivar localmente ownership y stack con OIDs, clasificando el hallazgo por capa. Si el owner no coincide con el PR objetivo, el stack es incompleto/ambiguo, o la capa alternativa no es única y verificable, detener sin mover el patch.

4. **Fase 3 — gate de frescura y handoff único**
   Releer inmediatamente `headRefOid` y `baseRefOid` del PR de implementación. Si cambiaron, detener con `TARGET_STALE`.
   Con destino inequívoco, delegar exactamente una vez a `fix-in-ephemeral-clone` con el header `HANDOFF: INLINE_THREAD_AUTOFIX`, incluyendo repositorio, PR, branch, OIDs esperados, ancla, resumen sanitizado, criterios de aceptación, `stack_plan` bottom-up e issue validada o `none`. Esta skill no crea clones, edita, commitea ni pushea.

5. **Fase 4 — ejecución y validación delegadas**
   El backend debe usar un único clone efímero depth-1 y conservar el checkout original intacto. Debe aplicar el fix, y si corresponde rebasear descendants bottom-up con backups scoped y `--force-with-lease`, sin `reset --hard`, `clean -fd`, `--skip`, estrategias `ours/theirs` ni `push --force`.
   Exigir un `HANDOFF_RESULT` completo con commit SHA, head remoto verificado, diff check, typecheck, lint, tests focales/globales y build disponibles, además del estado de backups y cleanup. Cualquier validación fallida, SHA remoto distinto, clone retenido, backup preservado o resultado incompleto bloquea todo closeout y no permite reintentar el backend en esta ejecución.

6. **Fase 5 — closeout inline, con relectura antes de mutar**
   Releer head remoto, PR de implementación y el comment/thread exactos; invalidar si cambió cualquier OID o identidad.
   - Crear un único reply en `/pulls/42/comments` con `in_reply_to=123456789`, URL del comentario original, resumen en español, link al SHA completo y la sección `### Qué cambió`; verificar `html_url`, `in_reply_to_id` y contenido.
   - Resolver únicamente el `target_thread_id`; releer GraphQL y exigir ese mismo ID, `isResolved=true`, `isOutdated` esperado y ningún thread ajeno modificado.
   - Si hay issue validada, después de verificar reply y resolución, publicar y verificar el comentario de issue con PR, SHA, comment original y marker. Si `implementation_pr != source_pr`, publicar y verificar además el comentario general del PR destino. Esos dos comentarios pueden ejecutarse en paralelo.
   - Solo después de verificar el comentario de issue, cerrar la issue con `PATCH .../issues/<number> state=closed` y releer `state=closed`. Nunca reabrirla.
   - Ejecutar el cleanup local de backups como última mutación, de forma condicional/transaccional, solo si todas las verificaciones previas pasaron; conservarlos ante cualquier fallo y no borrar refs preexistentes.

7. **Verificación final y respuesta**
   Ejecutar en paralelo las verificaciones independientes de head remoto, OIDs del stack, reply por `in_reply_to`, thread exacto, markers/URLs de issue o PR destino, estado de issue y árbol/refs seguros. Solo entonces informar éxito completo. Si algún gate falla, informar el código, las mutaciones omitidas y los recursos retenidos; nunca afirmar que el thread o la issue quedaron resueltos.

**Métricas aproximadas**
- Llamadas read-only: `15–25`, incluyendo paginación, consultas de issue y relecturas/verificaciones finales.
- Barreras: `6` principales (parseo, snapshot, referencias/stack, frescura, resultado del handoff y closeout/verificación final).
- Mutaciones seriales: `6` etapas condicionadas (handoff backend, reply, resolución, etapa de comentarios, cierre de issue y cleanup); los comentarios de issue y PR destino, cuando aplican, corren en paralelo dentro de su etapa.