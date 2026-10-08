#!/usr/bin/env bats

setup() {
  export TEST_REPO_ROOT="${BATS_TEST_DIRNAME}/../.."
  export CHECK_SCRIPT="${TEST_REPO_ROOT}/scripts/design/check-design-tokens.sh"
  export FIXTURE_FILE="${BATS_TEST_TMPDIR}/DESIGN.md"
}

# Escribe un DESIGN.md mínimo: front matter con la paleta recibida en $1, un
# bloque motion opcional en $3 y un boilerplate cuyo :root contiene las
# declaraciones recibidas en $2.
write_design_fixture() {
  local colors_block="$1"
  local root_declarations="$2"
  local motion_block="${3:-}"
  local motion_section=""
  if [[ -n "${motion_block}" ]]; then
    motion_section="motion:
${motion_block}"
  fi
  cat > "${FIXTURE_FILE}" <<EOF
---
name: Fixture
colors:
${colors_block}
${motion_section}
typography:
  body-md:
    fontSize: 14px
---

## Boilerplate

\`\`\`html
<style>
:root{
  ${root_declarations}
  --sans:'DM Sans',sans-serif;
}
body{color:var(--primary);}
</style>
\`\`\`
EOF
}

@test "el DESIGN.md del repositorio tiene front matter y :root sincronizados" {
  run bash "${CHECK_SCRIPT}"

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"colores sincronizados"* ]]
  [[ "${output}" == *"tokens de motion"* ]]
}

@test "acepta tokens de motion con comillas, comentarios y espacios distintos a los del :root" {
  write_design_fixture '  primary: "#1A1A1A"' '--primary:#1a1a1a;--motion-duration-fast:120ms;--motion-easing-standard:cubic-bezier(0.2,0,0,1);' '  duration-fast:   120ms   # hover
  easing-standard: "cubic-bezier(0.2, 0, 0, 1)"'

  run bash "${CHECK_SCRIPT}" "${FIXTURE_FILE}"

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"1 colores sincronizados y 2 tokens de motion"* ]]
}

@test "falla cuando una variable de motion no coincide con el token" {
  write_design_fixture '  primary: "#1A1A1A"' '--primary:#1a1a1a;--motion-duration-base:300ms;' '  duration-base: 200ms'

  run bash "${CHECK_SCRIPT}" "${FIXTURE_FILE}"

  [ "${status}" -eq 1 ]
  [[ "${output}" == *"valor distinto en --motion-duration-base: front matter 200ms, :root 300ms"* ]]
}

@test "falla cuando un token de motion no tiene variable en el :root" {
  write_design_fixture '  primary: "#1A1A1A"' '--primary:#1a1a1a;' '  duration-fast: 120ms'

  run bash "${CHECK_SCRIPT}" "${FIXTURE_FILE}"

  [ "${status}" -eq 1 ]
  [[ "${output}" == *"falta la variable --motion-duration-fast"* ]]
}

@test "falla cuando el :root declara una variable de motion que no es token" {
  write_design_fixture '  primary: "#1A1A1A"' '--primary:#1a1a1a;--motion-duration-slow:400ms;'

  run bash "${CHECK_SCRIPT}" "${FIXTURE_FILE}"

  [ "${status}" -eq 1 ]
  [[ "${output}" == *"sobra la variable --motion-duration-slow"* ]]
}

@test "acepta hex cortos y mayúsculas equivalentes al token" {
  write_design_fixture '  primary: "#1A1A1A"
  border-neutral: "#CCCCCC"' '--primary:#1a1a1a;--border-neutral:#ccc;'

  run bash "${CHECK_SCRIPT}" "${FIXTURE_FILE}"

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"2 colores sincronizados"* ]]
}

@test "falla cuando un valor del :root no coincide con el token" {
  write_design_fixture '  label: "#6B6B6B"' '--label:#888888;'

  run bash "${CHECK_SCRIPT}" "${FIXTURE_FILE}"

  [ "${status}" -eq 1 ]
  [[ "${output}" == *"valor distinto en --label: front matter #6b6b6b, :root #888888"* ]]
}

@test "falla cuando un token no tiene variable en el :root" {
  write_design_fixture '  primary: "#1A1A1A"
  link: "#1A4F7A"' '--primary:#1a1a1a;'

  run bash "${CHECK_SCRIPT}" "${FIXTURE_FILE}"

  [ "${status}" -eq 1 ]
  [[ "${output}" == *"falta la variable --link"* ]]
}

@test "falla cuando el :root declara un color que no es token" {
  write_design_fixture '  primary: "#1A1A1A"' '--primary:#1a1a1a;--bg:#f8f7f4;'

  run bash "${CHECK_SCRIPT}" "${FIXTURE_FILE}"

  [ "${status}" -eq 1 ]
  [[ "${output}" == *"sobra la variable --bg"* ]]
}

@test "ignora variables que no son colores, como las familias tipográficas" {
  write_design_fixture '  primary: "#1A1A1A"' '--primary:#1a1a1a;'

  run bash "${CHECK_SCRIPT}" "${FIXTURE_FILE}"

  [ "${status}" -eq 0 ]
  [[ "${output}" != *"--sans"* ]]
}

@test "devuelve 2 si el front matter no tiene bloque colors" {
  cat > "${FIXTURE_FILE}" <<'EOF'
---
name: Fixture
---
:root{
  --primary:#1a1a1a;
}
EOF

  run bash "${CHECK_SCRIPT}" "${FIXTURE_FILE}"

  [ "${status}" -eq 2 ]
  [[ "${output}" == *'no se encontró el bloque "colors:"'* ]]
}

@test "devuelve 2 si el archivo no existe" {
  run bash "${CHECK_SCRIPT}" "${BATS_TEST_TMPDIR}/no-existe.md"

  [ "${status}" -eq 2 ]
  [[ "${output}" == *"no se puede leer el archivo"* ]]
}
