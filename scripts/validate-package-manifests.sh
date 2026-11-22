#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bad=0
check_file() {
    local file="$1" line package
    [ -f "$file" ] || { echo "missing manifest: $file"; bad=1; return; }
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%%#*}"
        package="$(printf '%s' "$line" | tr -d '[:space:]')"
        [ -z "$package" ] && continue
        if [[ "$package" == *"|"* || "$package" == */* || "$package" == *"$"* ]]; then
            echo "invalid package name in $file: $package"
            bad=1
        fi
    done <"$file"
}

check_file "$root/packages/core.txt"
while IFS= read -r file; do check_file "$file"; done < <(find "$root/packages/extras" -type f -name '*.txt' | sort)
[ "$bad" = 0 ] || exit 1
echo "package manifests valid"
