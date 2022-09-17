local status, nvim_lsp = pcall(require, "lspconfig")
if not status then return end
-- https://github.com/neovim/nvim-lspconfig#suggested-configuration

local on_attach = function(client, bufnr)
  if client.name == "tsserver" then
    client.resolved_capabilities.document_formatting = false
  end
  -- formatting in save
  -- if client.server_capabilities.documentFormattingProvider then
  --   local command = vim.api.nvim_command
  --   command [[augroup Format]]
  --   command [[autocmd! * <buffer>]]
  --   command [[autocmd BufWritePre <buffer> lua vim.lsp.buf.formatting_seq_sync()]]
  --   command [[augroup END]]
  -- end

  -- Enable completion triggered by <c-x><c-o>
  vim.api.nvim_buf_set_option(bufnr, 'omnifunc', 'v:lua.vim.lsp.omnifunc')

  -- Mappings.
  -- See `:help vim.lsp.*` for documentation on any of the below functions
  local status_wk, wk = pcall(require, 'which-key')
  if (not status_wk) then return end

  wk.register({
    g = {
      D = { vim.lsp.buf.declaration, 'Go to declaration', noremap = true, buffer = bufnr },
      d = { ':Telescope lsp_definitions<CR>', 'Go to definition', noremap = true, buffer = bufnr },
      i = { ':Telescope lsp_implementations<CR>', 'Go to implementation', noremap = true, buffer = bufnr },
      T = { ':Telescope lsp_type_definitions<CR>', 'Go to type definition', noremap = true, buffer = bufnr },
      r = { ':Telescope lsp_references<CR>', 'Go to references', noremap = true, buffer = bufnr },
      f = { vim.lsp.buf.formatting, 'Formatting', noremap = true, buffer = bufnr },
    },
    ['<C-k>'] = { vim.lsp.buf.signature_help, 'Signature help', mode = 'i', buffer = bufnr },
  })
end

nvim_lsp.pyright.setup {
  on_attach = on_attach,
}

nvim_lsp.bashls.setup {
  on_attach = on_attach,
  filetypes = { 'zsh', 'bash', 'sh' }
}

nvim_lsp.svelte.setup {
  on_attach = on_attach,
}

nvim_lsp.yamlls.setup {
  on_attach = on_attach,
}

nvim_lsp.volar.setup {
  on_attach = on_attach,
  filetypes = { 'vue' },
}

nvim_lsp.tsserver.setup {
  on_attach = on_attach,
  filetypes = { 'typescript', 'typescriptreact', 'typescript.tsx', 'javascript', 'javascriptreact', 'javascript.jsx' },
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
