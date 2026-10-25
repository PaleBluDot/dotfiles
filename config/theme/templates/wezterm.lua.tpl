-- WezTerm colours for the current theme. bin/theme-set renders it
-- (with Omarchy, through the theme hook) into
-- ~/.local/state/omarchy/current/theme/wezterm.lua; wezterm.lua loads it as config.colors.
return {
  foreground = "{{ foreground }}",
  background = "{{ background }}",
  cursor_bg = "{{ bright_foreground }}",
  cursor_fg = "{{ background }}",
  cursor_border = "{{ bright_foreground }}",
  selection_fg = "{{ selection_foreground }}",
  selection_bg = "{{ selection_background }}",
  scrollbar_thumb = "{{ muted }}",
  split = "{{ muted }}",
  ansi = {
    "{{ background }}", "{{ red }}", "{{ green }}", "{{ yellow }}",
    "{{ blue }}", "{{ magenta }}", "{{ cyan }}", "{{ foreground }}",
  },
  brights = {
    "{{ muted }}", "{{ bright_red }}", "{{ bright_green }}", "{{ bright_yellow }}",
    "{{ bright_blue }}", "{{ bright_magenta }}", "{{ bright_cyan }}", "{{ bright_foreground }}",
  },
  tab_bar = {
    background = "{{ dark_background }}",
    active_tab = { bg_color = "{{ accent }}", fg_color = "{{ background }}" },
    inactive_tab = { bg_color = "{{ dark_background }}", fg_color = "{{ dark_foreground }}" },
    inactive_tab_hover = { bg_color = "{{ lighter_background }}", fg_color = "{{ foreground }}" },
    new_tab = { bg_color = "{{ dark_background }}", fg_color = "{{ dark_foreground }}" },
    new_tab_hover = { bg_color = "{{ lighter_background }}", fg_color = "{{ foreground }}" },
  },
}
