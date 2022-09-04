local status, wk = pcall(require, 'which-key')
if (not status) then return end

vim.g.mapleader = ','

wk.setup {
  triggers = 'auto',
  plugins = {
    spelling = {
      enabled = true,
      suggestions = 20,
    }
  }
}

local diagnostics_active = true

local function toggle_diagnostics()
  diagnostics_active = not diagnostics_active
  if diagnostics_active then
    vim.diagnostic.show()
  else
    vim.diagnostic.hide()
  end
end

local base_key_tree = {
  ['x']     = { '"_x', "Don't yank with x" },
  ['+']     = { "<C-a>", "Increment" },
  ['-']     = { "<C-x>", "Decrement" },
  ['dw']    = { 'vb"_b', "Delete a word backwards" },
  ['<C-a>'] = { 'gg<S-v>G', "Select all" },
  ['<M-w>'] = { '<C-w>w', 'Switch windows' },
  ['<M-q>'] = { ':q<CR>', 'Quit a window' },

  -- Resize window
  ['<C-left>']  = { '5<C-w><', 'Resize window to left' },
  ['<C-right>'] = { '5<C-w>>', 'Resize window to right' },
  ['<C-up>']    = { '5<C-w>+', 'Resize window to up' },
  ['<C-down>']  = { '5<C-w>-', 'Resize window to down' },

  -- Move lines
  ['<A-j>'] = { ':m .+1<CR>==', 'Move lines down' },
  ['<A-k>'] = { ':m .-2<CR>==', 'Move lines up' },
}

wk.register(base_key_tree)

wk.register({
  ['<A-j>'] = { '<Esc>:m .+1<CR>==gi', 'Move lines down' },
  ['<A-k>'] = { '<Esc>:m .-2<CR>==gi', 'Move lines up' },
}, { mode = 'i' })

wk.register({
  ['<A-j>'] = { ":m '>+1<CR>gv=gv", 'Move lines down' },
  ['<A-k>'] = { ":m '<-2<CR>gv=gv", 'Move lines up' },
}, { mode = 'v' })

wk.register({
  ['<Esc>'] = { '<C-Bslash><C-n>', 'ESC to exit from terminal insert mode to terminal normal mode' }
}, { mode = 't', noremap = true })

wk.register({
  -- Stay in visual mode after indenting
  ['<'] = { '<gv', 'Stay in visual mode after indenting to left' },
  ['>'] = { '>gv', 'Stay in visual mode after indenting to right' },
}, { mode = 'x' })

local normal_key_tree = {
  ['<leader>'] = {
    w = {
      name = '+Write...',
      w = { ':w<CR>', 'Write file' },
      a = { ':wa<CR>', 'Write all files' },
      q = { ':wa<CR>:qa<CR>', 'Write all and quit all' },
      ['q!'] = { ':wa<CR> :qa!<CR>', 'Write all and quit all' },
    },

    t = {
      name = '+Terminal...',
      v = { ':botright vnew <Bar> :terminal<CR>', 'Open terminal in vertical split view' },
      h = { ':botright new <Bar> :terminal<CR>', 'Open terminal in horizontal split view' },
      f = { '<cmd>Lspsaga open_floaterm<CR>', 'Open float term' },
      ['<Esc>'] = { '<cmd>Lspsaga close_floaterm<CR>', 'Kill float term' },
    },

    T = {
      name = '+Tab...',
      n = { ':tabedit<CR>', 'New tab' },
    },

    s = {
      name = '+Split...',
      s = { ':split<CR><C-w>w', 'Split horizontal' },
      v = { ':vsplit<CR><C-w>w', 'Split vertical' },
    },

    f = {
      name = '+Find...',
      f    = { '<cmd>lua require("telescope.builtin").find_files()<CR>',
        'Find files' },
      g    = { '<cmd>lua require("telescope.builtin").live_grep()<CR>', 'Live grep text' },
      b    = { '<cmd>lua require("telescope.builtin").buffers()<CR>', 'Buffers' },
      t    = { '<cmd>lua require("telescope.builtin").help_tags()<CR>', 'Help tags' },
      r    = { '<cmd>lua require("telescope.builtin").resume()<CR>', 'Resume' },
      d    = { '<cmd>lua require("telescope.builtin").diagnostics()<CR>', 'Diagnostics' },
      F   = {
        '<cmd>lua require("telescope").extensions.file_browser.file_browser({ path = "%:p:h", cwd = vim.fn.expand("%:p:h"), respect_git_ignore = false, hidden = true, grouped = true, previewer = false, initial_mode = "normal", layout_config = { height = 40 } })<CR>',
        'Find files (extension)'
      },
      c = { '<cmd>lua require("telescope.builtin").commands()<CR>', 'Commands' },
    },

    l = {
      name = '+LSP...',
      f = { '<cmd>Lspsaga lsp_finder<CR>', 'Definition, Implementations and references' },
      p = { '<cmd>Lspsaga preview_definition<CR>', 'Preview definiton' },
      c = { '<cmd>Lspsaga code_action<CR>', 'Code actions' },
    },
  },

  -- LSP
  ['<C-k>'] = { '<cmd>Lspsaga signature_help<CR>', 'Signature help', mode = 'i' },
  ['<C-j>'] = { '<cmd>Lspsaga diagnostic_jump_next<CR>', 'Diagnostic jump next' },
  K         = { '<cmd>Lspsaga hover_doc<CR>', 'Hover documentation' },
  ['<M-r>'] = { '<cmd>Lspsaga rename<CR>', 'Rename' },

  -- Tree
  ['<M-d>'] = { ':NvimTreeToggle<CR>', 'NvimTreeToggle' },
  ['<M-f>'] = { ':NvimTreeFindFile<CR>', 'NvimTreeFindFile', noremap = true, silent = true },

  g = {
    name = '+Global...',
    a = { '<Plug>(EasyAlign)', 'Start interactive EasyAlign for a motion/text object (e.g. gaip)' },
  },

  ['<Tab>'] = { '<cmd>BufferLineCycleNext<CR>', 'Buffer line cycle next' },
  ['<S-Tab>'] = { '<cmd>BufferLineCyclePrev<CR>', 'Buffer line cycle previuos' },
}

local visual_key_tree = {
  s = {
    name = '+Sort...',
    s = { ":'<,'>sort\n", "Sort" },
    u = { ":'<,'>sort u\n", "Sort uniq" },
  }
}

local select_key_tree = {
  g = {
    a = { '<Plug>(EasyAlign)', 'Start interactive EasyAlign in visual mode (e.g. vipga)' }
  }
}

wk.register(normal_key_tree)
wk.register(select_key_tree, { mode = 'x' })
wk.register(visual_key_tree, { prefix = "<leader>", mode = "v" })
