#!/usr/bin/env bash
#
# dotfiles hook: warp. Runs after its package and links (link, update,
# interactive). Arch, Mac and Windows get Warp from package: in
# dotfiles.yml; Debian and Fedora get it from Warp's own apt or dnf repo,
# which this adds (signed with Warp's key) before installing warp-terminal.
# Updates then come with the system's.
#
# Flags from dotfiles: --dry-run, --verbose, --force. Prints nothing when
# there's nothing to do; "next: ..." lines go to dotfiles' Next steps.

set -euo pipefail

# dnf prints its progress even with -q: keep its output, show it only
# when the install fails.
dnf_install() {
  local out
  if ! out="$(sudo dnf install -y -q "$@" 2>&1)"; then
    printf '%s\n' "$out" >&2
    return 1
  fi
}

dry=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) dry=true ;;
  esac
done

key_url=https://releases.warp.dev/linux/keys/warp.asc

case "${DOTFILES_PLATFORM:-}" in
  debian | fedora) ;;
  *) exit 0 ;;
esac
if command -v warp-terminal >/dev/null 2>&1; then
  exit 0
fi
if ! command -v curl >/dev/null 2>&1; then
  echo "next: install Warp (needs curl): https://www.warp.dev/download"
  exit 0
fi

if [[ $DOTFILES_PLATFORM == debian ]]; then
  keyring=/etc/apt/keyrings/warpdotdev.gpg
  list=/etc/apt/sources.list.d/warpdotdev.list
  if [[ $dry == true ]]; then
    echo "dry run, would add Warp's apt repo ($list) and install warp-terminal"
    exit 0
  fi
  if [[ ! -f $keyring ]]; then
    if ! command -v gpg >/dev/null 2>&1; then
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -q gpg >/dev/null
    fi
    tmp="$(mktemp)"
    trap 'rm -f "$tmp"' EXIT
    curl -fsSL "$key_url" | gpg --dearmor >"$tmp"
    sudo install -D -o root -g root -m 644 "$tmp" "$keyring"
  fi
  if [[ ! -f $list ]]; then
    echo "deb [arch=$(dpkg --print-architecture) signed-by=$keyring] https://releases.warp.dev/linux/deb stable main" |
      sudo tee "$list" >/dev/null
    echo "warp: added Warp's apt repo ($list)"
  fi
  sudo apt-get update -qq >/dev/null
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -q warp-terminal >/dev/null
else
  repo=/etc/yum.repos.d/warpdotdev.repo
  if [[ $dry == true ]]; then
    echo "dry run, would add Warp's dnf repo ($repo) and install warp-terminal"
    exit 0
  fi
  if [[ ! -f $repo ]]; then
    sudo rpm --import "$key_url"
    printf '%s\n' "[warpdotdev]" "name=warpdotdev" \
      "baseurl=https://releases.warp.dev/linux/rpm/stable" \
      "enabled=1" "gpgcheck=1" "gpgkey=$key_url" | sudo tee "$repo" >/dev/null
    echo "warp: added Warp's dnf repo ($repo)"
  fi
  dnf_install warp-terminal
fi
echo "warp: installed warp-terminal"
