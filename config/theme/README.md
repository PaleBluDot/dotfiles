# Theme templates

`templates/` has a colour template (`<file>.tpl`) for every tool that can take
a colour file, used or not, and is the one place to edit them. Each is filled
from a theme's `colors.toml` (`config/omarchy/themes/<slug>/colors.toml`) into
`~/.local/state/omarchy/current/theme/<file>` (the template name without
`.tpl`), the same folder Omarchy uses, so every tool reads one place on every
machine. A template renders only where its tool is installed:
[`tools`](tools) maps each output file to the commands (or macOS app paths)
that show the tool is there (`theme-set tools` shows the result here).

- **Without Omarchy** (Debian, Ubuntu, macOS), `bin/theme-set <theme>`
  renders the templates for the installed tools, the same way Omarchy does
  (output checked byte for byte against `omarchy-theme-set-templates`),
  swaps the folder in and writes `theme.name`. Then the theme-set hook
  (`config/omarchy/hooks/theme-set.d/60-dotfiles-theme`: starship palette,
  bat cache, tmux reload) and a terminal reload (alacritty, kitty, and
  ghostty on Linux). `dotfiles link` / `update` keep it current:
  `settings.theme` is only the first theme, a theme chosen here stays.
- **With Omarchy**, `theme-set` runs `omarchy-theme-set`, which renders its
  own built-in templates (the "Omarchy" ones below, for every tool, its
  choice). The same hook then runs `theme-set --extras`: the other
  templates, for the installed tools. `config/omarchy/themed/` (Omarchy's
  user templates) stays empty, since one repo folder can't vary per machine.

A file a theme ships itself (`hyprland.lua`, `vscode.json`) wins over the
template, in both. A new tool: its `<file>.tpl` in `templates/` and a line
in `tools`; nothing else.

## Variables

`{{ name }}` is replaced by the theme's colour; `{{ name_strip }}` is the hex
without `#`, `{{ name_rgb }}` is `r,g,b` (decimal).

From `colors.toml`: `background`, `dark_background`, `darker_background`,
`lighter_background`, `foreground`, `dark_foreground`, `light_foreground`,
`bright_foreground`, `accent`, `selection`, `muted`, `red`, `green`, `yellow`,
`blue`, `magenta`, `cyan`, `orange`, `brown`, `bright_red`, `bright_green`,
`bright_yellow`, `bright_blue`, `bright_magenta`, `bright_cyan`,
`active_border_color`, `active_tab_background`, `mode`.

Derived when the theme doesn't set them:
- `selection_background` = `selection`
- `selection_foreground` = `bright_foreground`
- `theme_type` = `mode` (`dark` or `light`)
- `purple` = `magenta`
- the rest of Omarchy's fallbacks (`omarchy-theme-color`): legacy `bg` /
  `colorN` names, `brown`, `dark_background`, `darker_background` and the
  `bright_*` colours mixed from their base, `mode` from the background's
  brightness.

Helpers (Omarchy's renderer and `theme-set` both have them):
- `{{ mix a b N% }}`: colour `a` blended N% towards `b` (claude, hermes,
  shell, t3code, pi); `mix_strip`, `mix_rgb` too.
- `{{ hypr_gradient key default }}`: Hyprland border gradient (hyprland.lua,
  Omarchy only).
- `{{ shell_gradient key default }}`, `{{ gradient_start key default }}`:
  the same gradient for the Omarchy shell (shell.toml).

## Templates

| Template | Output read by | From |
|---|---|---|
| `alacritty.toml.tpl` | Alacritty (`import` it) | Omarchy |
| `bat.tmTheme.tpl` | bat, installed as theme `omarchy` + `bat cache --build` | dotfiles |
| `btop.theme.tpl` | btop (`color_theme`) | Omarchy |
| `chromium.theme.tpl` | Chromium/Brave theme colour (Omarchy) | Omarchy |
| `claude.json.tpl` | Claude Code theme | Omarchy |
| `delta.gitconfig.tpl` | delta, `[include]` from `.gitconfig` (uses bat's `omarchy` theme) | new |
| `eza.yml.tpl` | eza, `~/.config/eza/theme.yml` | new |
| `foot.ini.tpl` | foot (`include=`) | Omarchy |
| `fzf.sh.tpl` | fzf, sourced from the shell (`FZF_DEFAULT_OPTS`) | new |
| `ghostty.conf.tpl` | Ghostty (`config-file =`) | Omarchy |
| `gum_env.lua.tpl` | gum / Omarchy menus | Omarchy |
| `helix.toml.tpl` | Helix theme | Omarchy |
| `hermes.yaml.tpl` | Hermes | Omarchy |
| `hyprland.lua.tpl` | Hyprland borders (Omarchy only) | Omarchy |
| `hyprland-preview-share-picker.css.tpl` | screen-share picker | Omarchy |
| `keyboard.rgb.tpl` | keyboard backlight colour | Omarchy |
| `kitty.conf.tpl` | kitty (`include`) | Omarchy |
| `lazydocker.yml.tpl` | lazydocker, merged into `config.yml` (`gui.theme`) | new |
| `lazygit.yml.tpl` | lazygit, `LG_CONFIG_FILE=config.yml,<this>` | new |
| `neovim.lua.tpl` | nvim (aether.nvim), `plugins/theme.lua` | Omarchy |
| `obsidian.css.tpl` | Obsidian (the Omarchy theme) | Omarchy |
| `pi.json.tpl` | pi | Omarchy |
| `shell.toml.tpl` | Omarchy shell | Omarchy |
| `starship-palette.toml.tpl` | starship, appended as `[palettes.<theme>]` | new |
| `superfile.toml.tpl` | superfile, `~/.config/superfile/theme/omarchy.toml` | new |
| `t3code.json.tpl` | t3code | Omarchy |
| `tmux.conf.tpl` | tmux, `source-file -q` from `tmux.conf` | dotfiles |
| `vscode-theme.json.tpl` | VS Code (as a local theme extension) | Omarchy |
| `warp.yaml.tpl` | Warp custom theme | new |
| `wezterm.lua.tpl` | WezTerm, `config.colors = dofile(...)` | new |
| `windows-terminal.json.tpl` | Windows Terminal colour scheme (`schemes`) | new |
| `yazi-theme.toml.tpl` | yazi, `~/.config/yazi/theme.toml` (yazi's default layout, theme colours) | new |
| `zellij.kdl.tpl` | zellij, `~/.config/zellij/themes/omarchy.kdl` | new |

"Omarchy" = a copy of Omarchy's built-in template (keep in step when Omarchy
updates them); "dotfiles" = wired up by dotfiles before these templates
(bat, tmux); "dotfiles" and "new" are rendered by `theme-set` (with
Omarchy: `--extras`, from the hook).

## Not covered

- **iTerm2:** `.itermcolors` needs each colour as fractions (0–1), which the
  variables can't give yet.
- **gitlogue:** only built-in themes, no custom theme files.
- **Terminal.app:** its profile format stores archived colour objects, not
  plain values.
