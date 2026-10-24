#!/usr/bin/env bash
#
# dotfiles hook: aether. Runs after its package (link, update, interactive).
#
# Writes the blueprints into ~/.config/aether/blueprints with this machine's
# paths. The repo keeps wallpaper paths relative to itself ("config/..."),
# so the same file works on every machine and the repo stays clean; Aether
# reads the paths as written, so its copies get the full path. Blueprints
# Aether saved there that the repo doesn't have yet are copied back into
# the repo (paths made relative again), for you to commit.
# Where Aether isn't packaged, says how to build it.
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

src="$DOTFILES/config/aether/blueprints"
parent="$HOME/.config/aether"
dest="$parent/blueprints"
shown="~/.config/aether/blueprints"

if ! command -v aether >/dev/null 2>&1; then
  echo "next: Aether isn't packaged on ${DOTFILES_PLATFORM:-this platform}; build it: git clone https://github.com/omacom/aether.git && cd aether && make build"
fi

physical() {
  (cd -P "$1" 2>/dev/null && pwd -P) || echo "$1"
}

# ~/.config/aether used to link the repo's whole config/aether folder: the
# copies would land inside the repo. Make it a real folder first.
if [[ -L $parent && $(physical "$parent") == "$(physical "$DOTFILES/config/aether")" ]]; then
  if [[ $dry == true ]]; then
    echo "dry run, would replace the link ~/.config/aether (to the repo) with a real folder, then write the blueprints in $shown"
    exit 0
  fi
  rm "$parent"
  mkdir -p "$parent"
  echo "aether: ~/.config/aether linked the repo's folder; it's a real folder now"
fi

if [[ -L $dest || ( -e $dest && ! -d $dest ) ]]; then
  echo "aether: $shown is a link or a file, not a folder; left it alone" >&2
  exit 1
fi
case "$(physical "$(dirname "$dest")")/" in
  "$(physical "$DOTFILES")/"*)
    echo "aether: $shown is inside the repo; the copies would end up in git" >&2
    exit 1
    ;;
esac

# A repo blueprint as this machine's copy, and back.
render() { sed "s|\"config/|\"$DOTFILES/config/|g" "$1"; }
unrender() { sed -e "s|\"$DOTFILES/config/|\"config/|g" -e "s|\"$HOME/.config/omarchy/|\"config/omarchy/|g" "$1"; }

# New blueprints saved by Aether: into the repo first.
if [[ -d $dest ]]; then
  for file in "$dest"/*.json; do
    [[ -f $file ]] || continue
    name="${file##*/}"
    [[ -e $src/$name ]] && continue
    if [[ $dry == true ]]; then
      echo "dry run, would copy ~/.config/aether/blueprints/$name into the repo"
    else
      unrender "$file" >"$src/$name"
      echo "aether: copied $name into the repo (new; commit it)"
    fi
  done
fi

written=0
for file in "$src"/*.json; do
  [[ -f $file ]] || continue
  name="${file##*/}"
  if [[ -f $dest/$name ]] && render "$file" | cmp -s - "$dest/$name"; then
    continue
  fi
  written=$((written + 1))
  if [[ $dry == true ]]; then
    echo "dry run, would write $shown/$name with this machine's paths"
    continue
  fi
  mkdir -p "$dest"
  render "$file" >"$dest/.$name.tmp"
  mv -f "$dest/.$name.tmp" "$dest/$name"
done
if [[ $written -gt 0 && $dry != true ]]; then
  echo "aether: wrote $written blueprint(s) in $shown with this machine's paths"
fi
