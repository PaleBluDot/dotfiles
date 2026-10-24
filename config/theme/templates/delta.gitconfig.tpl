# delta (git pager) colours. Include it from .gitconfig:
#   [include]
#     path = ~/.local/state/omarchy/current/theme/delta.gitconfig
[delta]
    syntax-theme = omarchy
    minus-style = syntax "{{ dark_background }}"
    minus-emph-style = syntax "{{ red }}"
    plus-style = syntax "{{ lighter_background }}"
    plus-emph-style = syntax "{{ green }}"
    line-numbers-minus-style = "{{ red }}"
    line-numbers-plus-style = "{{ green }}"
    line-numbers-zero-style = "{{ muted }}"
    file-style = "{{ accent }}" bold
    hunk-header-style = "{{ blue }}"
