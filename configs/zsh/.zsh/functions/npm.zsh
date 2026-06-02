npm-clean-install() {
    local log_prefix
    local log_separator
    log_prefix="[ $(styleText -b -c cyan "npm-clean-install") ]"
    log_separator="$(styleText -c gray -- "────────────────────────────────────────────────────────────")"

    print -r -- "${log_separator}"
    print -r -- "${log_prefix} Starting clean install..."
    print -r -- "${log_prefix} Removing node_modules if exists..."
    [ -d node_modules ] && rm -rf node_modules && print -r -- "${log_prefix} $(styleText -b -c yellow "Warning: node_modules removed.")"
    print -r -- "${log_prefix} Removing package-lock.json if exists..."
    [ -f package-lock.json ] && rm -rf package-lock.json && print -r -- "${log_prefix} $(styleText -b -c yellow "Warning: package-lock.json removed.")"
    # print -r -- "${log_prefix} Cleaning npm cache..."
    # npm cache clean --force
    print -r -- "${log_separator}"
    print -r -- "${log_prefix} Installing dependencies..."
    npm install
    print -r -- "${log_prefix} $(styleText -b -c green "Done.")"
    print -r -- "${log_separator}"
}
