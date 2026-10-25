# lazygit theme. Load it after the main config:
#   LG_CONFIG_FILE="$HOME/.config/lazygit/config.yml,$HOME/.local/state/omarchy/current/theme/lazygit.yml"
gui:
  theme:
    activeBorderColor:
      - "{{ accent }}"
      - bold
    inactiveBorderColor:
      - "{{ muted }}"
    searchingActiveBorderColor:
      - "{{ yellow }}"
      - bold
    optionsTextColor:
      - "{{ blue }}"
    selectedLineBgColor:
      - "{{ selection_background }}"
    inactiveViewSelectedLineBgColor:
      - "{{ lighter_background }}"
    cherryPickedCommitFgColor:
      - "{{ background }}"
    cherryPickedCommitBgColor:
      - "{{ cyan }}"
    markedBaseCommitFgColor:
      - "{{ background }}"
    markedBaseCommitBgColor:
      - "{{ yellow }}"
    unstagedChangesColor:
      - "{{ red }}"
    defaultFgColor:
      - "{{ foreground }}"
