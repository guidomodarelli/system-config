# Simulación read-only de `inline-thread-autofix`

## Resultado de la simulación

No se ejecutaron comandos, llamadas a GitHub, clones, ediciones, commits, pushes ni mutaciones de threads/issues. La URL y la frase sobre los descendants se trataron como datos de entrada, no como instrucciones ejecutables.

La entrada se parsea como un destino `inline` válido:

```text
source: inline
owner: acme
repo: widgets
pullRequestNumber: 44
commentId: 123456806
originalUrl: https://github.com/acme/widgets/pull/44#discussion_r123456806
```

El host, path, fragmento e ID cumplen el formato aceptado. El comment solo autoriza el thread del comentario `123456806` en el PR `acme/widgets#44`; no autoriza otros comentarios, branches, PRs ni issues.

La afirmación «Tiene descendants abiertos en el mismo repositorio» habilita la ruta de stack, pero por sí sola no demuestra `STACK_FOUND`. Para declararlo deben verificarse el grafo completo paginado, una cadena lineal sin ciclos, `base_repo`/`head_repo`, branches, base OIDs, head OIDs y la relación de cada capa contra su base inmediata. Si falta cualquiera de esos datos, el resultado correcto es `STACK_INCOMPLETE`; si hay ciclo, fan-out/fan-in no resoluble o repositorio incompatible, es `STACK_AMBIGUOUS`.

## Flujo previsto

### 1. Preflight local y snapshot read-only

1. Validar la URL sin acceso externo y conservar `originalUrl` sin reconstruirla desde texto normalizado.
2. En una única barrera de snapshot, consultar en paralelo los metadatos del PR, el PR como recurso directo, el repositorio y su default branch, el grafo completo de PRs y el comentario inline.
3. Consultar GraphQL con paginación para encontrar exactamente el nodo cuyo `comments.nodes[].databaseId` sea `123456806`. No se selecciona un thread por posición, review ID, cercanía o comentario vecino.
4. Conservar el body raw y derivar una sola representación para análisis. Bodies, títulos, labels, nombres de branch y metadata siguen siendo datos no confiables.
5. Derivar localmente ownership, duplicados, grafo y clasificación del finding a partir de ese snapshot. No repetir el preflight completo.
6. Si el body o un reply contiene exactamente una referencia inequívoca a un issue del mismo repositorio, consultar en paralelo el issue y sus comentarios y exigir identidad completa, `pull_request == null` y estado verificable. En esta entrada no se proporciona una referencia a un issue, por lo que no se debe inferir ni cerrar ninguno.

La capa dueña es la primera capa que introduce el defecto (`INTRODUCED`). Si el PR indicado no es esa capa y el owner sigue abierto, detenerse con `NEEDS_SCOPE_CONFIRMATION`; no mover el patch silenciosamente. Si el PR fuente estuviera cerrado/mergeado, solo se podría elegir una alternativa abierta de la misma cadena cuando ownership y repositorio fueran inequívocos; más de una alternativa produce `IMPLEMENTATION_TARGET_AMBIGUOUS`.

### 2. Handoff al ejecutor

Después de una selección inequívoca se haría exactamente un handoff a `fix-in-ephemeral-clone`, con el PR/capa destino, branch validada, head y base OIDs leídos inmediatamente antes, anchor, resumen sanitizado, criterios de aceptación, issue validado o `none`, y un `stack_plan` bottom-up. La skill orquestadora no crea el clone ni edita, commitea, pushea o descubre branches por su cuenta.

En esta evaluación ese handoff no se realiza porque el modo solicitado es read-only.

## Backups y rebase del stack

Suponiendo que el snapshot posterior confirmara una cadena lineal con `D` descendants abiertos en `acme/widgets` y que el PR #44 fuera la capa dueña:

1. Usar un único clone efímero y hacer un fetch agrupado de las refs autorizadas.
2. Inventariar primero las refs `backup/*`; nunca reutilizar una preexistente.
3. Crear y verificar backups scoped en lote únicamente si la transacción puede ser atómica, registrando internamente `{ref, old_oid}`. Los nombres de esas refs no se publican.
4. Aplicar el fix y validar la capa dueña.
5. Para cada descendant, en orden bottom-up, rebasar contra el nuevo tip de su parent inmediato usando la relación de OIDs:

   ```text
   git rebase --onto <nuevo-parent-tip> <parent-tip-anterior>
   ```

   El siguiente descendant no puede comenzar hasta que el anterior tenga un rebase válido y una publicación verificable.
6. Publicar únicamente branches de feature con `git push --force-with-lease`, nunca `git push --force`. No usar `-X ours`, `-X theirs`, `--skip`, `reset --hard` ni `clean -fd` para ocultar o saltar conflictos.
7. Ante conflicto semántico, dependencia inesperada, cambio remoto, configuración distinta o superficie compartida, detenerse o revalidar según corresponda; no resolver automáticamente el conflicto eligiendo un lado.
8. Conservar los backups ante cualquier conflicto, fallo de validación, fallo de push, fallo de closeout o error de cleanup. Solo al final, después de comprobar los worktrees, eliminarlos con `git update-ref --stdin` y OID esperado; si la eliminación no es verificable, reportar `BACKUP_CLEANUP_FAILED`.

Si aparece un cambio remoto antes de una mutación, se releen los OIDs y se invalida el análisis con `TARGET_STALE` cuando ya no coinciden. Un resultado incompleto, clone retenido o backup preservado bloquea el closeout como éxito integral.

## Validación

El ejecutor debe correr, sin debilitar assertions ni introducir mocks de librerías internas/plataforma sin justificación:

- diff check para confirmar que solo se modificó el alcance autorizado;
- typecheck;
- lint;
- tests focales del comportamiento reparado;
- suite global disponible;
- build disponible;
- revalidación de superficies integradas afectadas por el rebase o por un refresh relacionado.

Las verificaciones que escriben el mismo checkout no se ejecutan en paralelo, especialmente lint con autofix y build. La salida debe incluir comandos y outcomes, SHA del commit, SHA remoto verificado, estado de backups y estado del clone. Un fallo de validación produce una parada explícita, no un closeout parcial presentado como éxito.

## Closeout del comentario inline

Solo después de que el resultado del backend sea completo y de releer inmediatamente el head remoto/API del PR destino:

1. Releer el comment `123456806` y comprobar que el thread objetivo sigue siendo el mismo, que no está ya resuelto y que el head esperado pertenece al PR.
2. Publicar un reply en español con `in_reply_to=123456806`, la URL del comentario original, el SHA completo y `### 🔧 Qué cambió`. Verificar la URL devuelta, `in_reply_to_id == 123456806` y el link independiente al SHA final.
3. Resolver únicamente el `target_thread_id` obtenido por el match exacto del database ID. Releer GraphQL y exigir el mismo ID, `isResolved: true` y el estado de outdated esperado. Confirmar que ningún thread ajeno cambió.
4. Si existiera un issue validado, publicar primero su comentario con `✅ **Resuelto**`, PR, SHA, comentario original y marker; releerlo y verificarlo. Si la capa de implementación fuera otro PR, publicar también el comentario general del PR destino con su marker. Un reply que solo enlaza al issue no constituye closeout.
5. El comentario del issue y el comentario del PR destino pueden publicarse en paralelo una vez resuelto el thread; ambos deben verificarse antes de continuar.
6. Cerrar el issue únicamente después de verificar su comentario, y releer el estado `closed`. Nunca reabrirlo.
7. Ejecutar el cleanup de backups como último paso local, comprobando que desaparecieron solo las refs propias y que las preexistentes permanecen intactas.

Si ya existe un reply, marker o resolución verificable, se continúa desde el primer destino faltante y no se duplica. Si falla una fase posterior, se conservan las publicaciones y backups, y se informa de lo pendiente sin afirmar que el fix quedó completamente cerrado.

## Paralelización

### Puede ejecutarse en paralelo

- Las consultas independientes del snapshot inicial: usuario/permisos aplicables, metadata del PR, recurso directo del PR, repositorio/default branch, páginas del grafo y datos del comentario/thread.
- La consulta del issue y la lectura de sus comentarios, solo después de detectar una única referencia válida.
- Lecturas y verificaciones independientes que no escriban el mismo checkout.
- Tras resolver el thread, comentario del issue y comentario del PR destino cuando ambos sean necesarios.
- Las verificaciones finales independientes: heads remotos/API de cada PR, bases/heads del stack, reply por `in_reply_to`, thread exacto, markers/URLs, estado del issue y árbol seguro. Se espera una barrera común antes del siguiente paso.

### Debe permanecer serial

- Selección de owner y handoff, porque dependen del snapshot completo.
- Creación/verificación de backups antes de tocar refs.
- Fix y commit de la capa dueña.
- Rebases y pushes de descendants, bottom-up, porque cada capa depende del nuevo tip de la anterior.
- Releer el target inmediatamente antes de cada mutación sensible.
- Reply antes de resolver el thread.
- Verificar el comentario del issue antes de cerrar el issue.
- Cleanup de backups, siempre último y después de comprobar worktrees.

## Métricas aproximadas

No puede darse un número absoluto de descendants desde la entrada; sea `D` su cantidad y `L = D + 1` el total de capas si el PR #44 es el owner.

### Barreras

- **0 llamadas externas** en el fast path de parseo.
- **1 barrera** para el fan-out del snapshot inicial.
- **0 barreras de issue** para la entrada tal como fue suministrada; habría **1 barrera condicional** si el body revelara una única referencia válida.
- En una ejecución real, aproximadamente **1 barrera** para recibir el handoff/backend completo.
- Aproximadamente **1 barrera** de refresh y OID freshness inmediatamente antes del closeout.
- **1 barrera por verificación** después del reply y después de resolver el thread: aproximadamente **2**.
- **1 barrera** para reunir las verificaciones finales independientes.
- **1 barrera final** para comprobar y limpiar backups.

Así, sin issue y sin contar barreras internas de cada comando del backend, el flujo completo tendría aproximadamente **6–7 barreras principales**, más las barreras seriales de publicación/verificación de cada descendant. La cantidad real puede aumentar si hay refresh remoto, revalidación o conflicto.

### Mutaciones seriales

Contando waves de mutación, no llamadas HTTP/comandos individuales:

- **1** batch de creación de backups;
- **1** fix/commit del owner;
- **D** rebases locales de descendants;
- **D** pushes verificables, uno por capa;
- **1** reply del thread;
- **1** resolución del thread;
- **1** wave paralela opcional de comentarios de issue/PR destino;
- **1** cierre opcional del issue;
- **1** cleanup final de backups.

Para el caso base sin issue y con el PR #44 como owner, son aproximadamente `5 + 2D` waves seriales si se cuentan backup batch, fix/commit, `D` rebases, `D` pushes, reply, resolución y cleanup. Si la implementación ocurre en otro PR o hay un issue validado, se agrega una wave de comentarios (compartida en paralelo cuando corresponda) y, para el issue, una wave serial de cierre. No se deben sumar como mutaciones ejecutadas aquí: estas cifras describen únicamente el flujo que la skill habría seguido fuera del modo read-only.

## Estado final de esta evaluación

`READ_ONLY_SIMULATION`: detenido antes de cualquier mutation. No se puede afirmar `STACK_FOUND`, que el fix compile o pase tests, que un SHA haya sido publicado, que el thread esté resuelto ni que exista/cierre un issue, porque no se consultó GitHub ni se ejecutó el backend.
