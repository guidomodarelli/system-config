vim.keymap.set("n", "<leader>ps", function()
  require("telescope.builtin").grep_string({
    search = vim.fn.input("Grep String > "),
    additional_args = { "--hidden" },
    file_ignore_patterns = {
      "node_modules/.*",
      ".git/.*",
      ".npm/.*",
      ".bun/.*",
      ".vscode/.*",
      ".*.excalidraw",
      "package-lock.json",
      "yarn.lock",
    },
  })
end)

vim.keymap.set("n", "<leader>sg", function()
  require("telescope.builtin").live_grep({ additional_args = { "--hidden" } })
end)

return {
  "nvim-telescope/telescope.nvim",
  defaults = {
    vimgrep_arguments = {
      "rg",
      "--color=never",
      "--no-heading",
      "--with-filename",
      "--line-number",
      "--column",
      "--smart-case",
      "--hidden",
    },
    file_ignore_patterns = {
      "^.git/",
      "^node_modules/",
      "^vendor/",
    },
  },
  pickers = {
    find_files = {
      hidden = true,
    },
  },
}
