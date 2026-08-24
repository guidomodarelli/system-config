---
name: constants-refactor
description: Analiza y refactoriza constantes, literales funcionales y contratos cross-layer en cualquier repositorio de código. Usar siempre que usuario pida revisar constantes, mover valores a constants/, limpiar hardcodes, responder comentarios de PR sobre constantes, centralizar límites/códigos/rutas/regex o reducir duplicación entre capas, aunque no mencione explícitamente una carpeta constants. Clasifica qué mover y qué mantener local, preserva comportamiento y aplica cambios seguros con validación completa.
compatibility: Requiere acceso a filesystem, git y herramientas de validación definidas por el repositorio.
---

# Constants Refactor

## Objetivo

Centralizar valores con significado funcional cuando exista contrato compartido, duplicación real o riesgo de drift. Evitar `constants/` como depósito genérico: valores privados de módulo deben permanecer cerca de su responsabilidad.

Aplicar workflow completo cuando usuario pida implementar. Entregar solo análisis cuando usuario pida review o informe sin cambios.

## Quick start

1. Resolver repositorio, lenguaje/framework, rama base y alcance exacto.
2. Separar `git diff BASE...HEAD` de cambios no commiteados.
3. Inventariar declaraciones `const`, atoms escalares `as const`, objetos/arrays `as const`, enums/union literals, regex, límites, códigos, paths, timeouts y strings repetidos.
4. Comparar inventario con `constants/`, `config/`, `permissions/`, `utils/`, tipos/interfaces, schemas y módulos de dominio existentes.
5. Clasificar cada candidato: `mover`, `centralizar`, `extraer local`, `mantener local`, `no tocar`.
6. Implementar fuentes canónicas, migrar consumers y tests.
7. Ejecutar validaciones y reportar bloqueos reales sin ocultarlos.

## Organización física por dominio

Cuando `constants/` contenga varios módulos relacionados, agruparlos por dominio funcional y boundary, no solo por tipo primitivo o por orden de creación:

```text
constants/
├── <domain-a>/
│   ├── index.ts
│   ├── <domain-a>.ts
│   └── <domain-a>-errors.ts
├── <domain-b>/
│   └── index.ts
└── <shared-concern>.ts
```

Aplicar estas reglas:

- Mover juntas las constantes que representan el mismo dominio o contrato —por ejemplo códigos, rutas, límites, estados y tipos de un flujo— y mantener separadas las preocupaciones transversales realmente reutilizadas.
- Usar `index.ts` como entrypoint del dominio cuando haya varios módulos. Reexportar desde allí sin redeclarar valores, objetos `as const`, enums o tipos; una sola definición evita divergencias.
- Evitar colisiones entre un archivo y una carpeta con el mismo basename (`constants/<domain>.ts` y `constants/<domain>/`). Si se conserva el specifier público, mover la implementación al directorio y usar `index.ts` como fachada.
- Conservar shims legacy como archivos que solo reexportan la ubicación canónica cuando el path profundo no colisiona con una carpeta nueva. Mantener imports públicos existentes cuando la resolución siga siendo válida y migrarlos por boundary cuando no lo sea.
- Preservar el alias soportado por runtime y evitar cambiar imports masivamente solo por uniformidad. Verificar TypeScript, Jest, bundler y server por separado cuando sus resolvers difieran.
- No colocar en `constants/` valores dependientes de entorno, secretos, credenciales, configuración operativa o endpoints que deban tunearse por deployment; usar `config/` o runtime config.
- Revisar el boundary de cada constante: no exportar al cliente valores server-only, detalles internos de upstream o metadata sensible. Las constantes compartidas deben ser seguras para el bundle donde se consumen.
- Mantener constantes puras y sin side effects. Evitar que los barrels importen servicios u otros módulos que introduzcan ciclos; los módulos de dominio pueden depender de constantes compartidas, no al revés.
- Tras mover constantes, validar valores, referencias, tipos, identidad de objetos cuando importe y resolución de barrels/shims mediante tests de comportamiento o typecheck; no testear strings del archivo fuente.

### Atoms escalares y agregados

- Cuando un literal tenga significado unitario, estable y reutilizado dentro de un mismo contrato, definirlo una sola vez como atom escalar: `const SEMANTIC_ATOM = 'value' as const`.
- Construir arrays y agregados contractuales desde atoms: `const CONTRACT_VALUES = [SEMANTIC_ATOM, OTHER_ATOM] as const`.
- Nombrar atoms por rol semántico y dominio (`LABOUR_SHARE_SOURCE_SCANNER`), no por valor genérico (`VALUE`, `ITEM`, `TYPE`).
- Derivar unions desde el array contractual correspondiente, no desde un array de otro dominio. Mantener arrays distintos cuando tengan semánticas distintas aunque compartan atoms (`mixed` no pertenece a una lista de valores individuales).
- Compartir atom solo después de comprobar equivalencia de significado, boundary, serialización y consumers. Coincidencia textual aislada no justifica compartirlo.
- Mantener atoms puros, sin configuración de entorno, secretos, credenciales, servicios, permisos, imports server-only ni side effects.
- Preservar orden, identidad y forma observable. No reemplazar referencias canónicas por `Array.from`, spread, `Object.freeze` o composición dinámica cuando eso cambie identidad, mutabilidad o serialización requerida por consumers.
- No atomizar por estética valores únicos, labels/copy, fixtures externos, mapas contractuales ya cohesivos o literales triviales sin reutilización real.

## Alcance y exclusiones

- Interpretar `@constants/` como carpeta `constants/` salvo que repositorio ya defina otro alias explícito.
- Preferir aliases e imports existentes; no crear alias nuevo solo para este refactor.
- Respetar exclusiones explícitas del usuario por dominio, módulo, ruta o PR.
- Si usuario excluye un dominio, no modificar servicios, rutas, permisos, guards ni tests de ese dominio, aunque compartan strings con otro flujo.
- No editar manualmente catálogos generados de traducciones salvo pedido explícito y workflow del repositorio.
- No hacer commit, push, comentarios de PR ni cambios externos sin autorización explícita.

## Inventario

### Fuentes que revisar

Adaptar al layout del repositorio:

- `constants/`, `config/`, `settings/`
- `interfaces/`, `types/` y exports runtime dentro de módulos de tipos
- API, backend, frontend, servicios, adapters, middlewares y utilidades
- schemas y validadores
- hooks, loaders, SSR y clientes backend-for-frontend cuando existan
- tests y mocks
- comentarios inline y reviews del PR, cuando exista PR

### Búsquedas mínimas

Adaptar comandos al shell y lenguaje:

```bash
rg -n "export const|const [A-Z][A-Z0-9_]+|as const|enum " .
rg -n "['\"](status|reason|error|code|path|timeout|limit)" src api app lib utils tests
rg -n "timeout|max\(|min\(|regex\(|enumeration\(|allowlist|whitelist" src api app lib utils
rg -n "from ['\"].*/(interfaces|types|constants)/" src api app lib utils tests
```

Para PR:

- determinar base y HEAD desde GitHub/git;
- leer comentarios inline, threads y estado `resolved/outdated`;
- separar comentarios abiertos aplicables de comentarios ya resueltos u obsoletos;
- no tratar boilerplate de bots como hallazgo.

## Clasificación

### Mover a `constants/`

Recomendar/aplicar cuando exista una o más condiciones:

- mismo valor y misma semántica en dos o más capas;
- límite de contrato usado por schema, servicio y UI;
- código de error serializado y consumido por backend y cliente;
- estados de protocolo usados por validadores, serializadores y polling;
- allowlist de dominio compartida;
- métrica o atributo de contexto repetido entre routers, hooks o handlers;
- regex de input usada en varios boundaries;
- clave pública estable de error, separada de copy traducible;
- runtime constant ubicada dentro de `interfaces/` o `types/` que debe alimentar varios módulos.
- literal unitario reutilizado dentro de un mismo contrato, apto para atom escalar y composición en arrays/agregados `as const`.
- elementos repetidos en más de un array del mismo dominio cuando comparten semántica, sin fusionar arrays contractualmente distintos.

### Mantener local

No promover automáticamente:

- constante con un solo consumidor y semántica privada de adapter;
- datos de mocks, fixtures o catálogos locales;
- labels o mensajes visibles de UI;
- llamadas de localización y msgids;
- tamaños de página, delays o límites exclusivos de una vista;
- paths upstream privados de un cliente;
- statuses HTTP genéricos (`400`, `404`, `500`, `502`, `503`);
- timeouts con responsabilidades distintas, aunque compartan valor;
- mapas de un solo consumidor;
- constantes matemáticas/triviales sin significado de negocio.
- literales únicos o elementos de arrays sin reutilización real; no crear atoms solo por uniformidad visual.

### Separar destinos

- autorización → módulo `permissions/`, `auth/` o equivalente del dominio, no `constants` genérico;
- valores por entorno/deployment → `config/` o settings, no `constants`;
- rutas backend-for-frontend compartidas → `constants/routes.ts` o equivalente;
- paths upstream privados → cliente/adapter;
- mensajes user-facing → i18n/localization;
- regex/estados de parser únicamente locales → parser, salvo contrato cross-layer probado.

## Diseño seguro

### Preservar semántica de validación

Centralizar fuente de patrón no debe cambiar mecanismo de validación sin necesidad.

Preferir:

```ts
export const FACILITY_KIND_PATTERN = /^(warehouse|xd|sc)$/;

string().secure().regex(FACILITY_KIND_PATTERN)
```

No reemplazar automáticamente por un validador distinto: puede cambiar sanitización, coerción, clasificación (`format` vs `enum`) y forma de errores observables.

Para límites compartidos, usar misma constante en schema y validación manual. Mantener separados límites con objetivos distintos, por ejemplo lookup frente a payload malformed para logging.

Al componer arrays desde atoms, preservar orden, referencia e identidad cuando forman parte del contrato. `Array.from`, spread, `Object.freeze` y regex dinámicas requieren validación explícita porque pueden cambiar identidad, mutabilidad, flags o serialización.

### Seguridad y autorización

- Mantener validación basada en schemas en cada boundary usando el validador aprobado por el proyecto.
- Mantener allowlists; no reemplazar allowlist por valores derivados de input no confiable.
- No incluir tokens, cookies, headers, secrets, payloads sensibles ni PII en logs.
- No mover permisos a `constants` si existe estructura específica de autorización.
- No tocar autorización al hacer un refactor de valores salvo pedido explícito.
- No cambiar métodos HTTP, CSRF, auth ni authz como efecto colateral de mover rutas.
- No introducir dependencias nuevas para resolver duplicación si utilidades existentes alcanzan.

### Ciclos y tipos

- Usar objetos `as const` y unions derivados cuando lenguaje/configuración lo recomiende.
- No usar `enum` si configuración TypeScript prohíbe declaraciones no erasables.
- Mantener imports type-only desde `interfaces/` o `types/` cuando corresponda.
- Evitar que `constants/` importe valores desde módulos de tipos si esos módulos deben depender de `constants/`.
- Preferir dirección unidireccional: `atoms/constants → tipos/consumers` o imports type-only sin ciclo runtime.
- Derivar tipos desde atoms/agregados del mismo dominio; no importar valores runtime desde `interfaces/` o `types/` hacia `constants/`.
- Verificar reglas de ciclo, resolución de imports y aliases configurados por el repositorio.

### Documentación

- Agregar documentación del lenguaje para nuevas constantes, objetos de configuración, regex, tipos derivados y helpers no obvios.
- Documentar unidades (`_MS`), límites, formato y consumidor esperado.
- Mantener headers de módulo en archivos nuevos cuando sea convención del proyecto.

## Implementación

1. Crear o ampliar archivo de dominio cohesivo en `constants/`.
2. Identificar atoms escalares reutilizados y definirlos antes de arrays/agregados contractuales.
3. Construir arrays/agregados y tipos derivados desde atoms, conservando contratos separados.
4. Mantener nombre semántico; no usar nombres genéricos como `VALUE`, `LIMIT`, `DATA`.
5. Mover valores sin cambiar strings, orden, default, serialización o respuesta.
4. Actualizar imports de producción y tests.
5. Mantener fixtures literales cuando su finalidad sea validar contrato externo; no reemplazarlos todos por la misma constante.
6. Revisar diff por dominio excluido antes de continuar.
7. No mezclar refactor de constantes con cambios funcionales no solicitados.

## Verificación

Ejecutar comandos definidos por repo. Como base genérica:

```bash
git diff --check
```

Luego detectar y ejecutar comandos disponibles para lint, typecheck, tests y build. Para TypeScript, normalmente:

```bash
npx tsc --noEmit
```

Para feedback rápido, ejecutar primero suites focales de schemas, rutas, servicios, parser y componentes afectados. Luego ejecutar suite completa. En refactors con atoms, comprobar además valores, orden, identidad de arrays/tuplas, serialización y rechazo de valores inválidos.

También comprobar:

```bash
rg -n "@constants" .
rg -n "from ['\"].*/(interfaces|types).*(ERROR_CODES|STATUS|FACILITY|REASON)" src api app lib utils
```

No marcar tarea como completa si tests, lint o build fallan. Si falla por cambio preexistente, aislarlo, documentar archivo/línea y no modificarlo sin autorización.

## Formato de salida

Usar este formato salvo que usuario pida otro:

```markdown
## Alcance
- Base, HEAD, archivos y cambios locales excluidos.

## Candidatos movidos
| Archivo/línea | Valor | Destino | Motivo |

## Candidatos mantenidos locales
| Archivo/línea | Valor | Motivo |

## Cambios aplicados
- Fuentes canónicas.
- Consumers y tests.
- Exclusiones respetadas.

## Validación
| Comando | Resultado |

## Riesgos o bloqueos
- Fallos reales, preexistentes o no ejecutados.
```

Ser explícito cuando cambio es solo estructural y cuando una sustitución puede modificar comportamiento observable. No decir “todo funciona” si suite completa no pasó.
