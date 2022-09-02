local nvim_tree = require("nvim-tree")
local nvim_tree_config = require("nvim-tree.config")
local icons = require("icons")

local tree_cb = nvim_tree_config.nvim_tree_callback

nvim_tree.setup {
  hijack_directories = {
    enable = false,
  },
  -- open_on_setup = true,
  -- open_on_setup_file = true,
  ignore_ft_on_setup = {
    "startify",
    "dashboard",
    "alpha",
  },
  filters = {
    custom = { "^\\.git" },
    exclude = { "^\\.gitignore" },
  },
  update_cwd = true,
  renderer = {
    add_trailing = false,
    group_empty = false,
    highlight_git = false,
    highlight_opened_files = "none",
    root_folder_modifier = ":t",
    indent_markers = {
      enable = false,
      icons = {
        corner = icons.IndentMarkers.Corner .. " ",
        edge = icons.IndentMarkers.Edge .. " ",
        none = "  ",
      },
    },
    icons = {
      webdev_colors = true,
      git_placement = "before",
      padding = " ",
      symlink_arrow = " " .. icons.symlink.Arrow .. " ",
      show = {
        file = true,
        folder = true,
        folder_arrow = true,
        git = true,
      },
      glyphs = {
        default = icons.documents.File.Default,
        symlink = icons.symlink.File,
        folder = {
          arrow_open = icons.ui.ArrowOpen,
          arrow_closed = icons.ui.ArrowClosed,
          default = icons.documents.Folder.Default,
          open = icons.documents.Folder.Open,
          empty = icons.documents.Folder.Empty,
          empty_open = icons.documents.Folder.EmptyOpen,
          symlink = icons.documents.Folder.Symlink,
          symlink_open = icons.documents.Folder.SymlinkOpen,
        },
        git = {
          unstaged = icons.git.Unstaged,
          staged = icons.git.Staged,
          unmerged = icons.git.Unmerged,
          renamed = icons.git.Renamed,
          untracked = icons.git.Untracked,
          deleted = icons.git.Deleted,
          ignored = icons.git.Ignored,
        },
      },
    },
  },
  diagnostics = {
    enable = true,
    icons = {
      hint = icons.diagnostics.Hint,
      info = icons.diagnostics.Information,
      warning = icons.diagnostics.Warning,
      error = icons.diagnostics.Error,
    },
  },
  update_focused_file = {
    enable = true,
    update_cwd = true,
    ignore_list = {},
  },
  git = {
    enable = true,
    ignore = false,
    timeout = 500,
  },
  view = {
    width = 30,
    height = 30,
    hide_root_folder = false,
    side = "left",
    mappings = {
      custom_only = false,
      list = {
        { key = { "l", "<CR>", "o" }, cb = tree_cb "edit" },
        { key = "h", cb = tree_cb "close_node" },
        { key = "v", cb = tree_cb "vsplit" },
      },
    },
  },
}
