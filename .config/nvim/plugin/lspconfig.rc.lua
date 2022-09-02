local status, nvim_lsp = pcall(require, "lspconfig")
if not status then return end

-- https://github.com/neovim/nvim-lspconfig#suggested-configuration
local on_attach = function(client, bufnr)
  -- formatting
  if client.server_capabilities.documentFormattingProvider then
    local command = vim.api.nvim_command
    command [[augroup Format]]
    command [[autocmd! * <buffer>]]
    command [[autocmd BufWritePre <buffer> lua vim.lsp.buf.formatting_seq_sync()]]
    command [[augroup END]]
  end
  -- Enable completion triggered by <c-x><c-o>
  vim.api.nvim_buf_set_option(bufnr, 'omnifunc', 'v:lua.vim.lsp.omnifunc')

  -- Mappings.
  -- See `:help vim.lsp.*` for documentation on any of the below functions
  local bufopts = { noremap = true, silent = true, buffer = bufnr }
  local keymap = vim.keymap
  keymap.set('n', 'gD', vim.lsp.buf.declaration, bufopts)
  keymap.set('n', 'gd', vim.lsp.buf.definition, bufopts)
  keymap.set('n', 'gi', vim.lsp.buf.implementation, bufopts)
  keymap.set('n', 'gT', vim.lsp.buf.type_definition, bufopts)
  keymap.set('n', 'gr', vim.lsp.buf.references, bufopts)
end

nvim_lsp.volar.setup {
  on_attach = on_attach,
  filetypes = { 'vue' },
}

nvim_lsp.tsserver.setup {
  on_attach = on_attach,
  filetypes = { 'typescript', 'typescriptreact', 'typescript.tsx' },
  cmd = { 'typescript-language-server', '--stdio' }
}

nvim_lsp.sumneko_lua.setup {
  on_attach = on_attach,
  settings = {
    Lua = {
      diagnostics = {
        globals = {
          "vim"
        }
      },
      workspace = {
        library = vim.api.nvim_get_runtime_file("", true),
        checkThirdParty = false
      }
    }
  }
}
