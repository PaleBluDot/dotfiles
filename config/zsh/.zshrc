# OH-MY-ZSH CONFIGURATION

# Theme, update settings, and plugins
# -----------------------
ZSH_THEME=""
HIST_STAMPS="yyyy-mm-dd"

zstyle ':omz:update' mode auto
zstyle ':omz:update' frequency 7

# Lazy load nvm via the oh-my-zsh plugin — defers loading until node/npm/nvm is used
NVM_LAZY_LOAD=true

# Skip compaudit security check — speeds up compinit significantly
DISABLE_COMPFIX=true

plugins=(
  # 1password
  brew
  #colored-man-pages
  #composer
  #copypath
  # dotenv
  gh
  # git-auto-fetch
  #gulp
  macos
  npm
  nvm
  #postgres
  # python
  #rsync
  ssh
  #systemadmin
  #systemd
  # tailscalex
  # tldr
  #tmux
  #ubuntu
  #ufw
  # urltools
  #vscode
  #wp-cli
  zsh-autosuggestions
  zsh-syntax-highlighting
)

# COMPLETIONS
# fpath must be set before oh-my-zsh loads so compinit picks it up
# -----------------------
fpath+=${ZSH_CUSTOM:-${ZSH:-~/.config/zsh/oh-my-zsh}/custom}/plugins/zsh-completions/src

source $ZSH/oh-my-zsh.sh

# HISTORY
# Override HISTFILE after oh-my-zsh sets it to ~/zsh_history
# -----------------------
HISTFILE="$HOME/.local/share/zsh/history"

# TOOL DIRECTORIES
# Interactive-only tool paths
# -----------------------
export GITHUB_DIR="$HOME/github"
export COMPOSER_HOME="$HOME/.config/composer"
export WAKATIME_HOME="$HOME/.config/wakatime"
export SEMGREP_SETTINGS_FILE="$HOME/.config/semgrep/settings.yml"
export TEALDEER_CONFIG_DIR="$HOME/.config/tldr"


eval "$(starship init zsh)"
eval "$(zoxide init zsh)"
eval "$(op completion zsh)"; compdef _op op
eval $(thefuck --alias)


thefuck() {
  unfunction thefuck
  eval $(command thefuck --alias)
  thefuck "$@"
}

function y() {
	local tmp cwd; tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
	command yazi "$@" --cwd-file="$tmp"
	IFS= read -r -d '' cwd < "$tmp"
	[ "$cwd" != "$PWD" ] && [ -d "$cwd" ] && builtin cd -- "$cwd" || builtin true
	command rm -f -- "$tmp"
}

# LOCAL CONFIG
# Aliases, functions, theme, welcome message
# -----------------------
[[ ! -f $DOTFILES/config/zsh/.aliases ]] || source $DOTFILES/config/zsh/.aliases
[[ ! -f $DOTFILES/config/zsh/.functions ]] || source $DOTFILES/config/zsh/.functions


# Welcome screen
[[ ! -x "$(command -v welcome.sh)" ]] || source welcome.sh &&
fastfetch --pipe false
