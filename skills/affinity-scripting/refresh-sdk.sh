#!/usr/bin/env bash
# Build / refresh the local Affinity SDK reference from your installed app.
# Re-copies JSLib, (optionally) re-indexes codegraph, and regenerates the
# signature reference. Run with no args to rebuild only when the version
# changed; --force to always rebuild. First run = full build (setup.sh).
#
# Override the SDK location for non-default installs:
#   AFFINITY_JSLIB=/path/to/JSLib ./refresh-sdk.sh
#
# NOTE: affinity-sdk-api.md is parser-generated (complete signatures, no
# curated prose). It is derived from Affinity's proprietary SDK and is NOT
# committed to git — it is rebuilt locally from YOUR licensed install.
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${AFFINITY_JSLIB:-/Applications/Affinity.app/Contents/Resources/JSLib}"
APP_PLIST="$(dirname "$(dirname "$SRC")")/Info"   # .../Contents/Info (macOS)
DST="$SKILL_DIR/sdk/JSLib"
REF="$SKILL_DIR/affinity-sdk-api.md"
VERSION_FILE="$SKILL_DIR/sdk/VERSION"

command -v node >/dev/null || { echo "ERROR: node is required (for the signature parser)."; exit 1; }
[ -d "$SRC" ] || { echo "ERROR: Affinity SDK (JSLib) not found at: $SRC
  Install Affinity v3.2+, or set AFFINITY_JSLIB=/path/to/JSLib"; exit 1; }

# Version marker: app version on macOS, else a content hash of the SDK.
NEWVER=""
if command -v defaults >/dev/null; then
  NEWVER="$(defaults read "$APP_PLIST" CFBundleShortVersionString 2>/dev/null || true)"
fi
[ -z "$NEWVER" ] && NEWVER="sha-$(find "$SRC" -name '*.js' -type f -exec shasum {} + | shasum | cut -c1-12)"
OLDVER="$(cat "$VERSION_FILE" 2>/dev/null || echo none)"
echo "installed: $NEWVER   indexed: $OLDVER"

if [ "$NEWVER" = "$OLDVER" ] && [ "${1:-}" != "--force" ]; then
  echo "up to date — nothing to do (use --force to rebuild)."
  exit 0
fi

echo "==> 1/3 copying JSLib"
rm -rf "$DST"; mkdir -p "$DST"
cp -R "$SRC/" "$DST/"
echo "    $(find "$DST" -name '*.js' | wc -l | tr -d ' ') js files"

echo "==> 2/3 codegraph index"
if command -v codegraph >/dev/null; then
  codegraph init "$DST" >/dev/null 2>&1 || true
  codegraph index "$DST" 2>&1 | tail -3
else
  echo "    codegraph not installed — skipping graph (reference + raw source still built)."
  echo "    install: npm i -g @colbymchenry/codegraph   (optional; enables callers/callees/source queries)"
fi

echo "==> 3/3 regenerating signature reference"
node "$SKILL_DIR/extract-api.js" "$DST" > "$REF"
echo "    $REF — $(wc -l < "$REF" | tr -d ' ') lines, $(grep -c '^### ' "$REF") classes"

mkdir -p "$(dirname "$VERSION_FILE")"
echo "$NEWVER" > "$VERSION_FILE"
echo "done. SDK reference built at version $NEWVER"
