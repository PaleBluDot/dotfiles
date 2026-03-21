#!/usr/bin/env zsh

DRY_RUN=false
VERBOSE=false

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
    Windows)
      if [[ -n $COMSPEC ]]; then
        echo "windows-native"
      fi
      ;;
    *)
      echo "Error: unsupported OS '$(uname)'" >&2
      exit 1
      ;;
  esac
}
