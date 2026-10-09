# Reglas De Agentes

## Idioma En Salida Visible (Mandatorio)

- Todo texto visible para personas debe estar siempre en español.
- Esto incluye, sin limitarse a:
  - texto de UI/CLI
  - descripciones
  - títulos
  - headers
  - párrafos
  - mensajes de estado, errores y resúmenes

## Excepciones Técnicas (Mandatorio En Inglés)

- Deben mantenerse en inglés:
  - flags (`--dry-run`, `--help`, etc.)
  - comandos
  - nombres de funciones, variables y términos del lenguaje (bash, zsh, etc.)
  - términos técnicos y nomenclatura técnica

## Criterio De Aplicación

- Español para contenido orientado a personas.
- Inglés para elementos técnicos ejecutables o de implementación.

## Prohibición De `ccg` Desde Codex

- Codex tiene prohibido invocar la función Zsh `ccg`, tanto directamente como mediante otro shell, script o proceso delegado. Está reservada al usuario.
- No eliminar, vaciar ni alterar las señales de entorno de Codex para eludir la protección de `ccg`, ni reproducir su configuración para sortear esta prohibición.
- Los tests automatizados pueden simular esas señales únicamente en procesos aislados con un CLI `claude` falso, sin iniciar Claude real.

## Regla Para Especificaciones

- Al escribir, actualizar o revisar specs, consultar y aplicar la guía visual de `configs/.agents/DESIGN.md`.
- Si una spec no puede seguir esa guía por una restricción técnica o de formato, dejar explícita la razón en la respuesta final.
- Si se modifica la paleta de `configs/.agents/DESIGN.md` (front matter o `:root` del boilerplate), ejecutar `bash scripts/design/check-design-tokens.sh` y sus tests `scripts/design/test_check_design_tokens.bats`.

## Memoria Persistente Del Repositorio

- Los hechos duraderos específicos de este repositorio deben guardarse en `configs/.mcp-memory/memory.json` y commitearse en `system-config`.

## Compatibilidad De PowerShell (Mandatorio)

- Todo código PowerShell del repositorio (`*.ps1`, el profile, los `.bat` que invocan PowerShell y los scripts que genera o ejecuta) debe funcionar en **PowerShell 7+ (`pwsh`)** y en **Windows PowerShell 5.1 (`powershell.exe`)**.
- No usar sintaxis exclusiva de PowerShell 7: `??`, `??=`, `?.`, `?[]`, el ternario `a ? b : c`, `&&`/`||` entre pipelines, los escapes `` `e `` y `` `u{...} ``, `ForEach-Object -Parallel`, bloques `clean {}` ni `-replace` con scriptblock. Para ESC usar `[char]27`.
- No usar APIs exclusivas de .NET Core/.NET 6+ sin fallback para .NET Framework, por ejemplo `FileSystemInfo.ResolveLinkTarget`/`LinkTarget`, `ProcessStartInfo.ArgumentList`, `Path.Join` o `Path.GetRelativePath`. Detectarlas con `$obj.PSObject.Methods['Name']` o `$obj.PSObject.Properties['Name']`, y en 5.1 usar alternativas como las propiedades ETS `LinkType`/`Target` de `Get-Item` o `ProcessStartInfo.Arguments` con quoting explícito.
- No usar parámetros de cmdlets que solo existen en PowerShell 7 sin alternativa para 5.1, por ejemplo `ConvertFrom-Json -AsHashtable`, `Get-Content -AsByteStream`, `-Encoding utf8NoBOM`, `Split-Path -LeafBase`, `Join-Path -AdditionalChildPath`, `Sort-Object -Top`, `Select-String -Raw`/`-NoEmphasis`, `Test-Json` o `Join-String`.
- Guardar los `.ps1` que contengan caracteres no ASCII en UTF-8 **con BOM**. Sin BOM, Windows PowerShell 5.1 los lee como ANSI y corrompe los textos o rompe el parseo.
- En 5.1, `Set-Content`/`Out-File -Encoding UTF8` escriben BOM. Si el archivo no debe llevarlo (patches, caches, archivos leídos por otras herramientas), usar `[System.IO.File]::WriteAllText($path, $text, [System.Text.UTF8Encoding]::new($false))`.
- `$IsWindows`, `$IsLinux` y `$IsMacOS` no existen en 5.1; usar `$PSVersionTable.PSEdition` o `[Environment]::OSVersion` cuando haga falta distinguir plataforma.
- Validar cada cambio abriendo una sesión nueva de `pwsh` y otra de `powershell.exe`. Fuera de Windows no hay 5.1: validar la sintaxis con `pwsh`, revisar a mano los puntos anteriores e informar en la respuesta final que 5.1 no se pudo validar.

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
- Llamar `prompt` y verificar efectos. Ejemplo: `$global:LASTEXITCODE = 7; prompt; $LASTEXITCODE` debe devolver `7`. Los fetches de PR/CI corren como procesos `gh` (no jobs), así que `MURILASSO_JOB_COUNT` debe quedar en `0` sin jobs del usuario.

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

## Tests De PowerShell Con Pester

- Todos los tests de PowerShell son Pester y se nombran `*.Tests.ps1`: `scripts/dotfiler/dotfiler.ps1.Tests.ps1`, `scripts/setup/setup.ps1.Tests.ps1` y `configs/PowerShell/Microsoft.PowerShell_profile.Tests.ps1`. Se ejecutan con la última versión de Pester (6.x) y siguen siendo compatibles con Pester 5. No agregar scripts de test con asserts propios.
- Los scripts que ejecutan lógica al cargarse (`setup.ps1`, el profile) no se dot-sourcean completos: el `BeforeAll` del test extrae sus funciones con el AST y las dot-sourcea en el scope del test. Los CLIs externos (`winget`, `scoop`, `ghq`, etc.) se declaran como funciones vacías para poder mockearlos aunque no estén instalados.
- En tests nuevos o modificados, verificar mocks con `Should -Invoke`. No usar `Assert-MockCalled` ni `Assert-VerifiableMock`, que Pester 6 eliminó.
- Si no hay `pwsh`, bajarlo portable a `/tmp` siguiendo "Validación de PowerShell y Oh My Posh sin instalación".
- Pester se descarga desde PowerShell Gallery (`https://www.powershellgallery.com/packages/Pester`) con `Save-Module` a una carpeta temporal. No usar `Install-Module`, que lo instala en el perfil del usuario.

```bash
mkdir -p /tmp/psmodules
/tmp/pwsh-portable/pwsh -NoProfile -c 'Save-Module -Name Pester -Path /tmp/psmodules -Repository PSGallery -Force'

PSModulePath=/tmp/psmodules /tmp/pwsh-portable/pwsh -NoProfile -c '
Import-Module Pester
"Pester $((Get-Module Pester).Version)"
$config = New-PesterConfiguration
$config.Run.Path = @("scripts/dotfiler/dotfiler.ps1.Tests.ps1", "scripts/setup/setup.ps1.Tests.ps1", "configs/PowerShell/Microsoft.PowerShell_profile.Tests.ps1")
$config.Run.PassThru = $true
$config.Output.Verbosity = "None"
$result = Invoke-Pester -Configuration $config
"passed=$($result.PassedCount) failed=$($result.FailedCount)"
$result.Failed | ForEach-Object { $_.ExpandedName + " :: " + (($_.ErrorRecord | Select-Object -First 1).Exception.Message -split "`n")[0] }'
```

- **Distinguir regresiones de fallos previos:** correr los mismos tests sobre `HEAD` en un worktree temporal, sin tocar el checkout ni el trabajo sin commitear: `git worktree add --detach /tmp/sc-head HEAD`, ejecutar Pester con `Run.Path` apuntando a `/tmp/sc-head/...`, y después `git worktree remove --force /tmp/sc-head`. No copiar solo el `.ps1` a `/tmp`, porque los tests dependen de archivos cercanos a `$PSScriptRoot`.
- **Fallos conocidos en macOS** (también en `HEAD`, no son regresiones): los tests que usan rutas `C:\` (`Cannot find drive ... 'C'`) y los de `conditionalExcludes` que dependen de la plataforma. La cantidad puede variar con el tiempo; confirmar contra `HEAD` y reportarlos como no validables fuera de Windows.
- **Limpieza:** `rm -rf /tmp/psmodules`, además de la limpieza de `pwsh` de la sección anterior.

## Workspaces Generados Por Skills

- Una carpeta `*-workspace` con `SKILL.md` directamente en su primer nivel es una skill legítima y debe conservarse.
- Una carpeta `*-workspace` sin `SKILL.md` de primer nivel es un workspace temporal generado por una skill y no debe guardarse en el repositorio.
- Git no puede expresar directamente esa condición de existencia; `.gitignore` cubre artefactos generados conocidos y la validación final debe eliminar workspaces temporales antes de cerrar.
