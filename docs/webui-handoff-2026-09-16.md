# WebUI / GTK shim: handoff, 2026-09-16 (updated the same evening)

Written for the next agent picking up this stack. It records where the
branches are, what is verified, what is deliberately not done, and what is
the user's call rather than an agent's. The first version of this document
ended with a blocked item; that item is resolved and the section below says
how.

## 2026-09-17: the rebuild exists

The chain in `docs/webui-rebuild-plan.md` was built on 2026-09-17 as local
branches `webui/core-corrections` → `webui/wiring` →
`webui/contract-primitives` → `webui/services-boundary` → `webui/launcher`
→ `webui/shim-core` → `webui/shim-data` → `webui/default-flip`, from
`webui/01-vendor`. See the plan's status section for tips, per-layer
results, and the full-suite comparison against `main` (8665 examples on the
tip vs 8027 on main; the same 55 environment failures plus two
order-dependent ones that also fail on main). Everything below this line
describes the **old** stack, which is frozen. Nothing new is pushed.

## The stack

Every PR head lives on the `nisugi` fork; every PR base is the same-named
branch on `origin` (elanthia-online).

| PR | head branch (nisugi) | base (origin) | state |
|----|----------------------|---------------|-------|
| 1637 | `webui/04-slice-four-layout` | `webui/03-slice-three-menus` | mergeable |
| 1638 | `webui/05-map-groundwork` | `webui/04-slice-four-layout` | mergeable |
| 1639 | `webui/06-images-and-map` | `webui/05-map-groundwork` | mergeable (bases force-pushed, see below) |
| 1640 | `webui/07-slice-five` | `webui/06-images-and-map` | mergeable |
| 1641 | `webui/08-polish` | `webui/07-slice-five` | mergeable |
| 1643 | `webui/09-contract` | `webui/08-polish` | mergeable |
| 1644 | `webui/10-frontends` | `webui/09-contract` | mergeable |

Local work stacked on the rebased `nisugi/webui/10-frontends`, **none of it
pushed**:

| branch | contents |
|--------|----------|
| `webui/11-primitives-rebased` | nav / card / text.size / F10 / F8 (4 commits) |
| `webui/12-password-value` | F3, the password fix, plus the first version of this document (2 commits) |
| `webui/13-audit-fixes` | **66 commits**: every finding in Doug's 5.22.0 audit, the shape-layer contract (2.17.0), the Cairo/GdkPixbuf stand-ins, the per-script ledger, then (same evening) every minor and nit from mrhoribu's two rounds and the third review that had never been closed, plus a spec guard so no spec can open a real browser. `docs/webui-review-ledger.md` is the item-by-item status and the open decisions. Checked out. |

`webui/11-primitives` (old) is the stale pre-rebase copy. Do not build on it.

The natural PR shape: 11 → 12 → 13 as three PRs continuing the chain, each
based on the previous. 13 is large but every commit is one finding with its
own spec and its own commit message explaining the failure; review it by
commit.

### The previously blocked item, resolved

#1639–#1644 reported CONFLICTING because each PR's base branch on `origin`
held pre-rebase history. The user force-pushed the five `origin` bases
(`webui/05` through `webui/09`) to match the rebased `nisugi` branches on
2026-09-16. Verified afterwards with `git fetch origin` and
`git merge-base --is-ancestor`: every base is now an ancestor of its head.
The GitHub PR pages should show MERGEABLE on refresh. No agent pushed
anything; the global rule (no push without permission in the conversation,
never a force-push on a prior "push it") still stands.

## Doug's audit, finding by finding

`branch-issues.md` (audit at merged preview `f197a61d`, WebUI tip
`52a62791`) listed thirteen findings. Status at `webui/13-audit-fixes`:

| # | finding | status | where |
|---|---------|--------|-------|
| W01 | cancelled launcher work still launches / saves | **fixed** — persistent and saved paths were fixed by F5 on branch 10; the manual path still saved the entry before checking liveness | `7d97a46d` |
| W02 | `entry-N` keys change meaning when an entry is removed | **fixed** — keys are a digest of account+character+game, stable across neighbours, unresolvable once the entry is gone | `b89f2ad7`, `1c02c23d` |
| W03 | transient socket detach closes the launcher | **fixed** — a detach opens a 5s grace (the client's max backoff); an attach inside it cancels the close | `58fdfd83` |
| W04 | shutdown does not prevent new workers/callbacks | **fixed** on both queues — dispatcher owners are terminal (weakly recorded), session refuses late work, `sync` raises instead of hanging | `444ab98e` |
| W05 | table editing / activation / multi-select not in the browser | **fixed** — editors and dblclick/Enter activation landed on branch 11 (F8); ctrl/shift multi-selection added here | `4f3ba22d` |
| W06 | options + selection in one job leaves the viewer stale | **fixed** — viewer writes are queued and applied by the commit that follows the structural render | `2d8cac22` |
| W07 | shim bypasses the dispatcher's bound | **fixed** — the hop parks the dispatcher thread while the session queue is full, so the dispatcher's own bound and overflow refusal apply; timers were already bounded via `sync` | `b0197807` |
| W08 | removed widgets retained by bookkeeping | **fixed** — both paths: the container's identity map and the adapter's presentation readers | `cbed8018` |
| W09 | render discards a half-typed number | **fixed** — number fields are captured; unparseable text (`badInput`) is not, and is documented | `9d656288` |
| W10 | password never reaches the activation handler | **fixed** — F3 on branch 12 (submission scope) plus a runtime `clear_sensitive(page, cid)` so `entry.text = ""` empties the viewer's field | `42fe7a69`, `2ac51767` |
| W11 | an empty `Gtk::Image` refuses the whole page | **fixed** — an empty src is the defined "nothing to show" state; the client leaves the attribute off | `836d05f3` |
| W12 | stale-event retry cannot meet the server protocol | **fixed** — refusal first (now naming the event), render second; the client replays into the render that follows with the original payload and submission | `da1cfd3b` |
| W13 | full suite cannot load with native bindings | **fixed** — three specs opened `GLib::Timeout` as a class, the gem declares a module | `112d33b4` |

Also from the handoff's own list: the `Dispatcher#enqueue` OverflowError
carrier leak (`c61b3826`) and the missing runtime API to clear a viewer's
password field (`2ac51767`).

Every fix has a spec that was run **without** the fix and seen to fail,
except W02 (whose assertion cannot pass with positional keys by
construction) and the client-side halves, which are source-level assertions
in `assets_spec.rb` — see "what is owed" below.

## `architecture.md`, and the clean break from GTK

The user's stated goal: a clean break from GTK. Where that stands:

**Imaging (the "image fiasco") — done, without rewriting the scripts.**
The whole corpus draws three things with Cairo (stroked circle, stroked
box, two crossed lines; `map.lic`, `bsprofiles.lic`) and loads map tiles it
never inspects beyond width and height.

- Contract **2.17.0** (`dd78babf`) adds `line`, `rect` and `ellipse` layers
  to `composite`, with optional stroke/fill tints, stroke width and opacity.
  `contract.json` is regenerated; `export_spec` checks it.
- `lib/common/script_scope/gtk/drawing.rb` (`9794c16a`) gives the script
  scope its own `Cairo` and `GdkPixbuf`. A surface records shapes; a pixbuf
  built from it carries and scales them; a `Gtk::Image` of one renders as
  a composite of shape layers, alone or on a `Gtk::Layout`. A file pixbuf
  reads its size from the header (the existing `ImageHeader`). Raw pixels
  are PNG-encoded in pure Ruby (zlib) and inlined under the same 8KB cap.
  Cairo's R/B swap through a pixbuf is reproduced on purpose: every script
  pre-swaps to compensate. Anything else (`show_text`, a partial arc, an
  unknown pixbuf method) is reported through the ledger, never pretended.
- A `Gtk::Label` on a layout is now a `label` layer, so `;map`'s note pins
  (emoji labels — the old shim comment saying they were Cairo was wrong)
  show for the first time.
- `gtk_images_spec.rb` no longer requires either gem and must pass on a
  machine with neither. A shim-spec example proves a script binding
  resolves `Cairo` and `GdkPixbuf` to the stand-ins.

What this means: `;map` and `;bsprofiles` run unmodified with no native
image library in the process. The gems stay in the Gemfile only because the
`gtk3` gem (the native launcher) depends on them.

**A native `;map` rewrite is still on the table, not done.** It is ~2,300
lines of GTK window code (menus, drag/scroll/click, fix mode, settings,
geometry) and needs in-game testing. It is no longer *required* for the
image goal; it is required only if the aim is for `;map` to stop depending
on the shim at all. `scripts/eohunter/setup/page.rb:693` is the working
native pattern (`composite` with `region` layers and `surface_events`).

**The native GTK launcher is the remaining GTK.** `lib/common/gui/` and
`lib/common/authentication/gui.rb` — about 13.7k lines across 31 files that
reference `Gtk::` — plus the single `require 'gtk3'` in `lib/init.rb:419`.
`HAVE_GTK` is set there and read nowhere. The WebUI launcher already
reimplements the workflow. The `architecture.md` decision #4 (one
business-service boundary for catalog identity, credentials, auth and
session launch shared by both UIs) is the thing that turns removal into a
deletion; W02's stable keys are a first step. This is the Lich 6 gate:
a clean install with no GTK libraries that launches core and every
supported workflow on Windows, macOS and Linux.

**The ledger** (`1d4fdc3f`) answers the audit's "respond_to? lies" point:
unsupported-API hits are recorded per script and per API with counts,
`Gtk.unsupported_report` exposes them, and a session logs one summary line
for its script at shutdown. A season of previews therefore produces the
supported-script manifest from evidence. Known external-corpus gap the
ledger will confirm or refute: `DrawingArea` + arbitrary `draw` callbacks
(2 scripts per `docs/webui-gtk-shim-plan.md:219`, none bundled here).

## What is owed

- **A behavioural harness for `app.js`.** Every client fix here (W05
  multi-select, W09, W12's replay, the shape layers) is pinned only by
  source-string assertions in `assets_spec.rb`; the audit is right that
  those cannot establish behaviour, and the old password spec is the
  cautionary tale. `node` is installed on this box. A jsdom-style harness
  that loads `app.js` against a fake `WebSocket` and drives real DOM events
  is the next thing worth building, and W12's acceptance (concurrent A/B
  actions, repeated refusals, a control changed between attempts) should
  be its first cases.
- **Dirty-gated commits.** Attempted before this session and backed out
  (44 failures). Not re-attempted. No branch exists.
- **The golden/conformance harness.** Designed, never implemented.
- **F3's two contract-level gaps** are unchanged and still logged rather
  than silent: no live password strength meter (`password_input` has no
  `change`), and a re-prompt shows emptied fields (`clear_sensitive` after
  every submit). Both need a contract decision, not a shim patch.
- **`docs/webui-gtk-shim-plan.md`** still mixes historical intent with
  current claims (the ewaggle double-click claim is now true, since F8, but
  the document does not say when). Mark it historical and keep the current
  capabilities in one dated matrix.

## Verification on this box

- Full suite: **8596 examples, 55 failures, 1 pending** before the last two
  feature commits; the 55 are the known environment failures (14 files,
  listed in the agent memory `lich5-preexisting-spec-failures`), unchanged
  from the baseline. The run after the final commits was in progress when
  this was written; the WebUI + shim + launcher surface was
  **575+ examples, 0 failures** at every checkpoint.
- `bundle exec rspec spec/lib/webui spec/lib/common/script_scope
  spec/lib/common/webui_launcher spec/lib/common/webui_launcher_*_spec.rb`
  is the surface that must stay at 0.
- The full suite now **loads** with the real `gdk_pixbuf2` gem installed
  (it did not, before W13). Pending dropped from 6 to 1 because the image
  examples that used to skip now run.
- Rubocop is clean on every file touched.

## Traps in this codebase, learned the hard way

- **`respond_to?` is useless for capability checks on a shim widget.**
  `Widget#respond_to_missing?` returns true for every name. Test
  `node.class.method_defined?(:foo)`.
- **The shim overrides `render_children`.** `ShimAdapter` defines its own
  (`session.rb`) and passes `placement:`. Patching `Adapter#render_children`
  in `lib/webui/adapter.rb` is a no-op on the shim's render path.
- **The adapter `@mutex` is not reentrant.** `ShimAdapter#destroy_node!`
  runs *inside* the base lock; put per-handle cleanup there, not in a
  `destroy` override that takes the lock again.
- **Specs that assert on the component tree prove nothing about delivery.**
  Drive a real viewer through the runtime (see `gtk_password_spec.rb` and
  the W06 example in `gtk_review_fixes_spec.rb`).
- **A `sync` returns before the commit that follows its job.** To observe
  the flushed state (viewer writes, rendered props), queue another
  `session.sync { nil }` behind it.
- **`session.sync` on a shut-down session raises** (`Lich::WebUI::Error`)
  since W04; `enqueue` on one is dropped. Specs that shut down and then
  poke the session must expect that.
- **Contract version bump touches four places**: `contract.rb`, `app.js`
  `VERSION`, `contract_foundation_spec.rb`, `server_spec.rb` — then
  regenerate `contract.json` with the one-liner in `export_spec.rb`, and
  the jsdom fixtures with `ruby -Ilib spec/webui_client/fixtures/generate.rb`.
- **A viewer-scoped prop reaches the browser only in a render whose tree
  carries it**, and the tree seeds it once per viewer. To move a scroller
  again: write the value through `page.set(cid, prop, value, viewer:)` for
  every `runtime.viewer_ids(page)` and render the prop in exactly the next
  render, then drop it, or every later commit snaps the viewer back there.
  `scripts/map.lic` (`push_scroll`) and the shim's ScrolledWindow both do
  this.
- **Blocks handed to the tree builder run with the builder as `self`.**
  Read the script's own state into locals before the block; an ivar inside
  it is the builder's, silently nil.
- **TONES are `neutral positive caution danger`**; there is no `accent`
  tone for a tint.
- **Agent-side: the Bash tool's heredoc collapses `\\` to `\`.** A Python
  script fed through a heredoc wrote a literal NUL byte into `catalog.rb`
  (`b89f2ad7`, fixed in `1c02c23d`). Write edit scripts to a file with the
  Write tool and run them; never put a backslash escape in a heredoc-fed
  string that must land in source.
- Roughly 55 environment-related spec failures always fail on this box
  (Windows temp-file renames, subprocess launches, `Win32::MB_OK`). Never
  re-baseline against `main`.

## Housekeeping

- Working tree is clean; `webui/13-audit-fixes` is checked out.
- Nothing on 11/12/13 is pushed. The user decides when and where.
- Two stashes exist and are **not** part of this work; leave both alone.
- `vellum-fe.exe` (62MB) is untracked and ignored only via
  `.git/info/exclude`.
- Avoid `git stash` and `git reset --hard` in this repo. Use a worktree for
  throwaway experiments.
