#!/usr/bin/env zsh

##########################
##############@ VARIABLES
##########################
DRY_RUN=false
VERBOSE=false


##########################
##############@ FUNCTIONS
##########################
_log() {
  echo "$1"
}

_verbose() {
  if [[ "$VERBOSE" == true ]]; then
    echo "$1"
  fi
}

_detect_os() {
  case "$(uname)" in
    Darwin)
      echo "darwin"
      ;;
    Linux)
      if grep -qi "microsoft" /proc/version; then
        echo "wsl"
      else
        echo "linux"
      fi
      ;;
    MINGW*|MSYS*|CYGWIN*)
      echo "windows-native"
      ;;
    *)
      echo "Error: unsupported OS '$(uname)'" >&2
      exit 1
      ;;
  esac
}

_bootstrap() {
  DOTFILES=$(cd "$(dirname "$0")" && pwd)

  if command -v yq &>/dev/null; then
    _verbose "yq is installed"
  else
    _log "yq is not installed"
    _log "installing yq..."
    case "$(_detect_os)" in
      darwin)
        brew install yq
        ;;
      linux|wsl)
        sudo apt-get install yq
        ;;
      windows-native)
        winget install yq
        ;;
    esac
  fi
}


##########################
##################@ FLAGS
##########################
for arg in "$@"; do
  case "$arg" in
    --dry-run)
      DRY_RUN=true
      _log "dry run mode"
      ;;
    --verbose)
      VERBOSE=true
      _log "verbose mode"
      ;;
  esac
done


