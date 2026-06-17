---
name: pr-inline-comment-template
description: Format and publish GitHub PR review comments with a default Spanish template. Use when the user asks to "subir el comentario", "subí ese comment", "publicar comentario en el PR", "postear comentario inline", or otherwise asks Codex to upload a review/code comment to a pull request.
---

# PR Inline Comment Template

Use this skill when publishing or drafting a GitHub PR review comment. The comment must be in Spanish and use a clear template by default.

## Workflow

1. Identify the PR, changed file, line, and finding.
2. Keep the comment focused on one actionable issue.
3. Publish an inline comment when a precise changed line exists. Otherwise, publish a normal PR comment.
4. Use the default template below.
5. Include `<details>` only when extra context or step-by-step guidance is genuinely useful.
6. Before publishing, verify the whole comment visible to the author is in Spanish.

## Default Template

```markdown
🔎 <descripción breve del problema y del escenario donde importa>

✅ **Solución**
<acción concreta que debería hacer el autor>

<details>
<summary>Ver explicación y pasos sugeridos</summary>

<explicación simple y más detallada del problema, solo si agrega claridad real>

Pasos sugeridos:
1. <paso concreto>
2. <paso concreto>
3. <paso concreto>

</details>
```

## Rules

- Always write the comment in Spanish.
- Use simple, direct language.
- Start with `🔎` followed directly by a 1-3 sentence description. Do not write a "Resumen" heading.
- Keep `✅ **Solución**` actionable and specific.
- Do not include `<details>` by default.
- Include `<details>` only when one of these applies:
  - the issue is subtle and needs a simple explanation beyond the short summary;
  - the fix has multiple steps;
  - the author needs context to avoid applying the wrong fix;
  - the comment would otherwise become too long.
- If `<details>` is included, it may contain:
  - a simple explanation of the short description;
  - optional step-by-step solution;
  - optional example snippet when it helps.
- Omit "Pasos sugeridos" when the fix is obvious in one sentence.
- Do not add praise, filler, or broad refactor advice.
- Preserve exact code identifiers, paths, commands, errors, API names, and literals in their original language.

## Short Comment Example

```markdown
🔎 `config.read('application')` quedó fuera del `try`, así que si MELITK no puede leer el recurso `application`, el helper lanza antes de devolver `[]`.

✅ **Solución**
Mové `new Config()` y `config.read('application')` dentro del `try`, o manejá ese error explícitamente antes de parsear el archivo.
```

## Expanded Comment Example

```markdown
🔎 `getUserAttributes` ahora guarda atributos con `attribute_key`, pero `getBeARepData` todavía busca `att.key === 'shipping_position'`. En usuarios que ya son `operator` o `logistics_operator`, eso puede dejar visible el botón de Be a Rep cuando no corresponde.

✅ **Solución**
Actualizá la validación para usar `att.attribute_key` y ajustá los tests al nuevo formato de atributo.

<details>
<summary>Ver explicación y pasos sugeridos</summary>

El cambio de origen de datos también cambió la forma de los atributos. Si una parte del flujo sigue leyendo `key`, no encuentra `shipping_position`, aunque el atributo exista.

Pasos sugeridos:
1. Cambiar la búsqueda de `shipping_position` para contemplar `attribute_key`.
2. Actualizar los mocks de Be a Rep para usar el formato real que devuelve `getEntitiesByClientValuesAdmin`.
3. Agregar o ajustar un caso donde `shipping_position` tenga valor `operator` o `logistics_operator`.

</details>
```
