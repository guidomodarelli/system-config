local keymap = vim.keymap
local default_opts = { noremap = true, silent = true }

keymap.set('n', '<leader>f', ':Telescope find_files hidden=true <CR>', default_opts)
keymap.set('n', '<leader>s', ':Telescope live_grep<CR>', default_opts)

