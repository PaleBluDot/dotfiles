# EDITOR
# Use nano over SSH, VS Code locally
# -----------------------
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='nano'
else
  export EDITOR='code'
fi

# CORE DIRECTORIES
# Paths needed before .zshrc loads
# -----------------------
export ZSH="$HOME/.config/oh-my-zsh"
export DOTFILES="$HOME/.config/dotfiles"

# LANGUAGE RUNTIMES
# Go and NVM directories
# -----------------------
export GOROOT=/usr/local/go
export GOPATH="$HOME/.config/go"
export NVM_DIR="$HOME/.config/nvm"

# COMPLETION CACHE
# -----------------------
export ZSH_COMPDUMP="$ZSH/cache/.zcompdump-$HOST"

# HISTORY SUPPRESSION
# Disable history for noisy tools
# -----------------------
export LESSHISTFILE=-
export NODE_REPL_HISTORY=""

# PATH
# -----------------------
export PATH="$HOME/bin:$HOME/.config/npm/bin:$GOPATH/bin:$GOROOT/bin:$PATH"
