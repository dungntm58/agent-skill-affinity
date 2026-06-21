---
name: affinity-scripting
description: Use when scripting Affinity Designer, Photo, or Publisher (v3.2+, by Canva) through the affinity MCP server — calling mcp__affinity__execute_script, creating or editing documents, adding shapes/text/fills, rendering spreads, or looking up the JavaScript SDK. Skip the slow doc-spelunking; this maps the API.
---

# Affinity Scripting (affinity MCP, JS SDK)

Drive Affinity v3.2+ via the `affinity` MCP server (SSE, `http://localhost:6767/sse`). The app must be open with a document. `execute_script` runs JavaScript against the live app.

## Preflight — run FIRST (once per session)
Before any Affinity work, run the preflight script from this skill's directory (`$SKILL` = the folder containing this SKILL.md):
```
"$SKILL/preflight.sh"
```
It verifies the MCP server is reachable and **auto-builds/refreshes the local SDK index** if missing or stale (e.g. after an Affinity upgrade). Fast no-op when current. If it reports the MCP server unreachable, fix that (enable it in Affinity Settings, keep a doc open) before scripting.

## Hard rules (from preamble)
- **Read `preamble` once per session** before `execute_script`: `read_sdk_documentation_topic(preamble)`. Server enforces it.
- **`search_sdk_hints` BEFORE experimenting** — fast global solution pool. **`add_sdk_hint` after** solving by experiment (note: writes to a shared global pool — ask the user first).
- Scripts return **nothing** — use `console.log()` for all output.
- `require('/file.js')` form (leading slash). SDK file omittable: `'/shapes'` == `'/shapes.js'`.
- Coordinates are **document pixels**. Default new doc = A4 @ 300dpi = 2480×3508 px. `1mm = dpi/25.4 px`, `1pt = dpi/72 px`.
- **Don't `module.exports.main`** — scripts run directly. Drop the example boilerplate.
- Set current spread before editing **only if not already current** (setting it clears selection). A freshly created/current doc is already current — just `doc.addNode()`.
- `NOT_ALLOWED` error = user disabled AI / filesystem / network in Affinity settings. Filesystem is Desktop-only (`app.userDesktopPath`).
- Enums expose `keys`/`values`/`entries` as **properties, not methods**. Value ranges live in `param_ranges.min.json`, `struct_ranges.min.json`, `struct_array_sizes.min.json`.

## Fast API lookup (use these FIRST — skip the MCP doc reads)
A complete local index of the SDK is built by `setup.sh`. All paths below are **relative to this skill's own directory** (`$SKILL` = the folder containing this SKILL.md). Reach for these before `read_sdk_documentation_topic`:

1. **Signature reference** — `$SKILL/affinity-sdk-api.md`. Every class + method/static/getter/setter signature for all ~62 SDK files, 400+ classes. Grep it:
   `grep -n 'createSetCurrentSpread' "$SKILL/affinity-sdk-api.md"`
   The `## <file>` heading tells you the `require('/<file>')` path.
2. **codegraph** (if installed) — full source, callers/callees, impact. Indexed at `$SKILL/sdk/JSLib`. Query with the **absolute** path of that dir as `projectPath`:
   `codegraph_node(symbol, projectPath:"<abs>/sdk/JSLib")`, also `codegraph_search` / `codegraph_explore` (includeCode for verbatim source).
3. **Raw source** — `$SKILL/sdk/JSLib/<file>.js` (read/grep directly; a copy of the app's JSLib).

**First time / missing index:** if `affinity-sdk-api.md` or `sdk/` is absent, run `$SKILL/setup.sh` once (needs Affinity v3.2+ installed + node).

Only fall back to `read_sdk_documentation_topic` / `search_sdk_hints` if the index lacks something (e.g. native enum values, or examples). Enum values are NOT in the reference — they're native; read them at runtime via `Enum.keys/.values/.entries`.

**Staleness / refresh:** the index is a snapshot (version in `sdk/VERSION`). After an Affinity upgrade run `$SKILL/refresh-sdk.sh` (`--force` to rebuild regardless). If live `app.version` differs from `sdk/VERSION`, the index is stale.

> Tool-call syntax (`grep`, `codegraph_*`, `mcp__affinity__*`) is written in Claude Code form; adapt to your agent's equivalents. The MCP tool names themselves (`execute_script`, `read_sdk_documentation_topic`, …) are defined by the Affinity server and identical across agents.

## Which file has what
| Need | `require` | Key exports |
|------|-----------|-------------|
| App, version, Desktop path, alert | `/application` | `app` |
| Document, new-doc options, presets | `/document` | `Document`, `NewDocumentOptions`, `DocumentPreset`, `RasterFormat` |
| Node definitions (shape/text/table) | `/nodes` | `ShapeNodeDefinition`, `FrameTextNodeDefinition`, `TableTextNodeDefinition` |
| Shapes (rect/ellipse/star/QR…) | `/shapes` | `ShapeRectangle`, `ShapeEllipse`, `ShapeStar`, `ShapePolygon` |
| Fills, blend modes | `/fills` | `FillDescriptor`, `SolidFill`, `GradientFill`, `BlendMode` |
| Colours | `/colours` | `RGBA8`, `RGB8`, `CMYK8`, `HSLf`, `SVG11`, `Colour`, `Gradient` |
| Geometry | `/geometry` | `Rectangle`, `Point`, `Size`, `Transform`, `Curve`, `CurveBuilder` |
| Text content | `/storybuilder.js` ⚠ | `StoryBuilder` (wrapper with `.handle`) |
| Text styling deltas | `/story`, `/storydelta`, `/glyphatts`, `/fonts` | `StoryDelta`, `FontWeight`, `HardBreakType` |
| Commands / batched adds | `/commands` | `DocumentCommand`, `AddChildNodesCommandBuilder`, `CompoundCommandBuilder` |
| UI dialogs | `/dialog` | `Dialog`, `DialogResult` |
| Selections | `/selections` | `Selection`, `TextSelection` |
| Network / FS | `/network`, `/fs` | `HttpRequest`, `RequestMethod` |
| Blend mode enum | `affinity:common` | `BlendMode` |

⚠ **`StoryBuilder` must come from `/storybuilder.js`** (wrapper exposing `.handle`), NOT `affinity:story` (raw API) — `createFromStoryBuilder` needs the wrapper.

## Document basics
```js
const { Document, NewDocumentOptions } = require('/document');
const { app } = require('/application');
const doc = Document.create(NewDocumentOptions.createDefault()); // A4 300dpi; or Document.current
doc.sessionUuid;                       // pass to render_spread
doc.widthPixels; doc.heightPixels; doc.dpi; doc.format;
doc.spreadCount; doc.currentSpread; doc.layers; // .length, .first
doc.addNode(def);                      // adds to current spread
```

## Add a coloured rectangle + text (verified)
```js
const { Document } = require('/document');
const { RGBA8, SVG11 } = require('/colours');
const { BlendMode } = require('affinity:common');
const { FillDescriptor } = require('/fills');
const { ShapeRectangle } = require('/shapes');
const { ShapeNodeDefinition, FrameTextNodeDefinition } = require('/nodes');
const { StoryBuilder } = require('/storybuilder.js');     // wrapper!
const { Rectangle } = require('/geometry');

const doc = Document.current;

// rectangle
const fill = FillDescriptor.createSolid(RGBA8(220, 40, 40), BlendMode.Normal);
const rect = ShapeNodeDefinition.create(
  ShapeRectangle.create(), new Rectangle(60, 60, 480, 240), fill, null, null, null);
doc.addNode(rect);

// text frame
const sb = StoryBuilder.create().setToFrameTextDefaultStyle(doc.dpi, doc.format);
sb.addText('Scripting works ✓');
const text = FrameTextNodeDefinition.createFromStoryBuilder(new Rectangle(60, 340, 480, 120), sb);
doc.addNode(text);

console.log('layers:', doc.layers.length, 'uuid:', doc.sessionUuid);
```
Then render to confirm: `render_spread(document_session_uuid = <uuid>, spread_index = 0)`.

## Shapes & geometry
- `new Rectangle(x, y, width, height)` — top-left origin + size, in document px (NOT corner coords). Used both as a shape's bounding box and a text frame's box.
- Every shape class uses a zero-arg factory: `ShapeRectangle.create()`, `ShapeEllipse.create()`, `ShapeStar.create()`, etc. The shape is sized/placed by the `Rectangle` you pass to `ShapeNodeDefinition.create(shape, rect, …)` — it inscribes in that box (square box + ellipse = circle). So swap the shape, keep the same call shape.

## Colours
`RGBA8(r,g,b,a=255)`, `RGB8`, `CMYK8`, `HSLf`, plus `SVG11.red`/`.blue`/`.steelblue`/`SVG11.random()`. `FillDescriptor.createSolid(colour, BlendMode.Normal)`. `ShapeNodeDefinition.create` auto-wraps a bare `Colour` brushFill, but passing a `FillDescriptor` is explicit and safe.

## Common workflow
1. `read_sdk_documentation_topic(preamble)` (once).
2. `search_sdk_hints("how do I …")` before guessing.
3. Unknown class/signature? **grep `affinity-sdk-api.md`** or query codegraph (see "Fast API lookup"). MCP doc read only as last resort.
4. `execute_script` (always `console.log` results).
5. `render_spread(uuid, index)` to verify visually.
6. Happy? `save_script_to_library(title, description, code)` to persist.

## Gotchas
- No `console.log` → no output at all.
- `StoryBuilder` from the wrong module → `createFromStoryBuilder` fails.
- Re-setting the current spread wipes the selection.
- Shapes have no default `name` (`doc.layers.first.name` may be `undefined`) — that's fine.
- Use `createDefault`/`create` factory methods when a class has them; else `new`.
