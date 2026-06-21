#!/usr/bin/env bash
# Preflight for the affinity-scripting skill. Run this FIRST when the skill is
# used. Idempotent + fast when everything is current.
#   1) checks the Affinity MCP server is reachable
#   2) auto-builds/refreshes the local SDK index if missing or stale
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT=6767; URL="http://localhost:${PORT}/sse"

# --- 1. MCP reachability (port open = server listening) ---
# Affinity binds IPv6 (::1) — and sometimes IPv4 — so probe both.
mcp_up() {
  for host in ::1 127.0.0.1; do
    if (exec 3<>"/dev/tcp/${host}/${PORT}") 2>/dev/null; then exec 3>&- 3<&-; return 0; fi
  done
  return 1
}
if mcp_up; then
  echo "✓ Affinity MCP server reachable ($URL)"
else
  echo "✗ Affinity MCP server NOT reachable at $URL"
  echo "  → In Affinity: Settings → enable 'MCP Server' (keep a document open)."
  echo "  → Installed as a plugin? The bundled .mcp.json registers it automatically"
  echo "    once the in-app server is on (may need a session restart)."
  echo "  → Plain skill (no plugin)? Register manually once:"
  echo "      claude mcp add -s user --transport sse affinity $URL"
fi

# --- 2. SDK index freshness (auto-rebuild when missing or stale) ---
if [ -x "$DIR/refresh-sdk.sh" ]; then
  "$DIR/refresh-sdk.sh" || echo "  (SDK index not built — resolve the message above, then re-run preflight)"
else
  echo "✗ refresh-sdk.sh missing/not executable in $DIR"
fi
