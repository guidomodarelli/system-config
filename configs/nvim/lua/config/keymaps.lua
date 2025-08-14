-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local map = vim.keymap.set

map({ "n" }, "<A-d>", [["yyy"yp]], { desc = "Duplicate line/s" })
map({ "x" }, "<A-d>", [[mz"yy`z"yp`zj]], { desc = "Duplicate line/s" })
map({ "n", "x" }, "d", [["_d]], { desc = "Delete won't yank content" })
map({ "n", "x" }, "<S-d>", [["_<S-d>]], { desc = "Delete the rest of the line won't yank content" })
map({ "n", "x" }, "c", [["_c]], { desc = "Change won't yank content" })
map({ "n", "x" }, "<S-c>", [["_<S-c>]], { desc = "Change the rest of the line won't yank content" })
map({ "n" }, "<C-x>", [[<S-v>x]], { desc = "Cut current line" })
map({ "x" }, "<C-x>", [[x]], { desc = "Cut selected lines" })
map({ "x" }, "p", [[P]], { desc = "Paste content won't yank content" })
map({ "x" }, "P", [[p]], { desc = "Paste content won't yank content" })
