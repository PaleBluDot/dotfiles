#!/usr/bin/env bash
#
# dotfiles hook: cspell. Runs after its links (link, update, interactive).
#
# cspell has no system package: it's installed with npm. Its dictionaries
# are npm packages too: ~/.config/cspell/package.json lists the ones
# cspell.json imports, and npm install puts them in node_modules there
# (gitignored). Installed again when package.json changes (#50).
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

if ! command -v npm >/dev/null 2>&1; then
  echo "next: cspell needs npm: dotfiles link npm, then dotfiles link cspell"
  exit 0
fi

if ! command -v cspell >/dev/null 2>&1; then
  if [[ $dry == true ]]; then
    echo "dry run, would run: npm install -g cspell"
  else
    echo "cspell: not installed, installing it: npm install -g cspell"
    npm install -g cspell
  fi
fi

# The dictionaries. The stamp holds package.json's hash from the last
# install: a changed package.json installs again.
dir="$HOME/.config/cspell"
if [[ ! -f $dir/package.json ]]; then
  exit 0
fi
if command -v sha256sum >/dev/null 2>&1; then
  hash="$(sha256sum <"$dir/package.json" | cut -d' ' -f1)"
else
  hash="$(shasum -a 256 <"$dir/package.json" | cut -d' ' -f1)"
fi
stamp="$dir/node_modules/.dotfiles-package-sha256"
if [[ -d $dir/node_modules && -f $stamp && $(<"$stamp") == "$hash" ]]; then
  exit 0
fi
if [[ $dry == true ]]; then
  echo "dry run, would run: npm install in ~/.config/cspell (its dictionaries)"
  exit 0
fi
echo "cspell: installing its dictionaries: npm install in ~/.config/cspell"
(cd "$dir" && npm install --no-fund --no-audit)
printf '%s\n' "$hash" >"$stamp"
