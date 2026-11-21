#!/usr/bin/env bash
# kajukatli · uninstall. removes every link that points into this repo and puts your
# backed-up files back. packages and system services are left alone (it tells you how).
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}/kajukatli"

echo "  removing links into $REPO"
find "$CONFIG" "$HOME/.local/bin" -maxdepth 4 -type l 2>/dev/null | while read -r l; do
    case "$(readlink "$l")" in "$REPO"/*) rm -f "$l"; echo "    - ${l#$HOME/}";; esac
done

latest="$(ls -1d "$DATA"/backup/*/ 2>/dev/null | tail -n1 || true)"
if [ -n "$latest" ] && [ -f "$latest/.moved" ]; then
    echo "  restoring your files from $latest"
    while read -r dst; do
        src="$latest/${dst#$HOME/}"
        [ -e "$src" ] && [ ! -e "$dst" ] && { mkdir -p "$(dirname "$dst")"; mv "$src" "$dst"; echo "    + ${dst#$HOME/}"; }
    done < "$latest/.moved"
fi

for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    [ -f "$rc" ] && sed -i '/# kajukatli/d;/shell\/kajukatli.sh/d' "$rc"
done

cat <<'EOF'

  done. left in place on purpose:
    packages            pacman -Rns $(grep -v '^#' packages/packages.txt)   (look before you run it)
    login screen        sudo systemctl disable greetd && sudo systemctl enable <your old dm>
    gpu / nvidia files  /etc/udev/rules.d/61-kajukatli-gpu.rules, 80-nvidia-pm.rules,
                        /etc/modprobe.d/kajukatli-nvidia.conf, /usr/local/bin/kk-session
    caches & models     ~/.cache/kajukatli  ~/.local/share/kajukatli
EOF
