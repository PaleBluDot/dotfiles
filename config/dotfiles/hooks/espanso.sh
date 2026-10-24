#!/usr/bin/env bash
#
# dotfiles hook: espanso. Runs after its package and links (link, update,
# interactive). Makes espanso start at boot: registers it as a service
# (a systemd user service on Linux, a LaunchAgent on macOS, a startup entry
# on Windows) and runs it as that service. Also checks that espanso reads
# the linked repo config: it reads ~/.espanso first when that exists.
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

if ! command -v espanso >/dev/null 2>&1; then
  # Debian and Fedora have no package yet (#54).
  echo "next: install espanso: https://espanso.org/install/"
  exit 0
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
