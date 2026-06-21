# affinity-scripting — an agent skill for scripting Affinity (by Canva)

A portable [agent skill](https://agentskills.io/specification) for driving
**Affinity Designer / Photo / Publisher v3.2+** through its built-in MCP server
and JavaScript SDK. It gives any compatible AI coding agent fast, complete API
lookups instead of slow trial-and-error against the SDK docs.

Works with any agent that supports the `SKILL.md` standard — **Claude Code,
Codex, Gemini CLI, GitHub Copilot CLI**, and others.

## What it gives the agent
- **Verified patterns** for the common operations (create a document, add
  shapes / text / fills, render a spread) — copy-paste ready.
- **A complete signature reference** (`affinity-sdk-api.md`) — every exported
  class + public method/static/getter/setter across the ~62 SDK files
  (400+ classes), grep-able in one file.
- **A codegraph index** (optional) of the SDK for full source, callers,
  callees, and impact queries.
- **The doc-file map, hard rules, and gotchas** distilled from the SDK preamble.

## Requirements
- **Affinity v3.2+** installed, with its **MCP server enabled** in
  Settings → enable "MCP Server" / AI connector (serves `http://localhost:6767/sse`).
- Your agent connected to that MCP server (see below).
- **Node.js** (for the signature parser used at setup).
- **codegraph** CLI — *optional*, enables source/call-graph queries:
  `npm i -g @codegraph/cli`.

## Install

Clone into your agent's skills directory **as a folder named `affinity-scripting`**
(the skill's `name`), then run setup once:

```bash
# Claude Code
git clone https://github.com/dungntm58/agent-skill-affinity ~/.claude/skills/affinity-scripting
~/.claude/skills/affinity-scripting/setup.sh

# Codex / agents using ~/.agents/skills
git clone https://github.com/dungntm58/agent-skill-affinity ~/.agents/skills/affinity-scripting
~/.agents/skills/affinity-scripting/setup.sh
```

| Agent | Skills directory |
|-------|------------------|
| Claude Code | `~/.claude/skills/` |
| Codex | `~/.agents/skills/` (or `~/.codex/skills/`) |
| Gemini CLI | per its skills/extensions config |
| Copilot CLI | auto-discovered from installed plugins |

`setup.sh` copies the SDK from your installed Affinity app, builds the
signature reference, and (if codegraph is installed) indexes the SDK.

### Connect the Affinity MCP server
The skill drives Affinity through its MCP server. In Affinity: Settings →
enable **MCP Server**, grant the permissions you need (FileSystem / Network /
Canva-AI). Then register it with your agent, e.g. for Claude Code:

```bash
claude mcp add -s user --transport sse affinity http://localhost:6767/sse
```

Other agents: add an SSE MCP server pointing at `http://localhost:6767/sse`.

## Refresh after an Affinity upgrade
```bash
./refresh-sdk.sh           # rebuilds only if the installed version changed
./refresh-sdk.sh --force   # always rebuild
```

## How it works / what is generated
`setup.sh` → `refresh-sdk.sh` →
1. copies `JSLib` from your Affinity app into `sdk/JSLib/`,
2. runs `extract-api.js` to produce `affinity-sdk-api.md` (deterministic
   signature extraction — complete, no LLM),
3. optionally builds a codegraph index under `sdk/JSLib/.codegraph/`.

The generated `sdk/` and `affinity-sdk-api.md` are **git-ignored** — they are
rebuilt locally and never published.

## Legal
This repository contains only original skill files and tooling (MIT, see
`LICENSE`). It does **not** include the Affinity SDK, which is the property of
Canva / Serif. The SDK is copied from your own licensed installation at setup
time, and all SDK-derived artifacts are git-ignored. Affinity is a trademark of
Canva / Serif; this project is unaffiliated.
