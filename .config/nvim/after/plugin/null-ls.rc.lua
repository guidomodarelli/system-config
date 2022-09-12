local status, null_ls = pcall(require, 'null-ls')
if (not status) then return end

local formatting = null_ls.builtins.formatting
local diagnostics = null_ls.builtins.diagnostics

local diagnostics_format = '[#{s}] #{m}'

local formatting_eslint_d_condition = function(utils)
  return utils.root_has_file({
    ".eslintrc.js",
    ".eslintrc.cjs",
    ".eslintrc.yaml",
    ".eslintrc.yml",
    ".eslintrc.json",
    "package.json"
  })
end

---@diagnostic disable-next-line: redundant-parameter
null_ls.setup {
  ---@diagnostic disable-next-line: unused-local
  on_attach = function(client, bufnr)
    if client.server_capabilities.documentFormattingProvider then
      local command = vim.api.nvim_command
      command [[augroup Format]]
      command [[autocmd! * <buffer>]]
      command [[autocmd BufWritePre <buffer> lua vim.lsp.buf.formatting_seq_sync()]]
      command [[augroup END]]
    end
  end,
  sources = {
    formatting.eslint_d.with({
      condition = formatting_eslint_d_condition,
    }),
    diagnostics.eslint_d.with({
      diagnostics_format = diagnostics_format,
      condition = formatting_eslint_d_condition,
    }),
    diagnostics.zsh.with({
      diagnostics_format = diagnostics_format,
    }),
    formatting.shfmt.with({
      filetypes = { "sh", "zsh" }
    })
  }
}
