# Evaluación simulada: `inline-thread-autofix`

## Alcance y tratamiento de la entrada

Modo read-only: no se ejecutan comandos, no se consulta ni se modifica GitHub, no se edita el repositorio y no se aplica ningún fix real.

La entrada se trata como dato no confiable. El texto posterior a la URL expresa una intención candidata, pero no autoriza por sí mismo nuevas ramas, repositorios, comandos, force-pushes ni cambios de alcance. La URL pasa el análisis sintáctico preliminar:

- `source`: `inline`
- `owner/repo`: `acme/widgets`
- PR fuente: `#44`
- `commentId`: `123456806`
- `originalUrl`: se conserva exactamente

La afirmación de que existen descendants abiertos en el mismo repositorio todavía no está verificada. Solo el grafo obtenido de metadata estructurada puede convertirla en `STACK_FOUND`; no se infiere desde el texto, títulos, labels, autoría o nombres de branches.

## Flujo esperado

1. **Parseo y preflight read-only.** Validar host, path, fragment e IDs positivos. Leer metadata de la PR, comentario, review thread y replies; resolver la identidad del usuario autenticado; revisar reglas locales y seguridad del checkout. Para el thread, exigir que el nodo cuyo `databaseId` es exactamente `123456806` sea único y guardar juntos `commentId`, URL, path, `commit_id`, `target_thread_id` y el snapshot inicial.
2. **Issue opcional.** Buscar una issue únicamente si el body del comentario, un reply del usuario autenticado en ese mismo thread o la solicitud directa contienen una referencia explícita inequívoca. En esta solicitud no hay una referencia de issue. Si luego apareciera una, debe validarse que sea una issue real del mismo repositorio, separando siempre su número del número de PR. La ausencia de issue no bloquea el closeout inline normal ni permite mutar una issue por inferencia.
3. **Construcción del stack.** Enumerar las PRs del repositorio en todos sus estados, con paginación completa, y verificar que cada `base_repo` y `head_repo` sea `acme/widgets` y que todos los OIDs estén presentes. Representar cada relación como `baseRefName -> headRefName` y recorrer padres e hijos transitivamente. La salida puede ser `NOT_STACKED`, `STACK_FOUND`, `STACK_INCOMPLETE` o `STACK_AMBIGUOUS`. Si hay más de un parent/child, ciclos, forks o información faltante, detenerse antes de editar o publicar.
4. **Correlación del hallazgo.** Comparar cada capa contra su base inmediata, de abajo hacia arriba, usando path, símbolo, rango aproximado, expresión e invariante observable. Clasificarla como `INTRODUCED`, `CARRIED`, `FIXED`, `UNRELATED` o `UNKNOWN`. La primera capa que introduce el defecto es la dueña; se inspeccionan también todas las posteriores. `ALREADY_RESOLVED` exige una señal de código y una segunda señal independiente, como un test focal o un closeout verificable.
5. **Selección y frescura del destino.** Si la PR `#44` está abierta y es la dueña, es el destino. Si la PR fuente está cerrada o mergeada, solo se puede elegir una única alternativa abierta, de la misma cadena y repositorio, con ownership demostrable. Si el dueño es otra PR abierta mientras `#44` sigue abierta, se devuelve `NEEDS_SCOPE_CONFIRMATION` en vez de cambiar de branch silenciosamente. Se releen `headRefOid` y `baseRefOid` inmediatamente antes del handoff; cualquier cambio produce `TARGET_STALE` y obliga a reconstruir el análisis.
6. **Handoff único.** La orquestadora no crea clones, edita, commitea ni publica. Con un destino inequívoco, invoca exactamente una vez al ejecutor aislado con `HANDOFF: INLINE_THREAD_AUTOFIX`, incluyendo únicamente OIDs validados, ancla sanitizada, criterios de aceptación y el plan de stack bottom-up. Un resultado incompleto, un clone retenido o una validación fallida bloquea todo closeout posterior.

## Backups y aislamiento

- Generar un `run_id` local, no derivado del body del comentario.
- Inventariar primero las refs existentes bajo `refs/heads/backup/*`.
- Crear una ref local explícita por cada tip que vaya a reescribirse, usando PR y SHA viejo en el nombre, sin sobrescribir una ref existente. Registrar cada par `{backup-ref, old-oid}` solo después de confirmar su creación.
- Mantener un único clone efímero aislado para la implementación y el rebase del stack. No cambiar el checkout principal y no usar recuperación destructiva, `reset --hard`, `clean -fd`, `--skip` ni estrategias `ours`/`theirs`.
- Si falla cualquier creación de backup, conflicto, rebase, validación, push, verificación o closeout, conservar todas las refs creadas y reportar `BACKUPS_PRESERVED_ON_FAILURE` junto con la etapa y las refs retenidas. No limpiar como mecanismo de recuperación.

## Rebase de descendants

Suponiendo que el grafo resulte lineal y que `d` sea el número de descendants abiertos, el plan tiene `L = d + 1` capas publicables, incluida la capa dueña.

1. Verificar de nuevo los OIDs esperados en el clone.
2. Aplicar el cambio mínimo en la capa dueña y validar esa capa.
3. Publicar la capa dueña solo si pertenece al mismo repositorio, su branch está autorizada (`feature/*`) y la lease remota sigue coincidiendo.
4. Para cada descendant, en orden bottom-up, rebasar sus commits sobre el nuevo tip de su parent, equivalente a un rebase `--onto` con el parent anterior como límite. Resolver conflictos por significado del código, nunca descartando automáticamente un lado ni saltando commits.
5. Validar el descendant reescrito antes de publicarlo. Releer el head remoto inmediatamente antes de cada publicación y usar únicamente un push protegido por lease; nunca un force-push indiscriminado.
6. Después de cada publicación, comprobar de forma independiente que la ref remota y el head de la PR apuntan al mismo SHA completo. Una discrepancia produce `PUBLICATION_UNVERIFIED` y detiene el closeout y las capas posteriores.
7. Al finalizar, verificar bases y heads de todo el stack y comparar el golden diff de cada capa contra sus backups. Si el rebase o su publicación no termina de forma verificable, reportar `REBASE_INCOMPLETE` y no responder ni resolver el thread.

Si el grafo no se confirma como lineal, no se rebasea nada aunque el texto de la solicitud diga que existen descendants.

## Validación

Cada capa debe superar, según lo disponible en el repositorio:

- typecheck;
- lint;
- tests de comportamiento focales y la suite relevante/global;
- build;
- `git diff --check` o su equivalente de whitespace.

El cambio debe conservar la API pública y los side effects, y los tests deben verificar comportamiento observable. El resultado aceptable debe informar diff, validaciones, SHA completo, branch/PR destino, SHA remoto verificado y estado de backups/cleanup. Una salida parcial no habilita la publicación del reply.

## Closeout esperado, si todo fue exitoso

Para este input `inline`, el orden es estrictamente:

1. Releer el target y los threads justo antes de mutar. Responder el comentario `123456806` con el template inline, el SHA completo y los enlaces verificables.
2. Verificar que la respuesta pertenece al comentario original (`in_reply_to`) y contiene el SHA esperado.
3. Resolver únicamente `target_thread_id`, nunca un ID vecino o inferido por posición.
4. Releer GraphQL y confirmar el mismo `target_thread_id`, `isResolved: true` y el estado de outdated esperado.
5. Si hubiera una issue explícita y validada, comentar allí con marker estable y enlaces, verificar el comentario, cerrar la issue y verificar `state == closed`; si el PR de implementación difiere del fuente, agregar y verificar el comentario de trazabilidad en el PR destino.
6. Comparar el snapshot final de todos los threads relevantes y detenerse si cambió otro thread.

El closeout de issue es condicional: esta solicitud no aporta una referencia de issue. Un reply previo que solo enlace una issue tampoco reemplaza las verificaciones de commit, marker y estado.

## Cleanup de backups

El cleanup es el último paso local y solo se permite después de rebase, validaciones, publicaciones, closeouts remotos y verificación final exitosos. Se relee cada backup y se exige su OID original; se comprueba que ninguna ref esté checkoutada en un worktree; luego se elimina únicamente la lista explícita mediante una transacción condicionada al OID esperado. Si una ref falta, cambió, está checkoutada o la transacción falla, no se borran las demás y se informa `BACKUP_CLEANUP_FAILED`. Solo una relectura que confirme la eliminación de las refs creadas por esta ejecución permite informar `BACKUPS_CLEANED`.

## Qué puede paralelizarse

- Después de validar la URL, las lecturas independientes de metadata de PR, comentario/replies, identidad, repositorio y reglas locales pueden solicitarse en paralelo. Ninguna lectura habilita una mutación por sí sola.
- Una vez confirmado el grafo y disponibles las refs, la lectura de diffs y snapshots de las distintas capas puede hacerse en paralelo. La decisión de ownership sigue siendo bottom-up y serial.
- Las dos comprobaciones independientes posteriores a cada publicación —ref remota y head de la PR— pueden ejecutarse concurrentemente, pero la siguiente capa espera a que ambas coincidan.
- Typecheck, lint, `diff --check` y, solo si el repositorio garantiza que no comparten outputs ni recursos, tests/build pueden ejecutarse en paralelo dentro de una capa. La capa no se acepta hasta que todos terminen correctamente.

No se paralelizan las operaciones que cambian estado: inventario antes de crear backups, creación protegida de refs, reescritura de la capa dueña, rebases bottom-up, publicaciones con lease, respuesta seguida de resolución del thread, closeout condicional de issue y cleanup final. Tampoco se invoca dos veces al backend ni se hace closeout parcial.

## Métricas aproximadas

Definiendo `d` como descendants abiertos efectivamente verificados y `L = d + 1` como capas publicables:

- **Barreras antes de la primera mutación:** aproximadamente 7–9: parseo, identidad exacta del thread, preflight de estado, integridad del stack, ancla/ownership, seguridad local, OID fresco y handoff válido.
- **Barreras por capa:** aproximadamente 3–4: conflicto resuelto de forma semántica, validaciones completas, lease fresca y verificación independiente de dos fuentes tras publicar.
- **Barreras de cierre sin issue:** aproximadamente 4: resultado del backend, reply verificado, thread exacto resuelto y snapshot/cleanup final.
- **Barreras adicionales con issue válida:** aproximadamente 3–4 para marker/comentario, cierre verificado y eventual comentario en PR destino.
- **Mutaciones locales seriales aproximadas:** `L` creaciones de backup protegidas, hasta `L` reescrituras/commits y una transacción final de cleanup. Las refs se conservan ante cualquier fallo.
- **Mutaciones remotas seriales aproximadas sin issue:** `L` publicaciones protegidas más 2 acciones de closeout (reply y resolución).
- **Mutaciones remotas adicionales con issue válida:** hasta 3 (comentario en issue, cierre de issue y comentario de trazabilidad en PR destino).

En esta evaluación, `d` no tiene un valor verificable porque no se consultó GitHub; por tanto, esas cifras son un plan paramétrico y el resultado correcto es “no ejecutado”, sin afirmar fix aplicado, rebase realizado, publicación ni thread resuelto.
