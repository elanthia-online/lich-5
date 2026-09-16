# WebUI + GTK shim review

Review of `lib/webui/` and `lib/common/script_scope/gtk/` on `feat/webui-port`
(~11,900 lines), 2026-09-16. Findings were produced by parallel per-area
reviewers, then each was put through adversarial verification; everything
listed below was additionally confirmed by reading the cited code, and the
worst one by an executable reproduction.

Findings are ordered by what they cost you, not by where they live.

## Summary

The architecture is sound and the security surface is genuinely well built
(see [What is right](#what-is-right)). Nearly every correctness bug found is
an instance of **one systemic gap**: a viewer-scoped property written into
the shadow tree without the paired `Session#viewer_write` push. Fix the
pattern once and six separate user-visible bugs close together.

| # | Severity | Where | What |
|---|---|---|---|
| 1 | Critical | `widgets_data.rb:792` | `TreeIter#next!` hangs the session thread and corrupts the model |
| 2 | High | 4 sites | Viewer-scoped writes skip `viewer_write`; controls stick |
| 3 | High | `session.rb:497` | An exception from `commit` kills the session thread for good |
| 4 | High | `adapter.rb:188` | `destroy` does not reassign sibling slots |
| 5 | High | `session.rb:377` | `@viewers` mutated outside the mutex |
| 6 | High | `widgets.rb:654` | `destroyed?` is permanently false for non-Window widgets |
| 7 | Medium | `app.js:1072` | Reconnect handler closes over the socket variable |
| 8 | Medium | `app.js:493` | `disabled` never reaches `select` / `table` |
| 9 | Medium | `widgets.rb:581` | `hexpand=`/`vexpand=` omit `changed!`; `@vexpand` is dead |
| 10 | Low | various | Dead code, duplication, stale docs |

---

## 1. `TreeIter#next!` hangs the session thread — fix first

`lib/common/script_scope/gtk/widgets_data.rb:792`

`iter_first` returns the *stored* `TreeIter`, and `next!` mutates that same
object in place. `iter_after` then locates it with `@rows.index(iter)`, which
falls back to object identity because `TreeIter` defines no `==`. After the
first step the stored row 0 *is* row 1's data, so `iter_after` keeps
returning row 1.

The canonical GTK walk both corrupts the model and never terminates.
Reproduced:

```
before walk : ["alpha", "beta", "gamma"]
walk visited: ["alpha", "beta", "beta", "beta", "beta", ...]   # never ends
after  walk : ["beta", "beta", "gamma"]                        # model corrupted
```

`jinx.lic` uses exactly this loop at two sites (`2228`, `2457`):

```ruby
break unless it.next!
```

It only survives when the row it wants is the first one; otherwise the
session thread is gone and the script's UI is dead.

**Fix.** Have `next!` locate its position by `key`, not identity, and return a
fresh iter rather than mutating in place — or keep in-place mutation (which
does match ruby-gnome) and make `iter_after` search by `key`. The second is
the smaller change:

```ruby
def iter_after(iter)
  index = @rows.index { |row| row.key == iter.key }
  index && @rows[index + 1]
end
```

Related, same file: `path_indices` (`:897`) returns only the last path
component, so nested `TreeStore` paths collide; `remove` (`:857`) leaves the
caller's iter valid-looking, so later writes through it silently no-op.

## 2. Viewer-scoped writes that skip `viewer_write`

This is the systemic one. `ViewerStore` overlays each viewer's own last input
on top of props at serialize time (`viewer_store.rb:176`), so once a viewer
has touched a control, **only** an explicit `Session#viewer_write` can move
it again. The idiom

```ruby
@session.viewer_write(window_root, self, :checked, @active) if @handle
```

is hand-repeated at ten sites across four files, and every bug below is a
place where it was forgotten.

| Site | Effect |
|---|---|
| `widgets.rb:2457` `RadioButton#deactivate_quietly` | Deselected radio stays checked — two radios appear selected |
| `menus.rb:225` `RadioMenuItem#deactivate!` | Same, for menu radios (its `CheckMenuItem` sibling at `:119` does it right) |
| `widgets.rb:1748` `Adjustment#notify_owners` | `adjustment.value = n` re-renders but the viewer's number keeps the old value |
| `widgets_data.rb:435` `ComboBox#active=` | Guard is `if @handle && @active_id`, so clearing a selection (`active = -1`, `remove`, `remove_all`) pushes nothing and the stale choice remains |

`scroll_position` (`contract.rb:283`) is the same shape: viewer-scoped, seeded
into the overlay on the first commit that requests a scroll, and never pushed
again — so the *second* distinct scroll a script asks for is discarded.

**Fix.** Stop hand-writing the idiom. Either add a `Widget#push_viewer_value(name, value)`
helper and call it from every viewer-scoped setter, or (better) let `changed!`
push viewer-scoped props automatically so the invariant cannot be forgotten.
For `ComboBox`, drop the `&& @active_id` guard — `select.selected` is not
`required`, so `nil` is a legal "clear the selection" and `viewer_write`
already handles any value.

## 3. An exception from `commit` kills the session thread

`lib/common/script_scope/gtk/session.rb:486-498`

```ruby
begin
  job.call
rescue StandardError, ScriptError => error
  report(error)
end
commit unless @closed      # <-- outside the rescue
```

`commit` validates and re-renders, and `Session#commit` rescues only
`Lich::WebUI::Error` (`:389`). Any other exception out of `flush!` escapes
`run_loop` and the thread exits. The script's window then accepts no further
events, with no recovery short of restarting the script.

**Fix.** Move `commit` inside the `begin`/`rescue`, or wrap it in its own.

## 4. `Adapter#destroy` does not reassign sibling slots

`lib/webui/adapter.rb:188`

`detach` removes a child and then calls `assign_child_slots!(parent_node)`
(`:143`). `destroy` performs the same removal (`:195`) and does not. Slots are
index-derived (`:347-349`), so destroying a middle child of a `named` /
`named_dynamic` / `named_from_property` container leaves every later sibling
on a stale slot — children render in the wrong place, or `Page#render` starts
raising.

**Fix.** Call `assign_child_slots!(parent)` in `destroy`, exactly as `detach` does.

## 5. `@viewers` mutated outside the mutex

`lib/common/script_scope/gtk/session.rb:377`

```ruby
@viewers.delete(page) if page
```

Every other access is guarded — `note_viewer` (`:553`), `forget_viewer`
(`:557`), `viewers_for` (`:561`) — and those run on dispatcher threads. A
viewer attaching while a window closes can corrupt the hash.

**Fix.** Wrap it in `@mutex.synchronize`.

## 6. `destroyed?` is permanently false for every non-Window widget

`lib/common/script_scope/gtk/widgets.rb:654`

`Widget#destroy` never sets `@destroyed`, but `destroyed?` (`:662`) tests
exactly that ivar. Only `Window#destroy` (`:1941`) sets it. There are **50**
`.destroyed?` call sites in the script corpus, and the most frequent are
non-windows — `@@layout`, `view`, `marker`, `@log_view`, `@@panels_container`.
Guards like `widget.destroy unless widget.destroyed?` double-destroy.

**Fix.** Set `@destroyed = true` in `Widget#destroy`.

## 7. Reconnect handler closes over the socket variable

`lib/webui/assets/app.js:1072`

```js
socket.addEventListener("error", () => socket.close());
```

`socket` is module-level and reassigned by each `connect()` (`:1064`). A late
`error` from a dead socket therefore closes the *current live* one, whose
`close` handler schedules another `connect()`. Reconnect chains multiply.

**Fix.** Capture the instance: `const ws = new WebSocket(...)`, then
`ws.addEventListener("error", () => ws.close())`.

## 8. `disabled` never reaches `select` and `table`

`lib/webui/assets/app.js:493`, `:504`

`common()` only applies `disabled` when the element has such a property
(`:58`). `select` and `table` pass their **wrapper** (`<label>` via `field()`,
or a `<div>`) to `common()`, never the `<select>` itself — unlike `input()`,
which sets `control.disabled` explicitly (`:129`).

So `combo.sensitive = false` leaves the control fully interactive and the
browser keeps sending events the script believes it turned off. (`sensitive=`
is 42 uses in the census.)

**Fix.** Set `control.disabled` in the `select` renderer, and gate the
`table`'s row handlers on `props.disabled`.

## 9. `hexpand=` / `vexpand=` omit `changed!`, and `@vexpand` is dead

`lib/common/script_scope/gtk/widgets.rb:581-589`

Neither setter calls `changed!`, while the neighbouring `margin=` and
`set_padding` both do — so an expand toggled after the first render never
reaches the client. `@hexpand` *is* consumed for Box/Grid weighting (`:1072`,
`:1347`); `@vexpand` is **written and never read anywhere**, so vertical
expansion is silently ignored.

The Builder never translates `hexpand`/`vexpand` either, though the plan doc
lists both as properties it should handle — so Glade `vexpand="True"` does
nothing.

**Fix.** Add `changed!` to both setters; then either consume `@vexpand` for
vertical weighting or delete it and log it as unsupported.

## 10. Dead code, duplication, and stale docs

Verified unreferenced:

- `lib/api/webui.rb` — the whole file. Never required, no spec. Its sibling
  `lib/api/active_sessions.rb` *is* wired up at `lich.rbw:85`; this one never was.
- `Session.sessions` (`session.rb:189`) — zero references.
- `Server#websocket_upgrade?` (`server.rb:447`) — zero references.
- `@dirty` (`widgets.rb:739`, `:792`) — written twice, never read.
- `@min_height` (`widgets.rb:1454`) — `set_min_content_height` stores it; nothing reads it.
- `@sort_column` (`widgets_data.rb:916`) and `TreeViewColumn#sort_column_id`
  (`:1072`) — both write-only. `set_sort_column_id` silently does nothing, and
  the contract's `table.sort` is never populated, though `runtime.rb:325`
  already recognises `[:table, :sort_change]`.
- `Dispatcher::OwnerState#current` (`dispatcher.rb:124`) — written per event, never read.
- CSS: `.row-actions`, `.workflow-actions`, `.validation-message` match nothing any renderer emits.

Duplication worth collapsing:

- `owner_label` is copy-pasted verbatim into five WebUI classes.
- `validate_input_event!` and `validate_dynamic_input_value!` (`validator.rb:495`)
  are the same ~15-line validator twice, differing only in error wording.
- The `viewer_write` idiom (finding 2) — ten hand-written copies.

Traps rather than bugs:

- `STRUCTURE_TYPES` / `DISPLAY_TYPES` / `INPUT_TYPES` (`contract.rb:20-22`) are
  positional slices — `TYPES.first(11)`, `slice(11,5)`, `slice(16,10)`. Nothing
  reads them, they cover only 26 of 31 types (`table`, `dialog`, `composite`,
  `menu`, `menu_item` fall outside all three), and they mis-slice silently if
  `TYPES` is ever reordered. Delete them or derive them by name.
- `FileService#register` (`file_service.rb:37`) overwrites an existing alias
  with no owner check, while `unregister` (`:43`) correctly verifies ownership.
  Not currently exploitable — the shim derives aliases as `gtk-<owner>-<n>`
  (`session.rb:291`), so scripts cannot collide by accident — but the asymmetry
  should be closed.
- `text_input` branches on a launcher-private cid substring,
  `component.cid.includes("text_input:window-geometry")` (`app.js:472`), inside
  the generic renderer. Launcher specifics do not belong in the shared client.
- Five contract types — `log`, `markdown`, `overlay`, `slider`, `split` — have
  schemas and TreeBuilder support but no `app.js` renderer, so they paint
  "Renderer not implemented". Latent only: the shim emits none of them today.
- No Builder XML cache, though the plan requires caching by string hash.
  Measured: 110 ms for bigshot's XML, 84 ms for eloot's, per setup-window open,
  on the session thread. Real but modest — lower priority than the plan implies.

Docs: `docs/webui-gtk-shim-plan.md:90` still says the contract is "now 2.6.0".
It is 2.12.0, and `app.js` agrees — the code is in sync, only the table is stale.

## What is right

Worth stating plainly, because it shapes where effort should go:

- **The security surface is solid.** Loopback-only bind, `SecureRandom` session
  cookie compared with `Protocol.secure_compare`, single-use expiring launch
  tokens, an Origin allowlist plus `Sec-Fetch-Site` checks, masked-frame
  enforcement and payload caps. `FileService` does realpath containment, an
  extension allowlist, null-byte rejection and owner-scoped revocation.
- **No XSS surface in the client.** Zero occurrences of `innerHTML`,
  `outerHTML`, `insertAdjacentHTML`, `document.write`, `eval` or `new Function`.
  The markup renderer builds nodes with `createElement`/`textContent`, as the
  contract requires and `assets_spec` asserts.
- **`ShimAdapter` is a clean subclass**, not a fork of `Adapter` — it adds
  `commit`, batched `update`, placement and presentation, and overrides `set`
  for the viewer-scope rule.
- **The dispatcher and session loop are resilient** to handler exceptions, and
  `Session#sync` correctly guards against reentrancy from the session thread.
- **`?page=` filtering works** (`app.js:977`), and the shim always passes
  `page:` (`session.rb:522`), so the plan's "client attaches to every page"
  concern is resolved for shim-opened windows.
- The GTK references remaining in `lib/` outside the shim are **pre-existing
  lich-5 core** (the real GTK login GUI), not shim leakage; `lib/webui/`
  contains no GTK constant, only comments. The lich-6 boundary rule assumes
  Doug's PR #6 (GTK removal), which this branch deliberately did not take.

## Suggested order

1. Finding 1 — it hangs a live script (`jinx`).
2. Findings 3, 5, 4 — thread death, data race, slot corruption; all small diffs.
3. Finding 2 — do it as the shared helper, not four spot fixes.
4. Finding 6, then 7, 8, 9.
5. Finding 10 as cleanup, alongside the doc version fix.
