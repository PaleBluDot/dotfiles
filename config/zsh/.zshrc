# POWERLEVEL10K INSTANT PROMPT
# Uncomment to revert to p10k
# -----------------------
# if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
#   source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
# fi

# OH-MY-ZSH CONFIGURATION
# Theme, update settings, and plugins
# -----------------------
# ZSH_THEME="powerlevel10k/powerlevel10k"  # uncomment to revert to p10k
ZSH_THEME=""
HIST_STAMPS="yyyy-mm-dd"

zstyle ':omz:update' mode auto
zstyle ':omz:update' frequency 7

# Lazy load nvm via the oh-my-zsh plugin — defers loading until node/npm/nvm is used
NVM_LAZY_LOAD=true

# Skip compaudit security check — speeds up compinit significantly
DISABLE_COMPFIX=true

plugins=(
  1password
  brew
  #colored-man-pages
  #composer
  #copypath
  dotenv
  gh
  git-auto-fetch
  #gulp
  macos
  npm
  nvm
  #postgres
  #python
  #rsync
  ssh
  #systemadmin
  #systemd
  tailscale
  tldr
  #tmux
  #ubuntu
  #ufw
  urltools
  #vscode
  #wp-cli
  zsh-autosuggestions
  zsh-syntax-highlighting
)

# COMPLETIONS
# fpath must be set before oh-my-zsh loads so compinit picks it up
# -----------------------
fpath+=${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/zsh-completions/src

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

# SHELL TOOLS
# thefuck is lazy-loaded — only initializes on first use
# -----------------------
eval "$(zoxide init zsh)"
POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true

thefuck() {
  unfunction thefuck
  eval $(command thefuck --alias)
  thefuck "$@"
}

# LOCAL CONFIG
# Aliases, functions, theme, welcome message
# -----------------------
[[ ! -f $DOTFILES/config/zsh/.aliases ]] || source $DOTFILES/config/zsh/.aliases
[[ ! -f $DOTFILES/config/zsh/.functions ]] || source $DOTFILES/config/zsh/.functions
# [[ ! -f $DOTFILES/config/zsh/.p10k.zsh ]] || source $DOTFILES/config/zsh/.p10k.zsh  # uncomment to revert to p10k
eval "$(starship init zsh)"
[[ ! -x "$(command -v welcome.sh)" ]] || source welcome.sh && fastfetch --pipe false
