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
  local status_wk, wk = pcall(require, 'which-key')
  if (not status_wk) then return end

  wk.register({
    g = {
      D = { vim.lsp.buf.declaration, 'Go to declaration', noremap = true, silent = true, buffer = bufnr },
      d = { vim.lsp.buf.definition, 'Go to definition', noremap = true, silent = true, buffer = bufnr },
      i = { vim.lsp.buf.implementation, 'Go to implementation', noremap = true, silent = true, buffer = bufnr },
      T = { vim.lsp.buf.type_definition, 'Go to type definition', noremap = true, silent = true, buffer = bufnr },
      r = { vim.lsp.buf.references, 'Go to references', noremap = true, silent = true, buffer = bufnr },
    }
  })
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
