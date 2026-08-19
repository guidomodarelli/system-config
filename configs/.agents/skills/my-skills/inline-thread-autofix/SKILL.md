---
name: inline-thread-autofix
description: "Resuelve un thread inline de GitHub a partir de su URL: inspecciona el PR y el código, aplica el fix mínimo, ejecuta validaciones, crea commit, hace push, responde el thread con el template de cierre y lo marca como resuelto. Usar siempre cuando el usuario pase un link `discussion_r...` o pida resolver un comentario inline del PR. No cerrar threads si el fix no está validado, si el árbol tiene cambios ajenos o si el comentario ya fue respondido/resuelto."
compatibility: Requiere GitHub CLI autenticado (`gh`), git, filesystem y las herramientas de validación del repositorio.
---

# Inline Thread Autofix

## Objetivo

Resolver un único comentario inline de GitHub de punta a punta:

1. identificar PR, repo, comentario y thread;
2. entender el hallazgo y el código vigente;
3. aplicar el cambio mínimo que corrige el comportamiento;
4. agregar o actualizar tests relevantes;
5. ejecutar typecheck, lint, tests y build según el repositorio;
6. crear commit y hacer push a la branch del PR;
7. responder el thread con el template de cierre;
8. resolver el thread vía GraphQL;
9. verificar commit, respuesta y estado final.

El link entregado por el usuario autoriza el closeout de ese thread, pero no autoriza modificar otros threads, descartar cambios ajenos, usar flags destructivos ni ocultar validaciones fallidas.

## Input y alcance

Aceptar URL GitHub con forma:

```text
https://github.com/<owner>/<repo>/pull/<number>#discussion_r<comment_id>
```

Validar que:

- host sea `github.com`;
- path termine en `/pull/<número>`;
- fragment sea `discussion_r<número>`;
- owner, repo, PR y comment ID no sean reconstruidos desde texto no validado.

Si falta fragment inline, el comentario fue eliminado, el repo/PR no es accesible o el thread no puede resolverse, detenerse y explicar el bloqueo. Esta skill no procesa comentarios generales, review-bodies ni issues.

## Preflight GitHub

Ejecutar con valores validados y quoting seguro:

```bash
gh pr view <PR> --repo <owner>/<repo> --json state,headRefName,headRefOid,baseRefName,url
 gh api user --jq .login
 gh api repos/<owner>/<repo>/pulls/comments/<comment_id>
```

Consultar el thread con GraphQL para obtener `thread.id`, `isResolved`, `isOutdated` y comentarios/replies. Consultar comentarios del usuario autenticado para evitar duplicar respuestas.

- Si `isResolved: true`, no editar, no responder y no volver a resolver; reportar el estado.
- Si ya existe una respuesta de este usuario para el mismo comentario, no crear otra sin revisar si corresponde actualizarla.
- `isOutdated: true` no implica que el hallazgo sea inválido: inspeccionar el código vigente y decidir con evidencia.
- Si el PR no está `OPEN`, no hacer push ni closeout.

## Preflight local

1. Resolver el repositorio actual y leer `CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING`, scripts y reglas de testing.
2. Verificar que el remoto coincida con el repo del link y que la branch actual sea la branch del PR. Si no coincide, usar el mecanismo seguro definido por el repositorio; no tocar otra branch silenciosamente.
3. Revisar `git status --short` antes de editar.
4. Si hay cambios locales no creados por esta ejecución o archivos no relacionados, detenerse y pedir limpieza/aislamiento. Nunca usar `git reset --hard`, `git clean -fd`, checkout destructivo ni sobrescribir cambios ajenos.
5. Leer el archivo, símbolo y contexto del diff mencionado por el comentario; buscar consumers, tests y contratos relacionados.
6. Clasificar el comentario como correctness, security, performance, maintainability, tests o documentation. Si la sugerencia es incorrecta, no inventar un fix: dejar evidencia y no resolver automáticamente.

## Implementación

- Reproducir el escenario con un test o una prueba local antes de cambiar cuando sea posible.
- Aplicar el cambio mínimo y cohesionarlo con patrones existentes.
- Preservar API pública, status, códigos, retries, autorización, copy, serialización y side effects salvo que el comentario pida cambiar uno de ellos.
- Si cambia comportamiento, agregar/actualizar tests de comportamiento, errores y edge cases.
- No editar catálogos generados manualmente; usar el workflow oficial del repositorio.
- No agregar dependencias, flags destructivos ni mocks de SDK/plataforma sin justificación técnica.
- No incluir secretos, tokens, cookies, headers, payloads completos, stack, cause raw ni PII en logs, comentarios o respuestas.

## Validación obligatoria

Ejecutar primero validaciones focales y después las globales disponibles:

```bash
git diff --check
# typecheck del repositorio
# lint del repositorio
# tests focales del archivo/flujo
# suite completa
# build cuando exista
```

Consultar [`verification-matrix.md`](references/verification-matrix.md). No crear commit ni push si falla una validación relevante. Si un comando falla por una causa preexistente, aislarla con evidencia; no ocultar el fallo ni debilitar tests.

## Commit y push

Solo después de validar:

1. Revisar `git diff`, `git status` y que solo estén los archivos del fix.
2. Stagear paths explícitos; no usar `git add .` si hay posibilidad de archivos ajenos.
3. Crear mensaje siguiendo convención del repositorio. Terminar siempre con:

```text
Co-Authored-By: Claude <noreply@anthropic.com>
```

4. Obtener SHA completo del commit.
5. Push a la branch del PR.
6. Confirmar que `gh pr view <PR> --json headRefOid` coincide con el SHA publicado.

Si push recibe non-fast-forward, no forzar: fetch/rebase sobre la branch remota, revisar conflictos, ejecutar nuevamente validaciones y pushar. No hacer closeout con un SHA que no pertenezca al PR.

## Closeout del thread

Responder usando exactamente el template de [`closeout-template.md`](references/closeout-template.md). El resumen debe ser una línea concreta y en español; conservar en inglés solo identificadores, paths, comandos y nombres técnicos.

Para inline reply usar el SHA completo:

```bash
gh api repos/<owner>/<repo>/pulls/<pr>/comments \
  -f body='<body en español>' \
  -f commit_id='<sha completo>' \
  -F in_reply_to=<comment_id>
```

El reply debe incluir link al commit con el SHA corto de 7 caracteres. No publicar el reply antes de que el push sea visible.

Resolver el thread solo después de que el reply tenga éxito:

```bash
gh api graphql \
  -f threadId='<thread node id>' \
  -f query='mutation($threadId:ID!) { resolveReviewThread(input:{threadId:$threadId}) { thread { id isResolved } } }'
```

Si el reply se publicó pero la resolución falla, no duplicar el reply: reportar URL del reply y dejar el thread pendiente para reintento seguro. Si el push o validación falla, no responder ni resolver.

## Verificación final

Confirmar:

- PR `OPEN` y head SHA correcto.
- commit presente en remoto.
- reply creado en el thread correcto.
- `thread.isResolved === true`.
- working tree limpio, salvo cambios explícitamente solicitados.
- no se tocaron otros threads.

Formato de salida:

```markdown
## ✅ Fix aplicado
- <cambio y archivos principales>

## 🧪 Validación
- <comandos y resultados>

## 🚀 Publicación
- Commit: `<sha corto>`
- Reply: <URL>
- Thread: resuelto
```

Si no fue posible cerrar, explicar exactamente qué paso falló y qué quedó publicado o pendiente.
