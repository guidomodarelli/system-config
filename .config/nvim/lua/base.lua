vim.cmd('autocmd!')

local encoding = 'utf-8'

vim.opt.encoding     = encoding
vim.opt.fileencoding = encoding
vim.scriptencoding   = encoding

vim.wo.number = true

vim.opt.autoindent  = true    -- Start new lines correctly indented
vim.opt.backspace   = 'start,eol,indent'
vim.opt.backup      = false
vim.opt.backupskip  = '/tmp/*,/private/tmp/*'
vim.opt.breakindent = true
vim.opt.cmdheight   = 2
vim.opt.expandtab   = true    -- Do not expand tabs to spaces (see softtabstop)
vim.opt.hlsearch    = true    -- Highlight all search matches
vim.opt.ignorecase  = true
vim.opt.inccommand  = 'split' -- Incrementally show effects of commands, opens split
vim.opt.laststatus  = 3       -- Use a global statusline instead of one per window
vim.opt.scrolloff   = 10      -- Leave 5 lines above and below cursor
vim.opt.shiftwidth  = 2       -- Force indent spaces to equal to tabstop (see tabstop)
vim.opt.showcmd     = true    -- Show the keys pressed in normal mode until action is run
vim.opt.smartindent = true    -- Ident new lines in a smart way (see autoindent)
vim.opt.smarttab    = true    -- Treat spaces as tabs in increments of shiftwidth
vim.opt.tabstop     = 2       -- Number of columns to move when pressing <TAB> (see noexpandtab)
vim.opt.title       = true
vim.opt.wrap        = false   -- Do not wrap text that reaches the window's width

vim.opt.path:append { '**' }  -- Finding files - Search down into subfolders
vim.opt.wildignore:append { '*/node_modules/*' }

-- Undercurl
vim.cmd([[ let &t_Cs = '\e[4:3m' ]])
vim.cmd([[ let &t_Ce = '\e[4:0m' ]])

-- Turn off paste mode when leaving insert
vim.api.nvim_create_autocmd('InsertLeave', {
	pattern = '*',
	command = 'set nopaste'
})

-- Add asterisks in block comments
vim.opt.formatoptions:append { 'r' }
