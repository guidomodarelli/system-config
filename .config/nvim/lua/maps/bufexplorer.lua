local keymap = vim.keymap
local default_opts = { noremap = true, silent = true }

keymap.set('n', '<F7>', ':BufExplorer<CR>', default_opts)
keymap.set('n', '<F5>', ':bp<CR>', default_opts)
keymap.set('n', '<F6>', ':bn<CR>', default_opts)
