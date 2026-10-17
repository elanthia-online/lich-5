# Lich 5 developer docs

Design notes, protocol references, and API contracts for the lich-5 engine.
Generated API reference (YARD) lives at https://lich-5-docs.elanthia.online/.
These docs cover what YARD doesn't: cross-cutting behavior, wire protocols,
design decisions, and evidence behind them.

Docs are not packaged in releases (`/docs export-ignore`), and changes here
skip the RSpec run in CI.

## Index

| Doc | Kind | Covers |
|---|---|---|
| **Contributing** | | |
| [YARD style guide](contributing/yard-style-guide.md) | Guide | Which methods get docs, required tags, type notation |
| **Scripting API** | | |
| [Events](scripting/events.md) | API | `Events.on/emit/off` script-to-script notifications |
| [Script execution guards](scripting/script-execution-guard.md) | API | Cooperative command/time/cancellation boundaries for supervised scripts |
| [Static map routing](scripting/static-map-routing.md) | API | `Map.dijkstra(static_only: true)` |
| **Engine** | | |
| [Runtime I/O](engine/runtime-io.md) | Behavior | Detachable frontends, `Script#gets` timeouts, socket-read hooks |
| [GTK hardening](engine/gtk-hardening.md) | Behavior | Shared GTK main loop protection and callback retention |
| [SQLite busy timeout](engine/sqlite-busy-timeout.md) | Behavior | 5 s busy timeout on core DB connections |
| **Connection** | | |
| [EAccess protocol](connection/eaccess-protocol-analysis.md) | Protocol research | `eaccess.play.net:7910` command reference |
| [EAccess failure diagnostics](connection/eaccess-failure-diagnostics.md) | Behavior | Stage taxonomy for auth failure log lines |
| [Web login protocol](connection/web-login-protocol-analysis.md) | Protocol research | HTTPS `play.net` fallback auth (`WebLogin`) |
| [WebSocket shim findings](connection/websocket-shim-probe-findings.md) | Protocol research | `--game-transport=websocket`, direct→WS fallback |
| **Frontends** | | |
| [Capability declaration](frontends/capability-declaration.md) | Protocol | `SET_FRONTEND_CAPS` per-client stream rewrites |
| [Saved frontend editing](frontends/saved-frontend-editing.md) | Behavior | Launcher frontend assignment, `frontends.yml` |
| **XML stream** | | |
| [Saga stream: deferred items](xml-stream/saga-stream-deferred.md) | Tracking | Unverified/parked items for the Saga dialect |
| **Dependency recovery** | | |
| [Windows: R4L5 gem manifest](dependency-recovery/windows-r4l5-gem-manifest.md) | Behavior | Manifest-driven missing-gem repair |
| [macOS: Bundler recovery](dependency-recovery/macos-bundler-recovery.md) | Behavior | Transactional Bundler repair of default gems |
| **GemStone** | | |
| [Creature health API](gemstone/creature-api.md) | API | Exact `health`/`maxhealth` from `<crtrStatus>` |
| [Combat defs onboarding](gemstone/combat/defs-onboarding.md) | Guide | Extending the combat def grammar from log evidence |
| [Combat observation provenance](gemstone/combat/observation-provenance.md) | API | `event[:source]` / `observation_batch` contract |

**Kind:** *API*: a contract scripts can rely on. *Behavior*: how the engine
acts, for maintainers. *Protocol*: a wire format. *Research*: findings from
live probing that can go stale. *Tracking*: open-item log. *Guide*: how-to.

## Adding a doc

- Put it in the folder for the subsystem it describes. Folders follow `lib/`:
  game-specific docs go under `gemstone/` or `dragonrealms/`. Make a new
  folder only when an existing one doesn't fit; one-doc folders are fine
  for game namespaces, otherwise prefer the nearest existing folder.
- File names are lowercase kebab-case and don't repeat the folder name.
- Add a row to the index above.
- Link other docs with relative paths (`../connection/eaccess-protocol-analysis.md`).
  From code comments, reference the repo-root path (`docs/connection/...`).
- Moving a doc? Grep for its old path first: code comments in `lib/` and
  `spec/` cite docs by path.
