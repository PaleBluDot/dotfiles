#!/usr/bin/env zsh

##########################
##############@ VARIABLES
##########################
DRY_RUN=false
VERBOSE=false


##########################
##############@ FUNCTIONS
##########################
_detect_os(){
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
    echo "yq is installed"
  else
    echo "yq is not installed"
    echo "installing yq..."
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
      echo "dry run mode"
      ;;
    --verbose)
      VERBOSE=true
      echo "verbose mode"
      ;;
  esac
done


