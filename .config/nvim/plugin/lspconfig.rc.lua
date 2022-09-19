local status, nvim_lsp = pcall(require, 'lspconfig')
if not status then return end
-- https://github.com/neovim/nvim-lspconfig#suggested-configuration

local on_attach = function(client, bufnr)
  if client.name == 'tsserver' or client.name == 'jdtls' then
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

  if client.resolved_capabilities.document_highlight then
    local augroup = vim.api.nvim_create_augroup('lsp_document_highlight', { clear = true })
    vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
      group = augroup,
      buffer = 0,
      callback = vim.lsp.buf.document_highlight,
    })
    vim.api.nvim_create_autocmd('CursorMoved', {
      group = augroup,
      buffer = 0,
      callback = vim.lsp.buf.clear_references,
    })
  end

  On_attach_mappings(bufnr)
end

local capabilities = require('cmp_nvim_lsp').update_capabilities(vim.lsp.protocol.make_client_capabilities())

local servers = {
  'pyright',
  'groovyls',
  'svelte',
  'yamlls',
}

for _, lsp in ipairs(servers) do
  nvim_lsp[lsp].setup {
    on_attach = on_attach,
    capabilities = capabilities,
  }
end

nvim_lsp.jdtls.setup {
  on_attach = on_attach,
  capabilities = capabilities,
  filetypes = { 'java' }
}

nvim_lsp.bashls.setup {
  on_attach = on_attach,
  capabilities = capabilities,
  filetypes = { 'zsh', 'bash', 'sh' }
}

nvim_lsp.volar.setup {
  on_attach = on_attach,
  capabilities = capabilities,
  filetypes = { 'vue' },
}

nvim_lsp.tsserver.setup {
  on_attach = on_attach,
  capabilities = capabilities,
  filetypes = { 'typescript', 'typescriptreact', 'typescript.tsx', 'javascript', 'javascriptreact', 'javascript.jsx' },
  cmd = { 'typescript-language-server', '--stdio' }
}

nvim_lsp.sumneko_lua.setup {
  on_attach = on_attach,
  capabilities = capabilities,
  settings = {
    Lua = {
      runtime = {
        -- Tell the language server which version of Lua you're using (most likely LuaJIT in the case of Neovim)
        version = 'LuaJIT',
      },
      diagnostics = {
        globals = {
          'vim'
        }
      },
      workspace = {
        library = vim.api.nvim_get_runtime_file('', true),
        checkThirdParty = false
      },
      -- By default, lua-language-server sends anonymized data to its developers. Stop it using the following.
      telemetry = {
        enable = false,
      },
    }
  }
}
