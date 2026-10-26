#!/usr/bin/env bash
#
# dotfiles hook: secureboot. Runs after its packages and links (link,
# update, interactive). Sets up Secure Boot the linux-surface way: the
# Microsoft-signed shim starts Limine (copied as grubx64.efi, with an SBAT
# section, signed with our MOK key), and Limine starts kernel images
# signed with the same key. The links put the signing hooks in place; this
# puts the key, shim and the firmware boot entry in place, and signs what
# isn't signed yet.
#
# The MOK key never goes in the repo. It comes from /etc/secureboot-mok
# when it's there, otherwise from the 1Password document "Secure Boot MOK"
# (files MOK.key and MOK.crt, Personal vault). The key has to be enrolled
# in shim once per machine (MokManager); a reinstall keeps it enrolled.
# Secure Boot itself is switched on in the firmware, by hand, last.
#
# Arch with Limine + mkinitcpio only; anywhere else this says so and stops.
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

mok=/etc/secureboot-mok
shim=/usr/share/shim-signed
op_item="op://Personal/Secure Boot MOK"

if [[ ${DOTFILES_PLATFORM:-} != arch ]]; then
  echo "next: secureboot only knows Arch with Limine + mkinitcpio; on ${DOTFILES_PLATFORM:-this platform}, set up shim + MOK by hand (config/secureboot has the Arch pieces to adapt)"
  exit 0
fi

# The EFI partition: wherever Limine is (Omarchy mounts it at /boot).
# /boot is root-only, so look through sudo.
esp=""
for dir in /boot /efi /boot/efi; do
  if sudo test -f "$dir/EFI/limine/limine_x64.efi"; then
    esp="$dir"
    break
  fi
done
if [[ -z $esp ]]; then
  echo "next: secureboot: no Limine on the EFI partition (EFI/limine/limine_x64.efi); this setup needs Limine"
  exit 0
fi
limine="$esp/EFI/limine"

# The key: already here, or from 1Password. Written root-only.
if ! sudo test -r "$mok/MOK.key"; then
  if ! command -v op >/dev/null 2>&1; then
    echo "next: secureboot: no MOK key in $mok; install the 1Password CLI (op), or copy the key there from a backup, then run: dotfiles link secureboot"
    exit 0
  fi
  if [[ $dry == true ]]; then
    echo "dry run, would write $mok/MOK.key and MOK.crt from 1Password ($op_item)"
    exit 0
  fi
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  if ! op read "$op_item/MOK.key" >"$tmp/MOK.key" 2>/dev/null || ! op read "$op_item/MOK.crt" >"$tmp/MOK.crt" 2>/dev/null ||
    [[ ! -s $tmp/MOK.key || ! -s $tmp/MOK.crt ]]; then
    echo "next: secureboot: unlock 1Password (or add the document \"Secure Boot MOK\" to the Personal vault with the files MOK.key and MOK.crt), then run: dotfiles link secureboot"
    exit 0
  fi
  sudo install -d -m 700 -o root -g root "$mok"
  sudo install -m 600 -o root -g root "$tmp/MOK.key" "$mok/MOK.key"
  sudo install -m 644 -o root -g root "$tmp/MOK.crt" "$mok/MOK.crt"
  echo "secureboot: wrote the MOK key to $mok from 1Password (root-only)"
fi

# shim and MokManager next to Limine. shim loads grubx64.efi from its own
# folder; the 40-shim-limine-sync hook makes that from Limine.
for file in shimx64.efi mmx64.efi; do
  if ! sudo cmp -s "$shim/$file" "$limine/$file"; then
    if [[ $dry == true ]]; then
      echo "dry run, would copy $file to $limine"
      continue
    fi
    sudo cp "$shim/$file" "$limine/$file"
    echo "secureboot: copied $file to $limine"
  fi
done
if [[ $dry != true ]]; then
  sudo /etc/boot/hooks/post.d/40-shim-limine-sync
fi

# The firmware entry that starts shim. Disk and partition number from the
# partition mounted at $esp (it changes between installs).
if ! efibootmgr 2>/dev/null | grep -q 'Limine (shim)'; then
  part="$(findmnt -no SOURCE "$esp")"
  disk="/dev/$(lsblk -no PKNAME "$part")"
  num="$(cat "/sys/class/block/${part##*/}/partition")"
  if [[ $dry == true ]]; then
    echo "dry run, would add the firmware boot entry \"Limine (shim)\" ($disk partition $num)"
  else
    sudo efibootmgr --quiet --create --disk "$disk" --part "$num" --label "Limine (shim)" --loader '\EFI\limine\shimx64.efi'
    echo "secureboot: added the firmware boot entry \"Limine (shim)\" (first in the boot order)"
  fi
fi

# Kernel images built before the key was here are unsigned: rebuild them
# (mok-sign signs each one as it's built).
unsigned="$(sudo bash -c 'for f in "$1"/EFI/Linux/*.efi; do [[ -f $f ]] || continue; sbverify --cert "$2/MOK.crt" "$f" >/dev/null 2>&1 || echo "$f"; done' _ "$esp" "$mok")"
if [[ -n $unsigned ]]; then
  if [[ $dry == true ]]; then
    echo "dry run, would rebuild the unsigned kernel images (limine-mkinitcpio)"
  else
    sudo limine-mkinitcpio >/dev/null
    echo "secureboot: rebuilt and signed the kernel images"
  fi
fi

# Enrolled in shim? mokutil compares the DER form of the certificate.
der="$(mktemp)"
sudo openssl x509 -in "$mok/MOK.crt" -outform DER -out /dev/stdout >"$der"
if ! mokutil --test-key "$der" 2>/dev/null | grep -q 'already enrolled'; then
  if mokutil --list-new 2>/dev/null | grep -q 'Omarchy Surface MOK'; then
    echo "next: reboot, then in the blue MokManager screen: Enroll MOK, Continue, Yes, the password you chose"
  else
    echo "next: enroll the MOK key: sudo mokutil --import $mok/MOK.der (after: sudo openssl x509 -in $mok/MOK.crt -outform DER -out $mok/MOK.der), then reboot and enroll it in MokManager"
  fi
fi
rm -f "$der"
if mokutil --list-new 2>/dev/null | grep -q 'CN=linux-surface'; then
  echo "next: reboot, then in the blue MokManager screen enroll the linux-surface key (password: surface)"
fi
if ! mokutil --sb-state 2>/dev/null | grep -q 'SecureBoot enabled'; then
  echo "next: once the MOK keys are enrolled and the machine boots through \"Limine (shim)\": Surface UEFI (Volume Up + Power) > Security > Secure Boot > \"Microsoft & 3rd party CA\""
fi
