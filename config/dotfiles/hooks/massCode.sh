#!/usr/bin/env bash
#
# dotfiles hook: massCode. Runs after its links (link, update, interactive).
# No package: the massCode app is installed by hand. Until it is, says
# where to get it.
#
# Flags from dotfiles: --dry-run, --verbose, --force. Prints nothing when
# there's nothing to do; "next: ..." lines go to dotfiles' Next steps.

set -euo pipefail

case "${DOTFILES_PLATFORM:-}" in
  mac) [[ -d /Applications/massCode.app ]] && exit 0 ;;
  *) { command -v massCode || command -v masscode; } >/dev/null 2>&1 && exit 0 ;;
esac
echo "next: install the massCode app: https://masscode.io"
