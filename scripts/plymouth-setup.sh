#!/usr/bin/env bash
# Optional Plymouth setup with an initramfs and bootloader backup.
set -euo pipefail
sudo pacman -S --needed --noconfirm plymouth
sudo cp -a /boot/grub/grub.cfg "/boot/grub/grub.cfg.kajukatli-bak.$(date +%Y%m%d-%H%M%S)"
stamp="$(date +%Y%m%d-%H%M%S)"
sudo cp -a /etc/mkinitcpio.conf "/etc/mkinitcpio.conf.kajukatli-bak.$stamp"
for image in /boot/initramfs-linux*.img; do [ -f "$image" ] && sudo cp -a "$image" "$image.kajukatli-bak.$stamp"; done
# only add plymouth, right after udev / systemd (so before encrypt). every other hook stays
if ! grep -qE '^HOOKS=.*\bplymouth\b' /etc/mkinitcpio.conf; then
    sudo sed -i -E '/^HOOKS=/ s/([( ])(udev|systemd)([ )])/\1\2 plymouth\3/' /etc/mkinitcpio.conf
    grep -qE '^HOOKS=.*\bplymouth\b' /etc/mkinitcpio.conf || { echo "no udev or systemd hook found: add plymouth to HOOKS yourself" >&2; exit 1; }
fi
sudo mkinitcpio -P
