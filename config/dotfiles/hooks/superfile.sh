#!/usr/bin/env bash
#
# dotfiles hook: superfile (spf). Runs after its links (link, update,
# interactive). No package manager has it everywhere, so this runs
# superfile's own installer when spf is missing.
#
# Flags from dotfiles: --dry-run, --verbose, --force. Prints nothing when
# there's nothing to do; "next: ..." lines go to dotfiles' Next steps.

set -euo pipefail

dry=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) dry=true ;;
  esac
done

if command -v spf >/dev/null 2>&1; then
  exit 0
fi
if [[ ${DOTFILES_PLATFORM:-} == windows ]]; then
  echo "next: install superfile: powershell -ExecutionPolicy Bypass -Command \"Invoke-Expression (Invoke-WebRequest -UseBasicParsing -Uri https://superfile.dev/install.ps1).Content\""
  exit 0
fi
if ! command -v curl >/dev/null 2>&1; then
  echo "next: install superfile (needs curl): https://superfile.dev/install.sh"
  exit 0
fi
if [[ $dry == true ]]; then
  echo "dry run, would run superfile's installer: https://superfile.dev/install.sh"
  exit 0
fi
echo "superfile: not installed, running its installer (https://superfile.dev/install.sh)"
# Saved to a file first (not piped into bash): a failed or cut-off download
# stops here instead of running half a script.
installer="$(mktemp)"
trap 'rm -f "$installer"' EXIT
curl -fsSL -o "$installer" https://superfile.dev/install.sh
bash "$installer"
