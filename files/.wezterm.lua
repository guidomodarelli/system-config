-- Pull in the wezterm API
local wezterm = require("wezterm")

-- This will hold the configuration.
local config = wezterm.config_builder()

config.font = wezterm.font_with_fallback({
	"IosevkaTerm NF",
	"JetBrains Mono",
})

warn_about_missing_glyphs = false

config.font_size = 14

-- and finally, return the configuration to wezterm
return config
