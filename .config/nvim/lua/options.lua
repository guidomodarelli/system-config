local options = {
	tabstop        = 2, -- Number of columns to move when pressing <TAB> (see noexpandtab)
	softtabstop    = 2, -- Do not insert spaces when pressing tab (see shiftwidth)
	-- expandtab      = true, -- Do not expand tabs to spaces (see softtabstop)
	-- fileencoding   = 'utf-8',
	-- shiftwidth     = 2, -- Force indent spaces to equal to tabstop (see tabstop)
	autoindent     = true, -- Start new lines correctly indented
	background     = "dark",
	backspace      = 'indent,eol,start',
	backup         = false,
	backupskip     = '/tmp/*',
	breakindent    = true,
	cmdheight      = 1,
	completeopt    = { "menuone", "noselect" }, -- Completion engine options
	cursorline     = true, -- Highlight the line where the cursor is (see cursorlineopt)op
	cursorlineopt  = "number", -- Highlight the cursor line number (see cursorline)
	encoding       = 'utf-8',
	filetype       = 'on',
	fillchars      = vim.opt.fillchars + "diff:╱", -- Interface styling (see listchars)
	fixeol         = true, -- Restore EOL at EOF if missing when writing
	foldmethod     = "marker", -- Only allow foldings with triple brackets
	formatoptions  = 'tcqrn1',
	hidden         = true, -- Hide inactive buffers instead of deleting them
	hlsearch       = true, -- Highlight all search matches
	ignorecase     = true,
	inccommand     = "split", -- Incrementally show effects of commands, opens split
	incsearch      = true, -- Highlight search matches while writing (with hlsearch)
	laststatus     = 2, -- Use a global statusline instead of one per window
	linebreak      = true, -- Respect WORDS when wrap-breaking lines (see wrap)
	modelines      = 0,
	mouse          = "nvi", -- Allow mouse everywhere except in command line mode
	nrformats      = "unsigned", -- Treat all numbers as unsigned with <C-A> and <C-X>
	number         = true, -- Number column to the left (used with relativenumber)
	pumblend       = 5,
	relativenumber = true, -- Show numbers relative to cursor position (see number)
	scrolloff      = 10, -- Leave 5 lines above and below cursor
	shiftround     = false,
	showcmd        = true, -- Show the keys pressed in normal mode until action is run
	showmode       = true,
	showtabline    = 2, -- Show the tabline even when just one tab is open
	signcolumn     = "yes", -- Always show the sign column beside the number (see number)
	smartcase      = true,
	smartindent    = true, -- Ident new lines in a smart way (see autoindent)
	smarttab       = true, -- Treat spaces as tabs in increments of shiftwidth
	splitbelow     = true, -- Open splits below the current window
	splitright     = true, -- Open splits right of the current window
	termguicolors  = true, -- Enable 24-bit RGB color in the TUI
	timeoutlen     = 500, -- Milliseconds to wait before completing a mapped sequence
	ttyfast        = true,
	title          = true,
	updatetime     = 300, -- Milliseconds to wait before writing to swap file
	wildignorecase = true, -- Ignore case in filenames browsed by wildmenu
	wildoptions    = "pum",
	winblend       = 0,
	wrap           = false, -- Do not wrap text that reaches the window's width
}

for k, v in pairs(options) do
	vim.opt[k] = v
end

vim.scriptencoding = 'utf-8'
vim.opt.matchpairs:append '<:>'
vim.opt.path:append { '**' } -- Finding files - Search down into subfolders
vim.opt.wildignore:append { '*/node_modules/*' }
vim.opt.formatoptions:append { 'r' }
vim.opt.clipboard:append { 'unnamedplus' }

vim.cmd [[ let g:python3_host_prog= "/usr/bin/python3" ]]

-- Undercurl
vim.cmd [[let &t_Cs = "\e[4:3m"]]
vim.cmd [[let &t_Ce = "\e[4:0m"]]

vim.api.nvim_create_autocmd("InsertLeave", {
	pattern = "*",
	command = "set nopaste"
})

vim.cmd [[ set statusline=%F%m%r%h%w\ [FORMAT=%{&ff}]\ [TYPE=%Y]\ [POS=%l,%v][%p%%]\ [BUFFER=%n]\ %{strftime('%c')} ]]

vim.g.tex_flavor = "latex" -- Treat all .tex files as LaTeX instead of TeX
vim.opt.shortmess:append("c")

vim.cmd([[
	highlight! link CursorLineNr MatchParen
	highlight! link WinSeparator LineNr
]])
