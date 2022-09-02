local icons = require("icons")

require('lualine').setup {
  options = {
    icons_enabled = true,
    theme = 'solarized_dark',
    component_separators = {
      left = icons.separator.ThinRightSeparator,
      right = icons.separator.ThinLeftSeparator,
    },
    section_separators = {
      left = icons.blocks.Diagonal.LowerLeft,
      right = icons.blocks.Diagonal.UpperRight,
    },
    disabled_filetypes = {},
  },
  sections = {
    lualine_a = { 'mode' },
    lualine_b = { 'branch' },
    lualine_c = {
      {
        'filename',
        file_status = true,
        path = 0, -- 0 = just filename
      },
    },
    lualine_x = {
      {
        'diagnostics',
        sources = {
          'nvim_diagnostic'
        },
        symbols = {
          error = icons.diagnostics.Error .. " ",
          warn = icons.diagnostics.Warning .. " ",
          info = icons.diagnostics.Information .. " ",
          hint = icons.diagnostics.Hint .. " ",
        },
      },
      'encoding',
      'filetype',
    },
    lualine_y = { 'progress' },
    lualine_z = { 'location' },
  },
  inactive_sections = {
    lualine_a = {},
    lualine_b = {},
    lualine_c = {
      {
        'filename',
        file_status = true,
        path = 1, -- 1 = relative path
      }
    },
    lualine_x = { 'location' },
    lualine_y = {},
    lualine_z = {},
  },
  tabline = {},
  extensions = { 'fugitive' },
}
