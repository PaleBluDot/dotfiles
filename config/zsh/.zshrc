if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Load Correct Editor
# Checks if connected by SSH and sets
# the $EDITOR variable to nano editor.
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='nano'
else
  export EDITOR='code'
fi

# Export ENV variables
export ZSH="$HOME/.oh-my-zsh"
export PATH=$HOME/bin:$PATH
export GITHUB_DIR=$HOME/github
export DOTFILES=$HOME/.config/dotfiles
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export PATH=$GOPATH/bin:$GOROOT/bin:$PATH

# ZSH Configurations
ZSH_THEME="powerlevel10k/powerlevel10k"
HIST_STAMPS="yyyy-mm-dd"

zstyle ':omz:update' mode auto
zstyle ':omz:update' frequency 7

plugins=(
  git
  git-auto-fetch
  dotenv
  zsh-syntax-highlighting
  zsh-autosuggestions
  colored-man-pages
  composer
  copypath

)

# Source files needed for ZSH
source $ZSH/oh-my-zsh.sh
[[ ! -f $DOTFILES/config/zsh/.aliases ]] || source $DOTFILES/config/zsh/.aliases
[[ ! -f $DOTFILES/config/zsh/.functions ]] || source $DOTFILES/config/zsh/.functions
[[ ! -f $DOTFILES/config/zsh/.p10k.zsh ]] || source $DOTFILES/config/zsh/.p10k.zsh
[[ ! -x "$(command -v welcome.sh)" ]] || source welcome.sh && neofetch

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
