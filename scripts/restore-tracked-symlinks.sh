#!/usr/bin/env bash
# Recreate tracked Git symlinks when the checkout lost them (common on Windows
# without Developer Mode / core.symlinks=true).
set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
fixed=0

while IFS=$'\t' read -r mode _ _ relative; do
  test "$mode" = "120000" || continue
  path="$ROOT/$relative"
  if test -L "$path"; then
    continue
  fi
  target="$(git -C "$ROOT" show ":$relative" | tr -d '\r\n')"
  mkdir -p "$(dirname "$path")"
  rm -f "$path"
  (
    cd "$(dirname "$path")"
    ln -s "$target" "$(basename "$path")"
  )
  echo "JUICE_SYMLINK_RESTORED path=$relative -> $target"
  fixed=$((fixed + 1))
done < <(git -C "$ROOT" ls-files -s | awk '{print $1 "\t" $2 "\t" $3 "\t" substr($0, index($0,$4))}')

echo "JUICE_SYMLINKS_RESTORED count=$fixed"
