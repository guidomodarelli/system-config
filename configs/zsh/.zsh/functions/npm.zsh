npm-clean-install() {
    echo "[npm-clean-install] Removing node_modules if exists..."
    [ -d node_modules ] && rm -rf node_modules && echo "[npm-clean-install] node_modules removed."
    echo "[npm-clean-install] Removing package-lock.json if exists..."
    [ -f package-lock.json ] && rm -rf package-lock.json && echo "[npm-clean-install] package-lock.json removed."
    echo "[npm-clean-install] Cleaning npm cache..."
    npm cache clean --force
    echo "[npm-clean-install] Installing dependencies..."
    npm install
    echo "[npm-clean-install] Done."
}