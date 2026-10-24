#!/usr/bin/env bash
#
# dotfiles hook: warp. Runs after its links (link, update, interactive).
# No package: the Warp app is installed by hand. Until it is, says where
# to get it.
#
# Flags from dotfiles: --dry-run, --verbose, --force. Prints nothing when
# there's nothing to do; "next: ..." lines go to dotfiles' Next steps.

set -euo pipefail

case "${DOTFILES_PLATFORM:-}" in
  mac) [[ -d /Applications/Warp.app ]] && exit 0 ;;
  windows) command -v warp >/dev/null 2>&1 && exit 0 ;;
  *) { command -v warp-terminal || command -v warp; } >/dev/null 2>&1 && exit 0 ;;
esac
echo "next: install the Warp app: https://www.warp.dev/download"
