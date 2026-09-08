#!/usr/bin/env bash
# Rebuild the current release tree from the RC1 TIPA + content delta, then
# emit an unsigned TrollStore .tipa.
set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
VERSION="${JUICE_RELEASE_VERSION:-v0.2.0-rc2}"
BASE_TIPA="${JUICE_BASE_TIPA:-$ROOT/releases/Juice-Steam-Chocolate-Network-v0.2.0-rc1.tipa}"
DELTA="${JUICE_RELEASE_DELTA:-$ROOT/releases/Juice-v0.2.0-rc2-content-delta.tar.zst}"
DELTA_SUM="${DELTA}.sha256"
STAGE="${JUICE_PACKAGE_STAGE:-$ROOT/build/unsigned-ipa-tree}"
DIST="${JUICE_DIST:-$ROOT/dist}"
TIPA_OUT="${JUICE_TIPA_OUTPUT:-$DIST/Juice-${VERSION}-unsigned.tipa}"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required tool: $1" >&2
    exit 2
  }
}

need unzip
need zip
need python3
need zstd
need sha256sum

test -f "$BASE_TIPA" || { echo "Missing base TIPA: $BASE_TIPA" >&2; exit 2; }
test -f "$DELTA" || { echo "Missing release delta: $DELTA" >&2; exit 2; }
test -f "$DELTA_SUM" || { echo "Missing delta checksum: $DELTA_SUM" >&2; exit 2; }

echo "JUICE_UNSIGNED_TIPA_START version=$VERSION"
(cd "$ROOT" && sha256sum -c "$DELTA_SUM")

rm -rf "$STAGE"
mkdir -p "$STAGE" "$DIST"
unzip -q "$BASE_TIPA" -d "$STAGE"
test -d "$STAGE/Payload/Juice.app" || {
  echo "Base TIPA is missing Payload/Juice.app" >&2
  exit 3
}

python3 "$ROOT/scripts/juice-release-delta.py" apply "$STAGE" "$DELTA"

for required in \
  "$STAGE/Payload/Juice.app/Juice" \
  "$STAGE/Payload/Juice.app/Grape/build/wine-ios/loader/wine" \
  "$STAGE/Payload/Juice.app/Grape-X64/build/wine-ios/loader/wine"
do
  test -e "$required" || { echo "Rebuilt package missing: $required" >&2; exit 3; }
done

rm -f "$TIPA_OUT" "$TIPA_OUT.sha256"
(
  cd "$STAGE"
  zip -qry "$TIPA_OUT" Payload
)

(
  cd "$(dirname "$TIPA_OUT")"
  sha256sum "$(basename "$TIPA_OUT")" > "$(basename "$TIPA_OUT").sha256"
)

unzip -t "$TIPA_OUT" >/dev/null
echo "JUICE_UNSIGNED_TIPA_OK tipa=$TIPA_OUT"
ls -lh "$TIPA_OUT"
cat "$TIPA_OUT.sha256"
