-- Pull in the wezterm API
local wezterm = require 'wezterm'

-- This will hold the configuration.
local config = wezterm.config_builder()

config.font = wezterm.font_with_fallback {
  'Iosevka',
  'JetBrains Mono',
}

config.font_size = 14

-- and finally, return the configuration to wezterm
return config
