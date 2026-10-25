#!/usr/bin/env bash
#
# dotfiles hook: superfile (spf). Runs after its package and links (link,
# update, interactive). Arch, Mac and Windows get superfile from package:
# in dotfiles.yml; Debian and Fedora have no package, so this installs it
# when spf is missing: Fedora from the Terra repo (dnf keeps it updated),
# Debian with superfile's own installer, which update runs again when
# there's a newer release.
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

# superfile's installer, release $1 (1.2.3; empty = the latest). Saved to a
# file first (not piped into bash): a failed or cut-off download stops here
# instead of running half a script.
run_installer() {
  installer="$(mktemp)"
  trap 'rm -f "$installer"' EXIT
  curl -fsSL -o "$installer" https://superfile.dev/install.sh || return 1
  SPF_INSTALL_VERSION="$1" bash "$installer"
}

case "${DOTFILES_PLATFORM:-}" in
  debian | fedora) ;;
  *) exit 0 ;;
esac

# dotfiles update, spf from the installer (Debian, or Fedora before Terra
# installed it): a newer release goes over it, through the installer again.
# GitHub out of reach = a warning, the rest still runs.
if command -v spf >/dev/null 2>&1; then
  if [[ ${DOTFILES_COMMAND:-} != update ]] || ! command -v curl >/dev/null 2>&1; then
    exit 0
  fi
  if [[ $DOTFILES_PLATFORM == fedora ]] && rpm -q superfile >/dev/null 2>&1; then
    exit 0
  fi
  installed="$(spf --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)" || installed=""
  # The latest release's tag, from the redirect of /releases/latest.
  tag="$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/yorukot/superfile/releases/latest 2>/dev/null)" || tag=""
  tag="${tag##*/}"
  if [[ $tag != v* ]]; then
    echo "superfile: couldn't check GitHub for a newer release; skipped"
    exit 0
  fi
  if [[ -n $installed && $(printf '%s\n' "${tag#v}" "$installed" | sort -V | tail -n 1) == "$installed" ]]; then
    exit 0
  fi
  if [[ $dry == true ]]; then
    echo "dry run, would update superfile v${installed:-?} -> $tag (its installer)"
    exit 0
  fi
  if ! out="$(run_installer "${tag#v}" 2>&1)"; then
    printf '%s\n' "$out"
    echo "superfile: couldn't install $tag; still on v${installed:-?}"
    exit 0
  fi
  echo "superfile: updated v${installed:-?} -> $tag"
  exit 0
fi

if [[ $DOTFILES_PLATFORM == fedora ]]; then
  if [[ $dry == true ]]; then
    echo "dry run, would add the Terra repo and install superfile from it"
    exit 0
  fi
  # Terra's own way to add itself (https://developer.fyralabs.com/terra/installing).
  if ! rpm -q terra-release >/dev/null 2>&1; then
    dnf_install --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release
    echo "superfile: added the Terra repo"
  fi
  dnf_install superfile
  echo "superfile: installed superfile (Terra)"
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
run_installer ""
