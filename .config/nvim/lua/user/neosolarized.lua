local status, n = pcall(require, 'neosolarized')
if not status then return end

n.setup({
  comment_italics = true,
})

local cb = require('colorbuddy.init')

local Color = cb.Color
local colors = cb.colors
local Group = cb.Group
local groups = cb.groups
local styles = cb.styles

Color.new('black', '#000000')
Group.new('CursorLine', colors.none, colors.base03, styles.NONE, colors.base1)
Group.new('CursorLineNr', colors.yellow, colors.black, styles.NONE, colors.base1)
Group.new('Visual', colors.none, colors.base03, styles.reverse)

local cError = groups.Error.fg
local cInfo = groups.Information.fg
local cWarn = groups.Warning.fg
local cHint = groups.Hint.fg

Group.new('DiagnosticsVirtualTextError', cError, cError:dark():dark():dark():dark(), styles.NONE)
Group.new('DiagnosticsVirtualTextInfo', cInfo, cInfo:dark():dark():dark(), styles.NONE)
Group.new('DiagnosticsVirtualTextWarn', cWarn, cWarn:dark():dark():dark(), styles.NONE)
Group.new('DiagnosticsVirtualTextHint', cHint, cHint:dark():dark():dark(), styles.NONE)
Group.new('DiagnosticsUnderlineError', colors.none, colors.none, styles.undercurl, cError)
Group.new('DiagnosticsUnderlineWarn', colors.none, colors.none, styles.undercurl, cWarn)
Group.new('DiagnosticsUnderlineInfo', colors.none, colors.none, styles.undercurl, cInfo)
Group.new('DiagnosticsUnderlineHint', colors.none, colors.none, styles.undercurl, cHint)

