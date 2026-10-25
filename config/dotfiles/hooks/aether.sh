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
# Where Aether isn't installed (only Arch packages it), installs the latest
# GitHub release first; Mac and Windows have nothing to do.
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

src="$DOTFILES/config/aether/blueprints"
parent="$HOME/.config/aether"
dest="$parent/blueprints"
shown="~/.config/aether/blueprints"

case "${DOTFILES_PLATFORM:-}" in
  mac | windows) exit 0 ;; # Aether themes Omarchy (Linux)
esac

# Aether isn't installed (only Arch packages it): install the latest
# release from GitHub. Debian gets its .deb (apt pulls the libraries);
# everywhere else the prebuilt binary goes in ~/.local/bin, and the
# libraries it needs that are missing come from dnf.
install_aether() {
  local arch tag asset missing
  case "$(uname -m)" in
    x86_64) arch=amd64 ;;
    aarch64 | arm64) arch=arm64 ;;
    *)
      echo "next: Aether has no release for $(uname -m); build it: https://github.com/omacom/aether#build-from-source"
      return 0
      ;;
  esac
  if ! command -v curl >/dev/null 2>&1; then
    echo "next: install Aether (needs curl): https://github.com/omacom/aether/releases/latest"
    return 0
  fi
  if [[ $dry == true ]]; then
    echo "dry run, would install the latest Aether release from github.com/omacom/aether"
    return 0
  fi
  # The latest release's tag, from the redirect of /releases/latest.
  tag="$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/omacom/aether/releases/latest)"
  tag="${tag##*/}"
  if [[ $tag != v* ]]; then
    echo "aether: couldn't find the latest release on GitHub" >&2
    return 1
  fi
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  if [[ ${DOTFILES_PLATFORM:-} == debian ]]; then
    asset="aether_${tag#v}_${arch}.deb"
    curl -fsSL -o "$tmp/$asset" "https://github.com/omacom/aether/releases/download/$tag/$asset"
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -q "$tmp/$asset" >/dev/null
    echo "aether: installed $tag ($asset)"
    return 0
  fi
  asset="aether-linux-$arch"
  curl -fsSL -o "$tmp/aether" "https://github.com/omacom/aether/releases/download/$tag/$asset"
  mkdir -p "$HOME/.local/bin"
  install -m 755 "$tmp/aether" "$HOME/.local/bin/aether"
  echo "aether: installed $tag in ~/.local/bin/aether"
  missing="$(ldd "$HOME/.local/bin/aether" 2>/dev/null | awk '/not found/ {print $1}' | tr '\n' ' ')"
  if [[ -n $missing && ${PKG_MANAGER:-} == dnf ]]; then
    dnf_install webkit2gtk4.1 gtk3 gtk-layer-shell gstreamer1-plugins-good
    missing="$(ldd "$HOME/.local/bin/aether" 2>/dev/null | awk '/not found/ {print $1}' | tr '\n' ' ')"
  fi
  if [[ -n $missing ]]; then
    echo "next: Aether needs these libraries: ${missing% } (webkit2gtk 4.1, gtk3, gtk-layer-shell, gstreamer)"
  fi
}

if ! command -v aether >/dev/null 2>&1 && [[ ! -x $HOME/.local/bin/aether ]]; then
  install_aether
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

# A repo file as this machine's copy, and back. Other paths in $HOME
# (~/Wallpapers, the default wallpaper folder) are kept as "~/...".
render() { sed -e "s|\"config/|\"$DOTFILES/config/|g" -e "s|\"~/|\"$HOME/|g" "$1"; }
unrender() { sed -e "s|\"$DOTFILES/config/|\"config/|g" -e "s|\"$HOME/.config/omarchy/|\"config/omarchy/|g" -e "s|\"$HOME/|\"~/|g" "$1"; }

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
