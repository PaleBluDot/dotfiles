#!/usr/bin/env bash
#
# dotfiles hook: espanso. Runs after its package and links (link, update,
# interactive). Arch, Mac and Windows get espanso from package: in
# dotfiles.yml; Debian and Fedora have no package, so this installs it
# first (Fedora from the Terra repo, Debian from the latest GitHub
# release). Makes espanso start at boot: registers it as a service (a
# systemd user service on Linux, a LaunchAgent on macOS, a startup entry on
# Windows) and runs it as that service. Also checks that
# espanso reads the linked repo config: it reads ~/.espanso first when
# that exists.
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

# espanso has an X11 build and a Wayland build: the session picks. dotfiles
# only runs this on a machine with a graphical interface (gui: true in
# dotfiles.yml); from ssh, with no session to ask, Wayland, the default on
# Debian and Fedora.
session=wayland
if [[ ${XDG_SESSION_TYPE:-} == x11 ]] ||
  [[ ${XDG_SESSION_TYPE:-} != wayland && -z ${WAYLAND_DISPLAY:-} && -n ${DISPLAY:-} ]]; then
  session=x11
fi

# espanso isn't installed (Debian and Fedora have no package). Fedora gets
# espanso-x11 or espanso-wayland from the Terra repo, which this adds, like
# hooks/warp.sh adds Warp's, so dnf keeps it updated. Debian gets the .deb
# for the session from the latest GitHub release (apt pulls the libraries;
# the Wayland one's postinst gives espanso the capability it needs to read
# the keyboard).
install_espanso() {
  local tag asset
  case "${DOTFILES_PLATFORM:-}" in
    debian | fedora) ;;
    *)
      echo "next: install espanso: https://espanso.org/install/"
      return 0
      ;;
  esac
  if [[ $DOTFILES_PLATFORM == fedora ]]; then
    if [[ $dry == true ]]; then
      echo "dry run, would add the Terra repo and install espanso-$session from it"
      return 0
    fi
    # Terra's own way to add itself (https://developer.fyralabs.com/terra/installing).
    if ! rpm -q terra-release >/dev/null 2>&1; then
      dnf_install --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release
      echo "espanso: added the Terra repo"
    fi
    dnf_install "espanso-$session" libcap
    # Reading the keyboard on Wayland needs this capability.
    if [[ $session == wayland ]] && ! getcap "$(command -v espanso)" 2>/dev/null | grep -q cap_dac_override; then
      sudo setcap cap_dac_override+p "$(command -v espanso)"
    fi
    echo "espanso: installed espanso-$session (Terra)"
    return 0
  fi
  if [[ $(uname -m) != x86_64 ]]; then
    echo "next: espanso has no Debian package for $(uname -m); build it: https://espanso.org/docs/install/linux/#compiling-from-sources"
    return 0
  fi
  if ! command -v curl >/dev/null 2>&1; then
    echo "next: install espanso (needs curl): https://github.com/espanso/espanso/releases/latest"
    return 0
  fi
  asset="espanso-debian-$session-amd64.deb"
  if [[ $dry == true ]]; then
    echo "dry run, would install the latest espanso release from github.com/espanso/espanso ($asset)"
    return 0
  fi
  # The latest release's tag, from the redirect of /releases/latest.
  tag="$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/espanso/espanso/releases/latest)"
  tag="${tag##*/}"
  if [[ $tag != v* ]]; then
    echo "espanso: couldn't find the latest release on GitHub" >&2
    return 1
  fi
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  curl -fsSL -o "$tmp/$asset" "https://github.com/espanso/espanso/releases/download/$tag/$asset"
  # Readable by apt's own user: no "Download is performed unsandboxed" note.
  chmod 755 "$tmp"
  chmod 644 "$tmp/$asset"
  # The Wayland postinst runs setcap and fails without it.
  if [[ $session == wayland ]] && ! command -v setcap >/dev/null 2>&1; then
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -q libcap2-bin >/dev/null
  fi
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -q "$tmp/$asset" >/dev/null
  echo "espanso: installed $tag ($asset)"
}

if ! command -v espanso >/dev/null 2>&1; then
  install_espanso
  if [[ $dry == true ]] || ! command -v espanso >/dev/null 2>&1; then
    exit 0
  fi
fi

physical() {
  (cd -P "$1" 2>/dev/null && pwd -P) || echo "$1"
}

# espanso takes the first of ~/.espanso, ~/.config/espanso, then the OS
# default (~/Library/Application Support/espanso on macOS) that exists.
if ! config="$(espanso path config 2>/dev/null)" || [[ -z $config ]]; then
  echo "espanso: can't find its config folder (espanso path config fails); check ~/.espanso and ~/.config/espanso" >&2
  exit 1
fi
if [[ $(physical "$config") != "$(physical "$HOME/.config/espanso")" ]]; then
  echo "espanso: it reads $config, not ~/.config/espanso (the repo's config): move $config out of the way, then run: dotfiles link espanso" >&2
  exit 1
fi

# The Linux service is a systemd user service: no user session here (a
# container, su/sudo without a login) means nothing to register it with.
case "${DOTFILES_PLATFORM:-}" in
  arch | debian | fedora)
    if ! systemctl --user show-environment >/dev/null 2>&1; then
      echo "next: no systemd user session here; from your desktop session run: espanso service register && espanso start"
      exit 0
    fi
    ;;
esac

if espanso service check >/dev/null 2>&1; then
  if ! espanso status >/dev/null 2>&1; then
    if [[ $dry == true ]]; then
      echo "dry run, would start the espanso service"
      exit 0
    fi
    espanso service start >/dev/null
    echo "espanso: started the service"
  fi
  exit 0
fi

if [[ $dry == true ]]; then
  echo "dry run, would register espanso as a service (starts at boot) and start it"
  exit 0
fi
# Its output (systemd's "Created symlink ...") only when it fails.
if ! out="$(espanso service register 2>&1)"; then
  printf '%s\n' "$out" >&2
  exit 1
fi
# Running by hand (espanso start --unmanaged): restart it as the service.
if espanso status >/dev/null 2>&1; then
  espanso restart >/dev/null
else
  espanso service start >/dev/null
fi
echo "espanso: registered as a service; it starts at boot now"
if [[ ${DOTFILES_PLATFORM:-} == mac ]]; then
  echo "next: allow espanso in System Settings > Privacy & Security > Accessibility (it can't type without it)"
fi
