if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi


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
[[ ! -f $DOT_DIR/config/zsh/.aliases ]] || source $DOT_DIR/config/zsh/.aliases
[[ ! -f $DOT_DIR/config/zsh/.functions ]] || source $DOT_DIR/config/zsh/.functions
[[ ! -f $DOT_DIR/config/zsh/.p10k.zsh ]] || source $DOT_DIR/config/zsh/.p10k.zsh
[[ ! -x "$(command -v welcome.sh)" ]] || source welcome.sh && neofetch

POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true
