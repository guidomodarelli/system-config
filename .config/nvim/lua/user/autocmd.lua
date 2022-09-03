local augroups = {}

augroups.misc = {
	highlight_yank = {
		event = "TextYankPost",
		pattern = "*",
		callback = function()
			vim.highlight.on_yank({
				higroup = "IncSearch",
				timeout = 400,
				on_visual = true
			})
		end,
	},
}

augroups.prose = {
	wrap = {
		event = "FileType",
		pattern = { "markdown", "tex" },
		callback = function()
			vim.opt_local.wrap = true
		end,
	},
}

augroups.quit = {
	quit_with_q = {
		event = "FileType",
		pattern = { "checkhealth", "fugitive", "git*", "help", "lspinfo" },
		callback = function()
			-- vim.api.nvim_win_close(0, true) -- TODO: Replace vim command with this
			vim.api.nvim_buf_set_keymap(0, "n", "q",
				"<cmd>close!<cr>",
				{ noremap = true, silent = true })
		end
	}
}

for group, commands in pairs(augroups) do
	local augroup = vim.api.nvim_create_augroup("AU_" .. group, { clear = true })

	for _, opts in pairs(commands) do
		local event = opts.event
		opts.event = nil
		opts.group = augroup
		vim.api.nvim_create_autocmd(event, opts)
	end
end
