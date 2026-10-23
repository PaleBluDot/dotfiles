# EDITOR
# Use nano over SSH, VS Code locally
# -----------------------
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='nvim'
  export VISUAL='nvim'
else
  export EDITOR='nvim'
  # --wait: git commit waits for the file to be closed (.aliases falls back
  # to code when Insiders isn't installed).
  export VISUAL='code-insiders --wait'
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
export ZSH_CACHE_DIR="$XDG_CACHE_HOME/oh-my-zsh"
# DOTFILES: wherever this machine's repo is, found through the ~/.config/dotfiles
# link that dotfiles.sh makes. :A resolves the link (…/dotfiles/config/dotfiles),
# :h:h goes up two folders to the repo.
_dotfiles_link="$XDG_CONFIG_HOME/dotfiles"
[[ -L $_dotfiles_link ]] && export DOTFILES="${_dotfiles_link:A:h:h}"
unset _dotfiles_link
# Starship: a copy of starship.toml with the current theme's palette picked
# (the theme hook writes the palette's name to ~/.cache/starship/palette).
# The copy is redone whenever starship.toml changes, so edits show at once.
# No palette file (theme never set here) = the repo file as is.
_starship_src="$HOME/.config/starship/starship.toml"
_starship_copy="$XDG_CACHE_HOME/starship/starship.toml"
if [[ -r $XDG_CACHE_HOME/starship/palette && -f $_starship_src ]]; then
  if [[ ! -f $_starship_copy || $_starship_src -nt $_starship_copy ]]; then
    sed "s/^palette = .*/palette = \"$(<$XDG_CACHE_HOME/starship/palette)\"/" "$_starship_src" >"$_starship_copy"
  fi
  export STARSHIP_CONFIG="$_starship_copy"
else
  export STARSHIP_CONFIG="$_starship_src"
fi
unset _starship_src _starship_copy

# bat: the current theme's colours once the theme hook has installed them
# as bat's "omarchy" theme; otherwise --theme in bat's config (knuckles).
[[ -f $HOME/.config/bat/themes/omarchy.tmTheme ]] && export BAT_THEME="omarchy"

# LANGUAGE RUNTIMES
# Go and NVM directories
# -----------------------
# GOROOT only for a manual Go install (macOS); mise-managed Go sets its own,
# and a GOROOT pointing at a missing folder breaks it
[[ -d /usr/local/go ]] && export GOROOT=/usr/local/go
export GOPATH="$XDG_DATA_HOME/go"
export NVM_DIR="$HOME/.config/nvm"

# KEEP $HOME CLEAN
# Tools that would otherwise put caches and data straight into $HOME
# -----------------------
export npm_config_cache="$XDG_CACHE_HOME/npm"
export CARGO_HOME="$XDG_DATA_HOME/cargo"
export DOTNET_CLI_HOME="$XDG_DATA_HOME/dotnet"
export CUDA_CACHE_PATH="$XDG_CACHE_HOME/nv"
export GNUPGHOME="$XDG_DATA_HOME/gnupg"
export COMPOSER_CACHE_DIR="$XDG_CACHE_HOME/composer"

# COMPLETION CACHE
# Out of the repo (ZDOTDIR is config/zsh) and into the cache folder
# -----------------------
[[ -d $XDG_CACHE_HOME/zsh ]] || mkdir -p "$XDG_CACHE_HOME/zsh"
export ZSH_COMPDUMP="$XDG_CACHE_HOME/zsh/.zcompdump-$HOST"

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


