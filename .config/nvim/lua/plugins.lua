local status_ok, packer = pcall(require, "packer")
if not status_ok then
  print('Packer is not installed')
  print('Installing packer...')
  local install_path = vim.fn.stdpath 'data' .. '/site/pack/packer/start/packer.nvim'
  vim.fn.execute('!git clone https://github.com/wbthomason/packer.nvim ' .. install_path)
end

vim.cmd [[packadd packer.nvim]]

packer.startup(function(use)
  use "wbthomason/packer.nvim"

  use {
    "neovim/nvim-lspconfig", -- LSP
    "williamboman/nvim-lsp-installer",
  }

  use {
    "williamboman/mason.nvim",
    "williamboman/mason-lspconfig.nvim"
  }

  -- Formatter
  use "MunifTanjim/prettier.nvim" -- Prettier plugin for Neovim's built-in LSP client
  use "jose-elias-alvarez/null-ls.nvim" -- Use a Neovim as a language server to inject LSP diagnostics, code actions and more via Lua

  -- Icons
  use "kyazdani42/nvim-web-devicons"

  -- Statusline
  use {
    "nvim-lualine/lualine.nvim",
  }

  -- Find files and text
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
    -- run = function() require("nvim-treesitter.install").update({ with_sync = true }) end,
    run = ":TSUpdate"
  }

  -- Snippets
  use "L3MON4D3/LuaSnip"

  -- Sidebar tree
  use {
    "kyazdani42/nvim-tree.lua",
    tag = "nightly" -- optional, updated every week. (see issue #1193)
  }

  -- Git
  use {
    'lewis6991/gitsigns.nvim',
    -- tag = 'release' -- To use the latest release (do not use this if you run Neovim nightly or dev builds!)
  }
  use 'dinhhuy258/git.nvim'
  use { 'TimUntersberger/neogit', requires = 'nvim-lua/plenary.nvim' }

  -- Debugging
  use { "rcarriga/nvim-dap-ui", requires = { "mfussenegger/nvim-dap" } }

  -- typing
  use "windwp/nvim-autopairs"
  use "tpope/vim-surround"
  use "numToStr/Comment.nvim"
  use "windwp/nvim-ts-autotag"

  -- IDE
  use "Yggdroot/indentLine"
  use { 'akinsho/bufferline.nvim', tag = "v2.*" }
  use "editorconfig/editorconfig-vim"
  use "norcalli/nvim-colorizer.lua"
  use "glepnir/lspsaga.nvim" -- LSP UIs
  use "folke/which-key.nvim"
  use "tpope/vim-sleuth"
  use "navarasu/onedark.nvim"
  use "junegunn/vim-easy-align"
  use "camspiers/lens.vim"
  use "junegunn/goyo.vim"

  packer.sync()
end)

-- Automatically source and re-compile packer whenever you save this file
local packer_group = vim.api.nvim_create_augroup('Packer', { clear = true })
vim.api.nvim_create_autocmd('BufWritePost', {
  command = 'source <afile> | PackerCompile',
  group = packer_group,
  pattern = vim.fn.expand '$MYVIMRC',
})
