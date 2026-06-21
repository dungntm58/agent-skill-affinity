#!/usr/bin/env bash
# First-time setup: build the local Affinity SDK reference + codegraph index
# from your installed Affinity app. Safe to re-run. Just forces a full build.
#
#   ./setup.sh
#   AFFINITY_JSLIB=/custom/path/JSLib ./setup.sh   # non-default install
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "Setting up affinity-scripting skill in: $DIR"
exec "$DIR/refresh-sdk.sh" --force
