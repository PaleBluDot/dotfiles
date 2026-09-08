# EDITOR
# Use nano over SSH, VS Code locally
# -----------------------
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='nvim'
  export VISUAL='nvim'
else
  export EDITOR='code-insiders'
  export VISUAL='code-insiders'
fi

# CORE DIRECTORIES
# Paths needed before .zshrc loads
# -----------------------
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"

export ZSH="$HOME/.config/zsh/oh-my-zsh"
export DOTFILES="$HOME/.config/dotfiles"
export STARSHIP_CONFIG="$HOME/.config/starship/demo.toml"

# LANGUAGE RUNTIMES
# Go and NVM directories
# -----------------------
export GOROOT=/usr/local/go
export GOPATH="$HOME/.config/go"
export NVM_DIR="$HOME/.config/nvm"

# COMPLETION CACHE
# -----------------------
# export ZSH_COMPDUMP="$ZSH/cache/.zcompdump-$HOST"
export ZSH_COMPDUMP=""

# HISTORY SUPPRESSION
# Disable history for noisy tools
# -----------------------
export LESSHISTFILE=-
export NODE_REPL_HISTORY=""

# PATH
# -----------------------
export PATH="$HOME/bin:$HOME/.config/npm/bin:$GOPATH/bin:$GOROOT/bin:$PATH"


