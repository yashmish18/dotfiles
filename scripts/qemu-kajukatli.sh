#!/usr/bin/env bash
set -euo pipefail
disk="${1:-kajukatli-test.qcow2}"
iso="${2:-archlinux.iso}"
[ -f "$disk" ] || qemu-img create -f qcow2 "$disk" 40G
exec qemu-system-x86_64 \
    -machine q35,accel=kvm:tcg \
    -cpu host -smp 4 -m 4096 \
    -display gtk -vga virtio \
    -device virtio-net-pci,netdev=net0 \
    -netdev user,id=net0 \
    -cdrom "$iso" -boot d -enable-kvm
