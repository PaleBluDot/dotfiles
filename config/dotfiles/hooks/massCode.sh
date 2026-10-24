#!/usr/bin/env bash
#
# dotfiles hook: massCode. Runs after its package and links (link, update,
# interactive). Arch, Mac and Windows get massCode from package: in
# dotfiles.yml; Debian and Fedora have no package, so this installs the
# latest AppImage from GitHub as ~/.local/bin/masscode (it updates itself),
# plus the FUSE library AppImages need.
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

bin="$HOME/.local/bin/masscode"

case "${DOTFILES_PLATFORM:-}" in
  debian | fedora) ;;
  *) exit 0 ;;
esac
if command -v masscode >/dev/null 2>&1 || [[ -x $bin ]]; then
  exit 0
fi
if [[ $(uname -m) != x86_64 ]]; then
  echo "next: massCode has no Linux AppImage for $(uname -m): https://masscode.io"
  exit 0
fi
if ! command -v curl >/dev/null 2>&1; then
  echo "next: install massCode (needs curl): https://github.com/massCodeIO/massCode/releases/latest"
  exit 0
fi
if [[ $dry == true ]]; then
  echo "dry run, would install the latest massCode AppImage as ~/.local/bin/masscode"
  exit 0
fi

# The latest release's tag, from the redirect of /releases/latest.
tag="$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/massCodeIO/massCode/releases/latest)"
tag="${tag##*/}"
if [[ $tag != v* ]]; then
  echo "massCode: couldn't find the latest release on GitHub" >&2
  exit 1
fi
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
curl -fsSL -o "$tmp" "https://github.com/massCodeIO/massCode/releases/download/$tag/massCode-${tag#v}.AppImage"
mkdir -p "$HOME/.local/bin"
install -m 755 "$tmp" "$bin"
echo "massCode: installed $tag in ~/.local/bin/masscode"

# AppImages run through FUSE 2.
if ! /sbin/ldconfig -p 2>/dev/null | grep -q 'libfuse\.so\.2'; then
  if [[ $DOTFILES_PLATFORM == debian ]]; then
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -q libfuse2t64 >/dev/null 2>&1 ||
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -q libfuse2 >/dev/null
  else
    dnf_install fuse-libs
  fi
  echo "massCode: installed FUSE 2 (AppImages need it)"
fi
