local status, mason = pcall(require, 'mason')
if (not status) then return end
local status_lsp, lspconfig = pcall(require, 'mason-lspconfig')
if (not status_lsp) then return end

mason.setup {}
lspconfig.setup {
  ensure_installed = { 'tailwindcss' }
}

require 'lspconfig'.tailwindcss.setup {}
