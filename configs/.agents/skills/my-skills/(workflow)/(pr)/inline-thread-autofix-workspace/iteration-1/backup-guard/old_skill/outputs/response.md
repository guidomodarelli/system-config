# Simulación de evaluación: guard de backups

## Alcance

La entrada se parsea como un inline comment válido:

- `source`: `inline`
- `owner/repo`: `acme/widgets`
- `pullRequestNumber`: `44`
- `commentId`: `123456815`
- `originalUrl`: `https://github.com/acme/widgets/pull/44#discussion_r123456815`

Esta es una simulación read-only. No se ejecutaron comandos, no se consultó GitHub y no se modificó ninguna ref real.

## Estado hipotético antes del cleanup

Se asume que una ejecución previa del flujo terminó sus validaciones y registró explícitamente sus propias refs locales bajo `refs/heads/backup/*`:

| Ref | Propietario | OID esperado | OID observado al iniciar cleanup |
|---|---|---|---|
| `refs/heads/backup/<run-id>/pr-44/<oid-a>` | esta ejecución | `<oid-a>` | `<oid-b>` |
| `refs/heads/backup/<run-id>/pr-44/<oid-c>` | esta ejecución | `<oid-c>` | `<oid-c>` |
| `refs/heads/backup/other-run/pr-12/<oid-x>` | ejecución ajena | no registrada | `<oid-x>` |

La primera ref propia fue alterada entre su creación y el cleanup: su OID pasó de `<oid-a>` a `<oid-b>`. El cambio no se trata como autorización para borrar la ref ni como una ref nueva de esta ejecución.

## Detección

1. El cleanup relee cada `backup-ref` de la lista registrada junto con su `old-oid` esperado.
2. Detecta que `refs/heads/backup/<run-id>/pr-44/<oid-a>` ya no conserva `<oid-a>`.
3. La precondición de identidad falla (`observed_oid != expected_old_oid`), por lo que el cleanup se detiene con `BACKUP_CLEANUP_FAILED`.
4. La ref de `other-run` no se incluye en la lista registrada y no se considera candidata. No se usa un glob como `backup/*`, ni un borrado sin OID esperado.

La detección ocurre antes de aceptar cualquier resultado `BACKUPS_CLEANED`. La ref cambiada se conserva porque ya no puede demostrarse que el valor actual sea el backup que esta ejecución creó.

## Transacción

La operación permitida, si todas las precondiciones fueran válidas, sería una transacción `git update-ref --stdin` con únicamente las refs propias registradas y órdenes equivalentes a:

```text
delete <backup-ref-propia-1> <oid-a>
delete <backup-ref-propia-2> <oid-c>
prepare
commit
```

En este escenario, la transacción no debe llegar a `commit`: el chequeo previo de OID aborta antes de construirla. Incluso si una implementación la construyera para aprovechar el guard de compare-and-delete, la primera orden exigiría `<oid-a>` y no podría borrar la ref que ahora contiene `<oid-b>`; la preparación/commit debe rechazarse de forma atómica. No se degrada a borrar las refs que sí coinciden.

Consecuencias transaccionales seguras:

- no se borra la ref propia cuyo OID cambió;
- no se borra la otra ref propia coincidente de manera parcial;
- no se borra la ref ajena preexistente;
- no se ejecuta `git update-ref -d` sin OID esperado;
- no se reintenta con un listado global ni se fuerza la eliminación.

## Resultado seguro

```text
status: BACKUP_CLEANUP_FAILED
backups: BACKUPS_PRESERVED_ON_FAILURE
retained:
  - refs/heads/backup/<run-id>/pr-44/<oid-a> (esperaba <oid-a>, encontró <oid-b>)
  - refs/heads/backup/<run-id>/pr-44/<oid-c> (preservada por atomicidad)
  - refs/heads/backup/other-run/pr-12/<oid-x> (ajena, intacta)
```

La ejecución no afirma `BACKUPS_CLEANED` ni cierre integral. Si los closeouts remotos ya hubieran sido verificados antes de este último paso, se reportarían únicamente sus URLs ya publicadas y el cleanup pendiente; no se publicaría un comentario compensatorio ni se haría otra mutación de GitHub. En esta evaluación no existen URLs publicadas porque GitHub no fue consultado.

## Métricas aproximadas de la simulación

- Refs inspeccionadas: `3`
- Refs propias registradas: `2`
- Refs ajenas detectadas y protegidas: `1`
- Refs propias con OID cambiado: `1`
- Transacciones confirmadas: `0`
- Refs borradas: `0`
- Borrados parciales: `0`
- Refs ajenas tocadas: `0`
- Mutaciones GitHub/comandos ejecutados: `0`
- Retención de backups tras el fallo: `100%`
