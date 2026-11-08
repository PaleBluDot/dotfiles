#!/usr/bin/env bash
#
# dotfiles hook: ssh. Runs after its links (link, update, interactive), and
# from doctor when the ssh-agent isn't on.
#
# On Linux, ssh and git signing use 1Password's own agent when its desktop
# app is installed. Without it (a machine with no desktop) they use the
# systemd user ssh-agent instead (config/shell/env points SSH_AUTH_SOCK at
# it), with the keys loaded from 1Password by the sshkeys function. This
# turns that agent on: systemctl --user enable --now ssh-agent.socket.
#
# Nothing to do on macOS and Windows, with the 1Password app installed, or
# when the agent is already on.
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

[[ $(uname -s) == Linux ]] || exit 0
# 1Password's desktop app is the agent (and signs with op-ssh-sign).
[[ -x /opt/1Password/op-ssh-sign ]] && exit 0
command -v systemctl >/dev/null 2>&1 || exit 0
# The unit comes with OpenSSH; no unit, nothing to turn on.
systemctl --user cat ssh-agent.socket >/dev/null 2>&1 || exit 0

if systemctl --user is-enabled --quiet ssh-agent.socket 2>/dev/null &&
  systemctl --user is-active --quiet ssh-agent.socket 2>/dev/null; then
  exit 0
fi

if [[ $dry == true ]]; then
  echo "dry run, would run: systemctl --user enable --now ssh-agent.socket (no 1Password app here, so ssh and git signing use it)"
  exit 0
fi

if ! out="$(systemctl --user enable --now ssh-agent.socket 2>&1)"; then
  echo "couldn't turn on the ssh-agent (systemctl --user enable --now ssh-agent.socket): $out"
  exit 1
fi
echo "turned on the ssh-agent (systemctl --user enable --now ssh-agent.socket): no 1Password app here, so ssh and git signing use it"
echo "next: open a new shell; it asks for your 1Password password and loads your SSH keys (or run sshkeys)"
