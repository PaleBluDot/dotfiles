# fzf colours for the current theme. In .zshrc / .bashrc:
#   [[ -f ~/.local/state/omarchy/current/theme/fzf.sh ]] && source ~/.local/state/omarchy/current/theme/fzf.sh
export FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS:+$FZF_DEFAULT_OPTS }--color=fg:{{ foreground }},bg:{{ background }},hl:{{ accent }},fg+:{{ bright_foreground }},bg+:{{ selection_background }},hl+:{{ accent }},info:{{ cyan }},prompt:{{ blue }},pointer:{{ accent }},marker:{{ green }},spinner:{{ magenta }},header:{{ dark_foreground }},border:{{ muted }},gutter:{{ background }}"
