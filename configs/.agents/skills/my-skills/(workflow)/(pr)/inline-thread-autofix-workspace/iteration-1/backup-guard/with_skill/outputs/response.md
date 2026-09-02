# Simulación del guard de backups

## Detección

La entrada cumple el formato estricto de la skill y se clasifica como destino `inline`:

- Repositorio: `acme/widgets`
- PR fuente: `#44`
- Comentario objetivo: `discussion_r123456815`
- Único destino autorizado: el thread exacto asociado a ese comentario

En una ejecución real, el preflight conservaría el inventario de `refs/heads/backup/*` antes de cualquier mutación y separaría:

1. backups preexistentes o ajenos a esta ejecución, que nunca son candidatos a cleanup;
2. backups creados por esta ejecución, registrados junto con su OID esperado y ownership de la ejecución.

El cambio de OID de un backup propio antes del cleanup se detecta al releer las refs inmediatamente antes de la última operación local. El OID actual no coincide con el OID registrado al crear la ref, por lo que falla la comprobación de frescura/compare-and-swap. No se interpreta como permiso para adoptar el nuevo OID ni para borrar la ref.

## Transacción segura

El cleanup se ejecuta únicamente después de validaciones, publicación y closeout local, y después de comprobar también que ninguna ref está siendo usada por un worktree. La operación conceptual prepara eliminaciones condicionales para las refs propias, usando el OID registrado como `old_oid`, y las envía en una única transacción atómica con `git update-ref --stdin`.

Ante el mismatch detectado:

- la transacción completa se aborta; no se intenta borrar solo las refs que todavía coinciden;
- la ref propia cuyo OID cambió queda preservada;
- todos los demás backups de la ejecución también quedan preservados, porque cualquier error de cleanup conserva el conjunto completo;
- los backups preexistentes o ajenos no entran en la transacción y permanecen intactos;
- no se usa `--force`, `reset --hard`, `clean -fd`, ni una eliminación sin OID esperado;
- no se publican nombres de refs ni OIDs en el closeout.

El resultado seguro es `BACKUP_CLEANUP_FAILED`, con backups retenidos. El flujo no puede afirmar éxito integral: bloquea el closeout del thread, cualquier cierre de issue y cualquier comentario final que dependa de un resultado completo. La salida debe indicar la falla explícitamente y conservar el clone/recursos necesarios para recuperación, sin invocar el backend una segunda vez en la misma ejecución.

## Resultado simulado

```text
status: failure
code: BACKUP_CLEANUP_FAILED
backups: preservados; 0 eliminados
foreign_backups: intactos
changed_backup_ref: preservada
closeout: bloqueado
retry_in_same_execution: no permitido
```

Esto satisface el objetivo de finalizar de forma segura: la ejecución no borra backups ajenos ni la ref cuyo OID cambió, y tampoco oculta el fallo presentándolo como `BACKUPS_CLEANED`.

## Métricas aproximadas

### Flujo hipotético

- Refs propias verificadas antes del cleanup: 1 o más, según el inventario real.
- Mismatches de OID detectados: 1.
- Transacciones de cleanup intentadas: 1.
- Transacciones de cleanup confirmadas: 0.
- Refs eliminadas: 0.
- Backups ajenos/preexistentes tocados: 0.
- Refs propias preservadas por seguridad: 100%.
- Closeouts remotos ejecutados después del fallo: 0.

### Esta evaluación read-only

- Comandos Git ejecutados: 0.
- Consultas o mutaciones de GitHub ejecutadas: 0.
- Refs reales modificadas o eliminadas: 0.
- Único archivo escrito: el archivo de salida solicitado.
