local status_ok, packer = pcall(require, "packer")
if not status_ok then
  print('Packer is not installed')
  return
end

vim.cmd [[packadd packer.nvim]]

packer.startup(function(use)
  use "wbthomason/packer.nvim"

  use {
    "neovim/nvim-lspconfig", -- LSP
    "williamboman/nvim-lsp-installer",
  }

  -- Formatter
  use "MunifTanjim/prettier.nvim" -- Prettier plugin for Neovim's built-in LSP client
  use "jose-elias-alvarez/null-ls.nvim" -- Use a Neovim as a language server to inject LSP diagnostics, code actions and more via Lua

  -- Statusline
  use {
    "nvim-lualine/lualine.nvim",
    requires = { "kyazdani42/nvim-web-devicons", opt = true }
  }

  -- Find files and text
  -- use "folke/trouble.nvim"
  use {
    "nvim-telescope/telescope.nvim",
    requires = {
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope-file-browser.nvim"
    }
  }

  -- Completion
  use {
    "hrsh7th/nvim-cmp",
    requires = {
      "hrsh7th/cmp-buffer", -- nvim-cmp source for buffer words
      "hrsh7th/cmp-nvim-lsp", -- nvim-cmp source for neovim's built-in LSP
      "hrsh7th/cmp-nvim-lua",
      "octaltree/cmp-look",
      "hrsh7th/cmp-path",
      "hrsh7th/cmp-calc",
      "f3fora/cmp-spell",
      "hrsh7th/cmp-emoji",
      "saadparwaiz1/cmp_luasnip",
      "onsails/lspkind.nvim", -- vscode-like pictograms
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
  use "windwp/nvim-autopairs"
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
  use "glepnir/lspsaga.nvim" -- LSP UIs
  use "folke/which-key.nvim"
end)
