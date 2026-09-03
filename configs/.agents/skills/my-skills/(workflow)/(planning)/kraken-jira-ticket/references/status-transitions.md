# Máquina de estados del ticket padre

Leer esta referencia después de verificar trazabilidad bidireccional y antes de decidir o modificar estado del padre. Transiciones aplican solo al padre.

## Entradas requeridas

- `is_new_ticket`
- `current_parent_status`, obtenido con una relectura al entrar a esta máquina
- `PULL_REQUESTS`, colección canónica no obsoleta
- Estado individual de cada PR, obtenido en el paso 6 del flujo principal
- `ALL_PRS_MERGED`
- `reverse_links_verified`
- Lista actual de transiciones disponibles cuando ruta la requiera

## Precondiciones bloqueantes

No aplicar transición cuando:

- Trazabilidad Jira→PR o PR→Jira no está verificada.
- Algún estado PR no puede verificarse desde GitHub.
- Colección canonical contiene conflicto de padre.
- Campos obligatorios Jira no pasaron validación previa.

Recalcular:

```text
ALL_PRS_MERGED = PULL_REQUESTS is not empty and every state == "MERGED"
```

Nunca inferir estado desde branches, commits, labels, descripción, memoria o existencia de refs.

## Sin PR asociados

- Ticket nuevo: conservar flujo normal hasta `In Progress` si corresponde al proceso de creación.
- Ticket existente: preservar estado actual; no completar automáticamente.
- Nunca considerar colección vacía como “todos merged”.

## Existe PR no fusionado

Si cualquier PR está `OPEN` o `CLOSED` sin merge:

- Ticket nuevo debe terminar en `In Progress`.
- Ticket existente conserva estado actual; nunca retroceder.
- Padre no puede llegar a `Done`.
- Si padre ya está `Done`, no moverlo hacia atrás; reportar inconsistencia para revisión humana.

Para ticket nuevo, ruta inicial:

```text
Backlog → To Do → In Progress
```

| Acción | Transition id | Target |
|---|---|---|
| `To Do` | `331` | `To Do` (`10000`) |
| Fallback `Selected to Development` | `51` | `To Do` (`10000`) |
| `Start progress` | `71` | `In Progress` (`12834`) |

Reglas:

1. Usar `331`; si no está disponible, usar `51`.
2. `71` solo desde `To Do`.
3. Re-fetch padre después de cada transición.
4. Omitir estados ya alcanzados; nunca aplicar transición hacia atrás.
5. Si transición no llega a target esperado, detener y reportar estado real.

## Todos los PR fusionados

Solo colección no vacía con todos los estados verificados `MERGED` puede llegar a `Done`.

Ruta obligatoria:

```text
To Do → In Progress → Create New Release → Done
```

Procedimiento:

1. Leer status exacto del padre (relectura de entrada).
2. Si está antes de `To Do`, aplicar `331` (o `51` si no está disponible) y releer.
3. Si está `To Do`, aplicar `71` y releer.
4. Consultar `getTransitionsForJiraIssue` sin releer el padre: la lista de transiciones ya refleja el estado actual.
5. Elegir transición cuyo name o target status sea exactamente `Create New Release`.
6. Aplicar id retornado; nunca adivinarlo ni hardcodearlo. Releer padre.
7. Consultar transiciones disponibles.
8. Elegir transición cuyo target status sea exactamente `Done`.
9. Aplicar id retornado; nunca adivinarlo ni hardcodearlo.
10. Releer padre y bloquear finalización hasta status exacto `Done`.

Regla: releer el padre solo después de aplicar una transición; nunca dos relecturas consecutivas sin mutación entre ellas.

Si padre ya ocupa un estado de ruta, continuar desde allí. Si ya está `Done`, no aplicar transiciones; verificar únicamente coherencia con estados PR.

Nunca saltar directamente de `In Progress` a `Done`; `Create New Release` es obligatorio.

## IDs estáticos y dinámicos

- `331`, fallback `51` y `71` son IDs conocidos para estados iniciales.
- `Create New Release` y `Done` siempre deben resolverse desde transiciones disponibles del issue actual.
- No convertir nombres dinámicos en tabla estática de IDs.

## Fallos bloqueantes

Detener y reportar:

- Trazabilidad inversa no verificada.
- Estado de algún PR desconocido.
- Transición esperada ausente.
- Transition call no alcanza status esperado.
- Padre `Done` con algún PR no fusionado.
- Ruta requeriría retroceso de estado.

Reporte debe incluir status actual y nombres de transiciones disponibles, sin afirmar éxito.

## Salida para flujo principal

Devolver conceptualmente:

- Estado final verificado.
- Transiciones aplicadas, en orden.
- `transition_applied`: sí/no.
- `blocked`: sí/no.
- Motivo preciso cuando está bloqueado.

Flujo principal continúa a gate final solo cuando resultado no está bloqueado. Gate final re-fetch campos, asociaciones, backlinks, estados PR y status padre; no reinicia máquina ni repite transiciones ya verificadas.
