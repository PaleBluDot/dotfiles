# Warp custom theme. macOS: ~/.warp/themes/; Linux:
# ${XDG_DATA_HOME:-~/.local/share}/warp-terminal/themes/; Windows:
# %APPDATA%\warp\Warp\data\themes\.
name: Omarchy
accent: "{{ accent }}"
background: "{{ background }}"
foreground: "{{ foreground }}"
details: darker
terminal_colors:
  normal:
    black: "{{ background }}"
    red: "{{ red }}"
    green: "{{ green }}"
    yellow: "{{ yellow }}"
    blue: "{{ blue }}"
    magenta: "{{ magenta }}"
    cyan: "{{ cyan }}"
    white: "{{ foreground }}"
  bright:
    black: "{{ muted }}"
    red: "{{ bright_red }}"
    green: "{{ bright_green }}"
    yellow: "{{ bright_yellow }}"
    blue: "{{ bright_blue }}"
    magenta: "{{ bright_magenta }}"
    cyan: "{{ bright_cyan }}"
    white: "{{ bright_foreground }}"
