#!/usr/bin/env bash
#
# dotfiles hook: aether. Runs after its package (link, update, interactive).
#
# Writes the blueprints into ~/.config/aether/blueprints with this machine's
# paths. The repo keeps wallpaper paths relative to itself ("config/..."),
# so the same file works on every machine and the repo stays clean; Aether
# reads the paths as written, so its copies get the full path. Blueprints
# Aether saved there that the repo doesn't have yet are copied back into
# the repo (paths made relative again), for you to commit. settings.json
# and favorites.json get the same paths, and go both ways: see below.
# Where Aether isn't installed (only Arch packages it), installs the latest
# GitHub release first, and on update installs a newer release over it;
# Mac and Windows have nothing to do.
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

versions="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/versions"
case "$(uname -m)" in
  x86_64) arch=amd64 ;;
  aarch64 | arm64) arch=arm64 ;;
  *) arch="" ;;
esac

# The latest release's tag (v1.2.3), from the redirect of /releases/latest;
# nothing when GitHub can't be reached.
latest_tag() {
  local tag
  tag="$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/omacom/aether/releases/latest 2>/dev/null)" || return 0
  tag="${tag##*/}"
  if [[ $tag == v* ]]; then
    echo "$tag"
  fi
}

# Downloads release $1 and installs it. Debian gets its .deb (apt pulls the
# libraries); everywhere else the prebuilt binary goes in ~/.local/bin and
# its tag in dotfiles' state folder, for update to compare (the binary
# can't tell its version without opening its window).
fetch_aether() {
  local tag="$1" asset
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  if [[ ${DOTFILES_PLATFORM:-} == debian ]]; then
    asset="aether_${tag#v}_${arch}.deb"
    curl -fsSL -o "$tmp/$asset" "https://github.com/omacom/aether/releases/download/$tag/$asset" || return 1
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -q "$tmp/$asset" >/dev/null || return 1
    return 0
  fi
  curl -fsSL -o "$tmp/aether" "https://github.com/omacom/aether/releases/download/$tag/aether-linux-$arch" || return 1
  mkdir -p "$HOME/.local/bin" "$versions"
  install -m 755 "$tmp/aether" "$HOME/.local/bin/aether" || return 1
  echo "$tag" >"$versions/aether"
}

# Aether isn't installed (only Arch packages it): install the latest
# release. The binary's libraries that are missing come from dnf.
install_aether() {
  local tag missing
  if [[ -z $arch ]]; then
    echo "next: Aether has no release for $(uname -m); build it: https://github.com/omacom/aether#build-from-source"
    return 0
  fi
  if ! command -v curl >/dev/null 2>&1; then
    echo "next: install Aether (needs curl): https://github.com/omacom/aether/releases/latest"
    return 0
  fi
  if [[ $dry == true ]]; then
    echo "dry run, would install the latest Aether release from github.com/omacom/aether"
    return 0
  fi
  tag="$(latest_tag)"
  if [[ -z $tag ]]; then
    echo "aether: couldn't find the latest release on GitHub" >&2
    return 1
  fi
  fetch_aether "$tag"
  if [[ ${DOTFILES_PLATFORM:-} == debian ]]; then
    echo "aether: installed $tag (aether_${tag#v}_${arch}.deb)"
    return 0
  fi
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

# dotfiles update, Aether installed by this hook (the .deb on Debian, the
# binary in ~/.local/bin elsewhere; Arch's pacman updates its own): a newer
# release goes over it. GitHub out of reach = a warning, the rest still runs.
update_aether() {
  local installed tag
  if [[ -z $arch ]] || ! command -v curl >/dev/null 2>&1; then
    return 0
  fi
  if [[ ${DOTFILES_PLATFORM:-} == debian ]]; then
    installed="$(dpkg-query -W -f='${Version}' aether 2>/dev/null)" || return 0
    installed="v${installed#v}"
  elif [[ -x $HOME/.local/bin/aether ]]; then
    # No tag kept (installed before update did this): the latest goes over
    # it once.
    installed="$(cat "$versions/aether" 2>/dev/null)" || installed=""
  else
    return 0
  fi
  tag="$(latest_tag)"
  if [[ -z $tag ]]; then
    echo "aether: couldn't check GitHub for a newer release; skipped"
    return 0
  fi
  if [[ -n $installed && $(printf '%s\n' "$tag" "$installed" | sort -V | tail -n 1) == "$installed" ]]; then
    return 0
  fi
  if [[ $dry == true ]]; then
    echo "dry run, would update aether ${installed:-(version unknown)} -> $tag"
    return 0
  fi
  if ! fetch_aether "$tag"; then
    echo "aether: couldn't install $tag; still on ${installed:-the old one}"
    return 0
  fi
  echo "aether: updated ${installed:-(version unknown)} -> $tag"
}

if ! command -v aether >/dev/null 2>&1 && [[ ! -x $HOME/.local/bin/aether ]]; then
  install_aether
elif [[ ${DOTFILES_COMMAND:-} == update && ${DOTFILES_PLATFORM:-} != arch ]]; then
  update_aether
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

# settings.json and favorites.json: Aether saves them, git pull brings the
# repo's, so both sides change. The copy last written here (in dotfiles'
# state folder) tells which one did, and that one wins. Both changed (or
# no copy yet): Aether's goes into the repo, the repo's stays in git; the
# diff shows both, commit it or check out the repo's and run again.
state="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/aether"
for name in settings.json favorites.json; do
  repo="$DOTFILES/config/aether/$name"
  mine="$parent/$name"
  last="$state/$name"
  [[ -f $repo || -f $mine ]] || continue
  if [[ ! -f $mine ]]; then
    action=write why=""
  elif [[ ! -f $repo ]]; then
    action=copy why="new"
  elif render "$repo" | cmp -s - "$mine"; then
    action=same why=""
  elif [[ -f $last ]] && cmp -s "$mine" "$last"; then
    action=write why="" # only the repo changed
  elif [[ -f $last ]] && render "$repo" | cmp -s - "$last"; then
    action=copy why="changed in Aether"
  else
    action=copy why="changed in Aether and in the repo; git diff shows both"
  fi
  if [[ $dry == true ]]; then
    case "$action" in
      write) echo "dry run, would write ~/.config/aether/$name with this machine's paths" ;;
      copy) echo "dry run, would copy ~/.config/aether/$name into the repo ($why)" ;;
    esac
    continue
  fi
  case "$action" in
    write)
      mkdir -p "$parent"
      render "$repo" >"$parent/.$name.tmp"
      mv -f "$parent/.$name.tmp" "$mine"
      echo "aether: wrote ~/.config/aether/$name with this machine's paths"
      ;;
    copy)
      unrender "$mine" >"$repo"
      echo "aether: copied $name into the repo ($why; commit it)"
      ;;
  esac
  # Also when they already matched (first run, or the same change on both
  # sides), quietly: the next run compares against it.
  if ! cmp -s "$mine" "$last" 2>/dev/null; then
    mkdir -p "$state"
    cp "$mine" "$last"
  fi
done
