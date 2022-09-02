local keymap = vim.keymap
local default_opts = { noremap = true, silent = true }

keymap.set('n', '<leader>d', ':NvimTreeToggle<CR>', default_opts)
