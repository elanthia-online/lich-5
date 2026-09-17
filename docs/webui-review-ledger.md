# WebUI review ledger, 2026-09-16

Every finding from every review of the WebUI stack (PRs #1634-#1644 plus
the unpushed branches 11-13), with its status at `webui/13-audit-fixes`.
Sources:

- **R1** — mrhoribu's per-PR GitHub reviews (2026-09-16 19:38-19:39).
- **R2** — mrhoribu's second-pass issue comments (2026-09-16 20:34-20:37,
  "no Ruby toolchain").
- **R3** — the third review, F1-F13 (2026-09-16, base `ed662ca7`, tip
  `29f28fd6`).
- **CR** — the combined stack review (`combined-review-lich5-webui-stack.md`).
- **DA** — Doug's 5.22.0 audit: `branch-issues.md` (W01-W13) and
  `architecture.md` (six decisions).
- **SR** — the stack's own `docs/webui-review-2026-09-16.md` (ten findings).

Status vocabulary: **fixed** (commit named; every fix has a spec that was
run red first unless noted), **closed here** (this ledger's batch),
**moot** (the code it described no longer exists), **answered** (a
question, answered in the PR thread), **decision** (needs the user; see
part 2), **out of scope** (core code the stack never touched).

## Part 1 — every item

### Blockers, Majors, P1 and P2

| src | item | status |
|---|---|---|
| R1/R2/CR | `TreeIter#next!` corrupts the store (iter_first, append/prepend/insert, each) | fixed `18706d93`, `2faa9091` |
| R3 F2 | selection iterators alias the model | fixed `8669d39b` |
| R1 | "mutators return self" false for 829 setters | fixed `1e31db0f` (`Setters.def_setter`) |
| R1/R2 | no `const_missing`; then acronym names misclassified | fixed #1636, `e2bbb5a1` |
| R1/R2/CR | `Dialog#run` hangs: tab close, shutdown, concurrent run, destroy | fixed `2faa9091`; R3 F4 shutdown `52c677a9` |
| R2 | `Dialog#run` never drains `@responses` | fixed `a1cbb6af` |
| R1/CR/R3 F1/DA W12 | stale-generation retry loops / replays the wrong event / cannot meet the server protocol | fixed `648a0d40`, `140c4681`, `da1cfd3b` |
| R1 #1639 | `Runtime#page_refresh_lock` leak | fixed `62ea172b` |
| R1 #1639 / SR 7,8,9 | WS reconnect closes the live socket; `disabled` never reaches select/table; `hexpand=`/`vexpand=` omit `changed!` | fixed `62ea172b` |
| R1 #1639 | refusal toast swallowed on a click's second stale refusal | fixed with F1: attempts travel with the record; only a stale *report* is silent |
| R2 #1635 | `signal_connect` ids collide after disconnect | fixed `f22205f4` |
| R2 #1635 | `GLib::Idle.add` spins and leaks a source per pass | fixed `f22205f4` |
| R2 #1634 | `Adapter#handle_for` linear deep-`==` scan | fixed `66f198df` (reverse identity map) |
| R2 #1639 | `webui_data_uri` memoised on a mutable pixbuf | fixed `3b1179d0`; now **moot** (stand-ins, `9794c16a`) |
| R2 #1639 | `install_pixbuf_tracking!` patches real GdkPixbuf process-wide | **decision D7** |
| R2 #1634 | one browser process + temp profile per window | **decision D1** |
| R2 #1634 | socket writes have no timeout; `Runtime#shutdown` joins unbounded | **decision D2** |
| R2 #1635 | `Vars` marshals script classes under `ScriptScope::` | answered (corpus clean); **decision D8** |
| R2 #1635 | `respond_to_missing?` true for everything, `method_missing` nil | **decision D4** |
| R1 #1638 | stubbed-widget notice once per *process*, not per session | closed here (B5) |
| R1 #1640 | `ProgressBar#show_text` tautological | fixed `6519646c` |
| R1/R2 #1641 | rubocop backlog; intermediate PRs red | fixed `35b45529`, then per-PR (`c8532075`..`6988b866`) |
| R1 #1641 | `EnumWindows` LPARAM declared `long` | fixed `a24c414d` |
| R3 F3 / DA W10 | password never reaches the script | fixed `42fe7a69`, `2ac51767` (branch 12) |
| R3 F5 / DA W01 | launch after close during authentication | fixed branch 10 (F5), `7d97a46d` (manual path) |
| R3 F6 / DA W06 | refused viewer write evicts the viewer; options+selection ordering | fixed `2f6e510a`, `2d8cac22` |
| R3 F7 | password draft lost on rerender | fixed `3cd1c629` |
| R3 F8 / DA W05 | table row_activate, cell editors, multi-select | fixed branch 11 (F8), `4f3ba22d` |
| R3 F9 | pixbuf source map retains every bitmap | fixed `f39ce2aa` (`ObjectSpace::WeakKeyMap`) |
| R3 F10 | TreeStore is a flat ListStore | fixed branch 11 |
| R3 F11 | second pane gets the `first` slot | fixed `f39ce2aa` |
| R3 F12 | attach races refresh (generations `[2, 1]`) | fixed `92fac8b7` |
| R3 F13 | duplicate attach on every page-list broadcast | fixed `92fac8b7` |
| DA W02 | `entry-N` keys change meaning | fixed `b89f2ad7`, `1c02c23d` |
| DA W03 | transient detach closes the launcher | fixed `58fdfd83` |
| DA W04 | shutdown does not prevent new workers | fixed `444ab98e` |
| DA W07 | shim bypasses the dispatcher's bound | fixed `b0197807` |
| DA W08 | removed widgets retained by bookkeeping | fixed `cbed8018` |
| DA W09 | render discards a half-typed number | fixed `9d656288` |
| DA W11 | empty `Gtk::Image` refuses the page | fixed `836d05f3` |
| DA W13 | full suite cannot load with native bindings | fixed `112d33b4` |
| DA (06) | browser output still relies on native GdkPixbuf/Cairo | fixed `dd78babf`, `9794c16a`, `d1275cb8` (stand-ins, shape layers) |
| DA (03) | logging deduplicated globally, so silence proves nothing | fixed `1d4fdc3f` (per-script ledger) + B5 |
| SR 10 | dead code: `lib/api/webui.rb`, `websocket_upgrade?` | `c139cf10`; A1 |
| CR 6 | `lib/common/frontend.rb` packs an HWND with `'L!'` | **out of scope / decision D12** |

### Minors and nits

| src | item | status |
|---|---|---|
| R1 #1634 | `terminal_launch` dead guard | closed here (D1) |
| R1 #1634 | `webui_dev_option_spec` asserts on source text | closed here (D5) |
| R2 #1634 | `Dispatcher#await` cannot return, two raises | closed here (A2) |
| R2 #1634 | `enforce_bounds!` quadratic | closed here (A3) |
| R2 #1634 | `handle_file` unbounded read | closed here (A4) |
| R2 #1634 | `Validator` checks a `:forced` key nothing sets | not dead: `contract.rb:705` sets it (`sensitive`) |
| R2 #1634 | `ModalCoordinator#open` leaks a page on failure | closed here (A7) |
| R2 #1634 | `read_frame` blocks after `IO.select` | closed here (A5) |
| R2 #1634 | launch token in the browser command line | closed here (A11, doc) |
| R2 #1634 | `next unless @launch_data` reads like loop control | closed here (D3) |
| R2 #1634 | `overridden_path_value` doc stale | closed here (D4) |
| R2 #1634 | `SensitiveValue#clear_value!` read as a guarantee | closed here (A10) |
| R2 #1634 | `manual_connect` transfers the secret before `begin_operation` | closed here (D2) |
| R2 #1634 | Windows spec guards | answered in R1 |
| R1 #1635 | `Session.for` memoises `@null_owner` outside the mutex | closed here (B1) |
| R1 #1635 | `Script.__trusted_binding` has no spec | closed here (C7) |
| R1 #1635 | `Table#attach` drops x/y options silently | closed here (C8); yoptions documented as ignored |
| R1 #1635 | `GLib::Timeout.add` id race | closed here (C1) |
| R2 #1635 | every off-thread write enqueues a full commit | **decision D3** |
| R2 #1635 | `Box#render_children` runs three times per materialize | **decision D3** |
| R2 #1635 | `GridLayout#render_children` O(rows x cols x children) | **decision D3** |
| R2 #1635 | grid fillers never reclaimed | closed here (C10) |
| R2 #1635 | `serve_file` alias collides across owners | closed here (B3) |
| R2 #1635 | `@file_roots` lazily initialised outside the mutex | closed here (B3) |
| R2 #1635 | `@viewers` default-proc creates entries on read | closed here (B4) |
| R2 #1635 | adjacent string literals in the dropped-child message | fixed (`+`) |
| R2 #1635 | plan doc will rot | closed here (D7) |
| R2 #1635 | `;exec` defines constants into ScriptScope | **decision D9** |
| R2 #1635 | `const_added` shadowing precedence above `Object` | **decision D10** |
| R1 #1636 | `@pointer_window` never invalidated on close | closed here (B2) |
| R1 #1636 | native context menu suppressed whenever press/release wired; doc mismatch | closed here (D6, doc) |
| R1/R2 #1636 | `InheritedHelpers` MRO comment overstates; reachability for widget subclasses unpinned | closed here (C6) |
| R2 #1636 | `mnemonic_free` strips every underscore | fixed `5d88ab67` (GTK does the same; `__` was the real gap) |
| R2 #1636 | `OWN_DEFINITIONS` hand-maintained, forgetting is silent | closed here (B10) |
| R2 #1636 | `NAMESPACE_SUFFIXES` is empirical, say so | closed here (C5) |
| R2 #1636 | `const_added` depth-2 spec | closed here (C6) |
| R1 #1636 | `Gtk::UIManager` in the census? | answered: no; acronyms fixed anyway |
| R1 #1637 | `fill` parsed but has no effect | closed here (C9) |
| R1 #1637 | PR body version stale (2.11 vs 2.12) | PR description; fix at push time |
| R1 #1637 | `retriedEvents` key concatenation | moot (F1 keys a Map on page+cid+event) |
| R1 #1637 | adapter deadlock spec has no `ensure` | left: `join(5)` already bounds it; a leaked thread on failure is the failing run's problem |
| R1 #1637 | multi-viewer scroll extent | **decision D26** |
| R2 #1637 | silent clamps (box > 12, grid > 24, margin > 512, Paned full) | fixed `f2d581ba` |
| R2 #1637 | `size_request_axes` depends on parent at commit time | left: read at commit, when the parent is final; a commit between `set_size_request` and `add` is the only window and re-converges next commit |
| R2 #1637 | `Adjustment` defaults load-bearing | closed here (C4, comment) |
| R2 #1637 | `@centre_request` redundant nil | closed here (C3) |
| R2 #1637 | `@presentation_sources` never pruned | fixed `cbed8018` (W08) |
| R2 #1637 | which scripts were re-checked at `b030edee` | answered in thread |
| R1 #1638 | non-ASCII comments | fixed |
| R1 #1638 | `MessageDialog` outside the widget protocol | left: not a Widget in GTK either; no corpus script does arithmetic on one |
| R1 #1638 | `allocation` mirrors the requested size | answered: viewport reporting landed in #1641 for scrollers; base case is **decision D5** |
| R2 #1638 | `allocation` fabricates 640x480 silently | **decision D5** |
| R2 #1638 | `report_stubbed_widget` guard mismatch | fixed `180b6a92` |
| R2 #1638 | `@unsupported` double duty | moot (ledger rewrite) |
| R1 #1639 | password unmask discards masked typing | closed here (C12) |
| R1 #1639 | `Lint/Void`, `compare_by_identity`, shadowed rescue | fixed (`35b45529`, then `WeakKeyMap`) |
| R2 #1639 | `PixbufSources` never shrinks | fixed `f39ce2aa` |
| R2 #1639 | `Layout` child that is not an Image contributes nothing | fixed (labels are `label` layers, `9794c16a`) |
| R2 #1639 | empty `src` triggers a broken-image request | fixed `836d05f3` (W11) |
| R2 #1639 | `jpeg_size` length < 2 guard | left: loop terminates and the method is rescued; adding the guard changes nothing observable |
| R1 #1640 | re-adding the same child to a Paned slot duplicates it | closed here (B6) |
| R1 #1640 | rubocop unused args | fixed (scoped disables) |
| R1 #1640 | nested `run` recursion depth | answered: bounded by script nesting; no corpus script chains dialogs |
| R2 #1640 | `run` spins after `:stop` | fixed `52c677a9` (F4: `session_terminated` marks it destroyed first) |
| R2 #1640 | `nil`/`false` responses hang `run` | closed here (C2) |
| R2 #1640 | `Paned#position=` hand-writes the viewer_push pair | closed here (B7) |
| R2 #1640 | `ListBox` selection state never reaches the contract | closed here (B8, reported) |
| R2 #1640 | `ListBoxRow#index` uses `respond_to?` | closed here (B9) |
| R1 #1641 | nothing structural ties `scope: :viewer` to `viewer_push` | closed here (C13, spec) |
| R1 #1641 | `event.repeat` filtering drops key auto-repeat | **decision D6** |
| R1 #1641 | click coordinates rounded twice | closed here (C11) |
| R1 #1641 | dangling paragraph in the plan doc | closed here (D7) |
| R1 #1641 | scrolled-vs-click ordering after a drag | answered: WebSocket is FIFO per connection |
| R2 #1641 | every key press re-materializes every window | **decision D3** |
| R2 #1641 | key events non-coalescable; overflow closes the viewer | **decision D25** |
| R2 #1641 | `find_window` allocates a closure per poll | closed here (A12) |
| R2 #1641 | `presentation_support` allocates per render | closed here (A9) |
| R2 #1641 | `find_window` returns nil on > 1 match silently | closed here (A12) |
| R2 #1641 | `borderless:` ignored kwarg | fixed (scoped disable) |
| R2 #1641 | `owning_pid` pack comment | fixed |
| R2 #1641 | `INLINE_IMAGE` accepts a non-multiple-of-four body | closed here (A8) |
| R2 #1641 | are degradations surfaced to the player? | **decision D16** |
| R2 #1641 | marker size at max zoom vs `MAX_DATA_URI` | moot for map (markers are shape layers now); raw-pixel pixbufs still report through the ledger when over the cap |
| R3 | `ShimAdapter#render_children` duplicates the base traversal | **decision D13** |
| R3 | runtime and ViewerStore each enumerate viewer-state events | **decision D14** |
| R3 | `Dialog` and `MessageDialog` wait differently | **decision D15** |
| R3 | browser suite around real renders | owed (handoff); **decision D22** |
| CR 3 | rubocop | fixed |
| CR 4 | headline claims | fixed |
| CR 5 | commit claiming to close the self-review | fixed |
| DA (02) | `--webui-dev` is not an isolation boundary (`::Gtk`, other bindings escape) | **decision D30** |
| DA (07) | placement/overlay approximations need supported-workflow decisions | **decision D19/D20** |
| DA (08) | Windows presentation not executed by the audit | verified on this box (EnumWindows 409 windows, keep-above and opacity visually) |
| DA arch | decisions 1-6, capabilities matrix, YARD, rollout owner | **decisions D18-D24** |

## Part 2 — decisions, explained simply

**Decided 2026-09-16 (user):** D1 follow lich-6 (see D1). D2 yes. D3 yes
(coalesce now, structural dirty-tracking as its own PR). D4 yes, and it is
what `architecture.md` decision 3 asks for verbatim: "an unknown method
should produce actionable per-script diagnostics; do not let a generic
fallback or `respond_to?` silently turn into a promise of correctness" —
the ledger is the diagnostic, and `respond_to?` stops lying. D5 yes. D6
yes. D7 moot. D8 yes (alias before the default flips). D9 yes: an `;e`
one-liner is a trusted script and should see what scripts see, and after
L8 there is no core `Gtk` to see anyway. D10 yes (corpus clean). D12 yes
(own PR to main). D13–D15 yes. D16 yes. D17 yes. D18–D24 yes. D25 yes.
D26 yes. D30 yes. Each lands in the layer its write-up names.

Each one: what it is, why anyone cares, the options, and a recommendation.
None of these is a bug with a known fix that was skipped; each changes
behaviour someone might be relying on, costs real work, or is policy.

### D1. One browser process per window

Today every script window (`;map`, `;bigshot`, `;vars`) launches its own
Chrome with its own throwaway profile directory. That is why each window
has its own lifetime and why "close `;map`" cannot take `;bigshot` with it.
The cost is one Chrome process tree per window, and temp profile
directories that leak if Lich is killed hard.

Options: (a) keep it and say so in a comment (cheap, honest); (b) one
profile per Lich session so windows share a browser process (lighter,
but `--app` windows in a shared process share fate, and `find_window`
would need rework); (c) sweep stale `lich-webui-browser-*` temp dirs at
startup regardless.

**Answered by lich-6 (`Lich5/lich-6` at `a25aade`), 2026-09-16.** Doug's
design gives a private profile and process monitoring to the *launcher
only* (`lib/common/webui_launcher.rb:62` passes `on_exit`); a script page
opens through `Lich::WebUI.open`, which calls `BrowserLauncher.open(url)`
with no `on_exit`, so it lands in the user's ordinary Chrome as an app
window, detached, sharing that browser's process. The per-window process
is our shim's doing: `Session#open_browser` always passes `on_exit` so a
window can learn its browser died. Decision: follow lich-6. Shim windows
open without `on_exit`; the viewer `detach`/`close` path (already wired to
`Window#viewer_closed`) is how a closed window is noticed. `find_window`'s
"exactly one match" rule then applies only to the launcher.

### D2. Socket writes have no timeout; shutdown can wait forever

If a browser stops reading its socket (laptop asleep, frozen tab), the
runtime's `write` blocks with no deadline on whatever thread called
`refresh`, which in the shim is the script's session thread. `Runtime#
shutdown` then joins that thread with no budget. Nobody has reproduced it;
it needs a stalled browser.

Options: (a) `IO.select` write guard with a timeout that marks the
connection dead, and a bounded join in shutdown (small, in `lib/webui/`,
Doug's code); (b) leave it and rely on the OS closing the socket.

Recommendation: (a), as an L1 core-correction, because the shim puts a
script thread behind that write.

### D3. Commit-path cost: every write re-materializes every window

Every property write from a script thread enqueues a full commit, and
every job the session runs ends in a commit that walks every window's
whole widget tree. Holding an arrow key in `;map` is one full tree walk per
key repeat. Measured: 1.3 ms per no-op job on a 200-row window. It is not
visible today but it scales with window size and event rate.

A dirty-gated commit was attempted and backed out (44 spec failures)
because `changed!` marks the widget, not its ancestors, and structural
mutations (`add`, `pack_start`, `show_all`) do not go through it at all.
The same theme covers `Box#render_children` running three times per
materialize and the grid layout's rescans.

Options: (a) audit every mutation path and make dirty tracking structural
(its own PR, a few days); (b) coalesce: drain the queue and commit once
per batch (cheap, helps every event type, does not fix the per-commit
cost); (c) leave it for the preview and measure real windows.

Recommendation: (b) now in L6a, (a) as a follow-up PR after previews show
where it hurts.

### D4. Unknown methods return nil, and `respond_to?` says yes to everything

A script that calls a method the shim does not implement gets `nil` (or
`self` for setters) and a log line, not an exception. Combined with Lich's
`nil.anything -> nil` patch, a typo can travel a long way before anything
notices. `respond_to?` lies in the same direction, so scripts that check
for a capability get "yes" and then silence.

This was a deliberate choice: a script that dies on the first unimplemented
call never gets far enough to be debugged, and the ledger now records
every hit per script so nothing is truly silent.

Options: (a) keep, with the ledger as the truth; (b) narrow
`respond_to_missing?` to the setter shapes `method_missing` actually
handles and return `super` otherwise (scripts that probe capabilities get
honest answers; `Window#collect_scrollers` already works around the lie);
(c) raise on unknown methods (strict; would kill several corpus scripts on
first run).

Recommendation: (b). It changes no existing behaviour for scripts that just
call methods, and fixes the only outright wrong answer.

### D5. `allocation` answers 640x480 when a widget has no window

`widget.allocation` returns the requested size, or the window's default,
or 640x480 if there is no window at all, rather than `nil`. `nil` used to
become `coerce must return [x, y]` several frames later, naming nothing.
A confident wrong number is a better failure than that, but it is silent.

Options: (a) keep; (b) keep and report once through the ledger when the
fallback fires, so "the map centred somewhere odd" has a log line.

Recommendation: (b). One line.

### D6. A held key delivers one press, not a stream

The client drops browser key auto-repeat (`event.repeat`). A GTK window
would deliver a press per repeat, so a script that pans while a key is
held only moves once here. No corpus script is known to rely on repeat.

Options: (a) keep (protects the session thread from a repeat storm, see
D3); (b) deliver repeats with a `repeat: true` flag in the payload so a
script can opt in; (c) deliver repeats unconditionally like GTK.

Recommendation: (a) until D3's coalescing exists, then (b).

### D7. The shim patches the real GdkPixbuf gem, process-wide

**Decided 2026-09-16: moot.** The image shim is not carried into the
rebuild at all (see part 3); the patch, `PixbufSources`, the stand-ins and
`images.rb` go with it. Kept below for the record.

`install_pixbuf_tracking!` prepends methods onto the real `GdkPixbuf::
Pixbuf` class (if the gem is loaded) so a pixbuf remembers the file it
came from. That was the one place the shim reached outside its own
namespace. Since the stand-ins landed, scripts no longer see the real gem
at all: a bare `GdkPixbuf` in a script is the shim's own class, which
carries its source path natively.

Options: (a) delete the patch (and `PixbufSources`) now that nothing in
the script scope needs it; (b) keep it for a script that reaches the real
gem through `::GdkPixbuf`.

Recommendation: (a), in L6b. A script that writes `::GdkPixbuf` is
escaping the shim on purpose and gets the real gem's behaviour.

### D8. Script-defined classes have a different name under the flag

A script's `class Foo` is `Lich::Common::Foo` normally and `Lich::Common::
ScriptScope::Foo` under `--webui-dev`. `Vars` stores objects with
`Marshal`, which records the class name, so an instance of a script's own
class saved in one mode cannot load in the other, and Lich's `Vars` loader
then silently replaces the whole store with an empty one. Checked: no
script in the 230-script corpus stores an instance of its own class in
`Vars`/`Settings`/`CharSettings`, so it is not reachable today.

Options: (a) record it as a known limitation (done in the plan doc); (b)
alias each script-defined constant into `Lich::Common` as well, so the
Marshal name is stable across modes; (c) make the mode sticky per
character so it never flips.

Recommendation: (a) for the preview; (b) before the default flips (L7),
because at that point every user's mode changes at once.

### D9. `;exec` one-liners also run in the ScriptScope binding

`;e Foo = 1` now defines `ScriptScope::Foo`, and a bare `Gtk` in `;e`
resolves to the shim. That is consistent (an `;e` is a trusted script) but
it means ad-hoc debugging sees what scripts see, not what core sees.

Options: (a) keep, consistent; (b) give `;exec` the historical binding so
it can inspect core's `Gtk`.

Recommendation: (a). Anyone debugging core can write `::Gtk`.

### D10. Script helper methods sit above `Object` in every script class

`const_added` includes the helper module into every module and class a
script defines, so a script's top-level `def` is reachable from inside its
own classes (the `;armor` crash fix). Under the old binding those helpers
landed on `Lich::Common`, included into `Object`, so they were reachable
too, but *below* `Object` in precedence. Now they sit above it: a script
that defines a top-level method with the same name as something `Object`
provides (`display`, `format`, `test`) wins inside its own classes.

Options: (a) keep, and pin it with a spec (C6 does); (b) grep the corpus
for top-level `def`s named after `Object`/`Kernel` methods and fix those
scripts.

Recommendation: (a). The corpus grep is done: across the 230 scripts, no
top-level `def` shares a name with any `Object` instance or private method
(checked against the running Ruby's `Object.instance_methods +
private_instance_methods`). Nothing to fix today.

### D12. `frontend.rb` packs a 64-bit window handle into a 4-byte `long`

Pre-existing core code (`refocus_windows`) has the same LLP64 bug class
the stack fixed in `window_presentation.rb`: `'L!'` is 4 bytes on Windows,
so a real 64-bit HWND is truncated. It is outside every WebUI PR.

Options: (a) separate small PR to `main` with a Fiddle spec; (b) fold it
into L4 since it is Windows presentation code.

Recommendation: (a). It is a core bug, not a WebUI change.

### D13, D14, D15. Three maintainability refactors

- **D13** `ShimAdapter#render_children` re-implements the base adapter's
  traversal to inject placement and presentation. Two nearly identical
  walks drift. Fix: base adapter grows two narrow hooks.
- **D14** `Runtime` and `ViewerStore` each keep their own list of which
  events update viewer state. Adding an event can update one and forget
  the other. Fix: one table, both read it.
- **D15** `Dialog` waits on a Queue; `MessageDialog` waits on a `Future`
  through `ModalCoordinator`. The shutdown gap (F4) happened because only
  one of them was cancelled. Fix: `Dialog` uses the coordinator too.

Recommendation: D13 and D14 in L1 (they are Doug's code, and they are the
kind of change the rebuild exists for); D15 in L6a.

### D16. Degradations are recorded, not shown

When a script asks for `keep_above` on Linux or macOS, the runtime records
a degradation on the page and does nothing else. Nine scripts ask for it.
Nothing shows the player. On Windows it works.

Options: (a) keep (quiet); (b) the shim reports each degradation once
through the ledger, so it lands in the per-script summary; (c) a one-time
toast in the page.

Recommendation: (b). It costs one call and makes the ledger complete.

### D17. Two password gaps the contract does not allow

`password_input` has no `change` event by design (the value is write-only),
so a live strength meter cannot fire; and the client blanks the field after
every submit, so a re-prompt on a wrong password shows an empty field.
Both are logged through the ledger. Both need a contract change: a
payload-free `change` ("the value changed") and a `submit` that does not
clear on refusal.

Options: (a) accept both as limitations; (b) contract bump in L3 with both
primitives.

Recommendation: (b), because the launcher's own master-password screen is
the consumer.

### D18. Destination: WebUI is the core

Doug asks whether the goal is WebUI as core, GTK as core, or funded dual
support. The plan doc answers WebUI as core: 5.x previews it behind a
flag, L7 flips the default, Lich 6 deletes GTK. This ledger assumes that
answer. If it is wrong, D19-D23 change shape.

### D19 and D20 — decided 2026-09-16

Admission rule: a script authored by elanthia-online is never a shim
candidate (it is rewritten natively); any other script needs approval,
per feature, naming what it needs shimmed. The supported list is
therefore an approval list, and "who approves growth" is answered: the
user, per request. The two sections below are kept for the reasoning.

### D19. A checked-in supported-script list

Doug wants a file in the repo naming which scripts are supported under the
WebUI, with platforms, known degradations, and how they were exercised.
The ledger produces the evidence; someone has to write the list.

Recommendation: `docs/webui-supported-scripts.md`, seeded from the corpus
census in the plan doc, updated from ledger summaries during the preview.
Required before L6 by the rebuild plan.

### D20. Freeze the shim surface; who approves growth

Every GTK API the shim emulates is a promise to maintain. Doug's point: if
any new GTK API is eligible forever, the shim is a toolkit project. The
rebuild plan's "minimal" is "what the supported-script list exercises".

Recommendation: the supported list is the contract; a new API needs a
script on the list that uses it. Owner: whoever owns the list.

### D21. One business-service boundary

The native launcher and the WebUI launcher each mutate the catalog, hold
credentials, and launch sessions. Doug wants one shared service layer so
both UIs are thin. That is L4 in the rebuild plan (move the non-widget
helpers out of `lib/common/gui/`), and W02's stable keys were the first
step. Nothing to decide beyond confirming L4 stays in the plan.

### D22. Browser and runtime as a test target

Every client-side fix in this stack is pinned only by "the JavaScript
contains this string". Doug and the third review both say that cannot
establish behaviour, and the old password spec proved them right. The
rebuild plan gates L3 on a jsdom-style harness for `app.js`; the golden
harness was designed and never built.

Recommendation: build the `app.js` harness first (node is on this box),
with W12's acceptance as the first cases. The golden harness second.

### D23. The retirement gate

Doug's gate for deleting GTK: a clean install with no GTK libraries that
launches core and every supported workflow on Windows, macOS and Linux;
an explicit decision on image dependencies (answered: stand-ins); a
bounded support list for remaining scripts; and rollback that includes
settings written in both modes (D8). The plan's L8 acceptance is the same
list.

### D24. Documentation debts

A dated capabilities matrix (replacing the plan doc's mixed history and
claims), YARD on the public launcher/catalog/widget surface, and a named
rollout owner with stop conditions (unexpected launch after cancel, lost
action, settings mismatch, unresponsive dialog, growing resource use,
cannot return to GTK).

Recommendation: the matrix with L3 (it is the contract in prose); YARD as
each layer is rebuilt; the owner is the user.

### D25. A slow script handler can now overflow and close its own viewer

W07 made the shim's hop park the dispatcher thread when the session queue
is full, so the dispatcher's bound applies. Key events are not
coalescable (two different keys must not fold into one), so under a
sustained storm the bound trips, the runtime closes the viewer's
connection, and the failure looks nothing like its cause. Not reachable
with today's callbacks, which only enqueue.

Options: (a) accept (bounded is the point); (b) drop the *oldest* key
event instead of refusing when the queue is full of keys.

Recommendation: (a), documented at the contract comment.

### D26. Is one shim window ever open in two browsers?

`ScrolledWindow` keeps one shared scroll extent per widget, written by
whichever viewer reported last. If a page is attached by two viewers with
different window sizes, one overwrites the other. The shim opens one
browser per window, so it does not happen today.

Recommendation: declare single-viewer per shim window as the supported
case and refuse a second attach on a shim page. Small change in L6a.

### D30. The flag is not an isolation boundary

A script that writes `::Gtk` (fully qualified), code loaded in another
lexical scope, and non-trusted bindings all reach the real gem. Doug wants
an inventory and a policy. Grep the corpus for `::Gtk`, `::GdkPixbuf`,
`::Cairo`, `::GLib` and `Object.const_get('Gtk')`.

Inventory done: across the 230 scripts, zero uses of `::Gtk`, `::Gdk`,
`::GdkPixbuf`, `::Cairo`, `::GLib` or `::Pango`, and zero
`const_get('Gtk')`; 56 scripts mention `Gtk` at all, every one bare.
Policy recommendation: an escape is unsupported and the ledger cannot see
it, so the supported list excludes any script that does it; a boundary
check in CI (grep the bundled scripts for `::Gtk`) keeps it that way.

### D31. PR descriptions

Several PR bodies carry stale versions and example counts (#1637 says
2.11.0, head is 2.12.0; #1640/#1641 counts). These are fixed at push time
with the rest of the rebuild's PR bodies.

## Part 3 — what the shim will not cover (decided 2026-09-16)

Census over the 230-script corpus plus the three GTK scripts bundled in
lich-5 (`grep` for the class names; every hit read):

| need | scripts | decision |
|---|---|---|
| `Gtk::Image`, `GdkPixbuf`, `Gtk::Layout` | `map`, `bsprofiles`, `creaturebar`, `calibrate_creaturebar`, `xnarost`, `orbuculum` | not shimmed |
| Cairo drawing into a pixbuf | `map`, `bsprofiles` | not shimmed |
| `Gtk::DrawingArea` with `draw` callbacks | `creaturebar`, `calibrate_creaturebar` | not shimmed |
| `Gtk::Menu`, `MenuItem`, `CheckMenuItem`, `RadioMenuItem`, `SeparatorMenuItem`, `popup` | `map` (54 sites), `orbuculum` (29), `xnarost` (20), `creaturebar` (6) | not shimmed |
| `button-press-event` for click detection (no menu) | `bardwag`, `jinx`, `sspell`, `calibrate_creaturebar` | shimmed (press/release) |
| `Label#set_markup` | bigshot, spellson, armor, boon, sloot and others (149 sites) | shimmed |

`map`, `bsprofiles` and `creaturebar` (with its calibrator) are rewritten
natively against the contract (rebuild plan L6c). `xnarost` and
`orbuculum` are unsupported and unused. No `MenuBar`, `UIManager`,
`Toolbar` or `ImageMenuItem` exists in the corpus. The contract 2.7 doc's
"28 scripts" menu count was wrong; the class-level census is four.

### The elanthia-online GTK scripts (all excluded from the shim, to be rewritten)

`elanthia-online/scripts` (49): BlackArts, ForgeMaster, MyFletch, alias,
armor, autostart, bardwag, betazzherb, bigshot, boon, calibrate_creaturebar,
clearcheckwiz, creaturebar, ebounty, ecleanse, ecure, eforgery, eherbs,
eloot, ewaggle, fletchit, go2, hands_and_room, heal_spellup, iSigns,
isigils, jinx, localchat, loot-be-gone, madwarrior, map, mechfire, mybounty,
orbuculum, perfume, repository, sammu, sbounty, sellunder, signore, sloot,
soundfx, spellson, sspell, symbolz, uberfletch, vars, version, xnarost.
Bundled in lich-5 (15, all also above except `bsprofiles`): alias, armor,
autostart, bigshot, bsprofiles, ecleanse, eherbs, eloot, ewaggle, go2, jinx,
map, repository, vars, version.

## Part 4 — the outside review of 2026-09-17 (R1–R14)

A second, independent review of the rebuilt chain (`docs/webui-rebuild-review-2026-09-17.md`,
written against tips up to L3 `0ec7af2f`) found fourteen defects, six of
them release-blocking for the default flip. Each was reproduced by its
probe, fixed in the layer it belongs to, and pinned by a test that fails
without the fix. Nothing was deferred.

| finding | layer | what changed |
|---|---|---|
| R1 `--gtk` alone did not open the GTK launcher | L2 | the GTK branch takes the parsed launcher choice; the launcher_option spec now evaluates both branch predicates against the real parser |
| R2 Frontends Save read the submission as an Array | L5 | fields are read by cid like every other workflow; the spec drives the editor with a real `Submission` and saves, then edits |
| R3 two Lich servers overwrote each other's cookie | L1 | the cookie name carries the port; spec authenticates to two servers in one jar |
| R4 cancellation raced irreversible steps | L5 | `commit` runs each irreversible step under the launcher lock only while live and not closing; a terminal launch accepts the launch and begins the close as one step |
| R5 a refresh landing before a refusal lost the click | L1 + L3 | events carry a request id the refusal echoes (protocol 2.19 stays; the field is optional); records survive renders and expire by age; harness cases for refresh-then-refusal and two sends from one button |
| R6 a closed MessageDialog window waited an hour | L1 | the coordinator binds the modal page's close/detach/attach: explicit close dismisses at once, a dropped socket after a 5s grace |
| R7 cell edits mutated the model before the handler | L6b | only the renderer's own signal is emitted (`edited` with the text, `toggled` with the path) and the handler owns the model; the client makes a committed edit the cell's base so a refusal shows |
| R8 saved-entry keys aliased same-character entries | L4 | frontend and custom launch are in the digest |
| R9 a concurrent enqueue revived a shut-down owner | L1 | the state lookup refuses a tombstoned owner under the same lock |
| R10 table editor drafts were wiped by a render | L3 | editor cells are controls under their own cid, carrying the rendered value |
| R11 Builder never applied CellRenderer properties | L6b | only setters the class defines are applied; Glade fixture with `editable` and `activatable` |
| R12 the write timeout bounded each wait, not the write | L1 | one monotonic deadline per write, the lock wait included; slow-drain and queued-behind-a-stall specs |
| R13 password `changed` still suppressed | L6a | bound as a payload-free notification; the value never travels with it, and the mapping says so |
| R14 tree rows rendered flat | L3 | rows walk the tree, collapsed descendants are not drawn, children indent, a toggle emits `row_toggle` |

Two of the review's non-numbered notes stand as stated: the boundary
checker is a warning until L8, and the frontend mutation rules are still
duplicated between the two launchers (plan: consolidate before L8, with
parity tests). The `;map` rewrite the review said was undelivered is
`scripts/map.lic` 3.0.0 (plan, L6c).

## Part 5 — the second outside review of 2026-09-17 (F1–F7)

A follow-up review of the opened PRs (`docs/webui-pr-review-1634-1648-1655.md`,
against the tips #1648 `dba90bf2` through #1655 `28cd856f`) re-checked
the part 4 fixes and found seven defects, two of them priority one. Each
was reproduced by the review's own probe, fixed and pinned by a test
that fails without the fix. The fixes ride together in one PR on top of
the stack (`webui/review-2-fixes`, based on `webui/default-flip`), not
in the layer each belongs to: the layer column below says where the
defect lives, and a fix in a lower layer would have meant merging every
layer above it and pushing all eight branches again. Post-review fixes
go on top from here on.

| finding | layer | what changed |
|---|---|---|
| F1 a commit that raised killed the session thread and stranded a queued `sync` | L6a | the batch's commit is inside the same rescue as its jobs and the loop reports and continues; a synchronous job is an object the thread refuses if it ever ends with the job still queued; `enqueue` answers whether it took the job so `sync` cannot queue behind a shutdown |
| F2 the master-password change ran after close | L5 | the catalog call runs under `commit(operation)`, as every other irreversible step; a queued-executor spec closes before the job runs |
| F3 modal close raced the detach context | L1 | `detach` builds both lifecycle jobs before dispatching either; a lifecycle job with no render is skipped rather than raised |
| F4 shim tree expansion vanished on the next render | L3 + L6b | a tree store binds `row_toggle`, so the viewer store keeps the viewer's expansion across renders; the shim keeps its copy for `row_expanded?`, emits `row-expanded`/`row-collapsed`, and `expand_all`, `collapse_all`, `expand_row`, `collapse_row` push per row through the new `page.set(cid, "expanded:<row>", bool, viewer:)` write |
| F5 event records had no effective expiry and kept cleared passwords | L3 | every send and every received message sweep expired records, a refusal is aged before it is honoured, a closed page and a dropped socket drop their records, a control the script cleared drops every record that carried its value, and the set is capped at 256; no timer, which would have held the page's event loop |
| F6 the favorite could land on a sibling entry | L5 | the catalog answers an upsert with the key of the entry it wrote and the launcher favorites that key; `set_favorite` sets rather than toggles, so a re-saved favorite stays one |
| F7 title discovery adopted a pre-existing window | L1 | the windows already carrying the title are listed before the browser opens and excluded from discovery; only a window that appears after the open can be adopted |

On F5, the review asked for a timer or an acknowledgment protocol. Neither
was taken: a timer in the page holds its event loop (and the harness
process) for nothing, and an acknowledgment would be a protocol change
the native consumer would have to follow. Retention is bounded instead by
the page's own traffic, its close, its socket and the cap; an idle page
that receives nothing at all keeps at most 256 records until its next
message.

## Part 6 — the third outside review, of the whole stack (2026-09-17)

`docs/webui-pr-review-stack-combined-2026-09-17.md` reviewed #1634,
#1648–#1655, #1657 and #1658 together, re-verified F1–F7 (six fixed,
one partly) and found two Majors, both in #1657. Everything below is one
set of commits on `webui/review-2-fixes`, merged into `webui/yard-docs`.

| finding | what changed |
|---|---|
| Major 1: the F1 fix left `enqueue`'s closed check and push as two steps, so a shutdown between them stranded the job behind a `:stop` the thread had already drained past | the check, the push and the thread start are one step under `@thread_mutex`, which `shutdown` takes to set `@closed`; the spec pauses the real push exactly there and asserts the `sync` is answered either way, and that `shutdown` waits for the enqueue in progress |
| Major 2: a `--webui-no-browser` launch URL died in sixty seconds and answered a bare 403 | `Server#launch_url` takes a `lifetime`; a URL the player has to carry (no-browser, launcher and script windows alike) lives `REMOTE_LAUNCH_TOKEN_LIFETIME` = ten minutes; an expired or reused link answers 403 with a body saying so and naming `Lich::API.webui_launch_url`; the doc says both |
| 3: the remote-play doc said one tunnel per script window | one WebUI server per game session, every script window a page on it: one more `-L` per session |
| 4: four `Layout/MultilineMethodCallIndentation` offenses (RuboCop 1.91 on Linux; 1.8x here did not flag them) | the three chains are written as two statements; no chained continuation lines remain in the stack's files |
| 5: 163 documented private methods without `@api private` | tagged on `webui/yard-docs`, per `docs/YARD-STYLE-GUIDE.md` |
| 6: a busy `--webui-port` reported "unavailable, retry with GTK" | `Errno::EADDRINUSE` is caught by name and the message says which port, that another Lich may hold it, and to pick another `--webui-port` |
| 7: the `@return`/`@raise` tags on `enqueue` and `sync` promised what Major 1 broke | true as written now |
| 8: the child's `--webui-no-browser` was read from raw `ARGV` | resolved like the launcher flag beside it: `open_browser` in the launch context, else `Lich::WebUI::Options` |
| 9: `yard` not in the bundle | in the development group |

The open questions:

- **`PresentedWindow#adopt` trusts the requested pid rather than the HWND's owner.** Deliberate. With a shared Chromium profile the new window is legitimately owned by the Chrome that was already running, so the discovered HWND's pid is *expected* not to match; ownership cannot be the test. The identity evidence is the exclusion list (a window that existed before the open is never adopted) plus the refusal of more than one match. The pid check in `adopt` only discards a result from a search the window has since outlived.
- **A replay recomputed its record's `scope` from the current render**, so a render that no longer listed the control gave the replayed record an empty scope and `clear_sensitive` could not find the password it carried. Fixed: a replay's record inherits the scope of the record it replays, with a harness case that drops the `submissions` entry between the send and its refusal and asserts the cleared value is not sent again.
- **Shim expansion state is per page, not per viewer.** Correct because D26 holds: `Session#admit_viewer` refuses any viewer whose id is not the page's first, and a reconnecting browser re-attaches under its resume token with the same viewer id, so a shim page never has two viewers with two expansion states.
- **The `@!method` / `@!macro` directives in #1658** were checked by running `yard doc` (now in the bundle) and reading its warnings; see `webui/yard-docs`.

Also here, found by Tysong the same day: **Saga's direct login opened the launcher.** Saga starts a session as `<file>.sal --gtk --without-frontend --detachable-client=N --saga`, and the R1 fix had made `--gtk` alone open the GTK launcher, which then pre-empted the `.sal` login. Both launcher branches in `main.rb` now open only when no session was asked for: a toolkit flag beside a `.sal` runs that session. The routing spec evaluates the real Saga argument list against both branch predicates.

