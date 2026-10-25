#!/usr/bin/env bash
#
# dotfiles hook: espanso. Runs after its package and links (link, update,
# interactive). Arch, Mac and Windows get espanso from package: in
# dotfiles.yml; Debian and Fedora have no package, so this installs it
# first (Fedora from the Terra repo, Debian from the latest GitHub
# release; update installs a newer one over it). Makes espanso start at
# boot: registers it as a service (a systemd user service on Linux, a
# LaunchAgent on macOS, a startup entry on Windows) and runs it as that
# service. Also checks that
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
  local tag
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
  if [[ $dry == true ]]; then
    echo "dry run, would install the latest espanso release from github.com/espanso/espanso ($asset)"
    return 0
  fi
  tag="$(latest_tag)"
  if [[ -z $tag ]]; then
    echo "espanso: couldn't find the latest release on GitHub" >&2
    return 1
  fi
  fetch_deb "$tag"
  echo "espanso: installed $tag ($asset)"
}

# The Debian .deb for the session.
asset="espanso-debian-$session-amd64.deb"

# The latest release's tag (v1.2.3), from the redirect of /releases/latest;
# nothing when GitHub can't be reached.
latest_tag() {
  local tag
  tag="$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/espanso/espanso/releases/latest 2>/dev/null)" || return 0
  tag="${tag##*/}"
  if [[ $tag == v* ]]; then
    echo "$tag"
  fi
}

# Downloads release $1's .deb and installs it with apt.
fetch_deb() {
  local tag="$1"
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  curl -fsSL -o "$tmp/$asset" "https://github.com/espanso/espanso/releases/download/$tag/$asset" || return 1
  # Readable by apt's own user: no "Download is performed unsandboxed" note.
  chmod 755 "$tmp"
  chmod 644 "$tmp/$asset"
  # The Wayland postinst runs setcap and fails without it.
  if [[ $session == wayland ]] && ! command -v setcap >/dev/null 2>&1; then
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -q libcap2-bin >/dev/null || return 1
  fi
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -q "$tmp/$asset" >/dev/null || return 1
}

# dotfiles update on Debian, espanso from the GitHub .deb (Fedora's Terra
# package updates with dnf): a newer release goes over it, and a running
# espanso restarts on it. GitHub out of reach = a warning, the rest still
# runs.
update_espanso() {
  local installed="" tag pkg
  if [[ $(uname -m) != x86_64 ]] || ! command -v curl >/dev/null 2>&1; then
    return 0
  fi
  # The .deb installed (espanso-wayland or espanso-x11) stays the one.
  for pkg in espanso-wayland espanso-x11; do
    if installed="$(dpkg-query -W -f='${Version}' "$pkg" 2>/dev/null)" && [[ -n $installed ]]; then
      asset="espanso-debian-${pkg#espanso-}-amd64.deb"
      break
    fi
  done
  if [[ -z $installed ]]; then
    return 0
  fi
  # 2.3.0-1: the Debian revision off.
  installed="v${installed%-*}"
  tag="$(latest_tag)"
  if [[ -z $tag ]]; then
    echo "espanso: couldn't check GitHub for a newer release; skipped"
    return 0
  fi
  if [[ $(printf '%s\n' "$tag" "$installed" | sort -V | tail -n 1) == "$installed" ]]; then
    return 0
  fi
  if [[ $dry == true ]]; then
    echo "dry run, would update espanso $installed -> $tag"
    return 0
  fi
  if ! fetch_deb "$tag"; then
    echo "espanso: couldn't install $tag; still on $installed"
    return 0
  fi
  if espanso status >/dev/null 2>&1; then
    espanso restart >/dev/null 2>&1 || true
  fi
  echo "espanso: updated $installed -> $tag"
}

if ! command -v espanso >/dev/null 2>&1; then
  install_espanso
  if [[ $dry == true ]] || ! command -v espanso >/dev/null 2>&1; then
    exit 0
  fi
elif [[ ${DOTFILES_COMMAND:-} == update && ${DOTFILES_PLATFORM:-} == debian ]]; then
  update_espanso
fi

physical() {
  (cd -P "$1" 2>/dev/null && pwd -P) || echo "$1"
}

# No config folder yet: nothing linked here. Checked before asking espanso,
# which would make an empty ~/.config/espanso in the link's place.
if [[ ! -e $HOME/.espanso && ! -d $HOME/.config/espanso/config ]]; then
  echo "next: espanso has no config yet; run: dotfiles link espanso"
  exit 0
fi

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
