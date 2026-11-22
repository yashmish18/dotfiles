#!/usr/bin/env bash
# kajukatli · installer for arch linux
#
#   ./install.sh                  essentials, then a menu of extras to pick from
#   ./install.sh --yes            essentials + the recommended extras, no questions
#   ./install.sh --minimal        essentials only (no extras, no ai)
#   ./install.sh --extras=3,5,10  essentials + exactly these extras (numbers from the menu)
#   ./install.sh --links          only (re)link the dotfiles
#   ./install.sh --shaders        only recompile the shaders
#   ./install.sh --fonts          only (re)download the typefaces
#   ./install.sh --walls          only download the wallpaper pack
#   ./install.sh --ai             only (re)build the wallpaper ai
#   ./install.sh --dry-run        print the actions; change nothing
#   ./install.sh --update         git-pull only after local-change checks
#   ./install.sh --snapshot       back up kajukatli's settings and state (kk-personal-backup: your files)
#   ./install.sh --restore        restore the latest Kajukatli snapshot
#
# safe to run again: packages use --needed, links are replaced, and your own files are
# moved to ~/.local/share/kajukatli/backup/<date>/ before anything is linked over them.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}/kajukatli"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/kajukatli"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/kajukatli"
FONTS="${XDG_DATA_HOME:-$HOME/.local/share}/fonts/kajukatli"
BIN="$HOME/.local/bin"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$DATA/backup/$STAMP"
LOG="$DATA/install-$STAMP.log"

YES=0; ONLY=""; MINIMAL=0; EXTRAS_ARG=""
DRY_RUN=0; MODE=install
for a in "$@"; do
    case "$a" in
        --yes|-y) YES=1 ;;
        --minimal) MINIMAL=1; YES=1 ;;
        --extras=*) EXTRAS_ARG="${a#--extras=}" ;;
        --links) ONLY=links ;;
        --shaders) ONLY=shaders ;;
        --fonts) ONLY=fonts ;;
        --walls) ONLY=walls ;;
        --ai) ONLY=ai ;;
        --grub) ONLY=grub ;;
        --savings) ONLY=savings ;;
        --dry-run) DRY_RUN=1 ;;
        --update) MODE=update ;;
        --snapshot) MODE=snapshot ;;
        --restore) MODE=restore ;;
        --no-ai) EXTRAS_ARG="${EXTRAS_ARG:-default}"; NO_AI=1 ;;
        -h|--help) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "unknown option: $a (try --help)"; exit 2 ;;
    esac
done
NO_AI="${NO_AI:-0}"

LEDGER="$DATA/transactions.jsonl"
mkdir -p "$DATA"
ledger_record() {
    printf '%s\n' "$1" >>"$LEDGER"
}
# kajukatli's own state: settings, your hypr overrides, the shell's memory. personal files
# and keys are kk-personal-backup's job (encrypted, and best on another drive).
snapshot() {
    local out="$DATA/snapshot-$STAMP.tar.gz" p have=()
    for p in .config/kajukatli .config/hypr/modules/user.lua .config/hypr/modules/gpu.lua              .local/state/kajukatli .local/share/kajukatli/transactions.jsonl .local/share/kajukatli/ai.conf; do
        [ -e "$HOME/$p" ] && have+=("$p")
    done
    (umask 077; tar -C "$HOME" -czf "$out" "${have[@]}")
    echo "$out"
}

# ------------------------------------------------------------------ voice
c_acc=$'\033[38;2;233;192;139m'; c_dim=$'\033[38;2;143;138;128m'; c_bad=$'\033[38;2;226;112;100m'; c_ok=$'\033[38;2;150;200;140m'; c_b=$'\033[1m'; c_0=$'\033[0m'
say()  { printf '%s\n' "  ${c_acc}●${c_0} ${c_b}$*${c_0}"; }
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

case "$MODE" in
    update)
        if [ ! -d "$REPO/.git" ] || ! command -v git >/dev/null; then die "git checkout required for --update"; fi
        git -C "$REPO" config core.fileMode false 2>/dev/null || true
        branch="$(git -C "$REPO" branch --show-current 2>/dev/null || true)"
        [ -n "$branch" ] || die "cannot update a detached checkout"
        [ -z "$(git -C "$REPO" status --porcelain 2>/dev/null)" ] || die "local changes found; commit, stash, or restore them before --update"
        git -C "$REPO" fetch --prune origin
        git -C "$REPO" pull --ff-only origin "$branch"
        exit $?
        ;;
    snapshot)
        file="$(snapshot)"
        ledger_record "{\"type\":\"snapshot\",\"path\":\"$file\",\"time\":\"$(date -Iseconds)\"}"
        ok "snapshot: $file"
        exit 0
        ;;
    restore)
        latest="$(ls -1t "$DATA"/snapshot-*.tar.gz 2>/dev/null | head -n1 || true)"
        [ -n "$latest" ] || die "no Kajukatli snapshot found"
        tar -xzf "$latest" -C "$HOME"
        ok "restored snapshot: $latest"
        exit 0
        ;;
esac

mkdir -p "$DATA" "$STATE" "$CACHE" "$BIN"
exec > >(tee -a "$LOG") 2>&1

# ------------------------------------------------------------------ preflight
preflight() {
    if [ "$DRY_RUN" = 1 ]; then
        say "dry run: no system or user changes"
        return 0
    fi
    [ -f /etc/arch-release ] || die "this is made for arch linux (no /etc/arch-release here)."
    [ "$(id -u)" -ne 0 ] || die "run it as your normal user, not root. it asks for sudo when it needs it."
    command -v sudo >/dev/null || die "sudo is missing: pacman -S sudo, and add yourself to wheel."
    sudo -v || die "sudo didn't work."
    # keep sudo alive for the duration
    ( while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done ) 2>/dev/null &
    ping -c1 -W3 archlinux.org >/dev/null 2>&1 || warn "no internet? package installs will fail."
}

# ------------------------------------------------------------------ extras
EXTRA_FILES=()
EXTRA_ON=()
load_extras() {
    local f
    while IFS= read -r f; do
        EXTRA_FILES+=("$f")
        if grep -q '^# default: on' "$f"; then EXTRA_ON+=(1); else EXTRA_ON+=(0); fi
    done < <(ls "$REPO"/packages/extras/*.txt | sort -t/ -k1 -V)
}
extra_name() { basename "$1" .txt | sed 's/^[0-9]*-//'; }
extra_desc() { sed -n '1s/^# //p' "$1"; }
extra_chosen() { # extra_chosen <name>
    local i
    for i in "${!EXTRA_FILES[@]}"; do
        [ "$(extra_name "${EXTRA_FILES[$i]}")" = "$1" ] && { [ "${EXTRA_ON[$i]}" = 1 ]; return; }
    done
    return 1
}

choose_extras() {
    load_extras
    local i n
    if [ "$MINIMAL" = 1 ]; then
        for i in "${!EXTRA_ON[@]}"; do EXTRA_ON[$i]=0; done
    elif [ -n "$EXTRAS_ARG" ] && [ "$EXTRAS_ARG" != default ]; then
        for i in "${!EXTRA_ON[@]}"; do EXTRA_ON[$i]=0; done
        IFS=',' read -ra picks <<< "$EXTRAS_ARG"
        for n in "${picks[@]}"; do [ "$n" -ge 1 ] 2>/dev/null && [ "$n" -le "${#EXTRA_FILES[@]}" ] && EXTRA_ON[$((n-1))]=1 || true; done
    elif [ "$YES" != 1 ]; then
        while true; do
            echo
            say "extras · type numbers to switch them on/off, enter when done"
            for i in "${!EXTRA_FILES[@]}"; do
                local box="${c_dim}[ ]${c_0}"; [ "${EXTRA_ON[$i]}" = 1 ] && box="${c_ok}[x]${c_0}"
                printf '    %s %2d  %-16s %s\n' "$box" $((i+1)) "$(extra_name "${EXTRA_FILES[$i]}")" "${c_dim}$(extra_desc "${EXTRA_FILES[$i]}")${c_0}"
            done
            printf '  %s›%s ' "$c_acc" "$c_0"
            local line; read -r line </dev/tty || line=""
            [ -z "$line" ] && break
            for n in $line; do
                [ "$n" -ge 1 ] 2>/dev/null && [ "$n" -le "${#EXTRA_FILES[@]}" ] && EXTRA_ON[$((n-1))]=$((1 - EXTRA_ON[$((n-1))])) || true
            done
        done
    fi
    [ "$NO_AI" = 1 ] && for i in "${!EXTRA_FILES[@]}"; do [ "$(extra_name "${EXTRA_FILES[$i]}")" = wallpaper-ai ] && EXTRA_ON[$i]=0 || true; done
    local picked=()
    for i in "${!EXTRA_FILES[@]}"; do [ "${EXTRA_ON[$i]}" = 1 ] && picked+=("$(extra_name "${EXTRA_FILES[$i]}")") || true; done
    note "extras: ${picked[*]:-none}"
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
    if [ "$DRY_RUN" = 1 ]; then
        sed -e 's/#.*//' -e 's/[[:space:]]//g' "$REPO/packages/core.txt" | grep -v '^$' | sed 's/^/  package: /'
        load_extras
        ledger_record "{\"type\":\"dry-run\",\"action\":\"packages\",\"time\":\"$(date -Iseconds)\"}"
        return 0
    fi
    sudo pacman -Syu --noconfirm

    local lists=("$REPO/packages/core.txt") i
    for i in "${!EXTRA_FILES[@]}"; do [ "${EXTRA_ON[$i]}" = 1 ] && lists+=("${EXTRA_FILES[$i]}") || true; done

    local repo=() aur=() p
    while read -r p; do
        [ -z "$p" ] && continue
        # already satisfied, by the package itself or by something that provides it
        # (e.g. tuned-ppd provides power-profiles-daemon; installing both would conflict)
        pacman -T "$p" >/dev/null 2>&1 && continue
        if pacman -Si "$p" >/dev/null 2>&1; then repo+=("$p"); else aur+=("$p"); fi
    done < <(cat "${lists[@]}" | sed -e 's/#.*//' -e 's/[[:space:]]//g' | sort -u)

    # video decode/encode on the integrated gpu (mpv, mpvpaper, the recorder)
    if grep -q GenuineIntel /proc/cpuinfo; then repo+=(intel-media-driver vulkan-intel); fi
    if grep -q AuthenticAMD /proc/cpuinfo; then repo+=(vulkan-radeon); fi

    if [ "${#repo[@]}" -gt 0 ]; then
        note "${#repo[@]} from the official repos"
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
    ledger_record "{\"type\":\"packages\",\"core\":\"$REPO/packages/core.txt\",\"extraProfiles\":\"installed\",\"time\":\"$(date -Iseconds)\"}"
}

# ------------------------------------------------------------------ gpu
gpu() {
    local has_nv=0 has_ig=0
    # (no `| grep -q` here: with pipefail, grep quitting early makes the pipe "fail")
    local gpus
    gpus="$(lspci -nn 2>/dev/null | grep -Ei 'vga|3d|display' || true)"
    case "$gpus" in *10de:*) has_nv=1 ;; esac
    if printf '%s\n' "$gpus" | grep -iE '8086:|1002:' >/dev/null; then has_ig=1; fi

    say "graphics: $( [ $has_ig = 1 ] && echo -n "integrated " )$( [ $has_nv = 1 ] && echo -n "nvidia" )"
    sudo install -Dm644 "$REPO/system/udev/61-kajukatli-gpu.rules" /etc/udev/rules.d/61-kajukatli-gpu.rules
    # the battery's charge limit, settable from settings → power
    sudo install -Dm644 "$REPO/system/udev/62-kajukatli-battery.rules" /etc/udev/rules.d/62-kajukatli-battery.rules

    if [ $has_nv = 1 ]; then
        # any nvidia kernel driver already there (nvidia, nvidia-open, -dkms, -lts, 580xx…)? keep it:
        # adding nvidia-open-dkms next to nvidia-open is a package conflict
        local have_drv
        have_drv="$(pacman -Qq 2>/dev/null | grep -E '^nvidia(-open)?(-dkms|-lts)?$|^nvidia-[0-9]+xx' || true)"
        if [ -z "$have_drv" ]; then
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
    sudo udevadm trigger --subsystem-match=power_supply --action=add 2>/dev/null || true

    # route hyprland to the integrated gpu on hybrid laptops. external ports wired to the
    # nvidia card (common for hdmi on gaming laptops) only work if hyprland may use that card
    local nv_ports="" c v p
    for c in /sys/class/drm/card*-*; do
        [ -e "$c/status" ] || continue
        p="${c##*/}"; v="$(cat "/sys/class/drm/${p%%-*}/device/vendor" 2>/dev/null || true)"
        case "${p#*-}" in eDP*|LVDS*|DSI*|Writeback*) continue ;; esac
        if [ "$v" = 0x10de ]; then nv_ports="$nv_ports ${p#*-}"; fi
    done
    local out="$CONFIG/hypr/modules/gpu.lua"
    mkdir -p "$(dirname "$out")"
    [ -L "$out" ] && rm -f "$out"
    {
        echo "-- written by install.sh for this machine. safe to edit; rerunning install.sh rewrites it."
        if [ $has_nv = 1 ] && [ $has_ig = 1 ] && [ -n "$nv_ports" ]; then
            echo "-- hybrid laptop: draw on the integrated gpu. the nvidia card is listed second only"
            echo "-- because these ports are wired to it:$nv_ports (without it they show \"no signal\")"
            echo "hl.env(\"AQ_DRM_DEVICES\", \"/dev/dri/kk-igpu:/dev/dri/kk-dgpu\")"
        elif [ $has_nv = 1 ] && [ $has_ig = 1 ]; then
            echo "-- hybrid laptop: draw on the integrated gpu so the nvidia card can sleep."
            echo "-- (every external port is on the integrated gpu; kk-hdmi checks this again)"
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
    ledger_record "{\"type\":\"symlink\",\"src\":\"$src\",\"dst\":\"$dst\",\"time\":\"$(date -Iseconds)\"}"
}

links() {
    say "linking the dotfiles"
    # quickshell: the whole folder, so compiled shaders sit next to the qml that loads them
    backup_and_link "$REPO/config/quickshell/kajukatli" "$CONFIG/quickshell/kajukatli"
    backup_and_link "$REPO/config/quickshell/kk-photobooth" "$CONFIG/quickshell/kk-photobooth"
    # our own apps in the app drawer
    for f in "$REPO"/system/applications/*.desktop; do
        [ -f "$f" ] && install -Dm644 "$f" "$HOME/.local/share/applications/$(basename "$f")"
    done

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
    mkdir -p "$CONFIG/qt6ct"
    [ -L "$CONFIG/qt6ct/qt6ct.conf" ] && rm -f "$CONFIG/qt6ct/qt6ct.conf"
    sed "s|@CONFIG@|$CONFIG|g" "$REPO/config/qt6ct/qt6ct.conf.in" > "$CONFIG/qt6ct/qt6ct.conf"

    # scripts
    for f in "$REPO"/bin/*; do [ -f "$f" ] || continue; backup_and_link "$f" "$BIN/$(basename "$f")"; chmod +x "$f"; done
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

# ------------------------------------------------------------------ typefaces
# the shell's type ships in the repo (fonts/, open font licence, ~2 mb), so this needs no
# network: some providers block the hosts fonts are usually downloaded from.
#   bricolage grotesque  the interface      dm mono       numbers, the bar, the terminal
#   syne · unbounded · anton · fraunces · instrument serif   the desktop clocks
fonts() {
    say "typefaces"
    mkdir -p "$FONTS"
    local f n=0
    for f in "$REPO"/fonts/*.ttf "$REPO"/fonts/OFL-*.txt; do
        [ -f "$f" ] || continue
        install -Dm644 "$f" "$FONTS/$(basename "$f")"
        case "$f" in *.ttf) n=$((n+1)) ;; esac
    done
    # the old installer named downloaded files differently; drop those leftovers
    rm -f "$FONTS"/*%5B* 2>/dev/null || true
    fc-cache -f "$FONTS" >/dev/null 2>&1 || true
    if fc-list : family 2>/dev/null | grep -i "bricolage grotesque" >/dev/null; then ok "typefaces ($n)"; else warn "typefaces copied but fontconfig doesn't list them yet; try: fc-cache -fv"; fi
}

# ------------------------------------------------------------------ wallpapers
# public-domain paintings from wikimedia commons, fetched at 2560 px. the clock-behind-subject
# effect looks its best on pictures with a clear figure (friedrich, vermeer, waterhouse…).
WALLS=(
    "great-wave.jpg|Tsunami_by_hokusai_19th_century.jpg"
    "red-fuji.jpg|Red_Fuji_southern_wind_clear_morning.jpg"
    "kajikazawa.jpg|Kajikazawa_in_Kai_province.jpg"
    "wanderer.jpg|Caspar_David_Friedrich_-_Wanderer_above_the_sea_of_fog.jpg"
    "ninth-wave.jpg|Aivazovsky,_Ivan_-_The_Ninth_Wave.jpg"
    "pearl-earring.jpg|1665_Girl_with_a_Pearl_Earring.jpg"
    "starry-night.jpg|Van_Gogh_-_Starry_Night_-_Google_Art_Project.jpg"
    "parasol.jpg|Claude_Monet_-_Woman_with_a_Parasol_-_Madame_Monet_and_Her_Son_-_Google_Art_Project.jpg"
    "impression-sunrise.jpg|Monet_-_Impression,_Sunrise.jpg"
    "shalott.jpg|John_William_Waterhouse_-_The_Lady_of_Shalott_-_Google_Art_Project_edit.jpg"
    "the-kiss.jpg|The_Kiss_-_Gustav_Klimt_-_Google_Cultural_Institute.jpg"
    "moon-pine.jpg|100_views_edo_089.jpg"
    # strong outlines and a clear figure: the best ones for the line tracing and the clock
    "mucha-job.jpg|Alfons_mucha,_job,_litografia,_1896.jpg"
    "mucha-summer.jpg|Alfons_Mucha_-_The_Seasons_-_Summer_(1896).jpg"
    "mucha-hyacinth.jpg|Alfons_Mucha_-_Princess_Hyacinth,_1911.jpg"
    "mucha-zodiac.jpg|Alphonse_Mucha_-_Zodiac,_1869.jpg"
    "mucha-reverie.jpg|Reverie_1897.jpg"
    "utamaro-three-beauties.jpg|Utamaro_(1793)_Three_Beauties_of_the_Present_Time,_MFAB_21.6382.jpg"
    "sharaku-oniji.jpg|Toshusai_Sharaku-_Otani_Oniji,_1794.jpg"
    "kuniyoshi-skeleton.jpg|Takiyasha_the_Witch_and_the_Skeleton_Spectre,_by_Utagawa_Kuniyoshi.jpg"
    "hiroshige-shower.jpg|Hiroshige,_Sudden_shower_over_Shin-Ohashi_bridge_and_Atake,_1857_expanded.jpg"
)
wallpapers() {
    say "wallpaper pack"
    local dir="$HOME/Pictures/wallpapers/paintings" w name file got=0
    mkdir -p "$dir"
    for w in "${WALLS[@]}"; do
        name="${w%%|*}"; file="${w#*|}"
        [ -s "$dir/$name" ] && { got=$((got+1)); continue; }
        if curl -fsL --retry 6 --retry-delay 5 --max-time 120 -A "kajukatli-installer/1.0 (arch linux dotfiles)" \
                -o "$dir/$name.part" "https://commons.wikimedia.org/wiki/Special:FilePath/$file?width=2560"; then
            mv "$dir/$name.part" "$dir/$name"; got=$((got+1)); note "$name"
        else
            rm -f "$dir/$name.part"; warn "couldn't fetch $name"
        fi
        sleep 2   # wikimedia asks scripts to go gently (it rate-limits picture scaling)
    done
    ok "wallpapers ($got in ~/Pictures/wallpapers/paintings)"
    # anime: the month's top ones from wallhaven (sfw), straight to your machine
    if ask "also download 16 top anime wallpapers from wallhaven.cc (~60 mb)" y; then
        "$REPO/bin/kk-getwalls" 16 || warn "wallhaven didn't answer; try later: kk-getwalls"
    fi
}

# ------------------------------------------------------------------ ai
# a private venv on top of the system's numpy + pillow (so they aren't installed twice):
# onnxruntime + opencv-headless, ~250 mb, plus the models you pick.
ai_env() {
    say "wallpaper ai (subject cut-out for the depth clock, 3d parallax)"
    local level="full" r
    if [ "$YES" != 1 ]; then
        note "1  lite    u2netp, rough cut-outs, no parallax              ~5 mb of models"
        note "2  anime   isnet-anime, clean cut-outs of drawn art         ~170 mb"
        note "3  full    anime + depth for the 3d parallax                ~270 mb  (recommended)"
        note "4  photo   birefnet for photographs + depth                 ~320 mb"
        printf '  %s?%s which one %s ' "$c_acc" "$c_0" "[3]"
        read -r r </dev/tty || r=""
        case "${r:-3}" in 1) level=lite ;; 2) level=anime ;; 4) level=photo ;; *) level=full ;; esac
    fi
    local model=isnet-anime depth=0
    case "$level" in lite) model=u2netp ;; full) depth=1 ;; photo) model=birefnet-general-lite; depth=1 ;; esac
    printf 'model=%s\ndepth=%s\n' "$model" "$depth" > "$DATA/ai.conf"

    local py="$DATA/venv/bin/python"
    [ -x "$py" ] || python3 -m venv --system-site-packages "$DATA/venv"
    "$py" -m pip install --quiet --no-cache-dir --upgrade pip
    "$py" -m pip install --quiet --no-cache-dir onnxruntime opencv-python-headless
    # rembg (and its ~700 mb of numba / scipy / scikit-image) is no longer needed
    "$py" -m pip uninstall -y --quiet rembg pymatting numba llvmlite scikit-image scipy 2>/dev/null || true
    note "fetching the model(s) now so the first wallpaper doesn't wait"
    "$BIN/kk-prep" --fetch-models || warn "model download failed; it'll retry on the first wallpaper"
    # every wallpaper gets its cut-out, depth and ink map now, in the background at idle
    # priority, so switching is complete from the first time (log: $CACHE/prep-all.log)
    note "preparing every wallpaper in the background (cut-outs, depth, ink); takes a few minutes"
    nohup nice -n 19 ionice -c 3 sh -c 'for f in "$1"/*.jpg "$1"/*.jpeg "$1"/*.png "$1"/*.webp "$1"/*/*.jpg "$1"/*/*.png; do [ -f "$f" ] && "$2" "$f" >/dev/null; done'         sh "$HOME/Pictures/wallpapers" "$BIN/kk-prep" >"$CACHE/prep-all.log" 2>&1 &
    ok "wallpaper ai ($level)"
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
    # let networkmanager notice wi-fi that wants a sign-in page (the shell then opens it)
    if [ ! -f /etc/NetworkManager/conf.d/20-connectivity.conf ]; then
        printf '[connectivity]\nenabled=true\nuri=http://ping.archlinux.org/nm-check.txt\ninterval=300\n' \
            | sudo tee /etc/NetworkManager/conf.d/20-connectivity.conf >/dev/null
    fi
    sudo systemctl enable --now NetworkManager bluetooth
    sudo systemctl reload NetworkManager 2>/dev/null || true
    # power profiles: tuned-ppd and power-profiles-daemon speak the same d-bus api; use whichever is here
    if pacman -Qq tuned-ppd >/dev/null 2>&1; then
        sudo systemctl enable --now tuned tuned-ppd
    else
        sudo systemctl enable --now power-profiles-daemon
    fi
    systemctl --user enable --now pipewire pipewire-pulse wireplumber 2>/dev/null || true

    # login screen
    if extra_chosen greeter; then
        local dm
        dm="$(basename "$(readlink -f /etc/systemd/system/display-manager.service 2>/dev/null)" 2>/dev/null || true)"
        if [ "$dm" = "greetd.service" ]; then
            # ours from an earlier run? refresh it so the login screen gets updates too
            if grep -q "kk-session" /etc/greetd/config.toml 2>/dev/null; then
                sudo install -Dm644 "$REPO/system/greetd/config.toml" /etc/greetd/config.toml
                if pacman -Qq terminus-font >/dev/null 2>&1 && ! grep -q '^FONT=' /etc/vconsole.conf 2>/dev/null; then
                    echo 'FONT=ter-v32n' | sudo tee -a /etc/vconsole.conf >/dev/null
                fi
                note "login screen updated"
            else
                note "greetd already set up (your own config; left alone)"
            fi
        elif ask "use greetd + tuigreet as the login screen$([ -n "$dm" ] && [ "$dm" != "display-manager.service" ] && echo " (replaces $dm)")" y; then
            [ -f /etc/greetd/config.toml ] && sudo cp /etc/greetd/config.toml "/etc/greetd/config.toml.kk-backup-$STAMP"
            sudo install -Dm644 "$REPO/system/greetd/config.toml" /etc/greetd/config.toml
            # a sharp, larger console font for the login screen (terminus, 16x32)
            if pacman -Qq terminus-font >/dev/null 2>&1 && ! grep -q '^FONT=' /etc/vconsole.conf 2>/dev/null; then
                echo 'FONT=ter-v32n' | sudo tee -a /etc/vconsole.conf >/dev/null
            fi
            [ -n "$dm" ] && [ "$dm" != "display-manager.service" ] && sudo systemctl disable "$dm" || true
            sudo systemctl enable greetd.service
        fi
    fi
    # start in the lock screen: greetd logs you in once per boot and the shell locks at once.
    # the text login is still there after you log out.
    if [ -f /etc/greetd/config.toml ] && grep -q "kk-session" /etc/greetd/config.toml; then
        if grep -q '^\[initial_session\]' /etc/greetd/config.toml; then
            note "starts in the lock screen (auto-login is on)"
        elif ask "start straight into the kajukatli lock screen at boot (logs you in, then locks immediately; your password unlocks)" y; then
            printf '\n[initial_session]\ncommand = "kk-session --locked"\nuser = "%s"\n' "$USER" | sudo tee -a /etc/greetd/config.toml >/dev/null
            note "boots into the lock screen. to undo: remove [initial_session] from /etc/greetd/config.toml"
        fi
    fi
    ok "services"
}

# ------------------------------------------------------------------ terminal
terminal() {
    command -v zsh >/dev/null || return 0
    say "terminal"
    local line="[ -f \"$CONFIG/shell/kajukatli.sh\" ] && . \"$CONFIG/shell/kajukatli.sh\""
    [ -f "$HOME/.zshrc" ] || printf '# kajukatli
%s
' "$line" > "$HOME/.zshrc"
    grep -qF "shell/kajukatli.sh" "$HOME/.zshrc" || printf '
# kajukatli
%s
' "$line" >> "$HOME/.zshrc"
    if [ "$(basename "${SHELL:-}")" != zsh ] && ask "make zsh your shell (autosuggestions, highlighting, menu completion)" y; then
        sudo chsh -s "$(command -v zsh)" "$USER" && note "zsh from your next login"
    fi
    ok "terminal"
}

# ------------------------------------------------------------------ defaults
defaults() {
    say "first-run defaults"
    xdg-user-dirs-update 2>/dev/null || true
    mkdir -p "$HOME/Pictures/wallpapers" "$HOME/Pictures/screenshots" "$HOME/Videos/recordings" "$CONFIG/kajukatli"
    # nothing to look at yet? a few generated gradients so the desktop isn't empty
    if [ -z "$(find "$HOME/Pictures/wallpapers" -type f 2>/dev/null | head -n1)" ]; then
        python3 "$REPO/bin/kk-wallpapers" "$HOME/Pictures/wallpapers/generated" >/dev/null || true
    fi
    # folders open in the file manager, pictures and videos in their viewers (not the terminal)
    if command -v xdg-mime >/dev/null; then
        [ -f /usr/share/applications/org.gnome.Nautilus.desktop ] && xdg-mime default org.gnome.Nautilus.desktop inode/directory
        [ -f /usr/share/applications/org.gnome.Loupe.desktop ] && xdg-mime default org.gnome.Loupe.desktop image/png image/jpeg image/webp image/gif
        [ -f /usr/share/applications/mpv.desktop ] && xdg-mime default mpv.desktop video/mp4 video/webm video/x-matroska
    fi
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Classic' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface font-name 'Bricolage Grotesque 10' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface monospace-font-name 'DM Mono 10' 2>/dev/null || true
    # colours until the first wallpaper decides them
    [ -f "$CACHE/theme.json" ] || "$BIN/kk-theme" '#e9a86b' || true
    ok "defaults"
}

# ------------------------------------------------------------------ battery, ram, disk
# the safe laptop tunables (powertop's list minus usb autosuspend, which breaks some mice),
# compressed swap in ram, and caps on the things that grow: logs and the package cache.
savings() {
    ask "apply the battery, memory and disk savings (recommended on a laptop)" y || return 0
    say "savings"
    sudo install -Dm644 "$REPO/system/sysctl/90-kajukatli-power.conf" /etc/sysctl.d/90-kajukatli-power.conf
    sudo install -Dm644 "$REPO/system/modprobe/kajukatli-power.conf" /etc/modprobe.d/kajukatli-power.conf
    sudo install -Dm644 "$REPO/system/udev/63-kajukatli-pci-pm.rules" /etc/udev/rules.d/63-kajukatli-pci-pm.rules
    sudo install -Dm644 "$REPO/system/networkmanager/30-kajukatli-wifi-powersave.conf" /etc/NetworkManager/conf.d/30-kajukatli-wifi-powersave.conf
    sudo install -Dm644 "$REPO/system/journald/kajukatli.conf" /etc/systemd/journald.conf.d/kajukatli.conf
    sudo sysctl --system >/dev/null 2>&1 || true
    sudo systemctl restart systemd-journald 2>/dev/null || true
    sudo journalctl --vacuum-size=200M >/dev/null 2>&1 || true
    # zram: only if there's no swap set up already (keeps hibernation setups alone)
    if [ ! -f /etc/systemd/zram-generator.conf ] && ! swapon --show=NAME --noheadings 2>/dev/null | grep -v zram >/dev/null; then
        sudo install -Dm644 "$REPO/system/zram/zram-generator.conf" /etc/systemd/zram-generator.conf
        sudo systemctl daemon-reload && sudo systemctl start systemd-zram-setup@zram0.service 2>/dev/null || true
    fi
    # the package cache: keep only the newest version of each package, weekly
    if command -v paccache >/dev/null; then
        echo "PACCACHE_ARGS='-k1'" | sudo tee /etc/conf.d/pacman-contrib >/dev/null
        sudo systemctl enable --now paccache.timer >/dev/null 2>&1 || true
        sudo paccache -rk1 >/dev/null 2>&1 || true
        sudo paccache -ruk0 >/dev/null 2>&1 || true
    fi
    # pip's download cache from setting up the wallpaper ai is never needed again
    rm -rf "$HOME/.cache/pip"
    ok "savings (kk-power-report shows what's drawing power)"
}

# ------------------------------------------------------------------ grub
# the boot menu in the desktop's colours, over your wallpaper (bin/kk-grub). only for grub.
grub_theme() {
    [ -f /etc/default/grub ] && command -v grub-mkconfig >/dev/null || return 0
    ask "give the grub boot menu the kajukatli look" y || return 0
    say "grub theme"
    sudo pacman -S --needed --noconfirm freetype2 >/dev/null 2>&1 || true
    local tmp="$CACHE/grub-theme"
    python3 "$REPO/bin/kk-grub" "$tmp" >/dev/null || { warn "couldn't build the grub theme"; return 0; }
    sudo rm -rf /boot/grub/themes/kajukatli
    sudo install -d /boot/grub/themes
    sudo cp -r "$tmp" /boot/grub/themes/kajukatli
    local g=/etc/default/grub
    sudo cp "$g" "$BACKUP-grub.default" 2>/dev/null || sudo cp "$g" "$g.kajukatli-backup"
    set_grub() {   # set_grub KEY VALUE: replace or add KEY=VALUE
        if sudo grep -qE "^#?$1=" "$g"; then sudo sed -i -E "s|^#?$1=.*|$1=$2|" "$g"; else echo "$1=$2" | sudo tee -a "$g" >/dev/null; fi
    }
    set_grub GRUB_THEME '"/boot/grub/themes/kajukatli/theme.txt"'
    set_grub GRUB_GFXMODE 'auto'
    set_grub GRUB_TIMEOUT_STYLE 'menu'
    # a text-only console output would hide the theme
    sudo sed -i -E 's|^GRUB_TERMINAL_OUTPUT=console|#GRUB_TERMINAL_OUTPUT=console|' "$g"
    sudo grub-mkconfig -o /boot/grub/grub.cfg >/dev/null 2>&1 && ok "grub theme (kk-grub again after a new wallpaper)"         || warn "grub-mkconfig failed; your old grub.cfg is untouched"
}

# ------------------------------------------------------------------ run
echo
echo "  ${c_acc}${c_b}kajukatli${c_0}  ${c_dim}a desktop shell for arch + hyprland${c_0}"
echo "  ${c_dim}log: $LOG${c_0}"
echo

case "$ONLY" in
    links)   links; exit 0 ;;
    shaders) shaders; exit 0 ;;
    fonts)   fonts; exit 0 ;;
    walls)   wallpapers; exit 0 ;;
    ai)      ai_env; exit 0 ;;
    grub)    grub_theme; exit 0 ;;
    savings) savings; exit 0 ;;
esac

preflight
choose_extras
packages
if [ "$DRY_RUN" = 1 ]; then
    ledger_record "{\"type\":\"dry-run\",\"action\":\"install-plan\",\"time\":\"$(date -Iseconds)\"}"
    exit 0
fi
gpu
links
shaders
fonts
extra_chosen wallpaper-pack && wallpapers || true
extra_chosen wallpaper-ai && ai_env || note "no wallpaper ai: wallpapers and colours still work, the clock just stays in front."
services
extra_chosen terminal && terminal || true
defaults
savings || true
grub_theme || true

echo
ok "done."
note "reboot, log in, then:"
note "  super + w           wallpapers               super + i   settings & looks"
note "  super + space       launcher                 super + a   control center"
note "  super + shift + t   cycle looks              super + /   every key"
note "  something off?      kk-doctor"
echo
