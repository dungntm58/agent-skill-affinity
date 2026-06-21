# affinity-scripting — an agent skill for scripting Affinity (by Canva)

A portable [agent skill](https://agentskills.io/specification) for driving
**Affinity Designer / Photo / Publisher v3.2+** through its built-in MCP server
and JavaScript SDK. It gives any compatible AI coding agent fast, complete API
lookups instead of slow trial-and-error against the SDK docs.

Works with any agent that supports the `SKILL.md` standard — **Claude Code,
Codex, Gemini CLI, GitHub Copilot CLI**, and others. Ships as a **Claude Code
plugin** for zero manual setup, and as a plain skill everywhere else.

## What it gives the agent
- **Verified patterns** for the common operations (create a document, add
  shapes / text / fills, render a spread) — copy-paste ready.
- **A complete signature reference** (`affinity-sdk-api.md`) — every exported
  class + public method/static/getter/setter across the ~62 SDK files
  (400+ classes), grep-able in one file.
- **A codegraph index** (optional) of the SDK for full source, callers,
  callees, and impact queries.
- **The doc-file map, hard rules, and gotchas** distilled from the SDK preamble.
- **Zero manual setup on Claude Code** — the plugin auto-registers the `affinity`
  MCP server, and a preflight check builds/refreshes the SDK index on first use
  (and after Affinity upgrades) automatically.

## Requirements
- **Affinity v3.2+** installed, with its **MCP server enabled** in
  Settings → enable "MCP Server" / AI connector (serves `http://localhost:6767/sse`).
- Your agent connected to that MCP server (see below).
- **Node.js** (for the signature parser used at setup).
- **codegraph** CLI — *optional*, enables source/call-graph queries:
  `npm i -g @colbymchenry/codegraph`.

## Install

This repo is **both** a Claude Code plugin (auto-registers the MCP server) and a
plain `SKILL.md` skill for other agents.

First, in Affinity: **Settings → enable "MCP Server"** (grant FileSystem /
Network / Canva-AI as needed) and keep a document open. The server listens on
`http://localhost:6767/sse`.

### Claude Code (plugin — recommended)
The plugin's bundled `.mcp.json` registers the `affinity` MCP server for you —
no manual `claude mcp add`.

```text
/plugin marketplace add dungntm58/agent-skill-affinity
/plugin install affinity-scripting@agent-skill-affinity
```
Or, for local development against a clone:
```bash
git clone https://github.com/dungntm58/agent-skill-affinity
claude --plugin-dir ./agent-skill-affinity      # loads the plugin for the session
```
On first use the skill runs `preflight.sh`, which checks the MCP server and
**auto-builds the SDK index** (and auto-rebuilds it after an Affinity upgrade).

### Other agents (skill mode)
`SKILL.md` is a portable [open standard](https://agentskills.io/specification)
(Codex, Cursor, Windsurf, Copilot, Gemini, …). Only the auto-MCP `.mcp.json` and
`.claude-plugin/` are Claude-Code-specific; everywhere else it's **two manual
steps**: (1) install the skill folder, (2) register the MCP server.

**1. Install the skill** — symlink the `skills/affinity-scripting/` subdir of a
clone into the agent's skills dir, then run setup once:

```bash
git clone https://github.com/dungntm58/agent-skill-affinity ~/src/agent-skill-affinity
ln -s ~/src/agent-skill-affinity/skills/affinity-scripting <SKILLS_DIR>/affinity-scripting
<SKILLS_DIR>/affinity-scripting/setup.sh
```

| Agent | `<SKILLS_DIR>` |
|-------|----------------|
| Claude Code | install as plugin (above) — skips both steps |
| Codex | `~/.codex/skills/` or `~/.agents/skills/` (repo: `.agents/skills/`) |
| Cursor | `~/.cursor/skills/` (project: `.cursor/skills/`) |
| Copilot CLI | `~/.copilot/skills/` (repo: `.github/skills/`) |
| Windsurf | supports SKILL.md — check current Windsurf docs for its skills path |
| Gemini CLI | per its skills/extensions config |

> Tip: `~/.agents/skills/` is a shared location watched by Claude Code, Codex,
> and Copilot — symlink there once to cover all three.

**2. Register the Affinity MCP server.** The in-app server uses the **legacy
SSE transport** at `http://localhost:6767/sse`. Most clients speak it directly;
Codex is Streamable-HTTP-only and needs an `mcp-proxy` bridge.

*Claude Code* (if used as a bare skill, not the plugin):
```bash
claude mcp add -s user --transport sse affinity http://localhost:6767/sse
```
*Cursor* — `~/.cursor/mcp.json`:
```json
{ "mcpServers": { "affinity": { "url": "http://localhost:6767/sse" } } }
```
*Windsurf* — `~/.codeium/windsurf/mcp_config.json` (note `serverUrl`):
```json
{ "mcpServers": { "affinity": { "serverUrl": "http://localhost:6767/sse" } } }
```
*Copilot CLI* — `~/.copilot/mcp-config.json`:
```json
{ "mcpServers": { "affinity": { "type": "sse", "url": "http://localhost:6767/sse", "tools": ["*"] } } }
```
*Codex* — needs a proxy (Streamable-HTTP only). Requires [`mcp-proxy`](https://github.com/sparfenyuk/mcp-proxy) (`uvx`/`pipx`):
```bash
codex mcp add affinity -- uvx mcp-proxy --transport sse http://localhost:6767/sse
```

> The server binds IPv6 (`[::1]`). `localhost` resolves to it on macOS; if a
> client forces `127.0.0.1` and fails to connect, that's why — use `localhost`.
> Tool names differ per client (`mcp__affinity__execute_script` in Claude Code,
> `affinity.execute_script` elsewhere); the skill notes this.

## Refresh after an Affinity upgrade
`preflight.sh` does this automatically on skill use (rebuilds when the installed
version no longer matches `sdk/VERSION`). To run it by hand:
```bash
skills/affinity-scripting/refresh-sdk.sh           # rebuild only if version changed
skills/affinity-scripting/refresh-sdk.sh --force   # always rebuild
```

## How it works / what is generated
`preflight.sh` (run first by the skill) → `refresh-sdk.sh` →
1. copies `JSLib` from your Affinity app into `skills/affinity-scripting/sdk/JSLib/`,
2. runs `extract-api.js` to produce `affinity-sdk-api.md` (deterministic
   signature extraction — complete, no LLM),
3. optionally builds a codegraph index under `sdk/JSLib/.codegraph/`.

The generated `sdk/` and `affinity-sdk-api.md` are **git-ignored** — they are
rebuilt locally and never published.

## Repo layout
```
.claude-plugin/plugin.json      # Claude Code plugin manifest
.claude-plugin/marketplace.json # installable via /plugin marketplace add
.mcp.json                       # auto-registers the affinity MCP server
skills/affinity-scripting/
  SKILL.md                      # the skill (works standalone for any agent)
  preflight.sh                  # MCP check + auto build/refresh of the index
  setup.sh, refresh-sdk.sh      # build/refresh the local SDK index
  extract-api.js                # deterministic signature extractor
  sdk/, affinity-sdk-api.md     # generated locally (git-ignored)
```

## Legal
This repository contains only original skill files and tooling (MIT, see
`LICENSE`). It does **not** include the Affinity SDK, which is the property of
Canva / Serif. The SDK is copied from your own licensed installation at setup
time, and all SDK-derived artifacts are git-ignored. Affinity is a trademark of
Canva / Serif; this project is unaffiliated.
