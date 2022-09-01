local mason = require("mason")
local lspconfig = require("lspconfig")

require("nvim-lsp-installer").setup {}

local keymaps = require("user.keymaps")

mason.setup()

lspconfig.volar.setup {
  on_attach = keymaps.on_attach,
}

lspconfig.tsserver.setup {
  on_attach = keymaps.on_attach,
}

lspconfig.sumneko_lua.setup {
  on_attach = keymaps.on_attach,
  settings = {
    Lua = {
      diagnostics = {
        globals = {
          "vim"
        }
      },
      workspace = {
        library = vim.api.nvim_get_runtime_file("", true),
        checkThirdParty = false
      }
    }
  }
}
