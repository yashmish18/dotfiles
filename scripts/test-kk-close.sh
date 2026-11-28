#!/bin/sh
# super + q must never force-kill a virtual machine. a fake hyprctl: nothing real is closed.
set -eu
here="$(cd "$(dirname "$0")/.." && pwd)"; t="$(mktemp -d)"; trap 'rm -rf "$t"' EXIT
cat > "$t/hyprctl" <<'FAKE'
#!/bin/sh
case "$1" in
    activewindow) printf '{"address":"0x1","class":"%s","pid":999999}' "$CLS" ;;
    clients) echo '[{"pid":999999}]' ;;
    *) echo "$*" >> "$LOG" ;;
esac
FAKE
chmod +x "$t/hyprctl"
for CLS in "VirtualBox Machine" "VirtualBox Manager" "Qemu-system-x86_64" "virt-manager" "Vmware"; do
    : > "$t/log"; CLS="$CLS" LOG="$t/log" PATH="$t:$PATH" "$here/bin/kk-close"
    grep -q 'window.close' "$t/log" && ! grep -qE 'kill' "$t/log" || { echo "FAIL: $CLS" >&2; exit 1; }
done
: > "$t/log"; CLS=mpv LOG="$t/log" PATH="$t:$PATH" "$here/bin/kk-close"
grep -q 'window.kill' "$t/log" || { echo "FAIL: an ordinary app should still be killed" >&2; exit 1; }
echo "kk-close: passed"
