local keymap = vim.keymap
local opts = { noremap = true }

keymap.set('n', '<leader>S', '<cmd>lua require("spectre").open()<CR>', opts)

-- search current word
keymap.set('n', '<leader>sw', '<cmd>lua require("spectre").open_visual({select_word=true})<CR>', opts)
-- keymap.set('v', '<leader>s', '<esc>:lua require("spectre").open_visual()<CR>', nvim_spectre_opts)
--  search in current file
keymap.set('n', '<leader>sp', 'viw:lua require("spectre").open_file_search()<CR>', opts)
-- run command :Spectre
