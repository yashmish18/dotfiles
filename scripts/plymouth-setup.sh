#!/usr/bin/env bash
# Optional Plymouth setup with an initramfs and bootloader backup.
set -euo pipefail
sudo pacman -S --needed --noconfirm plymouth
sudo cp -a /boot/grub/grub.cfg "/boot/grub/grub.cfg.kajukatli-bak.$(date +%Y%m%d-%H%M%S)"
stamp="$(date +%Y%m%d-%H%M%S)"
sudo cp -a /etc/mkinitcpio.conf "/etc/mkinitcpio.conf.kajukatli-bak.$stamp"
for image in /boot/initramfs-linux*.img; do [ -f "$image" ] && sudo cp -a "$image" "$image.kajukatli-bak.$stamp"; done
sudo sed -i 's|^HOOKS=.*|HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block filesystems resume fsck plymouth)|' /etc/mkinitcpio.conf
sudo mkinitcpio -P
