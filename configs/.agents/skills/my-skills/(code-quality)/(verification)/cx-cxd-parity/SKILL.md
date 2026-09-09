---
name: cx-cxd-parity
description: Verifica y mantiene paridad funcional entre wrappers `cx`/`cxd` de Zsh y PowerShell, junto con sus completions. Usar siempre cuando una solicitud mencione `cx`, `cxd`, `_cx`, `_cxd`, cambie cualquiera de los wrappers, agregue o elimine flags, argumentos, subcommands, defaults, opciones de MCP/modelo o comportamiento visible de autocomplete, aunque el cambio afecte un solo shell.
---

# Paridad de `cx` y `cxd`

## Alcance

Aplicar workflow sobre estas superficies:

- `configs/zsh/.zsh/functions/codex.zsh`
- `configs/PowerShell/Microsoft.PowerShell_profile.ps1`
- `configs/zsh/.zsh/completions/_cx`
- `configs/zsh/.zsh/completions/_cxd`, cuando exista

La skill complementa `AGENTS.md` y no reemplaza sus guardrails de revisión dual.

## Workflow

1. Leer estado Git antes de editar y preservar cambios ajenos.
2. Leer siempre ambas implementaciones, incluso si solicitud nombra un solo shell.
3. Leer completions relacionadas cuando cambio pueda afectar flags, subcommands, argumentos, defaults o valores sugeridos.
4. Construir matriz breve de contrato observable:
   - invocación de `cx` y `cxd`;
   - flags y argumentos;
   - defaults y valores sugeridos;
   - opciones de modelo, razonamiento y MCP;
   - comportamiento de inicio, actualización y salida;
   - completions expuestas.
5. Aplicar cambio equivalente en ambas implementaciones cuando cambie contrato observable.
6. Actualizar únicamente completions afectadas; si no corresponde modificar una superficie, documentar razón concreta.
7. No sobrescribir cambios locales ajenos ni alterar `configs/.codex/config.toml` o `configs/zsh/.zshrc` sin autorización explícita.

## Validación

- Ejecutar `zsh -n configs/zsh/.zsh/functions/codex.zsh`.
- Si existe `pwsh`, analizar `configs/PowerShell/Microsoft.PowerShell_profile.ps1` con el parser de PowerShell; si no existe, reportar validación omitida y motivo.
- Ejecutar tests de `cx`/`cxd` relevantes cuando estén disponibles.
- Revisar que completions sigan representando contrato observable de wrappers.
- Ejecutar `git diff --check` sobre archivos propios y confirmar que no haya cambios ajenos incluidos.

## Cierre

Informar explícitamente:

- `Verificado Zsh: sí/no + evidencia`.
- `Verificado PowerShell: sí/no + evidencia`.
- `Verificadas completions: sí/no + archivos`.
- `Paridad aplicada: sí/no + razón si no correspondía`.
