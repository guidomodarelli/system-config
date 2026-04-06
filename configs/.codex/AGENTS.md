---
description: Rules for the agents.
alwaysApply: true
---

# User Rules

## Idioma y comunicación (executable policy)
```yaml
policy:
  id: "spanish-communication-rules"
  enabled: true

  actions:
    - enforce_output_language:
        target: "agent_plans"
        language: "Spanish"
        mode: "required_always"

    - enforce_output_language:
        target: "user_questions"
        language: "Spanish"
        mode: "required_always"

    - enforce_output_language:
        target: "review_findings"
        language: "Spanish"
        mode: "required_always"

  validate:
    - check: "plan_language_is_spanish"
      expected: true
      on_fail:
        severity: "error"
        message: "Agent plans must always be written in Spanish."

    - check: "user_questions_language_is_spanish"
      expected: true
      on_fail:
        severity: "error"
        message: "Questions to the user must always be asked in Spanish."

    - check: "review_findings_language_is_spanish"
      expected: true
      on_fail:
        severity: "error"
        message: "Review findings must always be presented in Spanish."
```

## Reglas de testing (obligatorias)
- Antes de dar un cambio por terminado, ejecutar los tests relevantes y asegurar que pasen.
- Si se agrega, modifica o elimina funcionalidad, se deben agregar o actualizar los tests correspondientes.
- Si no es posible ejecutar tests en el entorno actual, se debe informar explícitamente qué faltó validar y por qué.

## Reglas globales de diseño y mantenimiento
- Nombrar variables, funciones, métodos, clases, archivos, carpetas y demás elementos de forma clara, coherente, concisa, completa y autoexplicativa. → Skill: `enforce-naming-conventions`
- Evitar abreviaciones innecesarias y nombres de una sola letra, salvo convenciones ampliamente aceptadas y justificadas por el contexto. → Skill: `enforce-naming-conventions`
- Documentar con JSDoc o TSDoc cuando el lenguaje, la complejidad o la intención del código lo hagan relevante. → Skill: `jsdoc-required-javascript`
- Extraer valores hardcodeados con significado funcional a constantes o archivos de configuración cuando mejore la claridad, la reutilización o el mantenimiento. → Skill: `frontend-structure-accessibility-best-practices`
- Modularizar por responsabilidad y organizar el código en estructuras cohesionadas como `utils/`, `constants/`, `services/`, `adapters/` u otras equivalentes cuando corresponda. → Skills: `enforce-naming-conventions`, `frontend-structure-accessibility-best-practices`
- Priorizar eliminacion de duplicidad, alta cohesión, bajo acoplamiento y principios SOLID cuando aporten valor real al diseño. → Skills: `frontend-structure-accessibility-best-practices`, `mock-first-testing-design`
- Antes de implementar cambios relevantes, identificar módulos y responsabilidades; después del cambio, verificar que cada módulo conserve una responsabilidad clara. → Skill: `frontend-structure-accessibility-best-practices`
- Tras cada edición significativa, incluir una validación breve de 1 a 2 líneas indicando si se cumplió el objetivo del cambio y corregir si no se logró.
- En cambios relevantes, listar y justificar brevemente las principales decisiones de diseño tomadas.

## Ubicación de habilidades (AgentSkills)
- Mis **AgentSkills** están en: `~/.agents/skills`.

## Project context and mandatory tooling (executable policy)
```yaml
policy:
  id: "repo-location-nordic-rules"
  enabled: true

  condition:
    repository_path:
      starts_with: "~/ghq/work/"

  actions:
    - set_project_context:
        framework: "Nordic"
        runtime: "Node.js"
        extension: "Odin"

    - enforce_tool:
        name: "frontender-web-mcp"
        mode: "required_always"

    - enforce_code_language:
        language: "English"
        targets:
          - comments
          - string_literals
          - function_names
          - class_names
          - method_names
          - variable_names
          - constant_names
          - enum_names
          - other_code_terms

  validate:
    - check: "required_tool_present"
      expected: true
      on_fail:
        severity: "error"
        message: "frontender-web-mcp must be used for repositories under ~/ghq/work/."

    - check: "non_english_text_in_targets"
      expected: 0
      on_fail:
        severity: "error"
        message: "All code-related text must be in English for repositories under ~/ghq/work/."
```
