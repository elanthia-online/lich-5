# Genie Scripting Engine → Lich + Lichborne (Design & Roadmap)

> Status: **design / pre-implementation**. This document is the authoritative plan for
> porting the Genie4 scripting engine so that **Genie scripts run end-to-end on Lich +
> Lichborne** (and any other front-end that implements the hook protocol).

## Context

Three repositories, three languages:

| Repo | Path | Language | Role |
|---|---|---|---|
| **Genie4** | `~/repos/Genie4` | C# / .NET WinForms (~77k LOC) | Existing DragonRealms front-end **with** the scripting engine we are porting |
| **lich-5** | `~/repos/lich-5` | Ruby (~197k LOC) | Middleware proxy + scripting host — **new home of the ported engine** |
| **Lichborne** | `~/repos/Lichborne` | TypeScript / Electron / React (~62k LOC) | DragonRealms front-end — **new home of the ported front-end behaviors** |

**Goal:** run a real Genie script unmodified, end-to-end, across Lich (automation) +
Lichborne (front-end effects). **Constraint:** do not introduce a new *source language*
into any project (no C# in Lich, no Ruby in Lichborne). Where a Genie feature *inherently*
executes another language (its `js`/`jsblock` verbs run real JavaScript), that runtime is a
dependency of the script format, not a new project source language — see Decision 2.

Genie splits cleanly into two command namespaces, which map onto our two target repos:

- **Script verbs** (`Script/Script.cs`, `ScriptFunctions` enum @ line 555; dispatch in
  `RunScriptRow` @ 2472) — the *automation language*: `put`, `send`, `match`, `matchwait`,
  `waitfor`, `waitforre`, `gosub`/`return`, `goto`, `if`/`elseif`/`else`, `while`, `counter`,
  `timer`, `random`, `math`, `eval`, `var`, `action`, `pause`, `move`, `nextroom`, … → **Lich**.
- **Bar commands** (`Core/Command.cs`, ~287 `case`s) — mostly *front-end effects*:
  `highlight`, `macro`, `alias`, `gag`, `sub`, `trigger`, `window`, `preset`, `class`,
  `layout`, `playsound`, `link`, `image`, … → **Lichborne** (via the hook protocol).

## Architectural decisions (locked)

1. **Engine = clean-room embedded interpreter, NOT a transpiler.**
   Lich already has `WizardScript` (`lib/common/script.rb:3084`), a line→Ruby transpiler for
   the older Wizard DSL. We are **not** using or extending it. Genie's control flow (block
   `if/elseif/else`, `while`, `gosub/return`, `goto`, `matchwait`, async `action` triggers,
   an expression evaluator) is too rich to transpile faithfully — goto mixed with structured
   blocks does not survive translation to Ruby. Instead we port Genie's **state machine**
   (`Script.cs` + `Eval.cs` + `MathEval.cs`) to Ruby as its own subsystem. It runs on a Lich
   worker thread and reuses Lich's per-script buffer / pause / kill plumbing, but the
   interpreter *design* owes nothing to `WizardScript`.

2. **JavaScript (`js`/`jscall`/`jsblock`) = embed a real JS engine in Lich.**
   Genie executes real ECMAScript via the bundled Jint. The only faithful option is to
   execute real JS — a Ruby remap changes semantics. Plan: embed a JS runtime
   (`mini_racer`/V8, or a QuickJS binding) behind a thin adapter mirroring Genie's Jint host
   bindings (`echo`, `put`, `getGlobal`/`setGlobal`, `getVar`/`setVar` — see
   `Script.cs InitJintEngine` @ 710). Lua in Genie is only a stub → lowest priority / deferred.
   *Risk to track:* native dependency in Lich; gate behind a capability check so core DSL
   works even if the JS engine is unavailable.

3. **Front-end effects = a front-end-agnostic hook protocol; fidelity is the front-end's job.**
   Lich stays front-end agnostic (as it already is). Where a Genie script touches a Genie
   *front-end* feature (highlights, macros, named windows, gauges, class/preset coloring,
   playsound, echo-to-window), Lich emits a complete, self-describing **`<genieHook>`** event
   carrying enough Genie semantics for *any* front-end to reproduce the effect exactly. Lich does
   **not** implement or render the effect, and contains **no** front-end-specific code. Each
   front-end chooses how faithfully to render. **Lichborne is "first among many":** we design the
   protocol to be easy for Lichborne to adopt and will collaborate with the Lichborne devs, but
   **no Lichborne code is written in this effort** (see Scope below). The burden this places on
   us is protocol design — the hooks must be rich, versioned, and well documented. Canonical
   spec: `docs/genie-engine/hook-protocol.md`.

4. **Execution model = Option A: Lich-native thread (behavioral-fidelity bar).**
   `GenieScript < Script` runs on its own Lich worker thread; the interpreter is a
   read-next-line loop (blocking with deadline-based timeouts) that dispatches async actions +
   match tests + state transitions. Reuses Lich's full script lifecycle and participates in the
   command broker (Decision 5). **Acceptance criterion:** the choice of execution model must be
   invisible to end users — a corpus of real Genie scripts must produce identical *observable*
   behavior (command output, send timing / RT waits, action firing order, loop-guard thresholds).
   Genie's 10ms tick granularity is not user-observable and is not a fidelity requirement.

5. **Pacing = client of Lich's command broker** (see Open questions). Genie keeps its
   *sequencing* semantics (`put`/`send`/`do`, matchwait interaction) in the interpreter; the
   socket write + RT-respecting release + cross-script serialization go through the broker.

6. **`gag`/`sub` = applied in Lich's downstream stream (Model A), NOT via hooks.**
   `gag`/`ignore` and `sub`/`substitute` are implemented as a `DownstreamHook` in Lich, which
   rewrites/suppresses lines on the client-bound stream. This is universal (works on any
   front-end with zero front-end code) and preserves the original stream everywhere it matters:
   the hook runs at `games.rb:915`, *after* the raw line is pushed to `$_SERVERBUFFER_`
   (`games.rb:901`) and delivered to all scripts via `new_downstream` (`games.rb:912`). So
   `reget`/`regetall`, other scripts, and the `log.lic` transcript all still see the original
   line; only the client display (and any front-end-side transcript) is affected. Trade-off: a
   gag is global across all attached clients rather than per-client as in monolithic Genie
   (identical for the solo-client case). Other front-end effects (highlights, windows, gauges,
   sounds, macros, colors) remain `<genieHook>` emissions per Decision 3.

7. **Persistence = Genie's own config files (NOT the Lich DB).** We reuse Genie's whole model:
   a Genie-style `Config/` directory is the source of truth. `variables.cfg` is lines of
   `#var {key} {value}` (parsed by `Utility.ParseArgs`, already ported as `Text.parse_args`;
   `#var` writes lines, `#tvar` does not -- matches Genie's `bSaveToFile`). This gives
   **zero-migration** (drop in an existing Genie `Config/`), faithful scope (the shared file IS
   the account-wide/cross-character store, matching Genie's global `variables.cfg`), and one
   parser that later also feeds the front-end hook layer (highlights/macros/aliases/gags/subs/
   presets/classes/names all use the same `#command {args}` line format).
   - `%local` -> per-script in-memory (done).
   - `#tvar` -> session in-memory, cross-script (not written to file).
   - `#var` -> in-memory + persisted to `Config/variables.cfg` (account-wide, cross-character).
   - `#svar` -> emulated as persistent (variables.cfg or a sibling file); server sync later.
   - reserved (`$health`, ...) -> live from `XMLData`, read-only.
   Bridges: **multi-character** is the default (shared `Config/` dir). **Lich<->Genie** stays an
   opt-in mirror to `UserVars` (now lower priority; Genie config is self-contained).
   Config-dir location: a Lich setting `Lich::Genie.config_dir` (default
   `<SCRIPT_DIR>/GenieProfiles`), mirroring Genie's structure:
   - `GenieProfiles/Config/variables.cfg` -> account-wide globals (matches Genie's hardcoded
     global `Config/variables.cfg`).
   - `GenieProfiles/Config/*.cfg` -> shared front-end model (highlights/macros/... later).
   - `GenieProfiles/<game>-<char>/*.cfg` -> per-character profile overrides (later; matches
     Genie's per-profile ConfigDir for everything except variables).
   Genie's split: `variables.cfg` is always account-wide; all other `.cfg` are per-profile
   (per-character) when profiles are used, else shared. Globals shared across concurrent Genie
   scripts via a per-character in-memory `GlobalStore` synced to the file (load on start;
   read+write with atomic write + reload-on-mtime for cross-process safety).
   Build order: read+write `variables.cfg` first (unblocks config-driven scripts), then extend
   the parser to the other `.cfg` types as the hook layer lands.

## Target architecture

```
  Genie script file (.cmd, engine on)          ANY front-end (Lichborne = first)
        │                                          ▲   parses <genieHook .../>
        ▼                                          │   → its own renderer
  ┌───────────────────────────────┐    hook tags  │   (highlights, windows, gauges,
  │  Lich: Genie engine            │──────────────►│    classes/presets, playsound…)
  │  (lib/genie/…)                 │  via $_CLIENT_ │
  │  • lexer/line-parser           │               │
  │  • interpreter (PC + block/    │◄──────────────┘   user input / game XML
  │    call stack, actions)        │   downstream game stream (existing Lich pipeline)
  │  • Eval + MathEval (ported)    │
  │  • verb handlers ──────────────┼──► existing global_defs API (put/waitfor/matchwait/…)
  │  • JS bridge (mini_racer)      │        + XMLData (reserved vars) + Vars/Settings
  │  • #command router (Command.cs │
  │    port: engine vs FE-hook)    │
  └───────────────────────────────┘
```

Two data planes:
- **Automation plane** (in Lich): the interpreter runs on a Lich thread, blocks on the
  per-script downstream buffer for `waitfor`/`matchwait`, sends to the game via `Game.puts`.
  This *replaces* Genie's 10ms cooperative `TickScript` loop with Ruby's thread-per-script
  model — blocking reads instead of polling. No functional change to script semantics.
- **Front-end plane** (Lich → FE): front-end-directed verbs emit **client-agnostic hook
  tags** on the downstream stream to `$_CLIENT_`; the FE applies them.

## Client-agnostic hook protocol (draft)

Reuse the existing XML downstream pipeline (Lich already sends XML verbatim to XML
front-ends; Lichborne's `StormFrontParser.ts` already tag-parses). Define one namespaced tag:

```
<genieHook op="highlight" args='{"pattern":"kobold","color":"#ff0000","class":"combat"}'/>
<genieHook op="window"    args='{"name":"thoughts","action":"create"}'/>
<genieHook op="playsound" args='{"file":"alert.wav"}'/>
<genieHook op="var"       args='{"scope":"global","name":"foo","value":"bar"}'/>  (for FE var displays)
```

This section is a summary; the **canonical, shareable spec lives in
`docs/genie-engine/hook-protocol.md`** (the artifact we hand to front-end developers).

Design principles (front-end agnostic):
- **Emitted by Lich** whenever a Genie script or `#command` issues a front-end verb. New
  emitter alongside `send_to_client` (`games.rb:1122`) / `respond` (`global_defs.rb:1802`).
- **Self-describing & complete.** Each hook carries the full Genie semantics for its effect
  (e.g. a highlight hook includes pattern, color, class, match-scope, regex-vs-literal) so a
  front-end can reproduce Genie behavior *without* re-deriving anything. Payloads are versioned.
- **Consumed by any front-end.** Lich contains no per-front-end logic. Front-ends opt in.
- **Capability negotiation & graceful degradation.** Add a `Frontend` capability (e.g.
  `:genie_hooks`) to the existing registry (`lib/common/front-end.rb`). The tag is namespaced so
  a front-end that does not understand it safely ignores it; a script's automation still runs
  even if no front-end renders its front-end effects. Optionally suppress emission to
  non-capable front-ends.
- **Naming collision warning:** Lich already uses `$frontend == 'genie'` to mean *the Genie
  client*. Keep the engine namespace `Lich::Genie` and tag `<genieHook>` clearly distinct from
  that `'genie'` frontend string.

## Verb mapping table ("map up front" — the reduced implementation footprint)

Every Genie verb resolves to one of: **(D)** thin adapter over existing Lich API,
**(N)** new Ruby logic ported from Genie, **(H)** front-end hook, **(J)** JS bridge.

| Genie verb(s) | Target | Notes / Lich anchor |
|---|---|---|
| `put`, `send`, `do` | D+N | `put`/`send` → `Game.puts`/`fput`. `do` re-parses `#command`/aliases (port that path). |
| `move`, `nextroom` | D | `move` (`global_defs.rb`), room-change wait via `XMLData.room_id`. |
| `waitfor`, `waitforre` | D | `waitfor`/`waitforre` (`global_defs.rb:1531`). Verify regex dialect parity. |
| `match`, `matchre`, `matchwait` | D | `match`/`matchre`/`matchwait` (`global_defs.rb:1502`). |
| `wait`, `waiteval` | D+N | `wait` (prompt). `waiteval` needs ported `Eval`. |
| `pause`, `delay` | D | `pause` (`global_defs.rb`). |
| `goto`, `gosub`, `return` | N | Interpreter PC + call stack (Genie `CurrentLine.oLineList`). Not Lich labels. |
| `if`/`elseif`/`else`, `while`, `{`/`}` | N | Interpreter block stack (`BlockState`). Uses ported `Eval`. |
| `eval`, `evaluate` | N | Port `Eval.cs` (boolean/string expression evaluator). |
| `math`, `evalmath`, `counter` | N | Port `MathEval.cs` (arithmetic). |
| `random` | N | Ported RNG semantics. |
| `timer` | N | Ported timer state. |
| `var`/`setvar`/`unvar` (local) | N | Script-local var store (`ClassVariableList`). |
| `var` (global) | D | Lich `Vars`/`UserVars` (SQLite, char-scoped). Map `#svar`/`#tvar` scopes carefully. |
| reserved vars (roundtime, standing, stunned, hands, spell…) | D | Read from `XMLData` / DR `DRParser`; mirror Genie's `SetDefaultGlobalVars` names. |
| `action` (async triggers) | N | Port `ClassActionList`; evaluate per incoming line (model on `Watchfor`, but Genie-exact). |
| `shift`, `include`, `exit`, `label:` | N | Interpreter mechanics. |
| `echo` | H+N | To main window vs named window → hook; local echo → `echo`/`respond`. |
| `js`, `javascript`, `jscall`, `jsblock` | J | mini_racer bridge (Decision 2). |
| `plugin`, `pluginscript` | N (later) | Genie plugin host; defer, decide parity. |
| `gag`/`ignore`, `sub`/`substitute` | D | **Model A:** implemented as a Lich `DownstreamHook` (stream-side), not a hook. See Decision 6. |
| **Bar `#commands`**: `highlight`, `macro`, `alias`, `trigger`, `window`, `preset`, `class`, `layout`, `playsound`/`playwave`, `link`, `image`, `beep`/`flash` | H | Emit `<genieHook>` with full Genie semantics; any front-end renders it. |
| **Bar `#commands`** (engine-side): `var`, `eval`, `math`, `script`/`load`/`reload`, `pause`/`resume`/`abort` | D+N | Handled in Lich's ported `#command` router. |
| **Bar `#commands`** (connection): `connect`, `lconnect`, `disconnect` | drop | Lich owns the connection. |

## Lich module layout (proposed)

```
lib/genie/
  engine.rb          # Lich::Genie::Engine — GenieScript < Script; thread body runs interpreter
  lexer.rb           # line parser / ScriptFunctions classifier (port GetFunctionType/AppendString)
  interpreter.rb     # PC, block stack, call stack, RunScriptRow dispatch
  verbs/             # one module per verb group (flow, io, vars, match, math, action…)
  eval.rb            # port of Script/Eval.cs (boolean/string expressions)
  math_eval.rb       # port of Script/MathEval.cs (arithmetic)
  variables.rb       # local + global + tvar/svar scopes, mapped to Vars/Settings
  reserved_vars.rb   # bridge Genie reserved vars → XMLData / DRParser
  command_router.rb  # port of relevant Core/Command.cs: engine verbs vs FE-hook emit
  hooks.rb           # <genieHook> emitter (client-agnostic)
  js_bridge.rb       # mini_racer adapter mirroring Jint host bindings
```

Selection: gated by a Lich setting **`Lich::Genie.enabled`** (default **off**).
- **Off (default):** current behavior — `.cmd` and `.wiz` → `WizardScript`.
- **On:** `.cmd` → the Genie engine (`GenieScript`); **`.wiz` handling is disabled entirely**
  (not routed to Genie, not to WizardScript). The two engines are mutually exclusive.

Wire the toggle into the three script resolvers (`@@elevated_script_start`,
`Script.__find_script_file`, `@@elevated_exists` in `lib/common/script.rb`): when enabled, route
`.cmd` to `GenieScript` and make `.wiz` a no-op/error. Reuse `Script`'s thread/buffer/pause/kill;
override the run body.

## Scope: Lich only (front-ends deferred)

This effort ships **only Lich-side code**: the engine + the `<genieHook>` emitter + the
front-end-agnostic protocol spec. **No front-end code is written here.** Front-end rendering of
Genie effects is each front-end's responsibility, handed off via `docs/genie-engine/hook-protocol.md`.

Lichborne is the reference consumer ("first among many") and we will collaborate with its
maintainers, but Lichborne implementation is out of scope. The `~/repos/genie-port/Lichborne`
worktree is parked for later hand-off. Guidance for *any* front-end implementer (informational,
not a task list): map hook ops to the front-end's own highlight/window/gauge/color facilities;
common gaps to expect are user-defined gauges and live on-screen variable displays.

## Phased roadmap

- **Phase 0 — Foundations & spec.** Finalize naming, file extension, hook tag schema; set up
  a dedicated git branch; assemble a corpus of real Genie scripts as test fixtures.
- **Phase 1 — Interpreter core (Lich).** Lexer + PC/block/call stacks + `goto`/`gosub`/`if`/
  `while`; verbs that delegate (`put`/`send`/`waitfor`/`matchwait`/`pause`/`move`). A linear
  Genie script runs and sends commands to the game. *Milestone: a trivial hunting loop runs.*
- **Phase 2 — Expressions & state.** Port `Eval.cs` + `MathEval.cs`; `math`/`counter`/`eval`/
  `waiteval`/`random`/`timer`; local + global + tvar/svar variables; reserved vars from
  `XMLData`. *Milestone: conditional/looping scripts with math run correctly.*
- **Phase 3 — Actions & command router.** Async `action` triggers; port the engine half of
  `Command.cs`; `do`/alias re-parse path. *Milestone: trigger-driven scripts run.*
- **Phase 4 — Hook protocol + emitter (Lich only).** Finalize `docs/genie-engine/hook-protocol.md`
  (versioned op catalog + payloads), implement the `<genieHook>` emitter, add the `:genie_hooks`
  `Frontend` capability + graceful degradation. *Milestone: front-end verbs emit well-formed,
  complete hooks on the downstream stream (verified by fixtures), with automation unaffected when
  no front-end consumes them.* Front-end rendering is handed off, not built here.
- **Phase 5 — JS bridge.** mini_racer adapter + Jint host bindings; `js`/`jsblock`/`jscall`.
- **Phase 6 — Fidelity & hardening.** Infinite-loop detection (`LOOP_*` limits), broker-mediated
  round-time/pacing parity, plugins (decide scope), broad fixture regression pass.

## Testing strategy

- **Fixture corpus:** collect real Genie scripts (linear, conditional, math, action-driven,
  JS) under `spec/fixtures/genie/`.
- **Unit:** RSpec for `Eval`/`MathEval` against Genie's documented behavior; verb handlers
  with a stubbed game socket.
- **Integration:** drive the interpreter against a mock downstream buffer feeding canned game
  XML; assert emitted commands and `<genieHook>` tags (front-end-agnostic — assert the wire
  bytes Lich emits, no front-end needed).
- **End-to-end:** run a fixture script under a live/replayed Lich session with a capturing test
  client; verify automation output (commands to game) *and* the `<genieHook>` stream to the
  client. Real front-end rendering is validated separately by each front-end.

## Open questions / risks

- **Regex dialect parity** (.NET `Regex` → Ruby `Regexp`) for `match`/`action`/highlights.
- **`#svar` (server vars)** — Genie syncs these account-wide; Lich has no server-var store.
  Decide: local-only emulation vs new sync mechanism.
- **Round-time / command-queue pacing — DECIDED: Genie engine is a *client* of Lich's command
  broker, not a second pacer.** Genie internalizes broker-like concerns (RT gating ≈ `waitrt?`,
  the `put`/`send`/`do` queue, and the send-history loop-guard ≈ kill-switch), but at per-script
  scope. Lich's broker is process-wide arbitration of the shared socket. To avoid two authorities
  fighting over the socket: keep Genie *sequencing* semantics (`put`/`send`/`do`, matchwait
  interaction, per-script ordering) inside the interpreter, but delegate the actual socket write +
  RT-respecting release + cross-script serialization to the broker (`SendText` → broker
  submission, alongside `DRC.bput`). Map Genie's runaway-loop guard onto the broker's existing
  kill-switch/instrumentation rather than duplicating it. Open sub-item: does Genie's exact RT
  timing survive broker mediation, or do we need a Genie-compat release policy in the broker?
- **Plugin parity** (`IPlugin`/`IHost`) — port or drop for v1.
- **Extension/naming — DECIDED:** keep `.cmd`, gated by `Lich::Genie.enabled` (default off);
  when on, `.cmd` → Genie engine and `.wiz` is disabled. Namespace `Lich::Genie`, tag
  `<genieHook>` (kept distinct from the existing `'genie'` frontend string).
