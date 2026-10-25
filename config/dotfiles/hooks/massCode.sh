#!/usr/bin/env bash
#
# dotfiles hook: massCode. Runs after its package and links (link, update,
# interactive). Arch, Mac and Windows get massCode from package: in
# dotfiles.yml; Debian and Fedora have no package, so this installs the
# latest AppImage from GitHub as ~/.local/bin/masscode (it updates itself;
# update also installs a newer release over it), plus the FUSE library
# AppImages need.
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
# The installed tag, for update to compare (the AppImage can't tell its
# version without opening its window).
versions="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/versions"

# The latest release's tag (v1.2.3), from the redirect of /releases/latest;
# nothing when GitHub can't be reached.
latest_tag() {
  local tag
  tag="$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/massCodeIO/massCode/releases/latest 2>/dev/null)" || return 0
  tag="${tag##*/}"
  if [[ $tag == v* ]]; then
    echo "$tag"
  fi
}

# Downloads release $1's AppImage as ~/.local/bin/masscode.
fetch_masscode() {
  local tag="$1"
  tmp="$(mktemp)"
  trap 'rm -f "$tmp"' EXIT
  curl -fsSL -o "$tmp" "https://github.com/massCodeIO/massCode/releases/download/$tag/massCode-${tag#v}.AppImage" || return 1
  mkdir -p "$HOME/.local/bin" "$versions"
  install -m 755 "$tmp" "$bin" || return 1
  echo "$tag" >"$versions/masscode"
}

case "${DOTFILES_PLATFORM:-}" in
  debian | fedora) ;;
  *) exit 0 ;;
esac
if [[ $(uname -m) != x86_64 ]]; then
  if ! command -v masscode >/dev/null 2>&1 && [[ ! -x $bin ]]; then
    echo "next: massCode has no Linux AppImage for $(uname -m): https://masscode.io"
  fi
  exit 0
fi

# dotfiles update, the AppImage installed by this hook: a newer release
# goes over it (massCode also updates itself; this catches the ones it
# didn't). No tag kept (installed before update did this): the latest goes
# over it once. GitHub out of reach = a warning, the rest still runs.
if [[ -x $bin ]]; then
  if [[ ${DOTFILES_COMMAND:-} != update ]] || ! command -v curl >/dev/null 2>&1; then
    exit 0
  fi
  installed="$(cat "$versions/masscode" 2>/dev/null)" || installed=""
  tag="$(latest_tag)"
  if [[ -z $tag ]]; then
    echo "massCode: couldn't check GitHub for a newer release; skipped"
    exit 0
  fi
  if [[ -n $installed && $(printf '%s\n' "$tag" "$installed" | sort -V | tail -n 1) == "$installed" ]]; then
    exit 0
  fi
  if [[ $dry == true ]]; then
    echo "dry run, would update massCode ${installed:-(version unknown)} -> $tag"
    exit 0
  fi
  if ! fetch_masscode "$tag"; then
    echo "massCode: couldn't install $tag; still on ${installed:-the old one}"
    exit 0
  fi
  echo "massCode: updated ${installed:-(version unknown)} -> $tag"
  exit 0
fi
if command -v masscode >/dev/null 2>&1; then
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

tag="$(latest_tag)"
if [[ -z $tag ]]; then
  echo "massCode: couldn't find the latest release on GitHub" >&2
  exit 1
fi
fetch_masscode "$tag"
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
