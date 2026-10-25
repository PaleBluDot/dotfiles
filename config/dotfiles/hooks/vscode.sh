#!/usr/bin/env bash
#
# dotfiles hook: vscode. Runs after its package (link, update,
# interactive), and from the Omarchy theme-set hook on every theme change.
# Builds a local VS Code extension, local.dotfiles-themes, with one colour
# theme per repo theme that has no VS Code theme of its own (no vscode.json,
# or one naming this extension), filled from the theme's colors.toml through
# config/theme/templates/vscode-theme.json.tpl. Each theme has its own name
# (Sonic Night, not Omarchy's single "Omarchy"), so a theme change shows in
# VS Code without a window reload, and Settings Sync carries a theme name
# that exists on every machine this runs on.
#
# Packed as a .vsix (a zip) and installed with code --install-extension,
# for VS Code and VS Code Insiders when installed: no marketplace, no vsce.
# The version comes from a hash of everything that goes in, so an editor
# that already has this version is skipped.
#
# Flags from dotfiles: --dry-run, --verbose, --force. Prints nothing when
# there's nothing to do; "next: ..." lines go to dotfiles' Next steps.

set -euo pipefail

dry=false
force=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) dry=true ;;
    --force) force=true ;;
  esac
done

ID="local.dotfiles-themes"
DOTFILES="${DOTFILES:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
THEMES="$DOTFILES/config/omarchy/themes"
TEMPLATE="$DOTFILES/config/theme/templates/vscode-theme.json.tpl"

# ─── editors: "<name>|<command>|<extensions folder>" ─────────────────────
editors=()
for name in code code-insiders; do
  cmd="$(command -v "$name" 2>/dev/null)" || cmd=""
  # macOS: the app's own CLI when "Install 'code' command in PATH" wasn't run.
  if [[ -z $cmd && ${DOTFILES_PLATFORM:-} == mac ]]; then
    app="Visual Studio Code"
    if [[ $name == code-insiders ]]; then app="Visual Studio Code - Insiders"; fi
    cmd="/Applications/$app.app/Contents/Resources/app/bin/$name"
    [[ -x $cmd ]] || cmd=""
  fi
  if [[ -n $cmd ]]; then
    dir="$HOME/.vscode/extensions"
    if [[ $name == code-insiders ]]; then dir="$HOME/.vscode-insiders/extensions"; fi
    editors+=("$name|$cmd|$dir")
  fi
done
# No VS Code here: dotfiles already says so for the vscode tool.
if [[ ${#editors[@]} -eq 0 || ! -f $TEMPLATE ]]; then
  exit 0
fi

# ─── themes ──────────────────────────────────────────────────────────────
# One field from a theme's vscode.json ({"name": "...", "extension": "..."}).
json_field() {
  sed -n 's/.*"'"$1"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$2" | head -n 1
}

slugs=()
labels=()
list=""
for colors in "$THEMES"/*/colors.toml; do
  [[ -f $colors ]] || continue
  theme_dir="${colors%/colors.toml}"
  slug="${theme_dir##*/}"
  if [[ -f $theme_dir/vscode.json ]]; then
    # A theme from the marketplace (Starburst Dark): Omarchy installs that.
    [[ $(json_field extension "$theme_dir/vscode.json") == "$ID" ]] || continue
    label="$(json_field name "$theme_dir/vscode.json")"
  else
    # No vscode.json yet: sonic-night -> Sonic Night.
    label="$(printf '%s\n' "$slug" | awk -F- '{ for (i = 1; i <= NF; i++) $i = toupper(substr($i, 1, 1)) substr($i, 2); print }')"
  fi
  # The label goes into JSON and settings.json as it is.
  if [[ -z $label || $label == *[\"\\]* ]]; then
    echo "vscode: $slug: vscode.json needs a \"name\" without quotes or backslashes" >&2
    exit 1
  fi
  slugs+=("$slug")
  labels+=("$label")
  list="${list:+$list, }$label"
done
if [[ ${#slugs[@]} -eq 0 ]]; then
  exit 0
fi

# ─── version: a hash of the inputs ───────────────────────────────────────
sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | cut -c1-64
  else
    shasum -a 256 | cut -c1-64
  fi
}
sum="$( {
  cat "${BASH_SOURCE[0]}" "$TEMPLATE"
  for ((i = 0; i < ${#slugs[@]}; i++)); do
    printf '%s\n%s\n' "${slugs[i]}" "${labels[i]}"
    cat "$THEMES/${slugs[i]}/colors.toml"
  done
} | sha256)"
# Semver wants a number: the first 7 hex digits (up to 268435455).
VERSION="1.0.$((16#${sum:0:7}))"

# Installed when the folder is there and extensions.json (VS Code's list of
# what it loads) names it; an older build's folder stays behind for a while.
installed() {
  local dir="$1"
  [[ -f $dir/$ID-$VERSION/package.json ]] || return 1
  grep -Eq "\"relativeLocation\"[[:space:]]*:[[:space:]]*\"$ID-$VERSION\"" "$dir/extensions.json" 2>/dev/null
}

todo=()
for entry in "${editors[@]}"; do
  dir="${entry##*|}"
  if [[ $force == true ]] || ! installed "$dir"; then
    todo+=("$entry")
  fi
done
if [[ ${#todo[@]} -eq 0 ]]; then
  exit 0
fi
names=""
for entry in "${todo[@]}"; do
  names="${names:+$names, }${entry%%|*}"
done
if [[ $dry == true ]]; then
  echo "dry run, would build $ID $VERSION ($list) and install it for $names"
  exit 0
fi

# ─── build ───────────────────────────────────────────────────────────────
build="$(mktemp -d)"
trap 'rm -rf "$build"' EXIT
mkdir -p "$build/extension/themes"

# Fills the template from colors.toml: {{ key }}, {{ key_strip }} and
# {{ key_rgb }}, with the defaults Omarchy derives for keys a theme leaves
# out (selection_*, theme_type, purple). The theme's own name replaces
# "Omarchy". awk, not bash: Bash 3.2 (macOS) has no associative arrays.
render() {
  awk -v label="$2" '
    function hexval(s,   i, n) {
      n = 0
      for (i = 1; i <= length(s); i++) n = n * 16 + index("0123456789abcdef", tolower(substr(s, i, 1))) - 1
      return n
    }
    function set(k, v) { if (!(k in c)) { c[k] = v; keys[++nk] = k } }
    FNR == NR {
      if (match($0, /^[a-z_0-9]+[ \t]*=[ \t]*"[^"]*"/)) {
        k = $0; sub(/[ \t]*=.*/, "", k)
        v = $0; sub(/^[^"]*"/, "", v); sub(/".*/, "", v)
        set(k, v)
      }
      next
    }
    FNR == 1 {
      if ("selection" in c) set("selection_background", c["selection"])
      if ("bright_foreground" in c) set("selection_foreground", c["bright_foreground"])
      set("theme_type", ("mode" in c) ? c["mode"] : "dark")
      if ("magenta" in c) set("purple", c["magenta"])
    }
    {
      line = $0
      if (FNR == 2) sub(/"name": "Omarchy"/, "\"name\": \"" label "\"", line)
      if (index(line, "{{") > 0) {
        for (j = 1; j <= nk; j++) {
          k = keys[j]; v = c[k]
          gsub("\\{\\{ " k " \\}\\}", v, line)
          if (v ~ /^#[0-9a-fA-F]{6}$/) {
            gsub("\\{\\{ " k "_strip \\}\\}", substr(v, 2), line)
            gsub("\\{\\{ " k "_rgb \\}\\}", hexval(substr(v, 2, 2)) "," hexval(substr(v, 4, 2)) "," hexval(substr(v, 6, 2)), line)
          }
        }
      }
      print line
    }
  ' "$1" "$TEMPLATE"
}

contributes=""
for ((i = 0; i < ${#slugs[@]}; i++)); do
  slug="${slugs[i]}"
  out="$build/extension/themes/$slug.json"
  render "$THEMES/$slug/colors.toml" "${labels[i]}" >"$out"
  if grep -q '{{' "$out"; then
    echo "vscode: $slug: colors.toml lacks a colour the template uses: $(grep -o '{{ [a-z_0-9]* }}' "$out" | sort -u | tr '\n' ' ')" >&2
    exit 1
  fi
  ui="vs-dark"
  if grep -q '"type": "light"' "$out"; then ui="vs"; fi
  contributes="${contributes:+$contributes,
}            { \"label\": \"${labels[i]}\", \"uiTheme\": \"$ui\", \"path\": \"./themes/$slug.json\" }"
done

cat >"$build/extension/package.json" <<EOF
{
    "name": "dotfiles-themes",
    "displayName": "Dotfiles Themes",
    "description": "Colour themes built from the dotfiles repo's Omarchy themes",
    "publisher": "local",
    "version": "$VERSION",
    "engines": { "vscode": "^1.70.0" },
    "categories": ["Themes"],
    "contributes": {
        "themes": [
$contributes
        ]
    }
}
EOF
# What a .vsix holds besides extension/: the manifest code reads first and
# the zip's content types (Open Packaging Conventions).
cat >"$build/extension.vsixmanifest" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<PackageManifest Version="2.0.0" xmlns="http://schemas.microsoft.com/developer/vsx-schema/2011">
  <Metadata>
    <Identity Language="en-US" Id="dotfiles-themes" Version="$VERSION" Publisher="local" />
    <DisplayName>Dotfiles Themes</DisplayName>
    <Description xml:space="preserve">Colour themes built from the dotfiles repo's Omarchy themes</Description>
    <Categories>Themes</Categories>
    <Properties>
      <Property Id="Microsoft.VisualStudio.Code.Engine" Value="^1.70.0" />
    </Properties>
  </Metadata>
  <Installation>
    <InstallationTarget Id="Microsoft.VisualStudio.Code" />
  </Installation>
  <Dependencies />
  <Assets>
    <Asset Type="Microsoft.VisualStudio.Code.Manifest" Path="extension/package.json" Addressable="true" />
  </Assets>
</PackageManifest>
EOF
cat >"$build/[Content_Types].xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension=".json" ContentType="application/json" /><Default Extension=".vsixmanifest" ContentType="text/xml" /></Types>
EOF

vsix="$build/dotfiles-themes-$VERSION.vsix"
if command -v zip >/dev/null 2>&1; then
  (cd "$build" && zip -qr -X "$vsix" '[Content_Types].xml' extension.vsixmanifest extension)
elif command -v python3 >/dev/null 2>&1; then
  (cd "$build" && python3 -c 'import sys, zipfile; zipfile.main(["-c"] + sys.argv[1:])' "$vsix" '[Content_Types].xml' extension.vsixmanifest extension)
else
  echo "next: install zip (or python3), then run: dotfiles link vscode (builds the VS Code themes)"
  exit 0
fi

# ─── install ─────────────────────────────────────────────────────────────
first=false
for entry in "${todo[@]}"; do
  name="${entry%%|*}"
  cmd="${entry#*|}"
  cmd="${cmd%|*}"
  dir="${entry##*|}"
  if ! ls -d "$dir/$ID"-* >/dev/null 2>&1; then
    first=true
  fi
  # --force: the version is a hash, so a newer build can have a lower one.
  if ! out="$("$cmd" --extensions-dir "$dir" --install-extension "$vsix" --force 2>&1)"; then
    printf '%s\n' "$out" >&2
    echo "vscode: installing $ID in $name failed" >&2
    exit 1
  fi
done
echo "vscode: installed $ID $VERSION ($list) for $names"
if [[ $first == true ]]; then
  echo "next: restart VS Code once so it loads the dotfiles themes (theme changes need no reload after that)"
else
  echo "next: reload VS Code windows to see the changed theme colours"
fi
