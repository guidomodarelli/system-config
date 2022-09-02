local status, null_ls = pcall(require, 'null-ls')
if (not status) then return end

---@diagnostic disable-next-line: redundant-parameter
null_ls.setup {
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
    null_ls.builtins.diagnostics.eslint_d.with({
      diagnostics_format = '[eslint] #{m}\n(#{c})'
    }),
    null_ls.builtins.diagnostics.zsh
  }
}
