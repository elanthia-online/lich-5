# WebUI rebuild plan: from a chronological stack to an architectural one

Status: proposal written 2026-09-16; **built 2026-09-17** (see the status
section at the end). The old stack (#1634–#1644 plus local 11/12/13) is
frozen.

## Goal

Lich 5.x ships the WebUI as the default launcher with GTK still reachable
behind a flag; Lich 6 deletes GTK. Every line of code needed for both
already exists on the current stack and is reviewed and tested. What is
wrong is the shape: eleven PRs that describe *when* things happened
("slice four", "polish", "the long tail") rather than *what* a reviewer
approves. Only #1634 — Doug's core, vendored as-is — is approved, and it
is the one PR that is layered by architecture.

This plan re-layers the same code into PRs a reviewer can approve on their
own terms. It is curation, not a rewrite: cherry-pick by area, squash within
each area, keep the fail-first narratives in the PR descriptions.

## Principles

1. **#1634 stays.** Approved, base of everything; it is Doug's PRs #4 and #5
   from Lich5/lich-6 at `d952f2fd`. Never rewritten.
2. **One PR, one thing to approve.** Each layer has a stated purpose, a
   spec surface that must be at 0 failures, and an acceptance line. A
   reviewer should be able to say "this is core corrections" or "this is
   the launcher" without reading the layer below.
3. **Freeze the old stack when the rebuild starts.** After Astra's round,
   nothing lands on `webui/02` … `webui/13`. Every later fix goes into the
   new layer it belongs to. Double-maintenance is how this got messy.
4. **Carry the reviews as a checklist.** Doug's `branch-issues.md` (W01–W13),
   `architecture.md` (six decisions), and Astra's comments become one
   acceptance list. Each new PR description ticks the items it closes, so
   "did the rebuild lose anything" is answerable line by line.
5. **"Minimal shim" has a definition.** The shim's declared surface is what
   the supported-script list exercises: the bundled scripts under
   `scripts/` plus the 230-script census in `C:\Gemstone\scripts\scripts`.
   The per-script ledger (`Gtk.unsupported_report`) confirms or corrects
   that list during the preview. Not "what feels small".
6. **No push without the user asking, in the conversation.** The user pushes
   and opens PRs; an agent never does.

## The launcher decision, made once

Today the WebUI/GTK choice is smeared across four files: `argv_options`
parses `--webui-dev`, `main.rb` branches ahead of the GTK login, `init.rb`
decides whether to `require 'gtk3'`, `lich.rbw` decides whether to run
`Gtk.main`. Flip one without the others and the process is half in each
world.

The rebuild resolves it in one place, early:

```
Lich.launcher  # => :webui | :gtk, resolved once from, in priority order:
  1. an explicit flag        --webui / --gtk
  2. a persisted setting     launcher: gtk   (settings file; the launcher UI can set it)
  3. DEFAULT_LAUNCHER        a constant
```

The four sites only *read* it. Changing the project default is changing the
constant — one word, one commit, one spec ("with no flag and no setting the
launcher is DEFAULT_LAUNCHER") that changes with it and nothing else.

Two things the constant does not change: the `gtk3` gem stays a hard
dependency for as long as `:gtk` exists at all (you cannot require it lazily
on a machine without it), and the retirement gate is deletion, not
non-default. Keeping GTK default delays Lich 6's cut; it does not replace it.

## The layers

Base: `main` (which now contains everything #1634 rebased onto).

### L0 — `webui/core` (this is #1634, approved, unchanged)

Doug's `lib/webui/`: contract, validator, adapter, runtime, dispatcher,
server, browser launcher, native login launcher, 24 specs. Opt-in behind
`--webui-dev`. **Do not touch.**

### L1 — `webui/core-corrections`

Purpose: the runtime and client fixes that belong to Doug's core, presented
as corrections to it rather than as fallout from the shim. This is the PR
Doug reviews hardest; it should read as his code plus honest fixes.

From the stack:
- W04 dispatcher terminal owners `444ab98e` (dispatcher half only)
- W11 empty image source `836d05f3`
- W12 refusal-then-render, refusal names the event, replay with original
  submission `da1cfd3b` (supersedes `efdddee0` "a refusal replays the event
  it names, once" and the retry half of `648a0d40`)
- OverflowError carrier leak `c61b3826`
- runtime `clear_sensitive(page, cid)` — the runtime half of `2ac51767`
- `de6f639f` flush! refreshes outside its lock
- `9da1c97e` attach once per socket, in step with refresh
- `61908829` reconnect keeps the live socket (the socket part; contract
  2.15.1 bump travels with L3)
- `301ac472` handle lookup stops scanning every node
- `d21450f5` a modal appears in the window that raised it
- `5dc11450` scroll report stops racing its own render
- `b030edee` a background render keeps an unsent edit (text) and `d43577d2`
  (password) and W09 `9d656288` (number) — squash to one "edit preservation
  across a render"
- `9089e862` delete the dead author API
- W13 `112d33b4` (spec load fix; belongs wherever the first GTK-stub spec
  lands — here, since spec_helper is core)

Spec surface: `spec/lib/webui`. Acceptance: every W-item above ticked; the
runtime spec pins refusal order and the event field against the real
response sequence.

### L2 — `webui/wiring`

Purpose: how the WebUI gets into the process, and the launcher resolver.

- the 17 hook lines from `01d51c8e` (already in L0) are *replaced* by the
  resolver above: `Lich.launcher`, `--webui`/`--gtk`, the setting, the
  constant; `init.rb`, `lich.rbw`, `main.rb`, `argv_options` read it
- `2989bdc2` `--webui-dev` survives child sessions → becomes "the resolved
  launcher survives child sessions"
- `b1fecfbd` the shim's server outlives the script that started it (the
  service-lifetime part is wiring; the shim part goes to L6)
- `ScriptScope.activate!` and the plugin glob
- file-service roots the shim serves from (`SERVABLE_ROOTS`)

Spec surface: `spec/lib/main`, the resolver spec. Acceptance: with no flag
and no setting the launcher is `DEFAULT_LAUNCHER`; with `--gtk` startup is
byte-for-byte the GTK path.

### L3 — `webui/contract-primitives`

Purpose: the contract at its current version with every type rendering,
and the client harness that proves it.

- `9bd8f7fc` tabs.vertical
- `2b6fe56f` export the contract as JSON (+ `export_spec` gate)
- `777c363d` every declared type and property renders
- `e5fa305a` nav (2.16.0), `d1f4b075` group.card + text.size
- `dd78babf` line/rect/ellipse layers (2.17.0)
- `fe7f6d72` table max_height; `dfd100cb` row activation + editors (client
  half); W05 multi-select `4f3ba22d`
- contract bumps 2.7 → 2.17 collapse to one version history entry per
  version in the PR body; the code lands at 2.17.0
- **new work, gating this PR:** a behavioural harness for `app.js` — jsdom
  or equivalent under `node`, loading the real client against a fake
  `WebSocket` and driving DOM events. First cases: W12's acceptance
  (concurrent A/B actions, repeated refusals, a control changed between
  attempts), multi-select accumulation, edit preservation, shape layers.
  Every client claim in this PR moves from source-string assertion to a
  harness case.

Spec surface: `spec/lib/webui` + the harness. Acceptance: contract.json
matches; harness green; `contract_foundation_spec` locks 2.17.0.

### L4 — `webui/services-boundary`

Purpose: the one business-service boundary `architecture.md` decision #4
asks for, so the GTK launcher and the WebUI launcher share catalog identity,
credentials, authentication and session launch — and so Lich 6's cut is a
deletion.

- move the non-widget helpers out of `lib/common/gui/` into
  `lib/common/authentication/`: `MasterPasswordManager`, keychain access,
  what `entry_store`, `cli_password`, `cli_encryption_mode_change`,
  `cli_orchestration` reach for (lich-6 #6 did this inline: `entry_store`
  −76/+11)
- drop the GTK compaction hooks from `async_processor` and
  `memoryreleaser` (lich-6 #6 did the same)
- W02 stable entry keys `b89f2ad7` + `1c02c23d` land here, on the catalog
- add lich-6's `script/ci/check_core_gtk_boundary.rb` as a **warning**

Spec surface: `spec/lib/common/authentication`, `spec/lib/common/cli`,
catalog integration. Acceptance: `grep -l "common/gui" lib/` returns only
`lib/common/gui/*` itself, `gui_login.rb`, and `main.rb`'s GTK branch.

### L5 — `webui/launcher`

Purpose: the WebUI launcher as a complete replacement for the GTK login,
on the L4 services.

- `lib/common/webui_launcher*` from L0, plus:
- `79c49571`, `2678f327`, `f98c4c32`, `4de860db`, `ad904501`, `6988b866`
  (Frontends tab, squash to "the Frontends tab")
- `ae8860d4` + W01 `7d97a46d` (cancellation covers every path)
- W03 detach grace `58fdfd83`
- `2eaa04df` entry rows and the bare-page rule
- `a38e9436` launcher row sizing (launcher half)
- geometry store, dark theme, autosort as they stand
- the launcher sets and reads the persisted `launcher:` setting (L2)

Spec surface: `spec/lib/common/webui_launcher*`. Acceptance: every workflow
of the GTK login has a WebUI counterpart or a CLI one (conversion is CLI in
lich-6 and stays CLI here); the mid-authentication close spec passes for
saved, manual and persistent paths.

### The shim's admission rule (decided 2026-09-16)

- **A script authored by elanthia-online is not a shim candidate.** The
  org's own GTK scripts (49 in `elanthia-online/scripts`, 15 of them also
  bundled in lich-5, plus `bsprofiles`) are rewritten natively against the
  contract, not run through the shim. `map`, `bsprofiles` and `creaturebar`
  are the first three (L6c); the rest are scheduled by use, not by size.
- **Every other script needs approval, per feature.** A third-party script
  enters the supported list by naming what it needs shimmed (which widget
  classes, signals and models); the shim grows only for an approved need.
  The ledger is the evidence for the request; "loaded without error" is
  not an approval.
- Consequence: the shim's vocabulary is a floor set by the org scripts
  that have *not yet* been rewritten (they run on the shim during the
  preview) and then shrinks to what approved third-party scripts use. When
  the last org script is rewritten and no third-party script is approved
  for a family, that family is deleted.

### L6a — `webui/shim-core`

Purpose: the script scope and the widget vocabulary the supported-script
list uses. Declared surface, no "long tail".

Decisions folded in here (ledger part 2, decided 2026-09-16): shim
windows open the way lich-6 opens a script page — no private profile, no
process monitor; the viewer detach/close path notices a closed window
(D1). Commits coalesce per batch (D3). `respond_to_missing?` answers only
for the setter shapes `method_missing` handles (D4). The 640x480
allocation fallback and every presentation degradation report through the
ledger (D5, D16). `Dialog` waits through `ModalCoordinator` like
`MessageDialog` (D15). A shim page refuses a second viewer (D26).

- `ScriptScope` + `Nesting` + helpers (`e5e7c768`, `86b4fdbc`)
- `Session` (one thread per script, viewer writes deferred to commit
  W06 `2d8cac22`, hop backpressure W07 `b0197807`, terminal after shutdown
  W04 session half `444ab98e`, dialog cancellation `134ea254`, own-answer
  `6781986e`)
- `Widget`, containers, packing/layout (`d6bf3694`, `dd22b793`,
  `2d2853af`, `1a7afa98`, `f8185b66`, `a4387b82`, `84225e69`, `a574627e`,
  `0f272c86`, `fd561f02`), presentation (`82a37514`, `ed2582d5`,
  `f81b0301`, `1ee72ee5`), W08 retention `cbed8018`
- `const_missing` degradation `9b258b67`, `161ce0b8`, stubbed-widget notice
  `7d591d27`, `c6ddc457`, clamped-value reporting `9d0fc09d`, setter chain
  `a3d2d6f8`, `def_setter`
- password entry `8668064f` + F3 `42fe7a69` + the shim half of `2ac51767`
- the per-script ledger `1d4fdc3f`
- rubocop passes: fold `c8532075`, `d99734f4`, `243b1220`, `1b7829f7`,
  `6d1595fe` into their areas — there is no "style" commit in the new stack

Spec surface: `spec/lib/common/script_scope` minus data/menus/images.
Acceptance: `vars.lic` and `alias.lic` run unmodified; the supported-script
list is checked in (`docs/webui-supported-scripts.md`) with fixture
versions and known degradations, per `architecture.md` decision #2.

### L6b — `webui/shim-data`

Purpose: the rest of the declared surface. **No images, no menus.**
Decided 2026-09-16: the only scripts that draw images (`map`,
`bsprofiles`, `creaturebar`, `calibrate_creaturebar`) and the only scripts
that build `Gtk::Menu`s (`map`, `creaturebar`, plus `xnarost`/`orbuculum`,
which are unsupported and unused) are rewritten natively against the
contract instead of shimmed. The census is in
`docs/webui-review-ledger.md` (part 3). This is the "native rewrites of
Builder-heavy scripts" half of Doug's architecture note, and it is what
keeps the shim finite.

- Builder + data widgets `e5db107f`, TreeStore `f67c6495`, iter-as-cursor
  `14068770`, store walking `bbe554e1`/`132c45c6`, editors/activation shim
  half `dfd100cb`, `53a1cb79`
- markup (`Label#set_markup`, 149 call sites across bigshot, spellson,
  armor, boon, sloot) and pointer press/release (jinx, sspell, bardwag use
  it for click detection) from `91fa366e`/`6d715b4e` — **without** the menu
  classes, `popup`, or `context_menu` wiring; drag-drop setup `17e37d71`
  only if a supported script exercises it (ewaggle)
- slice five `e6ad27e5` minus `Overlay` and `Paned` unless a supported
  script uses them; `ProgressBar`/`ListBox` go with creaturebar's rewrite
  unless another script uses them; `Dialog` stays; key presses `d793e49a`;
  glib sources `fb586065`

**Not carried:** `images.rb`, `drawing.rb`, `menus.rb`, `Gtk::Layout`,
map interaction (`66160a55`, `ecc7877d`), the image/layout commits
(`782b51ef` .. `2db9087c`), the Cairo/GdkPixbuf stand-ins (`9794c16a`,
`d1275cb8`), `install_pixbuf_tracking!`, `PixbufSources`, and
`gtk_images_spec`/`gtk_menus_spec`/`gtk_map_interaction_spec`. A script
that names `Gtk::Image`, `Gtk::Layout`, `Gtk::Menu`, `GdkPixbuf` or `Cairo`
under the shim gets the stubbed-widget notice and the ledger entry, which
is the honest answer.

Spec surface: the rest of `spec/lib/common/script_scope` minus the three
files above. Acceptance: every script on the supported list that uses a
data widget runs unmodified (`jinx`, `ewaggle`, `repository`, `vars`).

### L6c — the image-and-menu scripts, rewritten in place

Purpose: `map`, `bsprofiles` and `creaturebar` stop using GTK and use the
WebUI directly. Each is rewritten **in its own file** in
`elanthia-online/scripts` -- `scripts/map.lic` *is* `;map`; there is no
side file and no launcher gate. The script requires the WebUI and tells a
Lich that is too old so. They consume the L3 primitives: `composite` with
`image`, `region`, `line`, `ellipse` and `label` layers (contract 2.17),
`surface_events` for clicks, `menu` with check/radio items and submenus
for the options menu, the `presentation` facility for keep-on-top,
borderless, opacity and hidden scrollbars, and `surface_zoom` (contract
2.19, added for this) for ctrl+wheel zoom. `scripts/eohunter/setup/page.rb`
was the working native pattern.

Status: **`map.lic` 3.0.0 is written (2026-09-17)** and awaits the user's
in-game test. It keeps every setting under its old keys, the per-character
window size and position, notes, tags, locations, links between sheets,
fix mode and `;map <room>`. It was verified two ways: a harness that loads
the script against a stubbed script scope and renders through the real
page, builder and validator (14 cases: sizing, layers, menus, click
routing, notes, find, zoom, geometry, settings, centring through a real
attach); and a real Chrome window on a real sheet, which opened at the
saved 400x300 and centred the room. Two client fixes fell out of it and
sit in L3: a window-level scroller no longer counts as the page's natural
size (the window opened the size of the sheet), and geometry no longer
restyles a fitted page on every render (the page stayed the stored width
when the viewer resized the window). `bsprofiles` and `creaturebar` are
next, in that order.

### L7 — `webui/default-flip` (Step A)

Purpose: `DEFAULT_LAUNCHER = :webui`. GTK stays behind `--gtk` and the
setting. The boundary checker stays a warning. This PR is one constant, one
spec line, and the release note.

### L8 — Lich 6: `gtk-removal` (Step B, lich-6 #6 as written)

Delete `lib/common/gui/`, `gtk.rb`, `gtk_compaction.rb`,
`authentication/gui.rb`, `gui_login.rb`, the `--gtk` flag and the setting,
gemcheck's gtk group, the GTK specs; flip the boundary checker to a hard
gate. After L4 this is `git rm` plus four small edits. Gate: a clean
install with no GTK libraries launches core and every supported workflow on
Windows, macOS and Linux.

## Not carried forward

- `docs/all` plan-status commits (`90372e25`, `27ae985a`, `f7b81e7e`,
  `afb5fdfa`, `9882a7cb`, `8f2c594d`, `3626e64f`, `9c56e0b7`): their
  content folds into the PR bodies and into one current capabilities
  matrix; `docs/webui-gtk-shim-plan.md` is marked historical.
- `0e4ebe21` Gtk.queue error names the script line — keep, in L6a.
- Anything the supported-script list does not exercise and the ledger never
  records is a candidate for *not* porting into L6. Decide per item, in the
  L6 PR bodies, with the census as evidence.

## Order of work

1. Astra's review round on the current stack completes. Fixes it produces
   land on the current stack (last time).
2. Freeze. Tag the tips (`webui/13-audit-fixes` and each PR head) so nothing
   is lost.
3. Build L1 → L7 in order on a fresh branch chain from `main`, each as its
   own PR based on the previous. L0 is #1634, already there.
4. Close #1635–#1644 with a comment pointing at the layer that replaced each.
5. L8 waits for the preview period and the ledger.

## Risks, named

- **Losing a fix in the cherry-pick.** Mitigation: the acceptance checklist
  (W01–W13, Astra's items, this document's per-layer lists) is ticked in
  each PR body, and the whole surface must be 0 failures at every layer.
- **The harness is new work on the critical path (L3).** It is the one
  thing here that does not exist yet. It is also the thing the audit is
  most right about; do not ship L3 without it.
- **"Minimal" drifts into "small".** The supported-script list is the
  arbiter; write it before L6, not after.
- **Review load.** L6a and L6b are still large. If a reviewer wants them
  split further, split by widget family; the per-area squash makes that
  possible.

## Status: built, 2026-09-17 (all local, nothing pushed)

The chain exists. Every layer is a local branch, based on the one before
it, starting from `webui/01-vendor` (#1634, which already sits on
`origin/main` at `236a9a2c`). Tips at the time of writing:

| layer | branch | commits | spec surface | result |
|---|---|---|---|---|
| L1 | `webui/core-corrections` | 9 | `spec/lib/webui` | 0 failures |
| L2 | `webui/wiring` | 3 | `spec/lib/main`, launcher_choice, script_scope, session_launcher | 0 (+1 known) |
| L3 | `webui/contract-primitives` | 14 | `spec/lib/webui` incl. the jsdom harness (18 cases) | 0 failures |
| L4 | `webui/services-boundary` | 4 | authentication, cli, gui, boundary check | 0 (+1 known) |
| L5 | `webui/launcher` | 2 | `spec/lib/common/webui_launcher*` | 0 failures |
| L6a | `webui/shim-core` | 15 | `spec/lib/common/script_scope` (core subset) | 0 failures |
| L6b | `webui/shim-data` | 5 | `spec/lib/common/script_scope` | 0 failures |
| L7 | `webui/default-flip` | 1 | launcher_choice | 0 failures |

Contract is 2.19.0 (2.18 payload-free password `change`; 2.19
`surface_zoom`). These documents (this plan, the review ledger, the
handoff) ride on L1 so a reviewer of the first PR has them.

Whole-chain run on the L7 tip: 1592 examples across every layer's
surface, 2 failures, both the known Windows environment ones
(`session_launcher_spec.rb:401`, `launch_data_spec.rb:166`, both fail on
`main`). The full suite was compared against `main` in a separate
worktree; see the handoff.

Separately, `fix/frontend-window-handle` (one commit off `main`) is D12.

**How it was built.** File-snapshot per layer from `webui/13-audit-fixes`,
not per-commit cherry-picks: the old commits were too intertwined to
replay by area, so each layer took the files that belong to it and
squashed them into area commits whose bodies carry the narrative. Two
things are new code rather than curation: `lib/common/launcher_choice.rb`
(L2) and `spec/webui_client/` (L3, the harness). Every decision in the
ledger (D1-D26) is implemented in the layer its write-up names; D13's
adapter hooks sit as the last commit of L6a, labelled `refactor(webui)`,
so they can be moved to L1 if the reviewer wants them there.

**Deviations from the plan above, on purpose.**
- L1 is server-side only. Every client fix (W12 replay, reconnect, edit
  preservation) lives in L3 with the whole client, because `app.js` could
  not be split by layer without surgery; L3's harness pins each of them.
- L6a's ledger/degradation and GLib code were split out of `widgets.rb`
  into `gtk/degradation.rb` and `gtk/glib.rb` so the area commits are
  real files.
- The launcher's toggle says "native launcher", not "GTK", because the
  core boundary checker (L4) flags any identifier containing `gtk` and the
  launcher must stay on the clean side of it.

**What the user does next.** Live test on this box with
`ruby lich.rbw` (WebUI default) and `ruby lich.rbw --gtk`; a script that
draws a window under each; a Multi-Launch child; and `;map` 3.0.0 (the
rewritten `scripts/map.lic`, which lives in `elanthia-online/scripts`, not
in this repository). Then push each layer branch to
`elanthia-online/lich-5` in order and open the stacked PRs, each based on
the previous branch; close #1635-#1644 with a comment pointing at the
layer that replaced them.
