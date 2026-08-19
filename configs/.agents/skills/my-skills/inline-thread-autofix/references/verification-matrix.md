# Matriz de verificación

## GitHub y thread

| Verificación | Resultado requerido |
|---|---|
| URL | owner/repo/PR/comment ID validados |
| PR | estado `OPEN`, branch y head conocidos |
| Comentario | body, path, line y commit de origen leídos |
| Thread | `isResolved: false` antes del trabajo |
| Duplicados | no existe reply previo del usuario para este comment ID |
| Push | head remoto coincide con SHA completo del fix |
| Reply | creado con `in_reply_to` y SHA que pertenece al PR |
| Resolve | `isResolved: true` después del reply |

## Código

| Verificación | Cuándo |
|---|---|
| `git status` limpio | antes de editar o árbol aislado |
| instrucciones del repo | siempre |
| diff focal | antes de stage |
| `git diff --check` | antes de commit |
| typecheck | proyectos tipados |
| lint/format | cuando lo defina el repo |
| tests focales | siempre que cambie comportamiento |
| suite completa | antes de closeout si el tiempo/tooling lo permite |
| build/runtime | cuando exista o el cambio lo requiera |

## Reglas de parada

Detener sin commit/push/reply/resolve si:

- el link no es un inline comment válido;
- el PR está cerrado/mergeado o el comentario ya está resuelto;
- el árbol contiene cambios ajenos y no hay aislamiento seguro;
- la sugerencia no es reproducible o requiere una decisión funcional no dada;
- typecheck, tests o build fallan sin causa preexistente demostrada;
- el SHA publicado no coincide con el head remoto;
- reply o resolución no pueden dirigirse inequívocamente al thread.

No usar `git reset --hard`, `git clean -fd`, `git push --force`, `--force` en uploads ni desactivar tests como recuperación.
