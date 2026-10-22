# tmux colours for the current theme. Rendered by Omarchy (or dotfiles on
# machines without it) into ~/.local/state/omarchy/current/theme/tmux.conf;
# tmux.conf sources it after its fallback theme.conf.
set -g @tmux_color_bg "{{ background }}"
set -g @tmux_color_fg "{{ foreground }}"
set -g @tmux_color_accent "{{ accent }}"
set -g @tmux_color_muted "{{ muted }}"
set -g @tmux_color_active "{{ green }}"
