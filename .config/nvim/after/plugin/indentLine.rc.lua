local status, indent = pcall(require, 'indentLine')
if (not status) then return end

indent.setup {}
