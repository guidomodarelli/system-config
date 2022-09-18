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
  -- Enable completion triggered by <c-x><c-o>
  vim.api.nvim_buf_set_option(bufnr, 'omnifunc', 'v:lua.vim.lsp.omnifunc')

  -- Mappings.
  -- See `:help vim.lsp.*` for documentation on any of the below functions
  local status_wk, wk = pcall(require, 'which-key')
  if (not status_wk) then return end

  wk.register({
    g = {
      D = { vim.lsp.buf.declaration, 'Go to declaration', noremap = true, buffer = bufnr },
      d = { '<cmd>Telescope lsp_definitions<CR>', 'Go to definition', noremap = true, buffer = bufnr },
      i = { '<cmd>Telescope lsp_implementations<CR>', 'Go to implementation', noremap = true, buffer = bufnr },
      T = { '<cmd>Telescope lsp_type_definitions<CR>', 'Go to type definition', noremap = true, buffer = bufnr },
      r = { '<cmd>Telescope lsp_references<CR>', 'Go to references', noremap = true, buffer = bufnr },
      f = { vim.lsp.buf.formatting, 'Formatting', noremap = true, buffer = bufnr },
      s = { vim.lsp.buf.document_symbol, 'Document Symbol', noremap = true, buffer = bufnr },
      w = {
        a = { vim.lsp.buf.add_workspace_folder, 'Add workspace folder', noremap = true, buffer = bufnr },
        r = { vim.lsp.buf.remove_workspace_folder, 'Remove workspace folder', noremap = true, buffer = bufnr },
        l = {
          '<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>',
          'List workspace folders',
          noremap = true,
          buffer = bufnr
        },
      },
      p = { '<cmd>Lspsaga preview_definition<CR>', 'Preview definiton' },
      F = { '<cmd>Lspsaga lsp_finder<CR>', 'Definition, Implementations and references' },
      C = { '<cmd>Lspsaga code_action<CR>', 'Code actions' },
    },

    ['<C-k>'] = { vim.lsp.buf.signature_help, 'Signature help', mode = 'i', buffer = bufnr },
    K         = { '<cmd>Lspsaga hover_doc<CR>', 'Hover documentation' },
    ['<M-r>'] = { '<cmd>Lspsaga rename<CR>', 'Rename' },
    ['[d']    = {
      '<cmd>lua vim.diagnostic.goto_prev({ border = "rounded" })<CR>',
      'Diagnostic jump previous',
      noremap = true,
      silent = true
    },
    [']d']    = {
      '<cmd>lua vim.diagnostic.goto_next({ border = "rounded" })<CR>',
      'Diagnostic jump next',
      noremap = true,
      silent = true
    },

  })
end

local capabilities = require('cmp_nvim_lsp').update_capabilities(vim.lsp.protocol.make_client_capabilities())

local servers = {
  'pyright',
  'jdtls',
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
          "vim"
        }
      },
      workspace = {
        library = vim.api.nvim_get_runtime_file("", true),
        checkThirdParty = false
      },
      -- By default, lua-language-server sends anonymized data to its developers. Stop it using the following.
      telemetry = {
        enable = false,
      },
    }
  }
}
