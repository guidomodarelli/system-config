--build() {
  npm run build
}

--dev() {
  npm run start-dev 2>/dev/null || npm run dev 2>/dev/null
}
