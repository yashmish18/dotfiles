#!/usr/bin/env bash
# Remove Kajukatli links and restore backed-up configuration.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}/kajukatli"
DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        -h|--help) echo "usage: ./uninstall.sh [--dry-run]"; exit 0 ;;
        *) echo "unknown option: $arg"; exit 2 ;;
    esac
done

echo "  removing links into $REPO"
while IFS= read -r link; do
    target="$(readlink "$link" 2>/dev/null || true)"
    case "$target" in
        "$REPO"|"$REPO"/*)
            if [ "$DRY_RUN" = 1 ]; then echo "    would remove ${link#$HOME/}"; else rm -f "$link"; echo "    - ${link#$HOME/}"; fi
            ;;
    esac
done < <(find "$CONFIG" "$HOME/.local/bin" -maxdepth 4 -type l 2>/dev/null)

latest="$(ls -1d "$DATA"/backup/*/ 2>/dev/null | tail -n1 || true)"
if [ -n "$latest" ] && [ -f "$latest/.moved" ]; then
    echo "  restoring your files from $latest"
    while IFS= read -r dst; do
        src="$latest/${dst#$HOME/}"
        if [ -e "$src" ] && [ ! -e "$dst" ]; then
            if [ "$DRY_RUN" = 1 ]; then echo "    would restore ${dst#$HOME/}"; else mkdir -p "$(dirname "$dst")"; mv "$src" "$dst"; echo "    + ${dst#$HOME/}"; fi
        fi
    done <"$latest/.moved"
fi

if [ "$DRY_RUN" = 0 ]; then
    rm -rf "$CONFIG/kajukatli"
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        [ -f "$rc" ] && sed -i '/# kajukatli/d;/shell\/kajukatli.sh/d' "$rc"
    done
fi

packages="$(cat "$REPO/packages/core.txt" "$REPO"/packages/extras/*.txt 2>/dev/null |
    sed -e 's/#.*//' -e 's/[[:space:]]//g' | grep -v '^$' | sort -u)"
echo
echo "  package list used by Kajukatli:"
printf '%s\n' "$packages" | sed 's/^/    /'
echo
echo "  left in place on purpose:"
echo "    review and remove packages with: sudo pacman -Rns <packages>"
echo "    login screen: sudo systemctl disable greetd"
echo "    system files: /etc/kajukatli, /etc/udev/rules.d/*kajukatli*,"
echo "                  /etc/modprobe.d/kajukatli-*.conf, /etc/systemd/journald.conf.d/kajukatli.conf"
