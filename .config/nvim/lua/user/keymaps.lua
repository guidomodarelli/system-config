local keymap = function(mode, shortcut, command, opts)
	opts = opts or { noremap = true, silent = true }
	vim.api.nvim_set_keymap(mode, shortcut, command, opts)
end

vim.g.mapleader = ','

keymap('n', '<leader>w', ':w<CR>')
keymap('n', '<leader>ws', ':w<CR> :source %<CR>')
keymap('n', '<leader>d', ':NvimTreeToggle<CR>')

-- Terminal
keymap('n', '<leader>tv', ':botright vnew <Bar> :terminal<CR>')
keymap('n', '<leader>th', ':botright new <Bar> :terminal<CR>')
keymap('t', '<Esc>', '<C-\\><C-n>')

-- Telescope
keymap('n', '<leader>f', ':Telescope find_files hidden=true <CR>')
keymap('n', '<leader>s', ':Telescope live_grep<CR>')

-- Switched of panels
keymap('n', '<C-j>', '<C-W>j')
keymap('n', '<C-k>', '<C-W>k')
keymap('n', '<C-h>', '<C-W>h')
keymap('n', '<C-l>', '<C-W>l')

-- Move lines
keymap('n', '<A-j>', ':m .+1<CR>==')
keymap('n', '<A-k>', ':m .-2<CR>==')
keymap('i', '<A-j>', '<Esc>:m .+1<CR>==gi')
keymap('i', '<A-k>', '<Esc>:m .-2<CR>==gi')
keymap('v', '<A-j>', ":m '>+1<CR>gv=gv")
keymap('v', '<A-k>', ":m '<-2<CR>gv=gv")

-- Buffer Explorer
keymap('n', '<F7>', ':BufExplorer<CR>')
keymap('n', '<F5>', ':bp<CR>')
keymap('n', '<F6>', ':bn<CR>')

-- Double ESC to exit from terminal insert mode to terminal normal mode
keymap("t", "<ESC><ESC>", [[<C-\><C-n>]])

-- Stay in visual mode after indenting
keymap("x", "<", "<gv")
keymap("x", ">", ">gv")

-- nvim-spectre
local nvim_spectre_opts = { noremap = true }
keymap('n', '<leader>S', '<cmd>lua require("spectre").open()<CR>', nvim_spectre_opts)

-- search current word
keymap('n', '<leader>sw', '<cmd>lua require("spectre").open_visual({select_word=true})<CR>', nvim_spectre_opts)
-- keymap('v', '<leader>s', '<esc>:lua require("spectre").open_visual()<CR>', nvim_spectre_opts)
--  search in current file
keymap('n', '<leader>sp', 'viw:lua require("spectre").open_file_search()<CR>', nvim_spectre_opts)
-- run command :Spectre

return {
	-- https://github.com/neovim/nvim-lspconfig#suggested-configuration
	on_attach = function(client, bufnr)
		-- Enable completion triggered by <c-x><c-o>
		vim.api.nvim_buf_set_option(bufnr, 'omnifunc', 'v:lua.vim.lsp.omnifunc')

		-- Mappings.
		-- See `:help vim.lsp.*` for documentation on any of the below functions
		local bufopts = { noremap = true, silent = true, buffer = bufnr }
		vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, bufopts)
		vim.keymap.set('n', 'gd', vim.lsp.buf.definition, bufopts)
		vim.keymap.set('n', 'K', vim.lsp.buf.hover, bufopts)
		vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, bufopts)
		vim.keymap.set('n', '<C-s>', vim.lsp.buf.signature_help, bufopts)
		vim.keymap.set('n', '<space>wa', vim.lsp.buf.add_workspace_folder, bufopts)
		vim.keymap.set('n', '<space>wr', vim.lsp.buf.remove_workspace_folder, bufopts)
		vim.keymap.set('n', '<space>wl', function()
			print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
		end, bufopts)
		vim.keymap.set('n', '<space>D', vim.lsp.buf.type_definition, bufopts)
		vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, bufopts)
		vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, bufopts)
		vim.keymap.set('n', 'gr', vim.lsp.buf.references, bufopts)
		vim.keymap.set('n', '<space>f', vim.lsp.buf.formatting, bufopts)
	end
}
