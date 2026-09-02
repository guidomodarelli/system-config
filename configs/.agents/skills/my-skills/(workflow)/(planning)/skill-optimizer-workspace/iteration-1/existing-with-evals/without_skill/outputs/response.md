## Plan operativo

Haré una evaluación **read-only** de `/Users/me/.claude/skills/example/SKILL.md`: revisaré el contrato de la skill, `evals/evals.json` y sus dos referencias, sin modificar el target.

1. **Baseline:** ejecutaré los casos existentes con el mismo modelo, configuración y número de repeticiones que use el candidato; registraré pass rate por caso, fallos, tokens y variabilidad.
2. **Candidato:** prepararé una copia temporal optimizada, manteniendo triggers, restricciones, referencias, formato de salida y comportamiento observable del contrato.
3. **Comparación:** repetiré exactamente la misma suite y reportaré delta de tokens, tasa de éxito, regresiones por caso y diferencias de comportamiento. Aceptaré el candidato solo si reduce tokens sin regresiones contractuales; de lo contrario, conservaré el baseline.
4. **Reporte:** incluiré método, métricas baseline/candidato, casos afectados, cambios realizados, limitaciones y recomendación.

No puedo garantizar resultados en evals ocultas, producción o modelos/configuraciones distintas; tampoco significancia estadística con pocas repeticiones ni estabilidad exacta de tokens ante variabilidad del modelo. Si las rutas o referencias son ficticias/inaccesibles, no puedo producir métricas reales ni afirmar que la optimización se ejecutó: dejaré esos valores explícitamente como no verificados.
