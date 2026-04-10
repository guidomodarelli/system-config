#!/bin/bash

set -euo pipefail

if ! command -v git >/dev/null 2>&1; then
  echo "[ ERROR ] El comando requerido 'git' no está disponible en PATH." >&2
  exit 2
fi

if ! ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  echo "[ ERROR ] Este script debe ejecutarse dentro de un repositorio Git válido." >&2
  exit 2
fi

ROOT_CONFIGS_DIR="$ROOT_DIR/configs"
CONFIG_PATHS_FILE="$ROOT_DIR/symlinks.yml"

POINTER="->"

print_last_argument() {
  printf "%s" "${@: -1}"
}

logRed() { print_last_argument "$@"; }
logGreen() { print_last_argument "$@"; }
logYellow() { print_last_argument "$@"; }
logBlue() { print_last_argument "$@"; }
logMagenta() { print_last_argument "$@"; }
logGray() { print_last_argument "$@"; }

check_commands() {
  local command_name

  for command_name in "$@"; do
    command -v "$command_name" >/dev/null 2>&1 || {
      printf "[ ERROR ] Falta comando requerido: %s\n" "$command_name" >&2
      return 1
    }
  done
}

command_supports_null_sorting() {
  printf "b\0a\0" | sort -z >/dev/null 2>&1
}

sanitize_text_for_log() {
  local text="$1"
  text="${text//$'\n'/ }"
  text="${text//$'\r'/ }"
  text="${text//$'\t'/ }"
  printf "%s" "$text" | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//'
}

capture_stderr_message() {
  local stderr_file="$1"
  if [ ! -s "$stderr_file" ]; then
    LAST_COMMAND_ERROR=""
    return 0
  fi
  LAST_COMMAND_ERROR=$(sanitize_text_for_log "$(cat "$stderr_file")")
}

run_command_with_optional_sudo() {
  local requires_sudo="$1"
  shift

  local -a raw_command=("$@")
  local -a command_to_run=("${raw_command[@]}")
  local stderr_file
  stderr_file=$(mktemp "${TMPDIR:-/tmp}/dotfiler_command_stderr_XXXXXX.log")

  if [ "$requires_sudo" = "true" ]; then
    command_to_run=(sudo "${command_to_run[@]}")
  fi

  if ! "${command_to_run[@]}" 2>"$stderr_file"; then
    capture_stderr_message "$stderr_file"
    rm -f "$stderr_file"
    return 1
  fi

  LAST_COMMAND_ERROR=""
  rm -f "$stderr_file"
  return 0
}

load_optional_helpers() {
  local style_file="$ROOT_CONFIGS_DIR/zsh/.zsh/functions/styleText.zsh"
  local constants_file="$ROOT_CONFIGS_DIR/zsh/.zsh/constants.zsh"
  local check_commands_file="$ROOT_CONFIGS_DIR/zsh/.zsh/functions/check_command.zsh"

  if [ -r "$style_file" ]; then
    # shellcheck disable=SC1090
    if ! source "$style_file"; then
      printf "[ AVISO ] No se pudo cargar helper opcional: %s\n" "$style_file" >&2
    fi
  fi
  if [ -r "$constants_file" ]; then
    # shellcheck disable=SC1090
    if ! source "$constants_file"; then
      printf "[ AVISO ] No se pudo cargar helper opcional: %s\n" "$constants_file" >&2
    fi
  fi
  if [ -r "$check_commands_file" ]; then
    # shellcheck disable=SC1090
    if ! source "$check_commands_file"; then
      printf "[ AVISO ] No se pudo cargar helper opcional: %s\n" "$check_commands_file" >&2
    fi
  fi
}

load_optional_helpers

TMP_SCRIPT=""
FAILED_TARGETS_FILE=""

DEBUG=${DEBUG:-false}
DRY_RUN=false
USE_COLOR=true
USE_ICONS=true
USE_PATH_STYLE=true
QUIET=false
VERBOSE=false

EXIT_CODE_SUCCESS=0
EXIT_CODE_RUNTIME_ERROR=1
EXIT_CODE_INPUT_ERROR=2

ICON_DELETE=${ICON_DELETE:-"✖"}
ICON_BACKUP=${ICON_BACKUP:-"↺"}
ICON_NOTE=${ICON_NOTE:-"!"}
ICON_LINK=${ICON_LINK:-"⇢"}
ICON_SKIP=${ICON_SKIP:-"⊘"}
ICON_DONE=${ICON_DONE:-"✔"}
ICON_GROUP=${ICON_GROUP:-"▸"}

START_TIME_SECONDS=$(date +%s)
START_TIME_ISO_UTC=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
COUNT_CREATED=0
COUNT_REPLACED=0
COUNT_BACKUPS=0
COUNT_SIMULATED=0
COUNT_ERRORS=0
COUNT_WINDOWS_QUEUED=0
COUNT_SUDO_OPERATIONS=0
LAST_OUTPUT_WAS_SEPARATOR=false
COUNT_PLANNED_CREATED=0
COUNT_PLANNED_REPLACED=0
COUNT_PLANNED_BACKUPS=0
COUNT_PLANNED_WINDOWS_QUEUED=0
SORT_SUPPORTS_NULL_BYTE=false
LAST_COMMAND_ERROR=""

is_debug() {
  if [ "$DEBUG" = true ]; then
    return 0 # true
  fi
  return 1 # false
}

is_darwin() {
  if [ "$(uname)" = "Darwin" ]; then
    return 0 # true
  fi
  return 1 # false
}

is_wsl() {
  if grep -qi microsoft /proc/version 2>/dev/null || grep -qi wsl /proc/version 2>/dev/null; then
    return 0 # true
  fi
  return 1 # false
}

get_linux_distro() {
  if [ -f "/etc/debian_version" ]; then
    echo "debian"
  else
    echo "all"
  fi
}

format_with_style() {
  local formatter="$1"
  shift

  if [ "$USE_COLOR" = "true" ] && command -v "$formatter" >/dev/null 2>&1; then
    "$formatter" "$@"
  else
    print_last_argument "$@"
  fi
}

print_red() {
  format_with_style "logRed" "$@"
}

print_green() {
  format_with_style "logGreen" "$@"
}

print_yellow() {
  format_with_style "logYellow" "$@"
}

print_blue() {
  format_with_style "logBlue" "$@"
}

print_magenta() {
  format_with_style "logMagenta" "$@"
}

print_gray() {
  format_with_style "logGray" "$@"
}

normalize_display_path() {
  local path="$1"

  if [[ "$path" == *\\* ]]; then
    printf "%s" "$path"
    return 0
  fi

  printf "%s" "$path" | sed -E 's#/+#/#g'
}

abbreviate_home_path() {
  local path="$1"

  if [[ "$path" == "$HOME"* ]]; then
    path="~${path/#$HOME/}"
  fi

  printf "%s" "$path"
}

printPath() {
  local path="$1"
  local normalized_path
  normalized_path=$(normalize_display_path "$path")

  if [ "$USE_PATH_STYLE" = "true" ] && [ "$USE_COLOR" = "true" ] && command -v styleText >/dev/null 2>&1; then
    styleText -u -i -- "$normalized_path"
  else
    printf "%s" "$normalized_path"
  fi
}

build_icon() {
  local icon_value="$1"

  if [ "$USE_ICONS" = "true" ]; then
    printf "%s" "$icon_value"
  fi
}

can_print_details() {
  if [ "$QUIET" = "true" ]; then
    return 1
  fi
  return 0
}

print_link_block_separator() {
  if can_print_details && [ "$LAST_OUTPUT_WAS_SEPARATOR" != "true" ]; then
    printf "%s\n" "$(print_gray -b "────────────────────────────────────────────────────────")"
    LAST_OUTPUT_WAS_SEPARATOR=true
  fi
}

log_info_action() {
  local message="$1"
  if can_print_details; then
    printf "[ %s ] %s\n" "$(print_blue -b "INFO")" "$message"
    LAST_OUTPUT_WAS_SEPARATOR=false
  fi
}

log_backup_action() {
  local message="$1"
  if can_print_details; then
    printf "[ %s ] %s %s\n" "$(print_green -b "RESP")" "$(print_green -b "$(build_icon "$ICON_BACKUP")")" "$message"
    LAST_OUTPUT_WAS_SEPARATOR=false
  fi
}

log_delete_action() {
  local message="$1"
  if can_print_details; then
    printf "[ %s ] %s %s\n" "$(print_red -b "ELIM")" "$(print_red -b "$(build_icon "$ICON_DELETE")")" "$message"
    LAST_OUTPUT_WAS_SEPARATOR=false
  fi
}

log_note_action() {
  local message="$1"
  if can_print_details; then
    printf "[ %s ] %s %s\n" "$(print_yellow -b "NOTA")" "$(print_yellow -b "$(build_icon "$ICON_NOTE")")" "$message"
    LAST_OUTPUT_WAS_SEPARATOR=false
  fi
}

log_warn_action() {
  local message="$1"
  printf "[ %s ] %s\n" "$(print_yellow -b "AVISO")" "$message" >&2
  LAST_OUTPUT_WAS_SEPARATOR=false
}

log_error_action() {
  local message="$1"
  printf "[ %s ] %s\n" "$(print_red -b "ERROR")" "$message" >&2
  LAST_OUTPUT_WAS_SEPARATOR=false
}

print_group_header() {
  local group_path="$1"
  if can_print_details; then
    printf "[ %s ] %s %s\n" "$(print_magenta -b "GRUPO")" "$(print_magenta -b "$(build_icon "$ICON_GROUP")")" "$(printPath "$group_path")"
    LAST_OUTPUT_WAS_SEPARATOR=false
  fi
}

print_operation_duration() {
  local started_at_seconds="$1"

  if [ "$VERBOSE" = "true" ] && can_print_details; then
    local ended_at_seconds
    ended_at_seconds=$(date +%s)
    local elapsed_seconds=$((ended_at_seconds - started_at_seconds))
    printf "[ %s ] transcurrido=%ss\n" "$(print_gray -b "TIEMPO")" "$elapsed_seconds"
    LAST_OUTPUT_WAS_SEPARATOR=false
  fi
}

print_help() {
  cat <<'USAGE'
Uso: ./scripts/dotfiler/dotfiler.sh [opciones]

Opciones:
  --dry-run   Muestra los cambios planificados sin escribir archivos
  --no-color  Desactiva los estilos ANSI
  --plain     Desactiva estilos, íconos y énfasis de rutas
  --verbose   Muestra detalles de tiempo por operación
  --quiet     Oculta logs por ítem y muestra solo resumen/errores
  --help      Muestra esta ayuda
USAGE
}

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
    --dry-run)
      DRY_RUN=true
      ;;
    --no-color)
      USE_COLOR=false
      USE_PATH_STYLE=false
      ;;
    --plain)
      USE_COLOR=false
      USE_ICONS=false
      USE_PATH_STYLE=false
      ;;
    --verbose)
      VERBOSE=true
      ;;
    --quiet)
      QUIET=true
      ;;
    --help)
      print_help
      exit 0
      ;;
    *)
      log_error_action "Opción desconocida: $1"
      print_help
      exit "$EXIT_CODE_INPUT_ERROR"
      ;;
    esac
    shift
  done
}

record_failed_target() {
  local target="$1"
  local reason="$2"
  reason=$(sanitize_text_for_log "$reason")
  printf "%s\t%s\n" "$target" "$reason" >> "$FAILED_TARGETS_FILE"
}

cleanup_temp_files() {
  rm -f "${TMP_SCRIPT:-}" "${FAILED_TARGETS_FILE:-}"
}

initialize_temp_files() {
  TMP_SCRIPT=$(mktemp "${TMPDIR:-/tmp}/wsl_symlink_XXXXXX.ps1")
  FAILED_TARGETS_FILE=$(mktemp "${TMPDIR:-/tmp}/dotfiler_failed_targets_XXXXXX.log")

  cat > "$TMP_SCRIPT" <<'POWERSHELL_HEADER'
$ErrorActionPreference = 'Stop'
# Autogenerated symlink creation script
POWERSHELL_HEADER
}

validate_paths_config() {
  if [ ! -f "$CONFIG_PATHS_FILE" ]; then
    log_error_action "No se encontró el archivo de configuración: $(printPath "$CONFIG_PATHS_FILE")"
    return 1
  fi

  if ! yq eval '.paths' "$CONFIG_PATHS_FILE" >/dev/null 2>&1; then
    log_error_action "Configuración inválida en $(printPath "$CONFIG_PATHS_FILE"): no se pudo interpretar YAML."
    return 1
  fi

  if ! yq eval -o=json '.paths' "$CONFIG_PATHS_FILE" | jq -e 'type == "array"' >/dev/null 2>&1; then
    log_error_action "Configuración inválida en $(printPath "$CONFIG_PATHS_FILE"): 'paths' debe ser un arreglo."
    return 1
  fi

  return 0
}

# Get the current WSL distribution name
get_wsl_distro_name() {
  if is_wsl; then
    local wsl_distro_name="${WSL_DISTRO_NAME:-}"
    if [ -n "$wsl_distro_name" ]; then
      echo "$wsl_distro_name"
      return 0
    fi

    if command -v wslpath >/dev/null 2>&1; then
      local win_root
      win_root=$(wslpath -w / 2>/dev/null)
      local distro_name_from_unc
      distro_name_from_unc=$(printf "%s" "$win_root" | sed -nE 's#^\\\\wsl(\.localhost)?\\([^\\]+)\\.*#\2#p')
      if [ -n "$distro_name_from_unc" ]; then
        echo "$distro_name_from_unc"
        return 0
      fi
    fi

    if [ -r /etc/os-release ]; then
      awk -F= '/^NAME=/{gsub(/^"/, "", $2); gsub(/"$/, "", $2); print $2; exit}' /etc/os-release | tr -d '\r\n'
      return 0
    fi
  fi

  return 1
}

# Format path for Windows when in WSL
format_wsl_windows_path() {
  local path="$1"
  local distro_name
  if ! distro_name=$(get_wsl_distro_name); then
    log_error_action "No se pudo resolver el nombre de la distribución WSL."
    return 1
  fi
  if [ -z "$distro_name" ]; then
    log_error_action "Se obtuvo un nombre de distribución WSL vacío."
    return 1
  fi

  path="\\\\wsl\$\\$distro_name$path"
  path="${path//\//\\}"

  printf "%s\n" "$path"
}

create_backup() {
  local path="$1"
  local requires_sudo="$2"
  local backup_path
  backup_path=$(resolve_backup_path "$path")

  if [ "$DRY_RUN" = "true" ]; then
    ((COUNT_PLANNED_BACKUPS+=1))
    log_backup_action "Crearía $(printPath "${backup_path//\\/\\\\}")"
    return 0
  fi

  if ! run_command_with_optional_sudo "$requires_sudo" mv "$path" "$backup_path"; then
    local failure_reason="Fallo al crear respaldo"
    if [ -n "$LAST_COMMAND_ERROR" ]; then
      failure_reason="$failure_reason: $LAST_COMMAND_ERROR"
    fi
    log_error_action "No se pudo crear respaldo para $(printPath "$path")"
    record_failed_target "$path" "$failure_reason"
    return 1
  fi

  ((COUNT_BACKUPS+=1))
  log_backup_action "Creado $(printPath "${backup_path//\\/\\\\}")"
}

resolve_backup_path() {
  local original_path="$1"
  local backup_path="${original_path}.bak"
  local index=1

  while [ -e "$backup_path" ] || [ -L "$backup_path" ]; do
    backup_path="${original_path}.bak.${index}"
    index=$((index + 1))
  done

  printf "%s" "$backup_path"
}

remove_old_symlink() {
  local target="$1"
  local requires_sudo="$2"

  if [ "$DRY_RUN" = "true" ]; then
    log_delete_action "Eliminaría symlink anterior $(printPath "$target")"
    return 0
  fi

  if ! run_command_with_optional_sudo "$requires_sudo" rm "$target"; then
    local failure_reason="Fallo al eliminar symlink anterior"
    if [ -n "$LAST_COMMAND_ERROR" ]; then
      failure_reason="$failure_reason: $LAST_COMMAND_ERROR"
    fi
    log_error_action "No se pudo eliminar symlink anterior $(printPath "$target")"
    record_failed_target "$target" "$failure_reason"
    return 1
  fi

  log_delete_action "Symlink anterior eliminado $(printPath "$target")"
}

escape_powershell_single_quotes() {
  local value="$1"
  printf "%s" "${value//\'/\'\'}"
}

validate_powershell_value() {
  local value="$1"

  if [[ "$value" == *$'\n'* ]] || [[ "$value" == *$'\r'* ]]; then
    return 1
  fi

  return 0
}

# This function creates a symbolic link from the source path to the target location
# It handles existing files by creating backups and removes old symlinks if they exist
make_symlink() {
  local path="$1"
  local target="$2"
  local started_at_seconds
  started_at_seconds=$(date +%s)

  local requires_sudo="false"
  local target_dir
  target_dir=$(dirname "$target")
  local writable_base_dir="$target_dir"

  if [ "$DRY_RUN" = "true" ]; then
    ((COUNT_SIMULATED+=1))
  fi

  while [ ! -d "$writable_base_dir" ] && [ "$writable_base_dir" != "/" ]; do
    writable_base_dir=$(dirname "$writable_base_dir")
  done

  if [[ ! -w "$writable_base_dir" ]]; then
    requires_sudo="true"
    ((COUNT_SUDO_OPERATIONS+=1))
    log_note_action "Usando permisos elevados para $(printPath "$target")"
  fi

  if [ -L "${target}.bak" ]; then
    if ! remove_old_symlink "${target}.bak" "$requires_sudo"; then
      return 1
    fi
  fi

  if [ -L "$target" ]; then
    if ! remove_old_symlink "$target" "$requires_sudo"; then
      return 1
    fi
    if [ "$DRY_RUN" = "true" ]; then
      ((COUNT_PLANNED_REPLACED+=1))
    else
      ((COUNT_REPLACED+=1))
    fi
  elif [ -e "$target" ]; then
    if ! create_backup "$target" "$requires_sudo"; then
      return 1
    fi
    if [ "$DRY_RUN" = "true" ]; then
      ((COUNT_PLANNED_REPLACED+=1))
    else
      ((COUNT_REPLACED+=1))
    fi
  else
    if [ "$DRY_RUN" = "true" ]; then
      ((COUNT_PLANNED_CREATED+=1))
    else
      ((COUNT_CREATED+=1))
    fi
  fi

  if [ "$DRY_RUN" != "true" ]; then
    if ! run_command_with_optional_sudo "$requires_sudo" mkdir -p "$(dirname "$target")"; then
      local failure_reason="Fallo al crear directorio padre"
      if [ -n "$LAST_COMMAND_ERROR" ]; then
        failure_reason="$failure_reason: $LAST_COMMAND_ERROR"
      fi
      log_error_action "No se pudo crear directorio padre para $(printPath "$target")"
      record_failed_target "$target" "$failure_reason"
      return 1
    fi
  fi

  if [[ "$path" == *\\wsl\$\\* ]]; then
    log_info_action "$(print_blue -b "$(build_icon "$ICON_LINK")") Preparando destino WSL del symlink $(printPath "${path//\\/\\\\}")"

    if [ "$DRY_RUN" = "true" ]; then
      ((COUNT_PLANNED_WINDOWS_QUEUED+=1))
      log_info_action "$(print_blue -b "$(build_icon "$ICON_SKIP")") Encolaría comando de symlink para Windows"
    else
      if ! command -v wslpath >/dev/null 2>&1; then
        record_failed_target "$target" "Falta comando requerido: wslpath"
        return 1
      fi
      local win_target
      if ! win_target=$(wslpath -w "$target" 2>/dev/null); then
        record_failed_target "$target" "Fallo al convertir destino con wslpath"
        return 1
      fi
      if ! validate_powershell_value "$win_target" || ! validate_powershell_value "$path"; then
        log_error_action "Se detectaron caracteres no válidos para PowerShell en las rutas del symlink"
        record_failed_target "$target" "Ruta inválida para script PowerShell"
        return 1
      fi
      local escaped_win_target
      escaped_win_target=$(escape_powershell_single_quotes "$win_target")
      local escaped_path
      escaped_path=$(escape_powershell_single_quotes "$path")
      echo "New-Item -ItemType SymbolicLink -Path '$escaped_win_target' -Target '$escaped_path' -Force -ErrorAction Stop | Out-Null" >> "$TMP_SCRIPT"
      ((COUNT_WINDOWS_QUEUED+=1))
    fi
  else
    if [ "$DRY_RUN" = "true" ]; then
      log_info_action "$(print_blue -b "$(build_icon "$ICON_SKIP")") Crearía symlink"
    else
      if ! run_command_with_optional_sudo "$requires_sudo" ln -s "$path" "$target"; then
        local failure_reason="Fallo al crear symlink"
        if [ -n "$LAST_COMMAND_ERROR" ]; then
          failure_reason="$failure_reason: $LAST_COMMAND_ERROR"
        fi
        log_error_action "No se pudo crear symlink $(printPath "$target") -> $(printPath "${path//\\/\\\\}")"
        record_failed_target "$target" "$failure_reason"
        return 1
      fi
    fi
  fi

  log_info_action "$(print_blue -b "$(build_icon "$ICON_LINK")") $(printPath "$target") $(print_magenta -b -- "${POINTER}${POINTER}") $(printPath "${path//\\/\\\\}")"
  print_operation_duration "$started_at_seconds"

  return 0
}

first_letter() {
  printf "%s" "${1:0:1}"
}

resolve_absolute_path() {
  local path="$1"

  if command -v realpath >/dev/null 2>&1; then
    realpath "$path" 2>/dev/null
    return $?
  fi

  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$path" 2>/dev/null
    return $?
  fi

  return 1
}

contains_glob_pattern() {
  local candidate_path="$1"
  [[ "$candidate_path" == *\** ]] || [[ "$candidate_path" == *\?* ]] || [[ "$candidate_path" == *\[* ]]
}

run_elevated_powershell_script() {
  local tmp_script="$1"
  local started_at_seconds
  started_at_seconds=$(date +%s)

  print_link_block_separator

  if ! grep -q 'SymbolicLink' "$tmp_script"; then
    log_info_action "$(print_blue -b "$(build_icon "$ICON_SKIP")") No hay operaciones de symlink para Windows encoladas; se omite PowerShell elevado."
    print_operation_duration "$started_at_seconds"
    return 0
  fi

  if [ "$DRY_RUN" = "true" ]; then
    log_info_action "$(print_blue -b "$(build_icon "$ICON_SKIP")") Modo simulación activo, se omite ejecución de PowerShell elevado."
    print_operation_duration "$started_at_seconds"
    return 0
  fi

  if ! check_commands wslpath powershell.exe; then
    return 1
  fi

  local win_tmp_script
  win_tmp_script=$(wslpath -w "$tmp_script")
  if ! validate_powershell_value "$win_tmp_script"; then
    log_error_action "La ruta del script temporal contiene caracteres no válidos para PowerShell."
    record_failed_target "powershell_elevado" "Ruta temporal inválida para PowerShell"
    return 1
  fi
  local escaped_win_tmp_script
  escaped_win_tmp_script=$(escape_powershell_single_quotes "$win_tmp_script")

  local powershell_command
  powershell_command="\$scriptPath = '$escaped_win_tmp_script'; \$process = Start-Process PowerShell -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', \$scriptPath) -Verb RunAs -Wait -PassThru -WindowStyle Hidden; exit \$process.ExitCode"
  if ! powershell.exe -NoProfile -Command "$powershell_command"; then
    log_error_action "No se pudo ejecutar el script de PowerShell elevado"
    record_failed_target "powershell_elevado" "Fallo al ejecutar script PowerShell"
    return 1
  fi

  print_operation_duration "$started_at_seconds"
}

# Get Windows username when in WSL
get_windows_username() {
  if is_wsl; then
    if [ -f /mnt/c/Windows/System32/cmd.exe ]; then
      /mnt/c/Windows/System32/cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r\n'
    elif command -v powershell.exe >/dev/null 2>&1; then
      # shellcheck disable=SC2016
      powershell.exe -Command '$env:USERNAME' 2>/dev/null | tr -d '\r'
    elif [ -n "${WSLENV:-}" ] && [ -n "${USERNAME:-}" ]; then
      echo "$USERNAME"
    else
      echo "$USER"
    fi
  else
    echo "$USER"
  fi
}

resolve_windows_username() {
  local windows_username
  windows_username=$(get_windows_username)
  windows_username=$(sanitize_text_for_log "$windows_username")

  if [ -n "$windows_username" ]; then
    printf "%s\n" "$windows_username"
    return 0
  fi

  if [ -n "${USER:-}" ]; then
    printf "%s\n" "$USER"
    return 0
  fi

  return 1
}

build_path_obj() {
  local path="$1"
  local target="$2"

  jq -cn --arg path "$path" --arg target "$target" '{path: $path, target: $target}'
}

get_abs_path() {
  local path="$1"

  if [ "$(first_letter "$path")" != "/" ] && [ "$(first_letter "$path")" != "~" ]; then
    path="$ROOT_CONFIGS_DIR/$path"
  fi

  if [ "$path" = "~" ]; then
    path="$HOME"
  elif [[ "$path" == \~/* ]]; then
    path="$HOME/${path#\~/}"
  fi

  if [ ! -e "$path" ] && [ ! -L "$path" ]; then
    return 0
  fi

  resolve_absolute_path "$path" || true
}

# Expand environment variables in a path string
expand_env_vars() {
  local path="$1"
  local user_value="$USER"
  local literal_home="\$HOME"
  local literal_user="\$USER"

  if [[ "$path" == /mnt/c/* ]] || [[ "$path" == WSL://* ]]; then
    user_value="${USERNAME:-$USER}"
  fi

  if [ "$path" = "~" ]; then
    path="$HOME"
  elif [[ "$path" == \~/* ]]; then
    path="$HOME/${path#\~/}"
  fi

  if [ "$path" = "$literal_home" ]; then
    path="$HOME"
  elif [[ "$path" == "$literal_home/"* ]]; then
    path="$HOME/${path#"$literal_home"/}"
  fi
  path="${path//\/\$HOME\//\/$HOME\/}"
  if [[ "$path" == */"$literal_home" ]]; then
    path="${path%/\$HOME}/$HOME"
  fi

  if [ "$path" = "$literal_user" ]; then
    path="$user_value"
  elif [[ "$path" == "$literal_user/"* ]]; then
    path="$user_value/${path#"$literal_user"/}"
  fi
  path="${path//\/\$USER\//\/$user_value\/}"
  if [[ "$path" == */"$literal_user" ]]; then
    path="${path%/\$USER}/$user_value"
  fi

  printf "%s\n" "$path"
}

expand_wildcard_paths() {
  local wildcard_path="$1"
  local wildcard_dir_path="."
  local wildcard_name_pattern="$wildcard_path"

  if [[ "$wildcard_path" == */* ]]; then
    wildcard_dir_path="${wildcard_path%/*}"
    wildcard_name_pattern="${wildcard_path##*/}"
  fi

  local absolute_wildcard_dir_path
  absolute_wildcard_dir_path=$(get_abs_path "$wildcard_dir_path")

  if [ -z "$absolute_wildcard_dir_path" ] || [ ! -d "$absolute_wildcard_dir_path" ]; then
    log_warn_action "Directorio no encontrado: $wildcard_dir_path"
    return 0
  fi

  if [ "$SORT_SUPPORTS_NULL_BYTE" = "true" ]; then
    find "$absolute_wildcard_dir_path" -maxdepth 1 -mindepth 1 -name "$wildcard_name_pattern" -print0 | sort -z
  else
    find "$absolute_wildcard_dir_path" -maxdepth 1 -mindepth 1 -name "$wildcard_name_pattern" -print0 |
      perl -0ne 'push @items, $_; END { print for sort @items }'
  fi
}

add_path_to_output() {
  local path="$1"
  local target="$2"
  local original_path="$1"
  local source_basename="${path##*/}"

  target="$target/$source_basename"

  path=$(get_abs_path "$path")
  if [ -z "$path" ]; then
    log_warn_action "Ruta de origen inválida o inexistente: $original_path"
    record_failed_target "$target" "Ruta de origen inexistente"
    ((COUNT_ERRORS+=1))
    return 0
  fi

  if [[ "$target" == WSL://* ]]; then
    if [ -z "${USERNAME:-}" ]; then
      log_error_action "No se pudo resolver el usuario de Windows para destino WSL."
      record_failed_target "$target" "Usuario de Windows no disponible para destino WSL"
      ((COUNT_ERRORS+=1))
      return 0
    fi
    target=${target//WSL:\/\//}
    target="/mnt/c/Users/$USERNAME/$target"
    target=$(expand_env_vars "$target")
    if ! path=$(format_wsl_windows_path "$path"); then
      record_failed_target "$target" "No se pudo construir la ruta UNC para WSL"
      ((COUNT_ERRORS+=1))
      return 0
    fi
  fi

  build_path_obj "$path" "$target"
}

process_path_entry() {
  local line="$1"
  local selector_override="$2"

  local line_fields
  line_fields=$(printf "%s\n" "$line" | jq -r ". as \$entry | [\$entry.path, (([\$entry.overrides[]? | select($selector_override) | .target] | first) // \"\"), (\$entry.target // \"null\")] | @tsv")

  local path
  local override_target
  local default_target
  IFS=$'\t' read -r path override_target default_target <<< "$line_fields"
  local target="${override_target:-$default_target}"
  local literal_home="\$HOME"
  local literal_user="\$USER"

  if [[ "$target" != WSL://* ]]; then
    if [ "$target" = "null" ]; then
      target="$HOME"
    elif [ "$(first_letter "$target")" != "/" ] &&
      [ "$(first_letter "$target")" != "~" ] &&
      [[ "$target" != "$literal_home"* ]] &&
      [[ "$target" != "$literal_user"* ]]; then
      target="$HOME"/"$target"
    fi
  fi

  target=$(expand_env_vars "$target")

  if is_debug; then
    echo "Path: $(printPath "${path//\\/\\\\}")" >&2
    echo "Target: $(printPath "$target")" >&2
    echo "-----------" >&2
  fi

  if contains_glob_pattern "$path"; then
    while IFS= read -r -d '' item; do
      if is_debug; then
        echo "Item: $(printPath "${item//\\/\\\\}")" >&2
        echo "Target: $(printPath "$target")" >&2
        echo "-----------" >&2
      fi
      add_path_to_output "$item" "$target"
    done < <(expand_wildcard_paths "$path")
  else
    add_path_to_output "$path" "$target"
  fi
}

get_paths() {
  local selector="$1"
  local selector_override="$2"
  local collected_paths_file
  collected_paths_file=$(mktemp "${TMPDIR:-/tmp}/dotfiler_paths_XXXXXX.jsonl")

  while read -r line; do
    process_path_entry "$line" "$selector_override" >> "$collected_paths_file"
  done < <(yq eval -o=json ".paths[] | select($selector)" "$CONFIG_PATHS_FILE" | jq -c '.')

  jq -sc '.' "$collected_paths_file"
  rm -f "$collected_paths_file"
}

retrieve_linux_paths() {
  local current_distro
  current_distro=$(get_linux_distro)
  local wsl_status
  if is_wsl; then
    wsl_status=true
  else
    wsl_status=false
  fi

  local selector='(
    .excludeFor == null or (
      [
        .excludeFor[]? |
        select(
          (
            .platform == null and
            .wsl != null and
            .wsl == '$wsl_status'
          ) or (
            .platform == "linux" and
            (.linuxDistro == null or .linuxDistro == "'$current_distro'")
          )
        )
      ] | length == 0
    )
  ) and (
    .onlyFor == null or (
      [
        .onlyFor[]? |
        select(
          (
            .platform == null and
            .wsl != null and
            .wsl == '$wsl_status'
          ) or (
            .platform == "linux" and
            (.linuxDistro == null or .linuxDistro == "'$current_distro'")
          )
        )
      ] | length > 0
    )
  )'

  local selector_override='((.platform == "linux") and
    (.linuxDistro == null or .linuxDistro == "'$current_distro'")) or
    (.platform == null and .wsl != null and .wsl == '$wsl_status')'

  get_paths "$selector" "$selector_override"
}

retrieve_darwin_paths() {
  local selector='(
    .excludeFor == null or ([.excludeFor[]? | select(.platform == "darwin")] | length == 0)
  ) and (
    .onlyFor == null or ([.onlyFor[]? | select(.platform == "darwin")] | length > 0)
  )'
  local selector_override='.platform == "darwin"'

  get_paths "$selector" "$selector_override"
}

retrieve_paths_for_platform() {
  if is_darwin; then
    retrieve_darwin_paths
  else
    retrieve_linux_paths
  fi
}

apply_resolved_paths() {
  local paths_json="$1"
  local is_first_link="true"
  local last_group=""

  print_link_block_separator

  while read -r line; do
    if [ -z "$line" ]; then
      continue
    fi

    local parsed_line
    parsed_line=$(printf "%s\n" "$line" | jq -r '[.path, .target] | @tsv')
    local path
    local target
    IFS=$'\t' read -r path target <<< "$parsed_line"

    local current_group
    if [[ "$target" == */* ]]; then
      current_group="${target%/*}"
    else
      current_group="."
    fi
    current_group=$(abbreviate_home_path "$current_group")

    if [ "$current_group" != "$last_group" ]; then
      if [ "$is_first_link" != "true" ]; then
        print_link_block_separator
      fi
      print_group_header "$current_group"
      last_group="$current_group"
    fi

    if ! make_symlink "$path" "$target"; then
      ((COUNT_ERRORS+=1))
      log_error_action "La operación falló para el destino $(printPath "$target")"
    fi

    is_first_link="false"
  done < <(printf "%s\n" "$paths_json" | jq -c '.[]')

  if [ "$is_first_link" = "false" ]; then
    print_link_block_separator
  fi
}

print_summary() {
  local end_time_seconds
  end_time_seconds=$(date +%s)
  local end_time_iso_utc
  end_time_iso_utc=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local total_elapsed_seconds=$((end_time_seconds - START_TIME_SECONDS))
  local status_value="[OK] Sin errores"
  local execution_mode="Aplicación real"
  local metric_column_width=32
  local value_column_width=20
  local simulated_label="Omitidos"
  local shown_created="$COUNT_CREATED"
  local shown_replaced="$COUNT_REPLACED"
  local shown_backups="$COUNT_BACKUPS"
  local shown_windows_queued="$COUNT_WINDOWS_QUEUED"
  local shown_simulated="$COUNT_SIMULATED"
  local created_label="Creados"
  local replaced_label="Reemplazados"
  local backups_label="Respaldos"
  local windows_queued_label="Ops. Windows en cola (PS)"

  format_metric_cell() {
    local metric_label="$1"
    local metric_length=${#metric_label}
    local dots_count=$((metric_column_width - metric_length))
    local dots=""

    if [ "$dots_count" -lt 0 ]; then
      dots_count=0
    fi

    while [ "$dots_count" -gt 0 ]; do
      dots="${dots}."
      dots_count=$((dots_count - 1))
    done

    printf "%s%s" "$metric_label" "$dots"
  }

  format_value_cell() {
    local value_text="$1"
    printf "%-${value_column_width}.${value_column_width}s" "$value_text"
  }

  if [ "$COUNT_ERRORS" -gt 0 ]; then
    status_value="[X] Con errores"
  fi

  if [ "$DRY_RUN" = "true" ]; then
    execution_mode="Simulación"
    shown_created="$COUNT_PLANNED_CREATED"
    shown_replaced="$COUNT_PLANNED_REPLACED"
    shown_backups="$COUNT_PLANNED_BACKUPS"
    shown_windows_queued="$COUNT_PLANNED_WINDOWS_QUEUED"
    simulated_label="Omitidos"
    created_label="Creados (plan)"
    replaced_label="Reemplazados (plan)"
    backups_label="Respaldos (plan)"
  fi

  print_link_block_separator
  printf "%s\n" "$(print_blue -b "RESUMEN")"
  LAST_OUTPUT_WAS_SEPARATOR=false
  printf "%s\n" "$(print_gray -b "╔══════════════════════════════════╦══════════════════════╗")"
  printf "%s\n" "$(print_gray -b "║ Métrica                          ║ Valor                ║")"
  printf "%s\n" "$(print_gray -b "╠══════════════════════════════════╬══════════════════════╣")"
  printf "%s\n" "$(print_gray -b "║ $(format_metric_cell "Inicio (UTC)") ║ $(format_value_cell "$START_TIME_ISO_UTC") ║")"
  printf "%s\n" "$(print_gray -b "║ $(format_metric_cell "Fin (UTC)") ║ $(format_value_cell "$end_time_iso_utc") ║")"
  printf "%s\n" "$(print_gray -b "║ $(format_metric_cell "Tiempo total (s)") ║ $(format_value_cell "$total_elapsed_seconds") ║")"
  printf "%s\n" "$(print_gray -b "║ $(format_metric_cell "Modo ejecución") ║ $(format_value_cell "$execution_mode") ║")"
  printf "%s\n" "$(print_gray -b "║ $(format_metric_cell "$created_label") ║ $(format_value_cell "$shown_created") ║")"
  printf "%s\n" "$(print_gray -b "║ $(format_metric_cell "$replaced_label") ║ $(format_value_cell "$shown_replaced") ║")"
  printf "%s\n" "$(print_gray -b "║ $(format_metric_cell "$backups_label") ║ $(format_value_cell "$shown_backups") ║")"
  printf "%s\n" "$(print_gray -b "║ $(format_metric_cell "$simulated_label") ║ $(format_value_cell "$shown_simulated") ║")"
  printf "%s\n" "$(print_gray -b "║ $(format_metric_cell "Ops. con sudo") ║ $(format_value_cell "$COUNT_SUDO_OPERATIONS") ║")"
  printf "%s\n" "$(print_gray -b "║ $(format_metric_cell "$windows_queued_label") ║ $(format_value_cell "$shown_windows_queued") ║")"
  printf "%s\n" "$(print_gray -b "║ $(format_metric_cell "Errores") ║ $(format_value_cell "$COUNT_ERRORS") ║")"
  printf "%s\n" "$(print_gray -b "║ $(format_metric_cell "Estado") ║ $(format_value_cell "$status_value") ║")"
  printf "%s\n" "$(print_gray -b "╚══════════════════════════════════╩══════════════════════╝")"

  if [ "$DRY_RUN" = "true" ]; then
    printf "[ %s ] Modo simulación activo, no se escribieron cambios en el sistema de archivos.\n" "$(print_blue -b "INFO")"
    LAST_OUTPUT_WAS_SEPARATOR=false
  fi

  print_link_block_separator

  if [ "$COUNT_ERRORS" -eq 0 ]; then
    printf "[ %s ] %s Configuración de symlinks finalizada.\n" "$(print_green -b "FIN")" "$(print_green -b "$(build_icon "$ICON_DONE")")"
  else
    printf "[ %s ] Finalizado con %s error(es).\n" "$(print_red -b "FIN")" "$COUNT_ERRORS"
  fi
  LAST_OUTPUT_WAS_SEPARATOR=false
}

print_diagnostics() {
  if [ ! -s "$FAILED_TARGETS_FILE" ]; then
    return 0
  fi

  print_link_block_separator
  printf "%s\n" "$(print_blue -b "DIAGNÓSTICO")"
  LAST_OUTPUT_WAS_SEPARATOR=false

  local diagnostic_index=1
  while IFS=$'\t' read -r failed_target failed_reason; do
    [ -z "$failed_target" ] && continue
    printf "[ %s ] %s) destino=%s | causa=%s\n" \
      "$(print_red -b "ERROR")" \
      "$diagnostic_index" \
      "$(printPath "$failed_target")" \
      "$failed_reason"
    diagnostic_index=$((diagnostic_index + 1))
    LAST_OUTPUT_WAS_SEPARATOR=false
  done < "$FAILED_TARGETS_FILE"
}

main() {
  parse_args "$@"

  if ! check_commands yq jq find mktemp sort awk sed; then
    return "$EXIT_CODE_INPUT_ERROR"
  fi
  if command_supports_null_sorting; then
    SORT_SUPPORTS_NULL_BYTE=true
  elif ! check_commands perl; then
    log_error_action "Se requiere 'sort -z' o 'perl' para ordenar resultados con rutas complejas."
    return "$EXIT_CODE_INPUT_ERROR"
  fi
  if ! command -v realpath >/dev/null 2>&1 && ! command -v python3 >/dev/null 2>&1; then
    log_error_action "Se requiere 'realpath' o 'python3' para resolver rutas absolutas."
    return "$EXIT_CODE_INPUT_ERROR"
  fi
  if ! validate_paths_config; then
    print_diagnostics
    return "$EXIT_CODE_INPUT_ERROR"
  fi

  initialize_temp_files
  trap cleanup_temp_files EXIT

  if ! USERNAME=$(resolve_windows_username); then
    log_error_action "No se pudo resolver el usuario actual para construir rutas destino."
    return "$EXIT_CODE_INPUT_ERROR"
  fi

  local resolved_paths_file
  resolved_paths_file=$(mktemp "${TMPDIR:-/tmp}/dotfiler_resolved_paths_XXXXXX.json")
  retrieve_paths_for_platform > "$resolved_paths_file"
  local paths
  paths=$(cat "$resolved_paths_file")
  rm -f "$resolved_paths_file"
  apply_resolved_paths "$paths"

  if ! run_elevated_powershell_script "$TMP_SCRIPT"; then
    ((COUNT_ERRORS+=1))
  fi

  print_summary
  print_diagnostics

  if [ "$COUNT_ERRORS" -gt 0 ]; then
    return "$EXIT_CODE_RUNTIME_ERROR"
  fi

  return "$EXIT_CODE_SUCCESS"
}

if [ "$EUID" = 0 ]; then
  log_error_action "No ejecutes este script como root."
  exit "$EXIT_CODE_INPUT_ERROR"
fi

main "$@"
