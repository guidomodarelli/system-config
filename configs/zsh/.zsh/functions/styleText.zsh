# Color name to code mapping. Sets STYLE_TEXT_COLOR_CODE instead of echoing so
# styleText can resolve colors without forking a subshell (it runs in hot
# paths such as interactive menus). Works in zsh and bash 3.2.
_style_text_resolve_color_code() {
  case "$1" in
  "black") STYLE_TEXT_COLOR_CODE="30" ;;
  "red") STYLE_TEXT_COLOR_CODE="31" ;;
  "green") STYLE_TEXT_COLOR_CODE="32" ;;
  "yellow") STYLE_TEXT_COLOR_CODE="33" ;;
  "blue") STYLE_TEXT_COLOR_CODE="34" ;;
  "magenta") STYLE_TEXT_COLOR_CODE="35" ;;
  "cyan") STYLE_TEXT_COLOR_CODE="36" ;;
  "white") STYLE_TEXT_COLOR_CODE="37" ;;
  "gray") STYLE_TEXT_COLOR_CODE="90" ;;
  *) STYLE_TEXT_COLOR_CODE="" ;;
  esac
}

function color_code() {
  _style_text_resolve_color_code "$1"
  echo "$STYLE_TEXT_COLOR_CODE"
}

# Get available colors
function available_colors() {
  echo "black red green yellow blue magenta cyan white gray"
}

# Modifiers
BOLD=1
ITALIC=3
UNDERLINE=4
REVERSE=7
STRIKETHROUGH=9

# Function to log styleText errors to file
logStyleTextError() {
  local errorMsg="$1"
  local timestamp=$(date +"%Y%m%d_%H%M%S")
  local logFile="/tmp/styleText_error_${timestamp}.log"

  # Create help text
  local help=""
  help+="$BREAK_LINE\n"
  help+="Usage: styleText [OPTIONS] TEXT\n"
  help+="$BREAK_LINE\n"
  help+="Options:\n"

  {
    echo -e "$errorMsg"
    echo -e "$help"
    echo
    echo "  -b, --bold            | Bold text"
    echo "  -i, --italic          | Italic text"
    echo "  -u, --underline       | Underline text"
    echo "  -s, --strikethrough   | Strikethrough text"
    echo "  -r, --reverse         | Reverse colors"
    echo "  -c, --color           | Text color name ($(available_colors))"
  } | column -t -s '|' >"$logFile"

  echo "Error log written to $logFile" >&2
}

styleText() {
  local MODIFIERS=""
  while [[ $# -gt 0 ]]; do
    if [[ "$1" != -* ]]; then
      break
    fi
    case "$1" in
    -b | --bold)
      MODIFIERS="${MODIFIERS};$BOLD"
      shift
      ;;
    -i | --italic)
      MODIFIERS="${MODIFIERS};$ITALIC"
      shift
      ;;
    -u | --underline)
      MODIFIERS="${MODIFIERS};$UNDERLINE"
      shift
      ;;
    -s | --strikethrough)
      MODIFIERS="${MODIFIERS};$STRIKETHROUGH"
      shift
      ;;
    -r | --reverse)
      MODIFIERS="${MODIFIERS};$REVERSE"
      shift
      ;;
    -c | --color)
      _style_text_resolve_color_code "$2"
      if [[ -n "$2" && -n "$STYLE_TEXT_COLOR_CODE" ]]; then
        MODIFIERS="${MODIFIERS};$STYLE_TEXT_COLOR_CODE"
        shift 2
      else
        local errorMsg="Invalid color name: $2\n"
        errorMsg+="Available colors: $(available_colors)"
        logStyleTextError "$errorMsg"
        return 1
      fi
      ;;
    --)
      shift
      break
      ;;
    *)
      local errorMsg="Unknown option: $0 '$1'"
      logStyleTextError "$errorMsg"
      return 1
      ;;
    esac
  done
  # MODIFIERS only holds digits and semicolons, so it is safe in the format.
  printf "\033[${MODIFIERS}m%s\033[m" "$@"
}

logWhite() {
  styleText -c white "$@"
}

logCyan() {
  styleText -c cyan "$@"
}

logMagenta() {
  styleText -c magenta "$@"
}

logBlue() {
  styleText -c blue "$@"
}

logYellow() {
  styleText -c yellow "$@"
}

logGreen() {
  styleText -c green "$@"
}

logRed() {
  styleText -c red "$@"
}

logGray() {
  styleText -c gray "$@"
}

styleLogMessage() {
  local text="$1"
  shift
  printf "[ $text ] %s\n" "$@"
}

logInfo() {
  styleLogMessage "$(logBlue "INFO")" "$@"
}

logSuccess() {
  styleLogMessage "$(logGreen "SUCCESS")" "$@"
}

logWarn() {
  styleLogMessage "$(logYellow "WARN")" "$@"
}

logError() {
  styleLogMessage "$(logRed "ERROR")" "$@"
}

# Function that formats command output with a colored prompt
# Usage examples:
#   logCommand "git status"   => $ git status   # git is green, status is normal
#   logCommand ls -la         => $ ls -la       # ls is green, -la is normal
# The command name is displayed in green, the rest in normal text,
# with a bold green "$" prompt at the beginning
logCommand() {
  local command
  local rest
  if [[ "$1" == *" "* ]]; then
    # If $1 contains spaces, split it and capture the first part
    command="${1%% *}"
    # The rest becomes part of the arguments
    rest="${1#* }"
    shift
    rest="$rest $@"
  else
    # If $1 doesn't have spaces, capture it normally
    command=$1
    shift
    rest="$@"
  fi
  printf "$(logGreen -b "$") $(logGreen -- $command) $rest\n"
}

logCommandOutput() {
  printf "$(logGreen -b "$") $@\n"
  eval "$@" | while read -r line; do
    printf "  $line\n"
  done
}
