if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Export ENV variables
export ZSH="$HOME/.oh-my-zsh"
export PATH=$HOME/bin:$PATH
export GITHUB_DIR=$HOME/github
export DOTFILES=$HOME/.config/dotfiles

# Source files needed for ZSH
source $ZSH/oh-my-zsh.sh
[[ ! -f $DOTFILES/config/zsh/.aliases ]] || source $DOTFILES/config/zsh/.aliases
[[ ! -f $DOTFILES/config/zsh/.functions ]] || source $DOTFILES/config/zsh/.functions
[[ ! -f $DOTFILES/config/zsh/.p10k.zsh ]] || source $DOTFILES/config/zsh/.p10k.zsh
[[ ! -x "$(command -v welcome.sh)" ]] || source welcome.sh

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

# Load Correct Editor
# Checks if connected by SSH and sets the $EDITOR
# variable to nano editor.
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='nano'
else
  export EDITOR='code'
fi

# Initializing NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Initializing theFuck package
eval $(thefuck --alias)

# Powerlevel p10k setting
POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true