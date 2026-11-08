#!/usr/bin/env bash
#
# dotfiles hook: ssh. Runs after its links (link, update, interactive).
#
# On `dotfiles link ssh` (or a link of everything), sets SSH up by running
# the ssh functions in config/shell/functions, the same ones you'd run by
# hand, so there's nothing left to do afterwards:
#
#   sshkeys        turn the ssh-agent on if needed, load your keys from
#                  1Password (no 1Password app here)
#   sshregister    this machine's SSH key, lab server entry and Host block
#                  in config/ssh/config
#   sshauthorize   pick who can log in here (authorized_keys)
#   ssh*           any other ssh function added later, alphabetically
#
# They ask questions (1Password password, section, which keys), so they
# run on the terminal; without one, they're listed under Next steps
# instead. One that fails or is cancelled is listed there too; sshkeys
# failing stops the rest (they need 1Password as well). When sshregister
# added a Host block, ~/.ssh/config is rebuilt once more so it's in there.
#
# Not on update (nothing to set up again) or the interactive install (its
# screens; a Next steps line says to run dotfiles link ssh when the keys
# aren't loaded).
#
# Flags from dotfiles: --dry-run, --verbose, --force. "next: ..." lines go
# to dotfiles' Next steps.

set -uo pipefail

dry=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) dry=true ;;
  esac
done

# The rebuild below runs link ssh again: don't run the functions twice.
[[ -n ${DOTFILES_SSH_NESTED:-} ]] && exit 0

repo="${DOTFILES:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
functions="$repo/config/shell/functions"
template="$repo/config/ssh/config"

# Known order first (keys, then this machine, then who may log in), then
# any other ssh* function.
order=""
for name in sshkeys sshregister sshauthorize; do
  [[ -f $functions/$name ]] && order+="$name "
done
for file in "$functions"/ssh*; do
  name="${file##*/}"
  [[ -f $file ]] || continue
  case " $order " in *" $name "*) continue ;; esac
  order+="$name "
done
order="${order% }"
[[ -n $order ]] || exit 0

for name in $order; do
  # shellcheck source=/dev/null
  source "$functions/$name"
done

case "${DOTFILES_COMMAND:-}" in
  link) ;;
  interactive)
    # Its screens are no place for prompts: a reminder when not set up yet.
    sshkeys --check >/dev/null 2>&1 || echo "next: run dotfiles link ssh to set up SSH (load your keys, register this machine, authorized_keys)"
    exit 0
    ;;
  *) exit 0 ;;
esac

if [[ $dry == true ]]; then
  echo "dry run, would run: ${order// /, } (they ask questions on the terminal)"
  exit 0
fi

if ! { : >/dev/tty; } 2>/dev/null; then
  echo "next: run ${order// /, } on a terminal to set up SSH (they ask questions)"
  exit 0
fi

before="$(cksum <"$template" 2>/dev/null || true)"
failed=""
for name in $order; do
  # On the terminal: their prompts don't end in a newline, so they'd stay
  # hidden in dotfiles' line-by-line output.
  if ! "$name" >/dev/tty 2>&1 </dev/tty; then
    failed+="$name "
    if [[ $name == sshkeys ]]; then
      # the rest need 1Password too: don't ask again
      for rest in $order; do
        [[ $rest == sshkeys ]] || failed+="$rest "
      done
      break
    fi
  fi
done

if [[ -n $failed ]]; then
  failed="${failed% }"
  echo "next: run ${failed// /, } again (failed or cancelled during dotfiles link ssh)"
fi

# sshregister added a Host block after ~/.ssh/config was filled in: fill it
# in again (1Password is signed in by now).
if [[ -n $before && $(cksum <"$template" 2>/dev/null) != "$before" ]]; then
  echo "config/ssh/config changed; filling in ~/.ssh/config again"
  DOTFILES_SSH_NESTED=1 "$repo/dotfiles.sh" link ssh
fi
exit 0
