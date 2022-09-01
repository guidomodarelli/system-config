local telescope = require("telescope")

telescope.setup({
  defaults = {},
  pickers = {
    find_files = {
      find_command = { "fd", "--type", "f", "--strip-cwd-prefix", "--ignore-file", ".gitignore", "--exclude", ".git" }
    }
  }
})
