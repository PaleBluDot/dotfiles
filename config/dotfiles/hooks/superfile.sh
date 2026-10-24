#!/usr/bin/env bash
#
# dotfiles hook: superfile (spf). Runs after its package and links (link,
# update, interactive). Arch, Mac and Windows get superfile from package:
# in dotfiles.yml; Debian and Fedora have no package, so this runs
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

case "${DOTFILES_PLATFORM:-}" in
  debian | fedora) ;;
  *) exit 0 ;;
esac
if command -v spf >/dev/null 2>&1; then
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
