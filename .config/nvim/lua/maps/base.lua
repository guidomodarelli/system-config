local keymap = vim.keymap
local default_opts = { noremap = true, silent = true }

keymap.set('n', '<leader>w', ':w<CR>', default_opts)
keymap.set('n', '<leader>q', ':q<CR>', default_opts)
keymap.set('n', '<leader>ws', ':wa<CR>:source %<CR>', default_opts)

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

-- Resize window
keymap.set('n', '<C-left>', '5<C-w><')
keymap.set('n', '<C-right>', '5<C-w>>')
keymap.set('n', '<C-up>', '5<C-w>+')
keymap.set('n', '<C-down>', '5<C-w>-')

-- Terminal
keymap.set('n', '<leader>tv', ':botright vnew <Bar> :terminal<CR>', default_opts)
keymap.set('n', '<leader>th', ':botright new <Bar> :terminal<CR>', default_opts)
keymap.set('t', '<Esc>', '<C-\\><C-n>', default_opts)

-- Move lines
keymap.set('n', '<A-j>', ':m .+1<CR>==', default_opts)
keymap.set('n', '<A-k>', ':m .-2<CR>==', default_opts)
keymap.set('i', '<A-j>', '<Esc>:m .+1<CR>==gi', default_opts)
keymap.set('i', '<A-k>', '<Esc>:m .-2<CR>==gi', default_opts)
keymap.set('v', '<A-j>', ":m '>+1<CR>gv=gv", default_opts)
keymap.set('v', '<A-k>', ":m '<-2<CR>gv=gv", default_opts)

-- Double ESC to exit from terminal insert mode to terminal normal mode
keymap.set("t", "<ESC><ESC>", [[<C-\><C-n>]], default_opts)

-- Stay in visual mode after indenting
keymap.set("x", "<", "<gv", default_opts)
keymap.set("x", ">", ">gv", default_opts)
