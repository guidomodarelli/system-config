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

## Validación de PowerShell sin instalación

En macOS no suele estar instalado `pwsh`. Para validarlo, bajar un binario portable a `/tmp`, sin `brew` ni cambios en el sistema, y borrarlo al terminar.

### Descarga (macOS arm64; en Intel usar `x64`)

```bash
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

### Probar el prompt murilasso

El prompt es nativo de PowerShell, sin Oh My Posh. Vive entre `# --- Prompt murilasso` y `# --- Fin prompt murilasso` del profile, y los tests Pester de `configs/PowerShell/Microsoft.PowerShell_profile.Tests.ps1` lo cargan de la misma forma. El profile completo depende de Windows, así que fuera de Windows se prueba solo esa sección:

- La sección usa `Get-StableExecutablePath` y `Get-ExecutableFingerprint` para la versión de Node. Fuera del profile no existen y el segmento de Node queda vacío, salvo que también se dot-sourceen esas funciones.
- Usar un repo git temporal en `/tmp` para armar cada escenario (cambios, stash, rebase, HEAD detached) y llamar `prompt` desde ahí.
- Las env vars `MURILASSO_PR_*` (PR y CI) se simulan exportándolas antes de llamar `prompt`. El estado se recalcula en cada render.
- `$global:LASTEXITCODE = 7; prompt; $LASTEXITCODE` debe devolver `7`.

```bash
/tmp/pwsh-portable/pwsh -NoProfile -c '
$lines = Get-Content configs/PowerShell/Microsoft.PowerShell_profile.ps1
$start = ($lines | Select-String -SimpleMatch "# --- Prompt murilasso ").LineNumber
$end = ($lines | Select-String -SimpleMatch "# --- Fin prompt murilasso").LineNumber
. ([scriptblock]::Create(($lines[($start-1)..($end-1)] -join [Environment]::NewLine)))
Set-Location /tmp/repo-prueba
$global:LASTEXITCODE = 7; $rendered = prompt; "LASTEXITCODE: $LASTEXITCODE"
$rendered -replace "\e\[[0-9;]*m", "" -replace "\e\]8;;[^\a]*\a", ""'
```

### Limitaciones conocidas

- En `pwsh -c` no hay historial, así que el prompt no detecta un comando nuevo: no muestra exit status ni duración y `❯` queda verde. El color rojo de `❯`, el segmento de exit code y la duración de un comando real solo se validan en una sesión interactiva; informarlo en la respuesta final.
- El indicador de carpeta sin permiso de escritura del theme zsh no se porta: calcular permisos efectivos en Windows en cada render es caro.

### Limpieza

```bash
rm -rf /tmp/pwsh-portable /tmp/pwsh.tar.gz
```

## Tests De PowerShell Con Pester

- Todos los tests de PowerShell son Pester y se nombran `*.Tests.ps1`: `scripts/dotfiler/dotfiler.ps1.Tests.ps1`, `scripts/setup/setup.ps1.Tests.ps1` y `configs/PowerShell/Microsoft.PowerShell_profile.Tests.ps1`. Se ejecutan con la última versión de Pester (6.x) y siguen siendo compatibles con Pester 5. No agregar scripts de test con asserts propios.
- Los scripts que ejecutan lógica al cargarse (`setup.ps1`, el profile) no se dot-sourcean completos: el `BeforeAll` del test extrae sus funciones con el AST y las dot-sourcea en el scope del test. Los CLIs externos (`winget`, `scoop`, `ghq`, etc.) se declaran como funciones vacías para poder mockearlos aunque no estén instalados.
- En tests nuevos o modificados, verificar mocks con `Should -Invoke`. No usar `Assert-MockCalled` ni `Assert-VerifiableMock`, que Pester 6 eliminó.
- Si no hay `pwsh`, bajarlo portable a `/tmp` siguiendo "Validación de PowerShell sin instalación".
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
