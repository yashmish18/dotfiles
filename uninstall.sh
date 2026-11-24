#!/usr/bin/env bash
# kajukatli · uninstall
#
#   ./uninstall.sh              take kajukatli out of your home: links, scripts, fonts, shell
#                               lines; your own files that were moved aside come back
#   ./uninstall.sh --all        everything, back to the arch you had before: also the system
#                               files (restored from the copies install.sh kept), the login
#                               screen, your login shell, the packages kajukatli added, the
#                               grub theme, caches and kajukatli's settings
#   ./uninstall.sh --dry-run    (with or without --all) say what would happen, change nothing
#   ./uninstall.sh --yes        don't ask (with --all: removes the packages without asking)
#
# your files are never touched: pictures (wallpapers included), documents, screenshots.
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}/kajukatli"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/kajukatli"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/kajukatli"
FONTS="${XDG_DATA_HOME:-$HOME/.local/share}/fonts/kajukatli"
BASE="$DATA/baseline"
DRY_RUN=0; ALL=0; YES=0
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        --all|--purge) ALL=1 ;;
        --yes|-y) YES=1 ;;
        -h|--help) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "unknown option: $arg (try --help)"; exit 2 ;;
    esac
done

say()  { printf '  \033[1m●\033[0m %s\n' "$*"; }
note() { printf '    %s\n' "$*"; }
do_() { # run it, or say it in a dry run
    if [ "$DRY_RUN" = 1 ]; then printf '    would: %s\n' "$*"; else "$@"; fi
}
ask() {
    [ "$YES" = 1 ] && return 0
    [ "$DRY_RUN" = 1 ] && return 0
    local r; printf '  ? %s [y/N] ' "$1"; read -r r </dev/tty || r=""
    [[ "$r" =~ ^[Yy] ]]
}

[ "$DRY_RUN" = 1 ] && say "dry run: nothing changes"
if [ "$ALL" = 1 ] && [ "$DRY_RUN" = 0 ]; then
    echo
    echo "  this takes kajukatli off this computer completely and puts back what was there before."
    ask "go ahead" || exit 1
    sudo -v || { echo "  needs sudo for the system part"; exit 1; }
fi

# ------------------------------------------------------------------ the session
if [ "$DRY_RUN" = 0 ]; then
    pkill -x qs 2>/dev/null; pkill -f 'quickshell.*kajukatli' 2>/dev/null; true
fi

# ------------------------------------------------------------------ links into the repo
say "links into $REPO"
while IFS= read -r link; do
    target="$(readlink "$link" 2>/dev/null || true)"
    case "$target" in
        "$REPO"|"$REPO"/*) do_ rm -f "$link"; [ "$DRY_RUN" = 1 ] || note "- ${link#$HOME/}" ;;
    esac
done < <(find "$CONFIG" "$HOME/.local/bin" -maxdepth 5 -type l 2>/dev/null)

# files install.sh copied (not linked)
for f in "$CONFIG/hypr/modules/theme.lua" "$CONFIG/hypr/modules/gpu.lua" "$CONFIG/qt6ct/qt6ct.conf" \
         "$HOME/.local/share/applications/kk-photobooth.desktop"; do
    [ -e "$f" ] && do_ rm -f "$f"
done
for f in "$HOME/.local/share/nautilus/scripts/Open terminal here" "$HOME/.local/share/nautilus/scripts/Send to phone" \
         "$HOME/.local/share/nautilus/scripts/Disks, storage and clean-up" "$HOME/.local/share/nautilus/scripts/Edit as administrator"; do
    [ -e "$f" ] && do_ rm -f "$f"
done
# user.lua is yours: kept unless everything goes
[ "$ALL" = 1 ] && [ -e "$CONFIG/hypr/modules/user.lua" ] && do_ rm -f "$CONFIG/hypr/modules/user.lua"
# generated colours (gtk, kitty, qt) carry kajukatli's mark: only those go
for f in "$CONFIG/gtk-3.0/gtk.css" "$CONFIG/gtk-4.0/gtk.css" "$CONFIG/kitty/colors.conf" "$CONFIG/qt6ct/colors/kajukatli.conf"; do
    [ -f "$f" ] && grep -q "kajukatli" "$f" 2>/dev/null && do_ rm -f "$f"
done

# ------------------------------------------------------------------ your files that were moved aside
say "your earlier config files"
restored=0
for b in $(ls -1d "$DATA"/backup/*/ 2>/dev/null | sort); do
    [ -f "$b/.moved" ] || continue
    while IFS= read -r dst; do
        src="$b/${dst#$HOME/}"
        [ -e "$src" ] || continue
        [ -L "$dst" ] && do_ rm -f "$dst"
        if [ ! -e "$dst" ] || [ "$DRY_RUN" = 1 ]; then
            do_ mkdir -p "$(dirname "$dst")"
            do_ cp -a "$src" "$dst"
            restored=$((restored + 1))
            [ "$DRY_RUN" = 1 ] || note "+ ${dst#$HOME/}"
        fi
    done <"$b/.moved"
done
[ "$restored" = 0 ] && note "(none were moved)"

# ------------------------------------------------------------------ shell rc lines, fonts
say "shell setup and fonts"
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    [ -f "$rc" ] && grep -q "kajukatli" "$rc" && do_ sed -i '/# kajukatli/d;/shell\/kajukatli.sh/d' "$rc"
done
[ -d "$FONTS" ] && do_ rm -rf "$FONTS" && { [ "$DRY_RUN" = 1 ] || fc-cache -f >/dev/null 2>&1 || true; }

if [ "$ALL" = 0 ]; then
    do_ rm -rf "$CONFIG/kajukatli" "$CACHE"
    echo
    say "done. kept on purpose:"
    note "packages, the login screen and system files (./uninstall.sh --all puts all of that back)"
    note "kajukatli's history and backups: $DATA"
    exit 0
fi

# ================================================================== --all: the system too
# ------------------------------------------------------------------ system files
say "system files"
known_new=(
    /etc/udev/rules.d/61-kajukatli-gpu.rules /etc/udev/rules.d/62-kajukatli-battery.rules
    /etc/udev/rules.d/63-kajukatli-pci-pm.rules /etc/udev/rules.d/80-nvidia-pm.rules
    /etc/modprobe.d/kajukatli-nvidia.conf /etc/modprobe.d/kajukatli-power.conf
    /etc/sysctl.d/90-kajukatli-power.conf /etc/NetworkManager/conf.d/30-kajukatli-wifi-powersave.conf
    /etc/NetworkManager/conf.d/20-connectivity.conf /etc/systemd/journald.conf.d/kajukatli.conf
    /usr/local/bin/kk-session /boot/grub/themes/kajukatli /etc/systemd/coredump.conf.d/kajukatli.conf
)
declare -A handled=()
if [ -f "$BASE/system-files.tsv" ]; then
    while IFS=$'\t' read -r how f; do
        [ -n "$f" ] || continue
        handled["$f"]=1
        key="$(printf '%s' "$f" | sed 's|/|%|g')"
        if [ "$how" = existed ] && [ -e "$BASE/files/$key" ]; then
            do_ sudo rm -rf "$f"
            do_ sudo cp -a "$BASE/files/$key" "$f"
            [ "$DRY_RUN" = 1 ] || note "restored $f"
        elif [ "$how" = new ]; then
            do_ sudo rm -rf "$f"
            [ "$DRY_RUN" = 1 ] || note "removed $f"
        fi
    done <"$BASE/system-files.tsv"
else
    note "(no record from install.sh: an install from before it kept one. removing the known files.)"
fi
for f in "${known_new[@]}"; do
    [ -n "${handled[$f]:-}" ] && continue
    sudo test -e "$f" && { do_ sudo rm -rf "$f"; [ "$DRY_RUN" = 1 ] || note "removed $f"; }
done
# older installs kept their own copies next to the file
[ -f /etc/default/grub.kajukatli-backup ] && [ -z "${handled[/etc/default/grub]:-}" ] && do_ sudo cp /etc/default/grub.kajukatli-backup /etc/default/grub
latest_greetd="$(ls -1t /etc/greetd/config.toml.kk-backup-* 2>/dev/null | head -n1 || true)"
[ -n "$latest_greetd" ] && [ -z "${handled[/etc/greetd/config.toml]:-}" ] && do_ sudo cp "$latest_greetd" /etc/greetd/config.toml

# grub: the theme line goes with the theme
if [ -f /etc/default/grub ] && grep -q 'themes/kajukatli' /etc/default/grub; then
    do_ sudo sed -i -E '/^GRUB_THEME=.*kajukatli/d' /etc/default/grub
fi
if command -v grub-mkconfig >/dev/null && [ -f /boot/grub/grub.cfg ]; then
    do_ sudo grub-mkconfig -o /boot/grub/grub.cfg
fi
do_ sudo udevadm control --reload-rules
do_ sudo sysctl --system

# ------------------------------------------------------------------ login screen and shell
say "login screen and shell"
was_dm="$(cat "$BASE/display-manager-replaced" 2>/dev/null || true)"
[ -n "$was_dm" ] || was_dm="$(cat "$BASE/display-manager" 2>/dev/null || true)"
now_dm="$(basename "$(readlink -f /etc/systemd/system/display-manager.service 2>/dev/null)" 2>/dev/null || true)"
if [ "$now_dm" = greetd.service ] && [ "$was_dm" != greetd.service ]; then
    do_ sudo systemctl disable greetd.service
    if [ -n "$was_dm" ] && [ "$was_dm" != "display-manager.service" ]; then
        do_ sudo systemctl enable "$was_dm"
        note "login screen: $was_dm again"
    else
        note "login screen: the text console again (there was none before)"
    fi
fi
was_shell="$(cat "$BASE/shell" 2>/dev/null || true)"
now_shell="$(getent passwd "$USER" | cut -d: -f7)"
if [ -n "$was_shell" ] && [ "$was_shell" != "$now_shell" ] && [ -x "$was_shell" ]; then
    do_ sudo chsh -s "$was_shell" "$USER"
    note "login shell: $was_shell"
fi

# ------------------------------------------------------------------ packages
say "packages"
if [ -f "$BASE/packages-explicit.txt" ]; then
    # installed explicitly since kajukatli, and on one of kajukatli's lists (or its gpu drivers /
    # aur helper): those go. anything else you installed yourself since stays.
    ours="$(cat "$REPO/packages/core.txt" "$REPO"/packages/extras/*.txt 2>/dev/null | sed -e 's/#.*//' -e 's/[[:space:]]//g' | grep -v '^$'
            printf '%s\n' intel-media-driver vulkan-intel vulkan-radeon nvidia-open-dkms nvidia-prime paru-bin paru quickshell-git)"
    mapfile -t remove < <(comm -23 <(pacman -Qqe | sort -u) <(sort -u "$BASE/packages-explicit.txt") | grep -Fxf <(printf '%s\n' "$ours" | sort -u) || true)
    if [ "${#remove[@]}" -gt 0 ]; then
        note "${#remove[@]} packages kajukatli added: ${remove[*]}"
        if ask "remove them (and whatever they pulled in that nothing else needs)"; then
            do_ sudo pacman -Rns --noconfirm "${remove[@]}" || note "some couldn't go (something else needs them); the rest did"
        fi
    else
        note "nothing to remove"
    fi
else
    note "no record of the packages from before kajukatli. the ones it lists:"
    cat "$REPO/packages/core.txt" "$REPO"/packages/extras/*.txt 2>/dev/null | sed -e 's/#.*//' -e 's/[[:space:]]//g' | grep -v '^$' | sort -u | tr '\n' ' ' | fold -s -w 90 | sed 's/^/      /'
    echo
    note "remove what you don't want with: sudo pacman -Rns <names>"
fi

# ------------------------------------------------------------------ what kajukatli kept for itself
say "kajukatli's own settings, caches and records"
do_ rm -rf "$CONFIG/kajukatli" "$STATE" "$CACHE" "$CONFIG/quickshell/kajukatli" "$CONFIG/quickshell/kk-photobooth"
# the wallpaper ai's python environment lives with the data
do_ rm -rf "$DATA"
for d in paintings anime generated; do
    [ -d "$HOME/Pictures/wallpapers/$d" ] && note "kept your wallpapers in ~/Pictures/wallpapers/$d (delete them yourself if you like)"
done

echo
say "done. reboot to come up in the arch you had before."
