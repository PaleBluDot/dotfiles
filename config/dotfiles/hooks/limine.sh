#!/usr/bin/env bash
#
# dotfiles hook: limine. Runs after its package and links (link, update,
# interactive). The links put the menu style hook (50-omarchy-limine-style)
# and its .path watcher in place; this sets up what they need and can't be
# a copied file, because /etc/default/limine and /boot/limine.conf hold this
# machine's disk IDs:
#
#   - /etc/default/limine: TARGET_OS_NAME="Advanced options", so the name
#     "Omarchy" is free for the style hook's own entry, and BOOT_ORDER
#     starting with linux-surface when that kernel is installed (the
#     Surface's touch and pen need it). Backed up once to .pre-advanced.
#   - /boot/limine.conf: limine-entry-tool finds its menu entry by the
#     machine-id line inside it, not by name, so a new TARGET_OS_NAME only
#     names entries it creates from now on. The entry the installer made is
#     renamed once here. Backed up once to .pre-advanced.
#
# Then runs the style hook (through its service, so it never runs twice at
# the same time as the .path watcher).
#
# Arch with Limine + limine-entry-tool (Omarchy) only; anywhere else this
# does nothing.
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

target="Advanced options"
defaults=/etc/default/limine
menu=/boot/limine.conf

[[ ${DOTFILES_PLATFORM:-} == arch && -f $defaults ]] || exit 0

# /etc/default/limine: the wanted file, written only when it differs.
want="$(mktemp)"
trap 'rm -f "$want"' EXIT
surface=false
if pacman -Q linux-surface >/dev/null 2>&1; then
  surface=true
fi
awk -v target="$target" -v surface="$surface" '
  /^TARGET_OS_NAME=/ { next }
  /^BOOT_ORDER="/ && surface == "true" && $0 !~ /^BOOT_ORDER="linux-surface[,"]/ {
    sub(/^BOOT_ORDER="/, "BOOT_ORDER=\"linux-surface, ")
  }
  { print }
  END { printf "TARGET_OS_NAME=\"%s\"\n", target }
' "$defaults" >"$want"
defaults_changed=false
if ! cmp -s "$want" "$defaults"; then
  if [[ $dry == true ]]; then
    echo "dry run, would update $defaults (TARGET_OS_NAME=\"$target\", linux-surface first in BOOT_ORDER)"
  else
    [[ -f $defaults.pre-advanced ]] || sudo cp -p "$defaults" "$defaults.pre-advanced"
    sudo install -m 644 -o root -g root "$want" "$defaults"
    echo "limine: updated $defaults (TARGET_OS_NAME=\"$target\", linux-surface first in BOOT_ORDER)"
    defaults_changed=true
  fi
fi

# /boot is root-only: everything below goes through sudo. A dry run never
# asks for a password: without a cached sudo it only says what it'd check.
sudo_q=(sudo)
if [[ $dry == true ]]; then
  sudo_q=(sudo -n)
  if ! sudo -n true 2>/dev/null; then
    echo "dry run, would check the boot menu entry name in $menu (needs sudo)"
    exit 0
  fi
fi
"${sudo_q[@]}" test -f "$menu" || exit 0

# Rename the generated entry (the top-level entry holding this machine's
# machine-id line) to $target, keeping its "+" (expanded) mark. Prints the
# old name when it renamed, nothing when there was nothing to do.
rename_entry() {
  "${sudo_q[@]}" python3 -I - "$menu" "$target" "$(cat /etc/machine-id)" "$1" <<'EOF'
import os, re, sys
conf, target, mid, dry = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4] == "true"
lines = open(conf).read().split("\n")
top = re.compile(r"^/(?!/)(\+?)(.*)$")
names = [(i, m.group(1), m.group(2).strip()) for i, l in enumerate(lines) if (m := top.match(l))]
if any(n == target for _, _, n in names):
    sys.exit(0)
for k, (i, plus, name) in enumerate(names):
    end = names[k + 1][0] if k + 1 < len(names) else len(lines)
    if any("machine-id=" + mid in l for l in lines[i:end]):
        print(name)
        if not dry:
            if not os.path.exists(conf + ".pre-advanced"):
                with open(conf + ".pre-advanced", "w") as f:
                    f.write("\n".join(lines))
            lines[i] = "/" + plus + target
            tmp = conf + ".rename-tmp"
            with open(tmp, "w") as f:
                f.write("\n".join(lines))
                f.flush()
                os.fsync(f.fileno())
            os.replace(tmp, conf)
        break
EOF
}

old="$(rename_entry "$dry")"
if [[ -n $old ]]; then
  if [[ $dry == true ]]; then
    echo "dry run, would rename the boot menu entry \"$old\" to \"$target\" in $menu"
  else
    echo "limine: renamed the boot menu entry \"$old\" to \"$target\""
  fi
fi

[[ $dry == true ]] && exit 0

# A new BOOT_ORDER only reaches the menu when limine-update rewrites it
# (it also rebuilds the kernel images: a minute or two).
if [[ $defaults_changed == true ]]; then
  sudo limine-update >/dev/null
  echo "limine: rebuilt the boot menu (limine-update)"
fi

# Reshape the menu now. systemctl waits for the oneshot, and joins it when
# the .path watcher already started it.
if [[ -n $old || $defaults_changed == true ]]; then
  if ! sudo systemctl start omarchy-limine-style.service; then
    echo "next: the boot menu style hook failed: journalctl -u omarchy-limine-style.service"
  fi
fi
