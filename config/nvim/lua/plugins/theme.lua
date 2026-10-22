-- The current theme's colours: Omarchy generates neovim.lua (aether.nvim set
-- to the theme's colours, colorscheme = "aether") on every theme change.
-- Loaded after colorscheme.lua, so it wins; where the file isn't there
-- (machines without Omarchy), colorscheme.lua's catppuccin stays.
local theme = vim.fn.expand("~/.local/state/omarchy/current/theme/neovim.lua")
if vim.fn.filereadable(theme) == 1 then
  return dofile(theme)
end
return {}
