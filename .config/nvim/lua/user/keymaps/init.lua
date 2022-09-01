vim.g.mapleader = ','

local keymap = vim.keymap
local default_opts = { noremap = true, silent = true }

-- Don't yank with x
keymap.set('n', 'x', '"_x')

-- Increment/Decrement
keymap.set('n', '+', '<C-a>')
keymap.set('n', '-', '<C-x>')

-- Delete a word backwards
keymap.set('n', 'dw', 'vb"_d')

-- Select all
keymap.set('n', '<C-a>', 'gg<S-v>G')

-- New tab
keymap.set('n', 'te', ':tabedit<CR>', { silent = true })

-- Split window
keymap.set('n', 'ss', ':split<CR><C-w>w', { silent = true }) -- Split horizontal
keymap.set('n', 'sv', ':vsplit<CR><C-w>w', { silent = true }) -- Split vertical

-- Move window
keymap.set('n', '<Space>', '<C-w>w')
keymap.set('n', '<C-j>', '<C-W>j', default_opts)
keymap.set('n', '<C-k>', '<C-W>k', default_opts)
keymap.set('n', '<C-h>', '<C-W>h', default_opts)
keymap.set('n', '<C-l>', '<C-W>l', default_opts)

-- Resize window
keymap.set('n', '<C-left>', '5<C-w><')
keymap.set('n', '<C-right>', '5<C-w>>')
keymap.set('n', '<C-up>', '5<C-w>+')
keymap.set('n', '<C-down>', '5<C-w>-')

keymap.set('n', '<leader>w', ':w<CR>', default_opts)
keymap.set('n', '<leader>ws', ':wa<CR>:source %<CR>', default_opts)
keymap.set('n', '<leader>d', ':NvimTreeToggle<CR>', default_opts)

-- Terminal
keymap.set('n', '<leader>tv', ':botright vnew <Bar> :terminal<CR>', default_opts)
keymap.set('n', '<leader>th', ':botright new <Bar> :terminal<CR>', default_opts)
keymap.set('t', '<Esc>', '<C-\\><C-n>', default_opts)

-- Telescope
keymap.set('n', '<leader>f', ':Telescope find_files hidden=true <CR>', default_opts)
keymap.set('n', '<leader>s', ':Telescope live_grep<CR>', default_opts)


-- Move lines
keymap.set('n', '<A-j>', ':m .+1<CR>==', default_opts)
keymap.set('n', '<A-k>', ':m .-2<CR>==', default_opts)
keymap.set('i', '<A-j>', '<Esc>:m .+1<CR>==gi', default_opts)
keymap.set('i', '<A-k>', '<Esc>:m .-2<CR>==gi', default_opts)
keymap.set('v', '<A-j>', ":m '>+1<CR>gv=gv", default_opts)
keymap.set('v', '<A-k>', ":m '<-2<CR>gv=gv", default_opts)

-- Buffer Explorer
keymap.set('n', '<F7>', ':BufExplorer<CR>', default_opts)
keymap.set('n', '<F5>', ':bp<CR>', default_opts)
keymap.set('n', '<F6>', ':bn<CR>', default_opts)

-- Double ESC to exit from terminal insert mode to terminal normal mode
keymap.set("t", "<ESC><ESC>", [[<C-\><C-n>]], default_opts)

-- Stay in visual mode after indenting
keymap.set("x", "<", "<gv", default_opts)
keymap.set("x", ">", ">gv", default_opts)

require "user.keymaps.nvim-spectre"

return {
  -- https://github.com/neovim/nvim-lspconfig#suggested-configuration
  on_attach = function(client, bufnr)
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
