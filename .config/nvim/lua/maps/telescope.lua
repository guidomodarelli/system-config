local keymap = vim.keymap
local opts = { noremap = true, silent = true }

keymap.set('n', ';f', '<cmd>lua require("telescope.builtin").find_files({ no_ignore = false, hidden = true })<CR>', opts)
keymap.set('n', ';r', '<cmd>lua require("telescope.builtin").live_grep()<CR>', opts)
keymap.set('n', ';b', '<cmd>lua require("telescope.builtin").buffers()<CR>', opts)
keymap.set('n', ';t', '<cmd>lua require("telescope.builtin").help_tags()<CR>', opts)
keymap.set('n', ';;', '<cmd>lua require("telescope.builtin").resume()<CR>', opts)
keymap.set('n', ';d', '<cmd>lua require("telescope.builtin").diagnostics()<CR>', opts)
keymap.set('n', 'sf',
  '<cmd>lua require("telescope").extensions.file_browser.file_browser({ path = "%:p:h", cwd = telescope_buffer_dir(), respect_git_ignore = false, hidden = true, grouped = true, previewer = false, initial_mode = "normal", layout_config = { height = 40 } })<CR>'
  , opts)
