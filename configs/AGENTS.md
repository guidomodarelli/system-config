# Reglas para wrappers `cx` y `cxd`

## Alcance

Estas instrucciones aplican a las implementaciones de Codex bajo `configs/`, incluyendo Zsh y PowerShell.

## Regla de paridad

- Todo cambio en `configs/zsh/.zsh/functions/codex.zsh` debe revisarse contra `configs/PowerShell/Microsoft.PowerShell_profile.ps1`.
- Todo cambio en `configs/PowerShell/Microsoft.PowerShell_profile.ps1` debe revisarse contra `configs/zsh/.zsh/functions/codex.zsh`.
- Actualizar ambas implementaciones cuando cambie el contrato observable: flags, subcommands, argumentos, defaults, selección de MCP, comportamiento de inicio o salida.
- Si la revisión concluye que no corresponde modificar la otra implementación, documentar la razón en la validación final.

## Completions Zsh

- Si un cambio afecta flags, subcommands, argumentos, defaults o valores sugeridos, revisar y actualizar `configs/zsh/.zsh/completions/_cx` y `configs/zsh/.zsh/completions/_cxd` cuando corresponda.
- Validar que completions sigan alineadas con contrato observable de wrappers; la skill `cx-cxd-parity` contiene workflow detallado.

## Validación específica de shells

- Ejecutar validación de sintaxis en Zsh (`zsh -n ...`) y validación equivalente en PowerShell cuando exista el ejecutable.
- Si la ejecución de validación de uno de los shells no está disponible en el entorno, informar de forma explícita y concreta en la respuesta final.

## Validación de PowerShell y Oh My Posh sin instalación

En macOS no suelen estar instalados `pwsh` ni `oh-my-posh`. Para validarlos, bajar binarios portables a `/tmp`, sin `brew` ni cambios en el sistema, y borrarlos al terminar.

### Descarga (macOS arm64; en Intel usar `amd64` / `x64`)

```bash
# oh-my-posh: binario único
curl -fsSL -o /tmp/omp https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/posh-darwin-arm64
chmod +x /tmp/omp && /tmp/omp version

# pwsh: tarball de la última release
tag=$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/PowerShell/PowerShell/releases/latest | sed 's#.*/tag/v##')
curl -fsSL -o /tmp/pwsh.tar.gz "https://github.com/PowerShell/PowerShell/releases/download/v$tag/powershell-$tag-osx-arm64.tar.gz"
mkdir -p /tmp/pwsh-portable && tar -xzf /tmp/pwsh.tar.gz -C /tmp/pwsh-portable
chmod +x /tmp/pwsh-portable/pwsh && xattr -dr com.apple.quarantine /tmp/pwsh-portable
/tmp/pwsh-portable/pwsh -NoProfile -c '$PSVersionTable.PSVersion.ToString()'
```

### Validar sintaxis del profile

```bash
/tmp/pwsh-portable/pwsh -NoProfile -c '
$tokens = $null; $errors = $null
[void][System.Management.Automation.Language.Parser]::ParseFile("configs/PowerShell/Microsoft.PowerShell_profile.ps1", [ref]$tokens, [ref]$errors)
"parse errors: $($errors.Count)"; $errors | ForEach-Object { $_.Message }'
```

### Renderizar `murilasso.omp.json` sin PowerShell

`oh-my-posh print` renderiza el theme contra un directorio y un estado simulado. Usar un repo git temporal en `/tmp` para armar cada escenario (cambios, stash, rebase, HEAD detached).

```bash
CFG=configs/PowerShell/murilasso.omp.json
/tmp/omp print primary --config $CFG --shell pwsh --plain --pwd /tmp/repo-prueba
/tmp/omp print right   --config $CFG --shell pwsh --plain --pwd /tmp/repo-prueba --status 130 --execution-time 75000
MURILASSO_JOB_COUNT=2 /tmp/omp print primary --config $CFG --shell pwsh --plain --pwd /tmp/repo-prueba
/tmp/omp print secondary --config $CFG --shell pwsh --plain
```

- Las env vars `MURILASSO_*` (PR, CI, jobs) se simulan exportándolas antes de `print`.
- Para inspeccionar qué expone un segmento (por ejemplo, contadores de git), usar un config mínimo con template de debug, como `{{ .Working.Unmerged }}`.

### Probar el wrapper `prompt` del profile con OMP real

El profile completo depende de Windows. Probar solo la sección `# --- Prompt murilasso para Oh My Posh` … `# --- Fin prompt murilasso`:

- Poner OMP en `PATH` con el nombre `oh-my-posh` (`mkdir -p /tmp/ompbin && cp /tmp/omp /tmp/ompbin/oh-my-posh`).
- Definir `LOCALAPPDATA=/tmp/lad` (el cache de init lo usa) y `$script:ProfileScriptDirectory` con la ruta de `configs/PowerShell`.
- Dot-sourcear las líneas de esa sección. El init cacheado falla porque `Get-ExecutableFingerprint` no está definido, y cae al init en vivo de OMP. Es lo esperado.
- Llamar `prompt` y verificar efectos. Ejemplo: `$global:LASTEXITCODE = 7; prompt; $LASTEXITCODE` debe devolver `7`, y los jobs `murilasso_fetch` no deben contarse en `MURILASSO_JOB_COUNT`.

```bash
PATH=/tmp/ompbin:$PATH LOCALAPPDATA=/tmp/lad /tmp/pwsh-portable/pwsh -NoProfile -c '
$lines = Get-Content configs/PowerShell/Microsoft.PowerShell_profile.ps1
$start = ($lines | Select-String -SimpleMatch "# --- Prompt murilasso para Oh My Posh").LineNumber
$end = ($lines | Select-String -SimpleMatch "# --- Fin prompt murilasso").LineNumber
$script:ProfileScriptDirectory = (Resolve-Path configs/PowerShell).Path
. ([scriptblock]::Create(($lines[($start-1)..($end-1)] -join [Environment]::NewLine)))
$global:LASTEXITCODE = 7; $rendered = prompt; "LASTEXITCODE: $LASTEXITCODE"
($rendered -join "`n") -replace "\e\[[0-9;?]*[A-Za-z]", "" -replace "\e\][^\a]*\a", "" -replace "\e[78]", ""'
```

### Limitaciones conocidas

- En `pwsh -c` no hay historial, así que OMP no calcula status (`NoExitCode`). El color de `❯` y el segmento `✘` con un comando fallido real solo se validan en una sesión interactiva; informarlo en la respuesta final.
- OMP cuenta los conflictos `AA` como staged, no como `Unmerged`. `BISECT` no se detecta.

### Limpieza

```bash
rm -rf /tmp/omp /tmp/ompbin /tmp/lad /tmp/pwsh-portable /tmp/pwsh.tar.gz
```
