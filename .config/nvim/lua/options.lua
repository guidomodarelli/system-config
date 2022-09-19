local options = {
	completeopt    = { 'menuone', 'noselect' },    -- Completion engine options
	cursorlineopt  = 'number',                     -- Highlight the cursor line number (see cursorline)
	filetype       = 'on',
	fillchars      = vim.opt.fillchars + 'diff:╱', -- Interface styling (see listchars)
	fixeol         = true,                         -- Restore EOL at EOF if missing when writing
	foldmethod     = 'marker',                     -- Only allow foldings with triple brackets
	formatoptions  = 'tcqrn1',
	hidden         = true,                         -- Hide inactive buffers instead of deleting them
	incsearch      = true,                         -- Highlight search matches while writing (with hlsearch)
	linebreak      = true,                         -- Respect WORDS when wrap-breaking lines (see wrap)
	modelines      = 0,
	mouse          = 'nvi',                        -- Allow mouse everywhere except in command line mode
	nrformats      = 'unsigned',                   -- Treat all numbers as unsigned with <C-A> and <C-X>
	number         = true,                         -- Number column to the left (used with relativenumber)
	relativenumber = true,                         -- Show numbers relative to cursor position (see number)
	shiftround     = false,
	showmode       = true,
	showtabline    = 2,                            -- Show the tabline even when just one tab is open
	signcolumn     = 'yes',                        -- Always show the sign column beside the number (see number)
	smartcase      = true,
	softtabstop    = 2,                            -- Do not insert spaces when pressing tab (see shiftwidth)
	splitbelow     = true,                         -- Open splits below the current window
	splitright     = true,                         -- Open splits right of the current window
	textwidth      = 79,
	timeoutlen     = 500,                          -- Milliseconds to wait before completing a mapped sequence
	ttyfast        = true,
	updatetime     = 300,                          -- Milliseconds to wait before writing to swap file
	wildignorecase = true,                         -- Ignore case in filenames browsed by wildmenu
}

for k, v in pairs(options) do
	vim.opt[k] = v
end

vim.opt.clipboard:append { 'unnamedplus' }
vim.opt.matchpairs:append '<:>'
vim.opt.shortmess:append('a')

vim.g.tex_flavor = 'latex' -- Treat all .tex files as LaTeX instead of TeX

vim.cmd([[ let g:python3_host_prog= '/usr/bin/python3' ]])

vim.cmd([[ set statusline=%F%m%r%h%w\ [FORMAT=%{&ff}]\ [TYPE=%Y]\ [POS=%l,%v][%p%%]\ [BUFFER=%n]\ %{strftime('%c')} ]])

vim.cmd([[
	highlight! link CursorLineNr MatchParen
	highlight! link WinSeparator LineNr
]])
