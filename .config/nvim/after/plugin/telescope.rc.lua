local status, telescope = pcall(require, 'telescope')
if (not status) then return end
local actions = require('telescope.actions')
local fb_actions = require 'telescope'.extensions.file_browser.actions

telescope.setup {
  pickers = {
    find_files = {
      find_command = { "rg", "--files", "--hidden", "--glob", "!.git/*" },
    },
  },
  defaults = {
    mappings = {
      n = {
        ['q'] = actions.close
      }
    },
  },
  extensions = {
    file_browser = {
      theme = 'dropdown',
      -- disables netrw add use telescope-file-browser in its place
      hijack_netrw = true,
      mappings = {
        -- your custom insert mode mappings
        ['i'] = {
          ['<C-w>'] = function()
            vim.cmd('normal vbd')
          end
        },
        ['n'] = {
          ['N'] = fb_actions.create,
          ['h'] = fb_actions.goto_parent_dir,
          ['c'] = fb_actions.change_cwd,
          ['g'] = fb_actions.goto_cwd,
        }
      }
    }
  }
}

telescope.load_extension('file_browser')
