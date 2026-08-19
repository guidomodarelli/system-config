# Template de cierre

Usar después de fix validado y commit pusheado/verificado en head de PR. Elegir variante según destino recibido.

## Comentario inline

```markdown
✅ **Resuelto** en [`{{sha_corto}}`]({{commit_url}}).

### 🔧 Qué cambió
> {{resumen_de_una_linea}}

<sub>🤖 Fix aplicado en respuesta a este comentario inline.</sub>
```

Usar `Resuelto` solo cuando reply fue creado en `in_reply_to` correcto y `resolveReviewThread` confirmó `isResolved: true`.

## Review body editada

Agregar este bloque al body original, sin reemplazarlo:

```markdown
---

✅ **Fix aplicado** en [`{{sha_corto}}`]({{commit_url}}).

### 🔧 Qué cambió
> {{resumen_de_una_linea}}

<sub>🤖 Fix aplicado en respuesta a esta review sin comentarios inline.</sub>

<!-- inline-thread-autofix: review:{{review_id}} -->
```

## Comentario general fallback

Usar misma variante review-body, precedida por referencia inequívoca:

```markdown
En respuesta a la [review original]({{review_url}}):

{{bloque_review_body}}
```

No usar `in_reply_to` para fallback. Mantener marcador estable `review:{{review_id}}` para evitar duplicados.

## Reglas

- `{{sha_corto}}` tiene 7 caracteres y apunta a commit completo en mismo repo.
- `{{resumen_de_una_linea}}` describe efecto observable, no repite diff.
- Mantener `### 🔧 Qué cambió` y resumen en blockquote (`>`).
- Texto visible va en español; conservar en inglés solo identifiers, paths, comandos y nombres técnicos.
- `Resuelto` queda reservado para inline threads; review-body usa `Fix aplicado`.
- No publicar hasta confirmar push y head remoto.
- No incluir stack, `cause`, tokens, secrets, cookies, headers, payloads, PII ni logs raw.
- Review editada debe conservar body original completo; fallback debe enlazar review original.
- No publicar template de éxito ante tests fallidos, fix no aplicado o closeout ambiguo.

## Falla del flujo

Si fix no pudo aplicarse o validación falló, no responder ni resolver automáticamente. Si hace falta diagnóstico, usar comentario separado y seguro, sin atribuir éxito a sugerencia ni publicar datos sensibles.
