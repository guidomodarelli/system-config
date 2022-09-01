require 'user.options'
require 'user.keymaps'

require 'user.nvim-tree'
require 'user.treesitter'
require 'user.telescope'
require 'user.lualine'
require 'user.neosolarized'
require 'user.bufferline'
require 'user.colorizer'
require 'user.gitsigns'
require 'user.ts-autotag'
require 'user.which-key'

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
    "williamboman/nvim-lsp-installer",
    "MunifTanjim/prettier.nvim"
  }

  -- Statusline
  use {
    "nvim-lualine/lualine.nvim",
    requires = { "kyazdani42/nvim-web-devicons", opt = true }
  }

  -- Find files and text
  -- use "folke/trouble.nvim"
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
      "f3fora/cmp-spell", "hrsh7th/cmp-emoji", "saadparwaiz1/cmp_luasnip",
      "onsails/lspkind.nvim"
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
  use {
    'lewis6991/gitsigns.nvim',
    -- tag = 'release' -- To use the latest release (do not use this if you run Neovim nightly or dev builds!)
  }

  -- Debugging
  use { "rcarriga/nvim-dap-ui", requires = { "mfussenegger/nvim-dap" } }

  -- typing
  use "jiangmiao/auto-pairs"
  use "tpope/vim-surround"
  use "tpope/vim-commentary"
  use "windwp/nvim-ts-autotag"

  -- IDE
  -- use "dense-analysis/ale"
  use "Yggdroot/indentLine"
  use "jlanzarotta/bufexplorer"
  use { 'akinsho/bufferline.nvim', tag = "v2.*", requires = 'kyazdani42/nvim-web-devicons' }
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
  use "norcalli/nvim-colorizer.lua"
  use({
    "glepnir/lspsaga.nvim",
    branch = "main",
    config = function()
      local saga = require("lspsaga")

      saga.init_lsp_saga({
        -- your configuration
      })
    end,
  })
  use "folke/which-key.nvim"
end)
