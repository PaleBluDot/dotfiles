#!/usr/bin/env bash
#
# dotfiles hook: omarchy. Runs after its packages and links (link, update,
# interactive). The links put surface-boot-theme-apply and its .path
# watcher in place, but the watcher only fires on a theme change, a
# branding edit or an Omarchy update. On a fresh install none of those has
# happened yet, so the boot menu wallpaper, its colors and the password
# screen stay stock until the next theme change. This runs it once, now.
# It only writes what changed, so a run with nothing new is quick and
# changes nothing.
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

[[ ${DOTFILES_PLATFORM:-} == arch && -x /usr/local/sbin/surface-boot-theme-apply ]] || exit 0

if [[ $dry == true ]]; then
  echo "dry run, would run: sudo systemctl start surface-boot-theme.service"
  exit 0
fi

# Through the service, not the script: systemctl waits for it, and never
# runs it twice at the same time as the watcher.
if ! sudo systemctl start surface-boot-theme.service; then
  echo "next: the boot screen theme failed to build: journalctl -u surface-boot-theme.service"
fi
