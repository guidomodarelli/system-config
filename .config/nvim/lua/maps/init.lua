vim.g.mapleader = ','

local keymap = vim.keymap

require "maps.base"
require "maps.bufexplorer"
require "maps.bufferline"
require "maps.nvim-spectre"
require "maps.nvim-tree"
require "maps.telescope"

return {
  -- https://github.com/neovim/nvim-lspconfig#suggested-configuration
  on_attach = function(client, bufnr)
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
    keymap.set('n', 'gD', vim.lsp.buf.declaration, bufopts)
    keymap.set('n', 'gd', vim.lsp.buf.definition, bufopts)
    keymap.set('n', 'K', vim.lsp.buf.hover, bufopts)
    keymap.set('n', 'gi', vim.lsp.buf.implementation, bufopts)
    keymap.set('n', '<C-s>', vim.lsp.buf.signature_help, bufopts)
    keymap.set('n', '<leader>wa', vim.lsp.buf.add_workspace_folder, bufopts)
    keymap.set('n', '<leader>wr', vim.lsp.buf.remove_workspace_folder, bufopts)
    keymap.set('n', '<leader>wl', function()
      print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
    end, bufopts)
    keymap.set('n', '<leader>D', vim.lsp.buf.type_definition, bufopts)
    keymap.set('n', '<leader>rn', vim.lsp.buf.rename, bufopts)
    keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, bufopts)
    keymap.set('n', 'gr', vim.lsp.buf.references, bufopts)
    keymap.set('n', '<leader>F', vim.lsp.buf.formatting, bufopts)
  end
}
