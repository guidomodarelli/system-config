vim.g.mapleader = ','

local keymap = vim.keymap.set
local default_opts = { noremap = true, silent = true }

keymap('n', '<leader>w', ':w<CR>', default_opts)
keymap('n', '<leader>ws', ':wa<CR>:source %<CR>', default_opts)
keymap('n', '<leader>d', ':NvimTreeToggle<CR>', default_opts)

-- Terminal
keymap('n', '<leader>tv', ':botright vnew <Bar> :terminal<CR>', default_opts)
keymap('n', '<leader>th', ':botright new <Bar> :terminal<CR>', default_opts)
keymap('t', '<Esc>', '<C-\\><C-n>', default_opts)

-- Telescope
keymap('n', '<leader>f', ':Telescope find_files hidden=true <CR>', default_opts)
keymap('n', '<leader>s', ':Telescope live_grep<CR>', default_opts)

-- Switched of panels
keymap('n', '<C-j>', '<C-W>j', default_opts)
keymap('n', '<C-k>', '<C-W>k', default_opts)
keymap('n', '<C-h>', '<C-W>h', default_opts)
keymap('n', '<C-l>', '<C-W>l', default_opts)

-- Move lines
keymap('n', '<A-j>', ':m .+1<CR>==', default_opts)
keymap('n', '<A-k>', ':m .-2<CR>==', default_opts)
keymap('i', '<A-j>', '<Esc>:m .+1<CR>==gi', default_opts)
keymap('i', '<A-k>', '<Esc>:m .-2<CR>==gi', default_opts)
keymap('v', '<A-j>', ":m '>+1<CR>gv=gv", default_opts)
keymap('v', '<A-k>', ":m '<-2<CR>gv=gv", default_opts)

-- Buffer Explorer
keymap('n', '<F7>', ':BufExplorer<CR>', default_opts)
keymap('n', '<F5>', ':bp<CR>', default_opts)
keymap('n', '<F6>', ':bn<CR>', default_opts)

-- Double ESC to exit from terminal insert mode to terminal normal mode
keymap("t", "<ESC><ESC>", [[<C-\><C-n>]], default_opts)

-- Stay in visual mode after indenting
keymap("x", "<", "<gv", default_opts)
keymap("x", ">", ">gv", default_opts)

require "user.keymaps.nvim-spectre"

return {
  -- https://github.com/neovim/nvim-lspconfig#suggested-configuration
  on_attach = function(client, bufnr)
    -- Enable completion triggered by <c-x><c-o>
    vim.api.nvim_buf_set_option(bufnr, 'omnifunc', 'v:lua.vim.lsp.omnifunc')

    -- Mappings.
    -- See `:help vim.lsp.*` for documentation on any of the below functions
    local bufopts = { noremap = true, silent = true, buffer = bufnr }
    keymap('n', 'gD', vim.lsp.buf.declaration, bufopts)
    keymap('n', 'gd', vim.lsp.buf.definition, bufopts)
    keymap('n', 'K', vim.lsp.buf.hover, bufopts)
    keymap('n', 'gi', vim.lsp.buf.implementation, bufopts)
    keymap('n', '<C-s>', vim.lsp.buf.signature_help, bufopts)
    keymap('n', '<space>wa', vim.lsp.buf.add_workspace_folder, bufopts)
    keymap('n', '<space>wr', vim.lsp.buf.remove_workspace_folder, bufopts)
    keymap('n', '<space>wl', function()
      print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
    end, bufopts)
    keymap('n', '<space>D', vim.lsp.buf.type_definition, bufopts)
    keymap('n', '<leader>rn', vim.lsp.buf.rename, bufopts)
    keymap('n', '<leader>ca', vim.lsp.buf.code_action, bufopts)
    keymap('n', 'gr', vim.lsp.buf.references, bufopts)
    keymap('n', '<space>f', vim.lsp.buf.formatting, bufopts)
  end
}
