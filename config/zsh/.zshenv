# EDITOR
# Use nano over SSH, VS Code locally
# -----------------------
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='nvim'
  export VISUAL='nvim'
else
  export EDITOR='nvim'
  export VISUAL='code-insiders'
fi

# CORE DIRECTORIES
# Paths needed before .zshrc loads
# -----------------------
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"

# zsh: only ~/.zshenv lives in $HOME; everything else is in ~/.config/zsh
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"

export ZSH="$HOME/.config/zsh/oh-my-zsh"
export DOTFILES="$HOME/Projects/github.com/PaleBluDot/dotfiles"
export STARSHIP_CONFIG="$HOME/.config/starship/starship.toml"

# LANGUAGE RUNTIMES
# Go and NVM directories
# -----------------------
# GOROOT only for a manual Go install (macOS); mise-managed Go sets its own,
# and a GOROOT pointing at a missing folder breaks it
[[ -d /usr/local/go ]] && export GOROOT=/usr/local/go
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

# PAGER
# Neovim as manpager
# -----------------------
export MANPAGER="nvim +Man!"

# PATH
# -----------------------
export PATH="$DOTFILES/bin:$HOME/bin:$HOME/.config/npm/bin:$GOPATH/bin:${GOROOT:+$GOROOT/bin:}$HOME/.docker/bin:$PATH"
# ~/.local/bin goes last (as Omarchy does): it holds files like uv's `env`
# that must not shadow system commands
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$PATH:$HOME/.local/bin" ;; esac


