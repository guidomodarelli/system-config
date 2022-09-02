local keymap = vim.keymap
local opts = { noremap = true, silent = true }

keymap.set('n', '<C-j>', '<cmd>Lspsaga diagnostic_jump_next<CR>', opts)
keymap.set('n', 'K', '<cmd>Lspsaga hover_doc<CR>', opts)
keymap.set('n', 'gd', '<cmd>Lspsaga lsp_finder<CR>', opts)
keymap.set('i', '<C-k>', '<cmd>Lspsaga signature_help<CR>', opts)
keymap.set('n', 'gp', '<cmd>Lspsaga preview_definition<CR>', opts)
keymap.set('n', '<F2>', '<cmd>Lspsaga rename<CR>', opts)
keymap.set('n', 'gca', '<cmd>Lspsaga code_action<CR>', opts)
keymap.set('n', 'gto', '<cmd>Lspsaga open_floaterm<CR>', opts)
keymap.set('n', '<Esc>', '<cmd>Lspsaga close_floaterm<CR>', opts)
