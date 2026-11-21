#!/usr/bin/env bash
# kajukatli · installer for arch linux
#
#   ./install.sh              everything, asking before anything that touches the system
#   ./install.sh --yes        everything, no questions (safe defaults)
#   ./install.sh --links      only (re)link the dotfiles
#   ./install.sh --shaders    only recompile the shaders
#   ./install.sh --ai         only (re)build the wallpaper ai environment
#   ./install.sh --no-ai      skip the ai environment (no 3d parallax / outlines)
#
# it is safe to run again: packages use --needed, links are replaced, your own files
# are moved to ~/.local/share/kajukatli/backup/<date>/ before anything is linked over them.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}/kajukatli"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/kajukatli"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/kajukatli"
BIN="$HOME/.local/bin"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$DATA/backup/$STAMP"
LOG="$DATA/install-$STAMP.log"

YES=0; ONLY=""; AI=1
for a in "$@"; do
    case "$a" in
        --yes|-y) YES=1 ;;
        --links) ONLY=links ;;
        --shaders) ONLY=shaders ;;
        --ai) ONLY=ai ;;
        --no-ai) AI=0 ;;
        -h|--help) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "unknown option: $a (try --help)"; exit 2 ;;
    esac
done

# ------------------------------------------------------------------ voice
c_acc=$'\033[38;2;201;183;156m'; c_dim=$'\033[38;2;143;138;128m'; c_bad=$'\033[38;2;181;101;90m'; c_ok=$'\033[38;2;138;154;123m'; c_0=$'\033[0m'
say()  { printf '%s\n' "  ${c_acc}·${c_0} $*"; }
note() { printf '%s\n' "    ${c_dim}$*${c_0}"; }
ok()   { printf '%s\n' "  ${c_ok}✓${c_0} $*"; }
warn() { printf '%s\n' "  ${c_bad}!${c_0} $*"; }
die()  { warn "$*"; exit 1; }
ask()  { # ask "question" default(y/n)
    local q="$1" d="${2:-y}" r
    if [ "$YES" = 1 ]; then [ "$d" = y ]; return; fi
    printf '  %s?%s %s %s ' "$c_acc" "$c_0" "$q" "$([ "$d" = y ] && echo '[Y/n]' || echo '[y/N]')"
    read -r r </dev/tty || r=""
    r="${r:-$d}"
    [[ "$r" =~ ^[Yy] ]]
}

mkdir -p "$DATA" "$STATE" "$CACHE" "$BIN"
exec > >(tee -a "$LOG") 2>&1

# ------------------------------------------------------------------ preflight
preflight() {
    [ -f /etc/arch-release ] || die "this is made for arch linux (no /etc/arch-release here)."
    [ "$(id -u)" -ne 0 ] || die "run it as your normal user, not root. it asks for sudo when it needs it."
    command -v sudo >/dev/null || die "sudo is missing: pacman -S sudo, and add yourself to wheel."
    sudo -v || die "sudo didn't work."
    # keep sudo alive for the duration
    ( while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done ) 2>/dev/null &
    ping -c1 -W3 archlinux.org >/dev/null 2>&1 || warn "no internet? package installs will fail."
}

# ------------------------------------------------------------------ packages
AUR_HELPER=""
find_aur_helper() {
    for h in paru yay; do command -v "$h" >/dev/null && { AUR_HELPER="$h"; return 0; }; done
    return 1
}
bootstrap_aur_helper() {
    ask "some packages are only in the aur. install paru (an aur helper) to get them" y || return 1
    sudo pacman -S --needed --noconfirm base-devel git
    local tmp; tmp="$(mktemp -d)"
    git clone --depth 1 https://aur.archlinux.org/paru-bin.git "$tmp/paru-bin"
    ( cd "$tmp/paru-bin" && makepkg -si --noconfirm )
    rm -rf "$tmp"
    find_aur_helper
}

packages() {
    say "updating the system and installing packages"
    sudo pacman -Syu --noconfirm

    local repo=() aur=()
    while read -r p; do
        [ -z "$p" ] && continue
        # already satisfied — by the package itself or by something that provides it
        # (e.g. tuned-ppd provides power-profiles-daemon; installing both would conflict)
        pacman -T "$p" >/dev/null 2>&1 && continue
        if pacman -Si "$p" >/dev/null 2>&1; then repo+=("$p"); else aur+=("$p"); fi
    done < <(sed -e 's/#.*//' -e 's/[[:space:]]//g' "$REPO/packages/packages.txt")

    # mesa's video decode/encode for the integrated gpu (mpv, mpvpaper, the recorder)
    if grep -q GenuineIntel /proc/cpuinfo; then repo+=(intel-media-driver vulkan-intel); fi
    if grep -q AuthenticAMD /proc/cpuinfo; then repo+=(vulkan-radeon); fi

    if [ "${#repo[@]}" -gt 0 ]; then
        note "${#repo[@]} to install from the official repos"
        sudo pacman -S --needed --noconfirm "${repo[@]}"
    else
        note "everything from the official repos is already here"
    fi

    if [ "${#aur[@]}" -gt 0 ]; then
        note "${#aur[@]} from the aur: ${aur[*]}"
        if find_aur_helper || bootstrap_aur_helper; then
            "$AUR_HELPER" -S --needed --noconfirm "${aur[@]}" || warn "some aur packages failed: ${aur[*]} (the rest still works)"
        else
            warn "skipped aur packages: ${aur[*]}"
        fi
    fi

    # the shell needs quickshell 0.3+ (lua-aware hyprland dispatch)
    local v; v="$(qs --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1 || true)"
    if [ -n "$v" ] && [ "$(printf '%s\n0.3\n' "$v" | sort -V | head -1)" != "0.3" ]; then
        warn "quickshell $v is older than 0.3."
        if find_aur_helper && ask "replace it with quickshell-git from the aur" y; then
            "$AUR_HELPER" -S --noconfirm quickshell-git
        fi
    fi
    ok "packages"
}

# ------------------------------------------------------------------ gpu
gpu() {
    local has_nv=0 has_ig=0
    lspci -nn 2>/dev/null | grep -Ei 'vga|3d|display' | grep -qi '10de:' && has_nv=1
    lspci -nn 2>/dev/null | grep -Ei 'vga|3d|display' | grep -qiE '8086:|1002:' && has_ig=1

    say "graphics: $( [ $has_ig = 1 ] && echo -n "integrated " )$( [ $has_nv = 1 ] && echo -n "nvidia" )"
    sudo install -Dm644 "$REPO/system/udev/61-kajukatli-gpu.rules" /etc/udev/rules.d/61-kajukatli-gpu.rules

    if [ $has_nv = 1 ]; then
        if ! pacman -Qq | grep -qE '^nvidia(-open)?(-dkms)?$|^nvidia-[0-9]+xx'; then
            if ask "install the nvidia driver (nvidia-open; for gtx 10-series and older pick no and install nvidia-580xx-dkms from the aur yourself)" y; then
                local heads=()
                for k in linux linux-lts linux-zen linux-hardened; do pacman -Q "$k" >/dev/null 2>&1 && heads+=("$k-headers"); done
                sudo pacman -S --needed --noconfirm nvidia-open-dkms nvidia-utils "${heads[@]}"
            fi
        fi
        sudo pacman -S --needed --noconfirm nvidia-prime nvidia-utils 2>/dev/null || true
        sudo install -Dm644 "$REPO/system/modprobe/nvidia.conf" /etc/modprobe.d/kajukatli-nvidia.conf
        sudo install -Dm644 "$REPO/system/udev/80-nvidia-pm.rules" /etc/udev/rules.d/80-nvidia-pm.rules
        for s in nvidia-suspend nvidia-hibernate nvidia-resume; do
            systemctl list-unit-files "$s.service" >/dev/null 2>&1 && sudo systemctl enable "$s.service" >/dev/null 2>&1 || true
        done
        note "the nvidia card sleeps unless you run something with: prime-run <app>"
    fi
    sudo udevadm control --reload-rules && sudo udevadm trigger --subsystem-match=drm || true

    # route hyprland to the integrated gpu on hybrid laptops
    local out="$CONFIG/hypr/modules/gpu.lua"
    mkdir -p "$(dirname "$out")"
    [ -L "$out" ] && rm -f "$out"
    {
        echo "-- written by install.sh for this machine. safe to edit; rerunning install.sh rewrites it."
        if [ $has_nv = 1 ] && [ $has_ig = 1 ]; then
            echo "-- hybrid laptop: draw on the integrated gpu so the nvidia card can sleep."
            echo "-- an hdmi port wired to the nvidia card needs it listed too:"
            echo "--   hl.env(\"AQ_DRM_DEVICES\", \"/dev/dri/kk-igpu:/dev/dri/kk-dgpu\")"
            echo "hl.env(\"AQ_DRM_DEVICES\", \"/dev/dri/kk-igpu\")"
        elif [ $has_nv = 1 ]; then
            echo "-- nvidia only"
            echo "hl.env(\"LIBVA_DRIVER_NAME\", \"nvidia\")"
            echo "hl.env(\"__GLX_VENDOR_LIBRARY_NAME\", \"nvidia\")"
            echo "hl.env(\"NVD_BACKEND\", \"direct\")"
            echo "hl.config({ cursor = { no_hardware_cursors = 1 } })"
        else
            echo "-- integrated graphics only: nothing to route."
        fi
    } > "$out"
    ok "gpu"
}

# ------------------------------------------------------------------ links
backup_and_link() { # src dst
    local src="$1" dst="$2"
    if [ -L "$dst" ]; then
        rm -f "$dst"
    elif [ -e "$dst" ]; then
        mkdir -p "$BACKUP/$(dirname "${dst#$HOME/}")"
        mv "$dst" "$BACKUP/${dst#$HOME/}"
        echo "$dst" >> "$BACKUP/.moved"
    fi
    mkdir -p "$(dirname "$dst")"
    ln -s "$src" "$dst"
}

links() {
    say "linking the dotfiles"
    # quickshell: the whole folder, so compiled shaders sit next to the qml that loads them
    backup_and_link "$REPO/config/quickshell/kajukatli" "$CONFIG/quickshell/kajukatli"

    # everything else file by file, so generated files (theme.lua, colors.conf) stay out of git
    local skip_re='/(theme\.lua|gpu\.lua|user\.lua|qt6ct\.conf\.in)$'
    while IFS= read -r -d '' f; do
        local rel="${f#$REPO/config/}"
        [[ "$rel" == quickshell/* ]] && continue
        [[ "/$rel" =~ $skip_re ]] && continue
        backup_and_link "$f" "$CONFIG/$rel"
    done < <(find "$REPO/config" -type f -print0)

    # yours to keep: copied once, never overwritten
    [ -e "$CONFIG/hypr/modules/user.lua" ] || install -Dm644 "$REPO/config/hypr/modules/user.lua" "$CONFIG/hypr/modules/user.lua"
    [ -e "$CONFIG/hypr/modules/gpu.lua" ]  || install -Dm644 "$REPO/config/hypr/modules/gpu.lua"  "$CONFIG/hypr/modules/gpu.lua"
    # regenerated by kk-theme
    [ -e "$CONFIG/hypr/modules/theme.lua" ] && [ ! -L "$CONFIG/hypr/modules/theme.lua" ] || \
        { rm -f "$CONFIG/hypr/modules/theme.lua"; install -Dm644 "$REPO/config/hypr/modules/theme.lua" "$CONFIG/hypr/modules/theme.lua"; }
    sed "s|@CONFIG@|$CONFIG|g" "$REPO/config/qt6ct/qt6ct.conf.in" > "$CONFIG/qt6ct/qt6ct.conf"

    # scripts
    for f in "$REPO"/bin/*; do backup_and_link "$f" "$BIN/$(basename "$f")"; chmod +x "$f"; done
    sudo install -Dm755 "$REPO/system/bin/kk-session" /usr/local/bin/kk-session

    # shell extras into bash / zsh
    local line="[ -f \"$CONFIG/shell/kajukatli.sh\" ] && . \"$CONFIG/shell/kajukatli.sh\""
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        [ -f "$rc" ] || { [ "$rc" = "$HOME/.bashrc" ] && touch "$rc" || continue; }
        grep -qF "shell/kajukatli.sh" "$rc" || printf '\n# kajukatli\n%s\n' "$line" >> "$rc"
    done

    [ -f "$BACKUP/.moved" ] && note "your old files are in $BACKUP"
    ok "links"
}

# ------------------------------------------------------------------ shaders
shaders() {
    say "compiling shaders"
    local qsb=""
    for c in /usr/lib/qt6/bin/qsb "$(command -v qsb 2>/dev/null || true)"; do [ -n "$c" ] && [ -x "$c" ] && { qsb="$c"; break; }; done
    [ -n "$qsb" ] || die "qsb not found (pacman -S qt6-shadertools)"
    local dir="$REPO/config/quickshell/kajukatli/shaders"
    for f in "$dir"/*.frag; do
        "$qsb" --glsl "100 es,120,150" --hlsl 50 --msl 12 -o "$f.qsb" "$f" || die "shader $(basename "$f") failed to compile"
        note "$(basename "$f")"
    done
    ok "shaders"
}

# ------------------------------------------------------------------ ai
ai_env() {
    say "building the wallpaper ai (depth for 3d parallax, subject outlines). about 1 gb on disk."
    local py="$DATA/venv/bin/python"
    [ -x "$py" ] || python3 -m venv "$DATA/venv"
    "$py" -m pip install --quiet --upgrade pip
    "$py" -m pip install --quiet "rembg[cpu]" onnxruntime opencv-python-headless pillow numpy
    if lspci 2>/dev/null | grep -qi nvidia && ask "also install cuda onnxruntime (faster prep on the nvidia gpu, +2 gb)" n; then
        "$py" -m pip install --quiet onnxruntime-gpu && note "run kk-prep with KK_PREP_GPU=1 prime-run … to use it"
    fi
    if ask "download the models now (~300 mb) instead of on the first wallpaper" y; then
        "$py" - <<'PY' || warn "model download failed; it'll retry on the first wallpaper"
from rembg import new_session
for m in ("birefnet-general-lite", "isnet-anime"):
    print("    model:", m, flush=True)
    new_session(m)
PY
        local depth="$DATA/models/depth-anything-v2-small.onnx"
        mkdir -p "$DATA/models"
        if [ ! -s "$depth" ]; then
            if curl -fL --progress-bar -o "$depth.part" "https://huggingface.co/onnx-community/depth-anything-v2-small/resolve/main/onnx/model.onnx"; then
                mv "$depth.part" "$depth"
            else
                rm -f "$depth.part"
                warn "depth model download failed; it'll retry on the first wallpaper"
            fi
        fi
    fi
    ok "wallpaper ai"
}

# ------------------------------------------------------------------ services
services() {
    say "system services"
    # networkmanager doesn't share the wifi card nicely with these
    for other in iwd systemd-networkd dhcpcd netctl; do
        if systemctl is-enabled "$other" >/dev/null 2>&1; then
            ask "$other is enabled and will fight networkmanager. disable it" y && sudo systemctl disable --now "$other" || true
        fi
    done
    sudo systemctl enable --now NetworkManager bluetooth
    # power profiles: tuned-ppd and power-profiles-daemon speak the same d-bus api; use whichever is here
    if pacman -Qq tuned-ppd >/dev/null 2>&1; then
        sudo systemctl enable --now tuned tuned-ppd
    else
        sudo systemctl enable --now power-profiles-daemon
    fi
    systemctl --user enable --now pipewire pipewire-pulse wireplumber 2>/dev/null || true

    # login screen
    local dm
    dm="$(basename "$(readlink -f /etc/systemd/system/display-manager.service 2>/dev/null)" 2>/dev/null || true)"
    if [ "$dm" = "greetd.service" ]; then
        note "greetd already set up"
    elif ask "use greetd + tuigreet as the login screen$([ -n "$dm" ] && [ "$dm" != "display-manager.service" ] && echo " (replaces $dm)")" y; then
        [ -f /etc/greetd/config.toml ] && sudo cp /etc/greetd/config.toml "/etc/greetd/config.toml.kk-backup-$STAMP"
        sudo install -Dm644 "$REPO/system/greetd/config.toml" /etc/greetd/config.toml
        [ -n "$dm" ] && [ "$dm" != "display-manager.service" ] && sudo systemctl disable "$dm" || true
        sudo systemctl enable greetd.service
    fi
    ok "services"
}

# ------------------------------------------------------------------ defaults
defaults() {
    say "first-run defaults"
    xdg-user-dirs-update 2>/dev/null || true
    mkdir -p "$HOME/Pictures/wallpapers" "$HOME/Pictures/screenshots" "$HOME/Videos/recordings" "$CONFIG/kajukatli"
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Classic' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface font-name 'IBM Plex Sans 10' 2>/dev/null || true
    # a default accent until the first wallpaper decides one
    [ -f "$CACHE/theme.json" ] || "$BIN/kk-theme" '#c9b79c' || true
    fc-cache -f >/dev/null 2>&1 || true
    ok "defaults"
}

# ------------------------------------------------------------------ run
echo
echo "  ${c_acc}kajukatli${c_0}  ${c_dim}· a desktop in black & white, for arch + hyprland${c_0}"
echo "  ${c_dim}log: $LOG${c_0}"
echo

case "$ONLY" in
    links)   links; exit 0 ;;
    shaders) shaders; exit 0 ;;
    ai)      ai_env; exit 0 ;;
esac

preflight
packages
gpu
links
shaders
[ "$AI" = 1 ] && ai_env || note "skipped the wallpaper ai (--no-ai). wallpapers still ink-fade, just without 3d and outlines."
services
defaults

echo
ok "done."
note "reboot, log in from the greeter, then:"
note "  super + w        pick a wallpaper (put some in ~/Pictures/wallpapers first)"
note "  super + space    launcher          super + a   control center"
note "  super + /        every key         kk-doctor   checks everything"
echo
