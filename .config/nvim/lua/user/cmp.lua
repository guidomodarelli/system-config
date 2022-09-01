require("luasnip")
require("luasnip.loaders.from_vscode").lazy_load()
local lspkind = require('lspkind')

local cmp = require("cmp")

if cmp == nil then
	return
end

cmp.setup {
	formatting = {
		format = lspkind.cmp_format({
			mode = 'symbol',
			maxwidth = 50
		})
	},
	snippet = {
		-- REQUIRED - you must specify a snippet engine
		expand = function(args)
			require("luasnip").lsp_expand(args.body) -- For `luasnip` users.
		end,
	},
	window = {
		-- completion = cmp.config.window.bordered(),
		-- documentation = cmp.config.window.bordered(),
	},
	mapping = cmp.mapping.preset.insert({
		["<C-u>"] = cmp.mapping.scroll_docs(4),
		["<C-d>"] = cmp.mapping.scroll_docs(-4),
		["<C-Space>"] = cmp.mapping.complete(),
		["<C-e>"] = cmp.mapping.abort(),
		["<CR>"] = cmp.mapping.confirm({ select = true }), -- Accept currently 
		-- selected item. Set `select` to `false` to only confirm explicitly 
		-- selected items.
	}),
	sources = cmp.config.sources({
		{ name = "nvim_lsp" },
		{ name = "luasnip" }, -- For luasnip users.
	}, {
		{ name = "buffer" },
	})
}
