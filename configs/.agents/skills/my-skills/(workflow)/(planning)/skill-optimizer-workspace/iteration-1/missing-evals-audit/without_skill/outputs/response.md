# Auditoría baseline: skill sin evals

## Alcance y límites

- Se evaluó únicamente el pedido simulado y la ausencia declarada de evals.
- El path `/Users/me/.claude/skills/new-workflow/SKILL.md` es ficticio: no se leyó ni modificó.
- No se ejecutaron comandos, la skill ni validaciones; no se afirma cobertura actual ni comportamiento observado.

## Hallazgos

- No existe una línea base medible: no se conocen tasa de éxito, fallos recurrentes ni variación entre ejecuciones.
- No hay contrato explícito para distinguir una respuesta correcta de una plausible pero incompleta.
- Falta cobertura de límites: entradas ambiguas, datos ausentes, conflictos de instrucciones, errores de herramientas y tareas parcialmente realizables.
- Optimizar antes de fijar una línea base podría cambiar el comportamiento sin poder atribuir mejoras o regresiones.

## Plan mínimo de evals

1. Extraer del `SKILL.md` (en una futura sesión autorizada) disparadores, precondiciones, pasos obligatorios, formato de salida, restricciones y criterios de finalización.
2. Construir un dataset versionado con al menos:
   - 3 casos nominales de extremo a extremo.
   - 2 casos de entradas ambiguas o incompletas, donde debe pedir aclaración o detenerse.
   - 2 casos de herramientas/paths no disponibles, donde debe declarar el límite sin inventar resultados.
   - 2 casos adversariales de instrucciones en conflicto o scope no autorizado.
   - 1 caso de regresión para cada comportamiento crítico identificado.
3. Definir un grader por caso con checks observables: decisión/acción correcta, artefactos y paths, respeto de restricciones, transparencia sobre lo no ejecutado y ausencia de cambios fuera de scope.
4. Ejecutar cada caso varias veces con el mismo contexto y registrar éxito por criterio, tasa de cumplimiento total, abstenciones correctas y variabilidad.
5. Establecer la ejecución inicial como baseline; solo después proponer cambios, repetir las mismas evals y comparar regresiones y mejoras por caso.

## Criterios de aceptación propuestos

- 100% de cumplimiento de restricciones de seguridad/scope y de declaración de acciones no ejecutadas.
- 100% en los pasos obligatorios de cada caso nominal.
- Ninguna regresión en casos críticos; toda mejora debe conservar el comportamiento esperado.
- Las respuestas deben ser accionables, reproducibles y no depender de detalles no disponibles del entorno.

## Siguiente paso

Obtener el contenido real de la skill y cualquier ejemplo de uso autorizado; convertir sus requisitos en casos y graders antes de tocar el comportamiento.