local opts = { noremap = true, silent = true }
local keymap = vim.keymap

keymap.set('n', 'g<C-j>', '<cmd>Lspsaga diagnostic_jump_next<CR>', opts)
keymap.set('n', 'K', '<cmd>Lspsaga hover_doc<CR>', opts)
keymap.set('n', 'gd', '<cmd>Lspsaga lsp_finder<CR>', opts)
keymap.set('i', 'g<C-k>', '<cmd>Lspsaga signature_help<CR>', opts)
keymap.set('n', 'gp', '<cmd>Lspsaga preview_definition<CR>', opts)
keymap.set('n', '<F2>', '<cmd>Lspsaga rename<CR>', opts)
keymap.set('n', 'gca', '<cmd>Lspsaga code_action<CR>', opts)
