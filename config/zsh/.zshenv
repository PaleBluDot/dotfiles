# Export ENV variables

# Load Correct Editor
# Checks if connected by SSH and sets
# the $EDITOR variable to nano editor.
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='nano'
else
  export EDITOR='code'
fi

# zsh home directory
export ZSH="$HOME/.config/oh-my-zsh"

# set go root and path
export GOROOT=/usr/local/go
export GOPATH=$HOME/.config/go

# set the dotfiles directory
export DOT_DIR=$HOME/.config/dotfiles

# set the github directory
export GITHUB_DIR=$HOME/github

# set zsh compdump directory
export ZSH_COMPDUMP=$ZSH/cache/.zcompdump-$HOST

# set less history file to /dev/null
export LESSHISTFILE=-

# set node history to /dev/null
export NODE_REPL_HISTORY=""

# set the nvm directory
export NVM_DIR="$HOME/.config/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# export the path
export PATH=$HOME/bin:$GOPATH/bin:$GOROOT/bin:$PATH