#!/usr/bin/env bash
#
# dotfiles hook: bash. Runs after its links (link, update, interactive).
#
# bash login shells read only the first of ~/.bash_profile, ~/.bash_login
# and ~/.profile. dotfiles links ~/.profile (config/shell/profile), which
# loads ~/.bashrc, so a ~/.bash_profile left by the OS (Arch, Git for
# Windows) or by an old dotfiles link would hide it. This removes it.
#
# Removed outright: an old link into the repo, or a file that only loads
# ~/.bashrc or runs brew shellenv (the stock files, nothing of yours).
# Anything else is kept as ~/.bash_profile.bak and gets a "next:" line, so
# you can move what you need into config/shell/profile. --force removes it
# without a backup.
#
# Flags from dotfiles: --dry-run, --verbose, --force. Prints nothing when
# there's nothing to do; "next: ..." lines go to dotfiles' Next steps.

set -euo pipefail

dry=false force=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) dry=true ;;
    --force) force=true ;;
  esac
done

file="$HOME/.bash_profile"
[[ -e $file || -L $file ]] || exit 0

# What to do with it: remove (nothing of yours in it) or backup.
action=backup
if [[ -L $file ]]; then
  target="$(readlink -f "$file" 2>/dev/null || true)"
  case "$target" in
    "${DOTFILES:-/nonexistent}"/*) action=remove ;;
  esac
elif [[ -f $file ]]; then
  action=remove
  while IFS= read -r line || [[ -n $line ]]; do
    line="${line#"${line%%[![:space:]]*}"}"   # trim leading space
    case "$line" in
      '' | '#'*) continue ;;
    esac
    if [[ $line =~ (\.|source)[[:space:]]+[\"\']?(~|\$HOME|\$\{HOME\})/\.bashrc ]] ||
      [[ $line == *"brew shellenv"* ]] ||
      [[ $line =~ ^if[[:space:]].*/\.bashrc.*then$ ]] ||
      [[ $line =~ ^(then|fi|else)$ ]]; then
      continue
    fi
    action=backup
    break
  done <"$file"
fi
[[ $force == true ]] && action=remove

if [[ $action == remove ]]; then
  if [[ $dry == true ]]; then
    echo "dry run, would run: rm -f ~/.bash_profile (it hides ~/.profile from bash login shells)"
  else
    rm -f "$file"
    echo "bash: removed ~/.bash_profile so login shells read ~/.profile (which loads ~/.bashrc)"
  fi
  exit 0
fi

if [[ -e $file.bak || -L $file.bak ]]; then
  echo "next: ~/.bash_profile hides ~/.profile, and ~/.bash_profile.bak is in the way; move what you need into config/shell/profile, delete both, then run: dotfiles link bash"
  exit 0
fi
if [[ $dry == true ]]; then
  echo "dry run, would run: mv ~/.bash_profile ~/.bash_profile.bak (it hides ~/.profile from bash login shells)"
else
  mv "$file" "$file.bak"
  echo "bash: moved ~/.bash_profile to ~/.bash_profile.bak so login shells read ~/.profile"
  echo "next: ~/.bash_profile.bak had settings of its own; move what you need into config/shell/profile, then delete it"
fi
