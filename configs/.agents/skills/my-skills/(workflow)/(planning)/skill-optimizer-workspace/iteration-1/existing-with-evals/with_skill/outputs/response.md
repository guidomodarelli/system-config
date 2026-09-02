## Estado
- Resultado: `BLOCKED`
- Objetivo: `balanced` (con foco explícito en reducir tokens y pasos)
- Target: `/Users/me/.claude/skills/example/SKILL.md`
- Motivo: simulación read-only con paths ficticios; no hay target, referencias ni `evals/evals.json` verificables para construir snapshot, candidato o evidencia.

## Diagnóstico
- El flujo correcto empieza por resolver el target y auditar `SKILL.md`, frontmatter, las dos referencias y `evals/evals.json`.
- Debe separar **contrato** (nombre, trigger, inputs/outputs, estados y archivos públicos), **invariantes** (seguridad, aislamiento, no-mutation, validaciones y gates) y **costo** (repetición, round-trips y fases seriales evitables).
- No es seguro proponer una reducción concreta sin reconstruir ese contrato. El cuello de botella real queda `N/D`; el prompt solo declara el objetivo, no evidencia de costo.
- Salvaguardas requeridas: snapshot inmutable, workspace separado, no modificar evals existentes para favorecer al candidato, fan-out acotado solo para lecturas, no mutar target/repo, y detenerse ante regresiones críticas.

## Snapshot
- Archivos esperados: `SKILL.md`, dos referencias declaradas y `evals/evals.json`.
- Baseline fingerprint, líneas, caracteres, tokens aproximados, contratos, comandos, prohibiciones y cobertura de evals: `N/D`.
- En una ejecución real se crearía un workspace hermano con `skill-snapshot/`, `iteration-1/` y `manifest.json`; no se creó aquí porque los paths son ficticios y la tarea exige simulación.

## Baseline y candidato
- **Baseline:** copia inmutable del target actual, evaluada contra todos los casos razonables de `evals/evals.json`.
- **Candidato:** versión hipotética con menos tokens/pasos, limitada a eliminar duplicación y optimizar fast paths o lecturas independientes; debe conservar nombre, descripción/triggers, frontmatter, contrato de entrada/salida, estados, guards, prohibiciones y dependencias.
- No se generó diff ni candidato real: faltan los contenidos del target y de sus referencias, y la operación solicitada es read-only.

## Evaluación
- Configuración prevista: ejecutar `old_skill` (baseline snapshot) y `with_skill` (candidato) en paralelo, con los mismos prompts y el mismo `evals/evals.json`.
- Casos previstos: todos los evals existentes; repetir los críticos tres veces si el modo full y el costo lo permiten.
- Resultado:

  | Métrica | Baseline | Candidato | Estado |
  |---|---:|---:|---|
  | Pass rate | N/D | N/D | No ejecutado |
  | Tokens | N/D | N/D | No medido |
  | Tool calls | N/D | N/D | No medido |
  | Timing / p95 | N/D | N/D | No medido |
  | Regresiones por eval | N/D | N/D | No ejecutado |

- Evidencia: no hay `trace`, `metrics.json`, `timing.json`, `grading.json` ni `benchmark.json`; por lo tanto no se afirma mejora.
- Viewer: no generado.

## Gates
1. Resolver y verificar el target, referencias y evals; si falta cualquiera, `BLOCKED`.
2. Congelar fingerprint y confirmar que el target no cambió durante la evaluación.
3. Pasar todas las assertions críticas de seguridad, autorización, aislamiento y no-mutation.
4. Preservar contrato, invariantes, cobertura y estados de parada.
5. Aceptar el candidato solo con evidencia reproducible de menor costo y sin regresión de calidad; una mejora declarada sin trace produce `NO_MEASURED_GAIN`.
6. Si falla un gate, conservar el baseline y no aplicar cambios.

## Cambios
- Target y repo: ninguno.
- Candidato, evals, referencias y configuración: ninguno.
- Único archivo escrito: este reporte en `/Users/gmodarelli/system-config/configs/.agents/skills/my-skills/(workflow)/(planning)/skill-optimizer-workspace/iteration-1/existing-with-evals/with_skill/outputs/response.md`.

## Validación
- Lectura: realizada sobre `/Users/gmodarelli/system-config/configs/.agents/skills/my-skills/(workflow)/(planning)/skill-optimizer/SKILL.md`.
- Comandos: no ejecutados, según la restricción de la tarea.
- Target/repo ficticio: no modificado.
- Commit/push: omitido.

## Limitaciones
- No pueden calcularse líneas, tokens, fingerprints, timings, tool calls, pass rate ni p95 sin ejecutar el harness sobre archivos reales.
- No puede verificarse el contenido, contrato o cobertura de las dos referencias y `evals/evals.json`.
- El siguiente paso operativo, fuera de esta simulación, sería obtener paths reales y autorización para crear únicamente el workspace de evaluación; el target seguiría sin editarse hasta superar todos los gates.
