require 'user.options'
require 'user.keymaps'

require 'user.nvim-tree'
require 'user.treesitter'
require 'user.telescope'
require 'user.lualine'
require 'user.neosolarized'

require 'user.cmp'
require 'user.settings'

vim.cmd [[packadd packer.nvim]]

local status_ok, packer = pcall(require, "packer")

if not status_ok then
	return
end

packer.startup(function(use)
	use "wbthomason/packer.nvim"

	-- Mason & LSP
	use {
		"williamboman/mason.nvim",
		"williamboman/mason-lspconfig.nvim",
		"neovim/nvim-lspconfig",
		"williamboman/nvim-lsp-installer"
	}

	-- Statusline
	use {
		"nvim-lualine/lualine.nvim",
		requires = { "kyazdani42/nvim-web-devicons", opt = true }
	}

	-- Find files and text
	use {
		"nvim-telescope/telescope.nvim", tag = "0.1.x",
		requires = { "nvim-lua/plenary.nvim" }
	}

	-- Completion
	use {
		"hrsh7th/nvim-cmp",
		requires = {
			"hrsh7th/cmp-buffer", "hrsh7th/cmp-nvim-lsp",
			"hrsh7th/cmp-nvim-lua",
			"octaltree/cmp-look", "hrsh7th/cmp-path", "hrsh7th/cmp-calc",
			"f3fora/cmp-spell", "hrsh7th/cmp-emoji", "saadparwaiz1/cmp_luasnip"
		}
	}

	-- Parser
	use {
		"nvim-treesitter/nvim-treesitter",
		run = function() require("nvim-treesitter.install").update({ with_sync = true }) end,
	}

	-- Snippets
	use "L3MON4D3/LuaSnip"

	-- Sidebar tree
	use {
		"kyazdani42/nvim-tree.lua",
		requires = {
			"kyazdani42/nvim-web-devicons", -- optional, for file icons
		},
		tag = "nightly" -- optional, updated every week. (see issue #1193)
	}

	-- Git
	use "airblade/vim-gitgutter"

	-- Debugging
	use { "rcarriga/nvim-dap-ui", requires = { "mfussenegger/nvim-dap" } }

	-- typing
	use "jiangmiao/auto-pairs"
	use "tpope/vim-commentary"
	use({
		"kylechui/nvim-surround",
		tag = "*", -- Use for stability; omit to use `main` branch for the latest features
		config = function()
			require("nvim-surround").setup({
				-- Configuration here, or leave empty to use defaults
			})
		end
	})

	-- IDE
	-- use "dense-analysis/ale"
	use "Yggdroot/indentLine"
	use "jlanzarotta/bufexplorer"
	use "ap/vim-buftabline"
	use "editorconfig/editorconfig-vim"
	use {
		"nvim-pack/nvim-spectre",
		"nvim-lua/plenary.nvim"
	}
	use {
		"svrana/neosolarized.nvim",
		requires = {
			"tjdevries/colorbuddy.nvim"
		}
	}
end)
