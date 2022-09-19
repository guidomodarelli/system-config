local augroups = {}

augroups.buf_write_pre = {
	trim_extra_spaces_and_newlines = {
		event = 'BufWritePre',
		command = [[
			let current_pos = getpos('.')
			silent! %s/\v\s+$|\n+%$//e
			silent! call setpos('.', current_pos)
		]],
	},
}

augroups.misc = {
	highlight_yank = {
		event = 'TextYankPost',
		callback = function()
			vim.highlight.on_yank({
				higroup = 'IncSearch',
				timeout = 400,
				on_visual = true
			})
		end,
	},
}

for group, commands in pairs(augroups) do
	local augroup = vim.api.nvim_create_augroup('AU_' .. group, { clear = true })

	for _, opts in pairs(commands) do
		local event = opts.event
		opts.event = nil
		opts.group = augroup
		vim.api.nvim_create_autocmd(event, opts)
	end
end
