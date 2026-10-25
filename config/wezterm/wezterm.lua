-- Pull in the wezterm API
local wezterm = require 'wezterm'

-- This will hold the configuration.
local config = wezterm.config_builder()

-- This is where you actually apply your config choices.
config.enable_tab_bar = false
-- config.use_fancy_tab_bar = false
config.window_background_opacity = 0.9

-- For example, changing the initial geometry for new windows:
config.initial_cols = 120
config.initial_rows = 50

-- or, changing the font size and color scheme.
config.font_size = 16
config.font = wezterm.font 'FiraCode NF'
-- config.color_scheme = 'Batman'

-- Colors follow the current theme: Omarchy generates wezterm.lua on every
-- theme change (on other machines, dotfiles does from settings.theme).
-- WezTerm's default colours stay as the fallback when that file isn't there.
-- Watched, so a theme change reloads the config.
local theme = wezterm.home_dir .. '/.local/state/omarchy/current/theme/wezterm.lua'
local ok, colors = pcall(dofile, theme)
if ok and type(colors) == 'table' then
  config.colors = colors
  wezterm.add_to_config_reload_watch_list(theme)
end

-- Finally, return the configuration to wezterm:
return config