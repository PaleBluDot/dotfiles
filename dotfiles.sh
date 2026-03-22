#!/usr/bin/env zsh

##########################
##############@ VARIABLES
##########################
readonly LOG_LEVEL_DEBUG=0
readonly LOG_LEVEL_INFO=1
readonly LOG_LEVEL_WARN=2
readonly LOG_LEVEL_ERROR=3
LOG_LEVEL=$LOG_LEVEL_INFO
DRY_RUN=false


##########################
##############@ FUNCTIONS
##########################
_log() {
  local level="$1"
  local message="$2"
  local level_num
  local prefix

  local CYAN="\033[0;36m"
  local GREEN="\033[0;32m"
  local YELLOW="\033[0;33m"
  local RED="\033[0;31m"
  local RESET="\033[0m"


  case "$level" in
    debug) level_num=$LOG_LEVEL_DEBUG;
           prefix="${GREEN}[DEBUG]  ${RESET}" ;;
    info)  level_num=$LOG_LEVEL_INFO;
           prefix="${CYAN}[INFO]   ${RESET}" ;;
    warn)  level_num=$LOG_LEVEL_WARN;
           prefix="${YELLOW}[WARN]   ${RESET}" ;;
    error) level_num=$LOG_LEVEL_ERROR;
           prefix="${RED}[ERROR]  ${RESET}" ;;
    *)     level_num=$LOG_LEVEL_INFO;
           prefix="${CYAN}[INFO]   ${RESET}" ;;
  esac


  [[ $level_num -lt $LOG_LEVEL ]] && return


  if [[ "$level" == "error" ]]; then
    echo -e "$prefix $message" >&2
  else
    echo -e "$prefix $message"
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
      _log error "Unsupported OS '$(uname)'"
      exit 1
      ;;
  esac
}

_bootstrap() {
  export DOTFILES=$(cd "$(dirname "$0")" && pwd)


  if command -v yq &>/dev/null; then
    _log debug "yq is installed"
  else
    _log info "yq is not installed"
    _log info "installing yq..."
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
    --dry-run|-n)
      DRY_RUN=true ;;
    --debug|-d)
      LOG_LEVEL=$LOG_LEVEL_DEBUG ;;
  esac
done

[[ "$DRY_RUN" == true ]] && _log info "dry run mode"
[[ "$LOG_LEVEL" == "$LOG_LEVEL_DEBUG" ]] && _log info "debug mode"



##########################
####################@ RUN
##########################
_bootstrap

_log info "test message"
_log debug "test message"
_log warn "test message"
_log error "test message"

# _log info "dotfiles script loaded successfully"