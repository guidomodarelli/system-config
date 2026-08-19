# Template de cierre inline

Usar este formato después de un fix validado y pusheado. Es equivalente al template exitoso de `codex-autofix-loop`, adaptado para un único thread inline.

```markdown
✅ **Resuelto** en [`{{sha_corto}}`]({{commit_url}}).

### 🔧 Qué cambió
> {{resumen_de_una_linea}}

<sub>🤖 Fix aplicado en respuesta a este comentario inline.</sub>
```

## Reglas

- `{{sha_corto}}` debe tener 7 caracteres.
- `{{commit_url}}` debe apuntar al commit completo en el mismo repo.
- `{{resumen_de_una_linea}}` debe describir efecto observable, no repetir todo el diff.
- Mantener encabezado `### 🔧 Qué cambió` y colocar resumen en bloque de cita (`>`); no convertirlo en párrafo genérico.
- El comentario visible debe estar en español; mantener en inglés solo identifiers, paths, comandos y nombres técnicos.
- No incluir stack, `cause`, tokens, secrets, payloads, PII ni logs raw.
- No usar “Resuelto” si el commit no fue pusheado y verificado en el PR.
- No publicar template de éxito para tests fallidos o fix no aplicado.

## Falla del flujo

Si el cambio no pudo aplicarse por un fallo del agente, no responder ni resolver automáticamente. Si es necesario dejar diagnóstico, usar un comentario separado y seguro, sin atribuir la falla a la sugerencia ni publicar detalles sensibles.
