#!/usr/bin/env bash
# scripts/selfcheck.sh: quick checks for bugs that already happened once. changes nothing of yours.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
t="$(mktemp -d)"; trap 'rm -rf "$t"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

for f in install.sh uninstall.sh scripts/*.sh bin/kk-*; do
    case "$(head -n1 "$f")" in
        *python*) python3 -c 'import sys; compile(open(sys.argv[1]).read(), sys.argv[1], "exec")' "$f" ;;
        *bash*) bash -n "$f" ;;
        *sh*) sh -n "$f" ;;
    esac || fail "syntax: $f"
done

# a saved "false" stays false
pref="$(grep -o "if \.\[\$k\] == null then \$d else \.\[\$k\] end" bin/kk-storage)" || fail "kk-storage pref"
[ "$(echo '{"a":false}' | jq -r --arg k a --arg d true "$pref")" = false ] || fail "false read as default"

# low-memory undo keeps a line that had no final newline
mkdir -p "$t/bin" "$t/cfg"; printf '#!/bin/sh\n' > "$t/bin/brave"; chmod +x "$t/bin/brave"
printf -- '--mine' > "$t/cfg/brave-flags.conf"
for m in apply undo; do PATH="$t/bin:$PATH" HOME="$t" XDG_CONFIG_HOME="$t/cfg" bin/kk-lowmem "$m" >/dev/null; done
grep -qx -- '--mine' "$t/cfg/brave-flags.conf" || fail "lowmem undo removed your line"

# generated css: the marker comment is closed, or the whole file is a comment
grep -q 'close = " \*/" if comment == "/\*"' bin/kk-theme || fail "kk-theme css comment"

# --dry-run never runs a real action
for a in --update --links --rollback --restore; do
    out="$(XDG_DATA_HOME="$t/data" ./install.sh --dry-run "$a" 2>&1 || true)"
    case "$out" in *"nothing was changed"*) ;; *) fail "dry run: $a" ;; esac
done

bin/kk-themes list >/dev/null || fail "kk-themes list"
if command -v node >/dev/null; then node scripts/test-insert-plan.js >/dev/null || fail "workspace insert plan"; fi
echo "selfcheck passed"
