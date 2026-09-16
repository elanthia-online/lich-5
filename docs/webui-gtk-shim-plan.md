# GTK-to-WebUI shim: plan and handoff

Status: slices one, two, and three are on branch `feat/webui-port`
(2026-09-16), and slice four is in progress - box packing, per-window
pages, and the dropped setters are done; see slice four for what is
left. Slices five through seven are unstarted. This document is
the handoff: everything a new session needs to continue without
re-deriving it.

Slice three landed contract 2.7.0 (`menu`, `menu_item`, `context_menu`,
`press`/`release`, `text.markup`; written up in
`docs/webui-contract-2.7-menus-markup.md`), the shim's menu family in
`lib/common/script_scope/gtk/menus.rb`, `PointerSurface` on `EventBox`
and `Label`, and markup passthrough on `Label`. Between slices two and
three, live testing of eloot/bigshot fixed: `--webui-dev` propagation to
Multi-Launch children, the WebUI server dying with the first script that
started it (`Session.start_service` starts it from `ThreadGroup::Default`),
`?page=` so each window shows one page (pulled forward from slice four),
size requests no longer forwarded as fixed sizes except on inputs/views,
`xalign`, `wrap`, and a bare-page stylesheet. Slice-three live check still
owed: `;xnarost` or `;map` right-click menu, `;creaturebar` labels.

Slice two landed `Gtk::Builder` and the data widgets (Notebook, SpinButton,
ComboBox, TreeView family, TextView, Expander, Separator, RadioButton); all
nine Glade-built scripts render headlessly. Two things it changed that
section 3 below now reflects: value-bearing widgets always bind their
`change` event (`Widget#always_bound_events`), and multi-property updates
go through `ShimAdapter#update` as one validated step. Slice-two live
checks still owed: `;eloot` and `;bigshot` setup windows in a browser.

## 1. Where things stand

Branch `feat/webui-port` on `Nisugi/lich-5` (local only, never pushed):

| Commit | What |
| --- | --- |
| `622d6c14` | Vendors Doug's WebUI from `Lich5/lich-6` at `d952f2fd` (his PRs #4 + #5) as an opt-in launcher behind `--webui-dev`. GTK untouched. His PR #6 (GTK removal) deliberately not taken. |
| `6213d611` | Slice one of the shim: `ScriptScope` + `lib/common/script_scope/gtk/`. vars.lic and alias.lic run unmodified in the browser. Contract 2.5.0 -> 2.6.0. |

Verified live on Windows: launcher login, `;vars setup`, `;alias setup`.

Run it: `ruby lich.rbw --webui-dev`. Without the flag nothing changes.

Specs that matter:

```
bundle exec rspec spec/lib/common/script_scope            # the shim (12)
bundle exec rspec spec/lib/webui spec/lib/common/webui_launcher \
  spec/lib/common/webui_launcher_redux_spec.rb \
  spec/lib/common/webui_launcher_workflows_spec.rb \
  spec/lib/main/webui_dev_option_spec.rb                  # Doug's WebUI (185)
bundle exec rspec spec/lib/common/script*_spec.rb          # Script binding change (239)
bundle exec rubocop <changed files>
```

Known pre-existing failure, not ours: `spec/lib/common/session_launcher_spec.rb:379`
fails on Windows on `main` too (`/tmp` path expansion). Leave it.

Rules for this branch: never push (global rule; ask). Commit messages end
with the `Co-Authored-By` line the session provides. One slice per commit.

## 2. Architecture in one screen

```
script code  --eval'd in-->  Lich::Common::ScriptScope binding
                              constant lookup: ScriptScope -> Lich::Common -> Lich -> Object
                              so `Gtk` resolves to ScriptScope::Gtk (the shim); core still sees ::Gtk

ScriptScope::Gtk widgets  (lib/common/script_scope/gtk/widgets.rb)
   retained shadow tree; the widget IS the source of truth for state
        |
   Session (lib/common/script_scope/gtk/session.rb)
   one per owning Script: the emulated GTK thread + ShimAdapter + viewers + browser pids
        |
   Lich::WebUI::Adapter  (Doug's imperative port: create/get/set/attach/detach/bind/unbind/destroy/modal)
        |
   Page -> TreeBuilder -> Contract validation -> Runtime -> Server/WebSocket -> app.js
```

Files:

| Path | Role |
| --- | --- |
| `lib/common/script_scope.rb` | `ScriptScope` module: `activate!`, `active?`, `script_binding`. Loads plugins via glob `script_scope/*/boot.rb`. Must never mention Gtk. |
| `lib/common/script_scope/gtk/boot.rb` | plugin entry; requires session + widgets |
| `lib/common/script_scope/gtk/session.rb` | `ShimAdapter`, `Session` |
| `lib/common/script_scope/gtk/widgets.rb` | `Gtk::*`, `Gdk::*`, `GLib::*` for scripts |
| `lib/common/script.rb` | `Script.__trusted_binding` picks ScriptScope when active (two call sites) |
| `lib/main/main.rb` | activates ScriptScope after a `--webui-dev` login |
| `lib/webui/contract.rb` | Doug's contract, now 2.6.0 |
| `lib/webui/assets/app.js`, `app.css` | client; we added `grid`, `scroll`, focus/blur |
| `spec/lib/common/script_scope/gtk_shim_spec.rb` | the shim spec; the model for all later slices |
| `docs/webui-redux/` (lich-6 only) | Doug's requirement ledger and evidence format |

## 3. Invariants you must keep

These are the things that took the longest to find. Do not relearn them.

**Doug's boundary rules** (`script/ci/check_core_gtk_boundary.rb` and
`check_shim_namespace.rb` in lich-6; not run in lich-5 yet, but honor them):
no `Gtk`/`GLib`/`Gdk`/`GdkPixbuf`/`Pango` constant, no identifier matching
`/gtk/i`, and no `require` of a path containing `gtk` anywhere in `lib/` or
`lich.rbw` outside `lib/common/script_scope/gtk/`; nothing outside that
directory may reference `ScriptScope::Gtk`. That is why the plugin is loaded
by glob and why `main.rb` calls `ScriptScope.activate!` and nothing more
specific.

**Contract changes are versioned, additive, and deliberate.** `Contract::VERSION`
is asserted by `contract_foundation_spec` (`publishes exactly the locked
X vocabulary`), `contract_spec` (`negotiate!`), and `server_spec` (hello).
The client `VERSION` in app.js must move with it. `negotiate!` only checks
the major, so 2.x clients keep working. New types must be added to
`TYPES` (and the count in `contract_foundation_spec`), get an
`ATTRIBUTE_APPLICABILITY` entry, and a `BASE_SCHEMAS` entry.

**Class identity is real.** Scripts do `.class == Gtk::Entry`,
`instance_of?`, `is_a?`, and subclass `Gtk::CheckButton`/`Gtk::Window`
(signore.lic). Shim classes must be the actual constants scripts see; never
wrap them.

**Mutators return self.** 642 call sites chain
`Gtk::Alignment.new(...).add(x).set_width_request(100)`.

**Threading.** One `Session` thread per owning script, created lazily from
the script's own thread (so it inherits the script's ThreadGroup and dies
with it). Everything script-facing runs there in order: `Gtk.queue` blocks,
signal handlers, `GLib::Timeout` callbacks, and `commit` after each job.
WebUI dispatcher callbacks only `enqueue` and return - `Future#await`
raises `ReentryError` on a dispatcher thread, so blocking `dialog.run` is
legal only because it runs on the session thread. `Session#sync` is for
specs and timer threads; never call it from the session thread.

**Viewer-scoped properties.** `text_input.value`, `checkbox.checked`,
`tabs.selected`, `expander.open`, `split.position`, `table.selected/sort`,
`scroll.scroll_to` are `scope: :viewer`. Two consequences:

1. `Adapter#set` on them requires an explicit viewer and raises otherwise.
   `ShimAdapter#set` overrides that and writes them as shared props (the
   shim widget is the single source of truth).
2. The `ViewerStore` overlays the viewer's last input on top of props at
   serialize time, so a script write after the user has typed would be
   shadowed. `Session#viewer_write` pushes the value to every attached
   viewer through `Page#set(cid, name, value, viewer:)`. Any new widget
   with a viewer-scoped value must call it from its setter (see
   `Entry#text=` and `CheckButton#active=`). Viewers are learned from
   `EventContext#viewer_id` on every event and from the page `attach`
   lifecycle; forgotten on `detach`.

**Page lifecycle vs component events.** `attach`/`detach`/`close` bind on
the page handle and are stored in `Page#lifecycle_bindings`, not in
`last_render.bindings`. Component bindings are keyed `[cid, event]` in
`page.last_render.bindings`. Specs drive both directly by calling the
stored proc with an `EventContext`; no socket needed.

**Cid lookup.** Every shim widget sets `key: "wN"`; the cid is found by
`page.last_render.tree.each.find { |c| c.props[:key] == key }`.

**Container capacity rules.** `columns` is `named_dynamic`: children
attach must satisfy `children.length < count`, so a horizontal `Box`
sets `count` from its visible child count *before* attaching (already in
`Box#node_props` + `Widget#materialize!` ordering). `grid` is
flow-ordered: `Table#ordered_children` sorts by `(top, left)`; there is no
col/row placement in the contract, only `span`/`row_span`, and
`Adapter#render_children` does not pass `placement` at all.

**Client attaches to every page.** app.js `receive()` attaches to all
descriptors in `hello`/`pages`, so every browser window renders every
registered page. Fine for one window per script; a real problem the
moment two scripts have windows. Slice four fixes it.

**Browser windows.** `BrowserLauncher.open(url, geometry:, on_start:,
on_exit:)` spawns Chrome/Edge with its own profile dir per window so the
process exit is observable; `Session` treats exit as `delete_event`
(deduped with the `close` lifecycle). `Session.browser_open` /
`browser_kill` are the test seams.

**Modals.** `Service#modal` registers a `dialog` page and returns a
`Future`; `no_viewer: 'wait'` so it survives with no viewer connected;
`Session#modal` opens a small browser window when `connection_count` is
zero. `MessageDialog#run` awaits and maps the button id to
`ResponseType`; cancel/timeout -> `DELETE_EVENT`, as GTK does.

**Unsupported API.** `Widget#method_missing` logs once per
`Class#method` via `Gtk.log_unsupported` and returns `self` for
setters, `nil` otherwise. Watch the Lich log for
`webui-gtk-shim: unsupported` lines when trying a new script; that list
is the backlog.

## 4. The census (what the 49 scripts use)

From `C:\Gemstone\scripts\scripts` (230 scripts, 49 use GTK, 252
`Gtk.queue` sites, 9 use `Gtk::Builder`). Instances, code + Builder XML:

| Class | Count | Contract node | Slice |
| --- | ---: | --- | --- |
| Label | 910 | `text` | 1 (markup: 3) |
| CheckButton | 745 | `checkbox` | 1 |
| Entry | 449 | `text_input` | 1 |
| Box / HBox / VBox | 445 | `stack` / `columns` | 1 (packing: 4) |
| Alignment | 395 | props only | 4 |
| Grid / Table | 155 | `grid` | 1 |
| Frame | 160 | `group` | 1 |
| Button | 135 | `button` | 1 |
| ScrolledWindow / Viewport | 117 | `scroll` / `stack` | 1 (adjustments: 4) |
| Window | 59 | `page` | 1 |
| ComboBoxText / ComboBox | 67 | `select` | 2 |
| SpinButton / Adjustment | 87 | `number_input` | 2 |
| TreeView family | 144 | `table` | 2 |
| Notebook | 25 | `tabs` | 2 |
| TextView | 14 | `textarea` | 2 |
| Separator | 47 | `divider` | 2 |
| Expander | 4 | `expander` | 2 |
| Builder | 9 scripts | parser | 2 |
| Menu family | 107 (28 scripts) | **missing** | 3 |
| `set_markup` | 149 | **missing** | 3 |
| MessageDialog / Dialog | 11 | `dialog` | 1 / 5 |
| Image / Pixbuf | 39 | `image` | 5 |
| Layout + EventBox | 8 | `composite` | 5 |
| DrawingArea + Cairo `draw` | 4 (2 scripts) | **missing** | 6 |
| drag-and-drop | 3 scripts | **missing** | 6 |
| Paned, Overlay, ListBox, ProgressBar | 1-2 each | `split`, `overlay`, `list`?, `progress` | 5 |

Signals: clicked 91, toggled 50, activate 42, changed 33, delete_event
35, focus-out 10, button-press 12, drag-data 12, draw 4, scroll 3,
row-activated 3, edited 2, key-press 1.

State I/O: `.active?` 600, `.text` 463, `.value` 95 reads; `.active=`
295, `.text=` 287, `tooltip_text=` 139, `sensitive=` 42 writes. Reads are
synchronous and must answer from the shadow.

Geometry reads are window-level only (`allocation`, `position`) at close
time. No per-widget layout engine is needed.

All `Gtk::Tooltips` uses are commented out. `Gtk::Version::MAJOR == 3`
gates the Builder scripts (shim reports 3.24.0). Nine scripts return
`true` from `delete_event` to veto close.

## 5. Slices

Each slice is one commit with a spec file modeled on
`gtk_shim_spec.rb`: build the tree, `session.sync {}`, assert
`page.last_render.tree`, fire bindings, assert re-rendered props. Add a
live check with a named script. Update the "unsupported" backlog from the
Lich log.

### Slice 2 - `Gtk::Builder` and the data widgets

**Unlocks:** bigshot, BlackArts, eloot, ebounty, eherbs, ecleanse, ewaggle,
go2, repository - the nine largest UIs. Also jinx, sbounty, mybounty,
madwarrior (code-built Notebook/TreeView).

**Contract change:** none. Everything maps into 2.6.0.

**Start with a census of the XML**, not the Glade schema:
`grep -ohE 'class="Gtk[A-Za-z]+"' *.lic | sort | uniq -c` and
`grep -ohE '<property name="[a-z_-]+"' *.lic | sort | uniq -c` across the
nine scripts, plus `<packing>` property names and `<signal>` entries.
Build the parser to exactly that list; log the rest.

**Widgets to add** (ruby-gnome surface, contract node):

- `Notebook` -> `tabs`: `append_page(child, label_widget)`,
  `prepend_page`, `set_tab_label`, `page=`/`set_page`/`page`,
  `n_pages`, `get_nth_page`, `remove_page`, signal `switch-page` ->
  `select`. Tab labels are widgets in GTK; flatten to `label.text`. Names
  go in `names:` and children are `named_from_property` - the Adapter
  assigns slots from `names` order, so keep `names` and children in step
  and set `names` before attaching.
- `SpinButton` -> `number_input`: `new(adjustment)`, `new(min, max,
  step)`, `set_range`, `set_increments`, `set_digits`, `value`/`value=`,
  `value_as_int`, `adjustment` (shared `Adjustment`), signal
  `value-changed` -> `change`. `min`/`max` are required by the contract;
  default 0..100 when the script gives none.
- `ComboBoxText` -> `select`: `append_text`, `append(id, text)`,
  `prepend_text`, `insert_text`, `remove(i)`, `remove_all`, `active`
  (index) / `active=`, `active_text`, `active_id`/`active_id=`, signal
  `changed` -> `change`. Contract options are `{value, label}`; use the
  index as the value string when the script gives no id.
- `TreeView` + `ListStore`/`TreeStore` + `TreeViewColumn` +
  `CellRendererText/Toggle/Combo` + `TreeSelection` + `TreeIter` ->
  `table`. The biggest piece. Model API used: `ListStore.new(String,
  Integer, ...)`, `append`, `prepend`, `insert`, `iter[i]`, `iter[i]=`,
  `set_value`, `get_value`, `remove(iter)`, `clear`, `each { |model,
  path, iter| }`, `iter_first`, `iter_next!`, `get_iter(path)`,
  `set_sort_column_id`, `n_columns`. View API: `append_column`,
  `insert_column`, `TreeViewColumn.new(title, renderer, text: 0,
  background_set: 2, ...)`, `column.sort_column_id=`, `headers_visible=`,
  `selection.mode=` (single/multiple/none), `selection.selected`,
  `selection.selected_rows`, `selection.select_iter`, `unselect_all`,
  signals `row-activated` -> `row_activate`, selection `changed` ->
  `selection_change`, renderer `edited` -> `cell_edit`, renderer
  `toggled` -> `cell_edit` with the toggle editor. Give every row a stable
  key (iter identity), map columns by attribute (`text: n` picks model
  column n). Rows are `{key, parent, expanded, cells: {col_key => value}}`;
  check `Validator` for the exact `cell_map` and `editor` shapes before
  writing.
- `TextView` + `TextBuffer` -> `textarea`: `buffer.text`/`buffer.text=`,
  `buffer.set_text`, `buffer.insert(iter, text)` (append), `end_iter`,
  `editable=`, `wrap_mode=`, `cursor_visible=`. Tags: strip for now.
- `Expander` -> `expander`: `label`, `expanded`/`expanded=`, signal
  `notify::expanded` rarely; `add`.
- `Separator` / `HSeparator` / `VSeparator` -> `divider`.
- `RadioButton` -> `radio`: groups. GTK builds groups from the first
  button (`RadioButton.new(group, label)` / `member:`); the contract has
  one `radio` node with `options`. Represent the group as one node owned
  by the first button; other buttons become options; `active?` reads the
  group's selected. This is the one awkward mapping in the slice.
- `Builder`: `new`, `add_from_string(xml)`, `add_from_file`,
  `get_object(id)`, `[]`, `objects`, `connect_signals { |handler| method
  (handler) }` (yields handler name, expects a callable back; also the
  form with no block that uses the builder's own methods). Scripts
  subclass it: `class Setup < Gtk::Builder`. Parse `<object class=
  id=>`, `<property name=>` (translate `visible`, `can_focus`, `label`,
  `active`, `sensitive`, `tooltip_text`, `hexpand`/`vexpand`, `halign`,
  `margin_*`, `width_request`, `orientation`, `spacing`, `homogeneous`,
  `adjustment`, `model`, `text`, `digits`, `numeric`, `wrap`, `xalign`,
  `use_markup`, `shadow_type`, `label_xalign`, `tab_pos`), `<child>` with
  `<packing>` (`expand`, `fill`, `position`, `left_attach`, `top_attach`,
  `width`, `height`, `pack_type`, `padding`) and `type="tab"` children
  (Notebook tab labels), `<signal name= handler= object=>`, top-level
  `GtkAdjustment` and `GtkListStore` objects (with `<columns>` and
  `<data>` rows), `GtkTreeViewColumn` children of a TreeView with
  `<attributes>`. Booleans are `True`/`False` strings.

**Client renderers to add** in app.js (with CSS): `expander`
(`<details>`), `textarea`, `number_input`. The contract declares them;
Doug's launcher never used them. Check `viewer_state_event?` in
`runtime.rb` already lists their change events (it does).

**Live check:** `;eloot` setup window first (cleanest XML), then
`;bigshot` setup.

**Gotchas already known:** `Gtk::Builder` scripts check
`Gtk::Version::MAJOR == 3` before loading XML - satisfied. eloot's XML is
~2,000 lines in a heredoc; parse time matters, cache by string hash.
`TreeViewColumn#set_cell_data_func` appears 0 times - skip it.

### Slice 3 - menus and markup (contract 2.7) - DONE

Landed as described below with these deviations: the popup is driven by a
viewer-scoped `menu.open` property (the shim sets it from `Gtk::Menu#popup`,
the client emits `close` on dismissal) rather than only by `context_menu`,
because scripts open menus imperatively from a `button-press-event`
handler; `context_menu` exists too for declarative use. Pointer events
landed on `stack` as well as `group`/`text`/`image` because `EventBox`
maps to `stack`. Tooltip markup was not done (stripped). A popup menu
attaches to the window that last saw a pointer event
(`Session#popup_window`) and is kept as a hidden page child via
`Window#attach_popup`. Specs: `gtk_menus_spec.rb`, validator markup
examples, page_spec menu-children example.

**Unlocks:** the 28 scripts with `Gtk::Menu` context menus and every
script whose labels use `set_markup` for bold/big/colored text
(creaturebar, spellson, armor, boon, sloot...).

**Contract change - propose it as a written extension first**, in Doug's
schema style (`property(...)`, `event(...)`, `ATTRIBUTE_APPLICABILITY`),
with the census counts as justification. Then implement:

- New types `menu` (children `menu_item`), `menu_item` (`label`, `kind:
  normal/check/radio/separator`, `active` viewer-scoped for check/radio,
  `group`, `submenu` as a child `menu`; events `activate`, `change`).
- New attribute `context_menu` applicable to every container and control:
  the id of a `menu` node registered on the page, shown on right-click;
  the client emits `menu_item` events into the page's bindings.
- `menubar` as a `menu` with `bar: true`.
- Shim: `Menu`, `MenuBar`, `MenuItem`, `CheckMenuItem`, `RadioMenuItem`,
  `SeparatorMenuItem`, `append/prepend/insert`, `submenu=`, `popup`
  (deprecated 3-arg form), `popup_at_pointer`, `show_all`; signals
  `activate` and `toggled`. Scripts open popups from a
  `button-press-event` handler when `event.button == 3`; that requires
  a pointer event on the source widget, so also add `pointer` events
  (`press/release`, `button`, `x`, `y`, `modifiers`) on `group`, `image`
  and `text` - 12 scripts use `button-press-event`; most only to detect
  the right button.
- `markup` property on `text` (alternative to `content`): a sanitized
  Pango subset - `b`, `i`, `u`, `s`, `tt`, `big`, `small`, `span` with
  `foreground`/`color`, `background`, `size`, `weight`, `font_desc`,
  `style`, `underline`. Validator must parse and refuse anything else
  (Doug refuses raw HTML by design - the client builds nodes with
  `createElement`/`textContent`, never `innerHTML`; `assets_spec`
  asserts this). Colors are the open question: the contract has four
  semantic tones and no free RGBA on text (only on composite layers).
  Recommend allowing `#rrggbb` and named CSS colors in `span
  foreground/background` only, as validated literals. Same subset for
  `tooltip` markup.
- Shim `Label#set_markup` passes the markup through instead of stripping
  tags. Also `use_markup=`.

**Client:** menu overlay with keyboard support; context-menu wiring;
markup renderer (recursive `createElement` from the validated parse
tree, never string HTML).

**Live check:** `;creaturebar` labels, any script with a right-click
menu (map.lic's is the most demanding; xnarost simpler).

### Slice 4 - fidelity: packing, pages per window, scroll, host hints

**Unlocks:** nothing new; makes everything already running look and
behave right. Do this before showing translated scripts to users.

Done so far: box packing (`4c09a59e`), per-window page selection (pulled
forward between slices two and three), scroll adjustments (contract
2.9.0), and the two dropped setters in `82128165` - `set_width_request` (288 sites, never aliased to
`width_request=`) and `Gtk::Misc#set_padding(xpad, ypad)` (9 scripts,
not implemented). Still open below: theme, close veto.

Two gaps deliberately left, both needing a contract change rather than
shim work: `Alignment`'s `yalign` has nowhere to go (the contract has
`align` but no `valign`), and asymmetric padding still collapses to the
larger side (`margin` is one integer). Only 8 call sites pad
asymmetrically and 307 of ~340 `Alignment.new` uses are `xscale: 1`,
which the existing fill guard already handles - so neither is worth a
bump on its own. Fold them into the next contract change.

- **Box packing.** DONE (`4c09a59e`). Honor `expand`/`fill`/`padding` and `pack_end`
  ordering. Contract: add optional child placement `expand: bool`, `fill:
  bool` on `stack`/`columns` children, and `homogeneous`; `Adapter
  #render_children` must start passing `placement:` (it does not today -
  a one-line change plus storing placement on the adapter `Node`).
  `Alignment` -> `halign` on the child (`xalign` 0/0.5/1 ->
  start/center/end; `xscale` 1 -> fill) plus `margin` from
  `set_padding`: done. `valign` and per-side margin still want
  `margin: {top, right, bottom, left}` or four attributes, plus a
  `valign` prop; see the note above.
- **Per-window page selection.** DONE (pulled forward). app.js attaches every page. Honor the
  `?page=<address>` query the launcher already puts in the URL: a window
  opened for a page attaches only that page (and any `dialog` page from
  the same owner, so modals still appear in it). Windows opened without a
  page keep today's behavior.
- **Scroll adjustments.** DONE (contract 2.9.0, written up in the
  addendum to `docs/webui-contract-2.7-menus-markup.md`).
  `scroll_position: {x, y, bottom}` viewer-scoped on `scroll`, and the
  `scrolled` event gained `upper`/`page_size` so the scripts' own
  arithmetic has real numbers. `bottom` is a flag, not a pixel value:
  every script spells scroll-to-bottom as `value = upper - page_size`,
  which the shim cannot evaluate, so the intent travels instead and the
  client resolves it against `scrollHeight` after layout. A reported
  position clears a pending request, so a hand-scrolling viewer is not
  yanked. map.lic's two-axis pixel path is written but untestable until
  `Gtk::Layout` -> `composite` lands in slice 5. Note SpinButton's
  `.adjustment.value=` (12 sites) was never a scroll and already worked.
- **Window props.** DONE. `keep_above` -> `always_on_top`, `decorated`
  false -> `borderless`, `opacity` -> `opacity`, all through the
  `presentation` facility, which the runtime already refuses
  per-property and records as a degradation; `always_on_top` and
  `borderless` are declared and refused, waiting on the FE host (slice
  7). The client honors `opacity`, the one of the three it can.
  `resizable` is deliberately *not* mapped: the facility's `scrollbars`
  is about the page's own scrollbars, and a browser tab cannot refuse a
  resize -- it stays readable shadow state only.

  Two things this needed beyond the mapping. All four are readable, not
  just writable, because creaturebar persists `decorated?` to its config
  file. And creaturebar spells "hide the window" as `set_opacity(0.0)`,
  below the contract's 0.1 floor, so the facility clamps while the script
  still reads back its own write; the validator rejects 0.0 outright, so
  without the clamp that script would take the render down.

  Facilities live beside the tree rather than on a node, so a
  presentation-only change altered no props and never marked the page
  dirty. `ShimAdapter#refresh_facilities` plus a `@synced_presentation`
  guard on the window fixes that without a render loop. Handles are
  opaque by design, so the window registers a reader
  (`presentation_source`) rather than the adapter walking back to it.
- **Grid columns.** DONE (contract 2.10.0). Both options in the original
  note, as it turns out: a `weights` prop on `grid` mirroring `columns`,
  *fed* by `AttachOptions::EXPAND` per column. `Gtk::Table` records it at
  attach from the x options; `Gtk::Grid` has no attach options and
  derives it at render from child `hexpand`, which scripts set after
  attaching. With nothing expanding the prop is omitted and the client
  keeps `repeat(cols, auto)`, which is GTK's own behavior.

  The corpus is thinner than the note assumed: only 8 live attach sites
  of 145 pass EXPAND, all naming the entry column of a label/entry pair.
  `Gtk::Alignment` wraps 71 of the attached children and looked like a
  second signal, but every Alignment in the corpus is `xscale: 0`, so it
  can only say "do not stretch" -- already the default. Reading it would
  have changed nothing and added a conflicting path, so it is not used.
  A FILL-only attach is likewise not an expand request.
- **Theme.** A GTK-shaped stylesheet: control heights, label baselines,
  frame legends, dark mode via `color-scheme`. Doug's `app.css` is
  launcher-specific (`[data-cid*="group:entry-"]` rules); keep those and
  add a general layer. The six DSL-rewritten scripts on the lich-5
  `feat-webui-framework` branch are the visual reference for what "looks
  right" meant to the user.
- **Close veto.** Nine scripts return `true` from `delete_event`. The
  browser is already gone; the honest behavior is to leave the widget
  tree alive (already the case) and let the script `present` it again,
  which reopens a window. Document it.

### Slice 5 - the long tail of widgets

- `Image` + `GdkPixbuf::Pixbuf` -> `image` via `FileService`: `Pixbuf.new
  (file:)` registers the file's directory with `service.register_files
  (alias, dir, owner:)` and serves it; `scale_simple` -> `scale` prop;
  `pixbuf.width/height` from the PNG/JPEG header (stdlib, no gem).
  `Pixbuf.new(data:, width:, height:...)` from Cairo surfaces -> slice 6.
- `Gtk::Layout` + `put`/`move` + `EventBox` -> `composite` (image layers
  at x/y, `region_activate`/`surface_activate` events). map.lic,
  orbuculum, xnarost. map.lic also uses `Gdk::EventScroll` and motion;
  check what `composite.surface_events` gives before promising drag.
- `Dialog` (custom, 4 uses): `dialog` accepts children; `content_area`/
  `vbox`/`child` return a `Box` that renders inside the dialog page;
  `add_button(label, response)`; `run`. Same modal path as MessageDialog.
- `Paned` -> `split`, `Overlay` -> `overlay`, `ProgressBar` ->
  `progress`, `ListBox`/`ListBoxRow` -> `stack` of `group` (no `list`
  type in the contract; propose one only if a real script needs
  selection).
- `Gtk::Switch` (login GUI only) -> `toggle`.
- `key-press-event` + `Gdk::Keyval` (isigils) -> `accelerators` facility.
- `Gdk::Screen.default.width/height` -> from the viewer's `geometry`
  facility once a window is attached; keep the 1280x800 default before.
- `GLib::Timeout` at 250 ms (creaturebar) - measure commit cost; the
  Adapter re-validates the whole component on every `set`. If it shows,
  batch `set`s per commit.

### Slice 6 - canvas and drag-and-drop (contract 2.8)

> **Census, 2026-09-16: most of this slice has no consumer.** Checked against
> `scripts/*.lic` in this checkout before starting work:
>
> - **`Gtk::DrawingArea`: zero users.** Nothing in the corpus draws live.
> - **`Cairo::` : two users**, `bsprofiles.lic:483` and `map.lic:2492,2544`.
>   Both draw *offscreen* to a `Cairo::ImageSurface` and convert with
>   `GdkPixbuf::Pixbuf.new(data:)`. That path already works -- the shim
>   encodes such a pixbuf to a PNG `data:` URI (`32bd1282`). Neither needs a
>   canvas type or a Cairo->Canvas2D command list.
> - **Drag and drop: one user**, `ewaggle.lic` (the plan also named bardwag
>   and sspell; neither is in this checkout). And ewaggle already offers the
>   same operation without dragging: `row-activated` (double-click) calls
>   `move_spell_between_lists`, `ewaggle.lic:547-558`. `row_activate` is
>   already in the contract and already wired, and it works today.
>
> So the canvas type is **not built**: it is speculative infrastructure for a
> script that does not exist. What ewaggle actually needed was for its setup
> to stop *raising*: `Gtk::TargetFlags::SAME_APP` raised NameError and
> `Gtk::TargetEntry.new(target, flags, info)` raised ArgumentError, both from
> `Gtk.const_missing`, and the calls are unguarded -- so the window died
> mid-build and took with it the double-click handler registered a few lines
> later. Fixed by teaching `const_missing` that a flags/enum-shaped name
> degrades to a namespace of symbols (as `Gdk`'s fallback already did) and
> that a stubbed widget's constructor accepts arguments.
>
> Real browser drag-and-drop between tables remains unbuilt and unneeded.
> Revisit only if a script appears that can *only* be driven by dragging.

- `canvas` type: `commands: [...]` as a bounded command list (Cairo ->
  Canvas2D: `save/restore`, `translate/scale/rotate`, `move_to/line_to/
  curve_to/arc/rectangle/close_path`, `set_source_rgb(a)`, `set_line_width/
  cap/join/dash`, `stroke/fill/fill_preserve/paint/clip`,
  `select_font_face/set_font_size/show_text`, `set_operator`), `size`;
  events `draw_request {width, height}` and pointer events.
  `text_extents` needs a round trip or an approximation; document which.
- Shim: `DrawingArea` with a recording `Cairo::Context`; `queue_draw`
  re-runs the `draw` handler on the session thread and commits the new
  command list; `allocated_width/height` from the last `draw_request`.
  `Cairo::ImageSurface` + `Cairo::Context` used offscreen (map.lic
  markers) become a canvas-backed `image` source (`canvas:<key>`).
- Drag-and-drop between tables (bardwag, sspell, ewaggle):
  `drag_source_set`/`drag_dest_set` with `TargetEntry`, signals
  `drag-data-get` (source, given a `SelectionData` to fill with
  `set_text`) then `drag-data-received` (target, reads `data.text`).
  Contract: `drag: {source: bool, target: bool}` on `table`, event `drop
  {from: cid, row: key}`; the shim synthesizes the two GTK signals in
  order with one `SelectionData` object.

### Slice 7 - hosts, login, goldens, and the end state

- **FE-docked panels.** The lich-5 `feat-webui-framework` branch has a
  handshake and docs for embedding pages as docked panels
  (`docs/webui-fe-integration.md`, `docs/webui-new-nodes-for-vellum.md`
  on that branch) - port the idea, not the code. Vellum is the user's
  own FE; this is where `always_on_top` and multi-window layouts become
  real.
- **Desk mode.** One page, floating draggable panels, for the 28
  `keep_above` scripts when no FE host exists.
- **Login through the shim.** `lib/common/gui/*` (42 GTK classes incl.
  `Switch`, `TreeStore`, `AccelGroup`, `CssProvider`) either runs through
  the shim or is replaced by Doug's `WebUILauncher` (already in the
  tree). Recommend the latter: it exists, it is tested, and it is what
  lich-6 ships. Gap to close first: it predates lich-5's configurable
  frontend registry (#1558), HTTPS web-login fallback (#1570), and
  `--refresh-characters`/`--add-character` (#1504).
- **Goldens.** Doug's `Lich::Common::ConformanceHarness` takes a script
  id and a trace of recorded GTK calls and returns pass/fail. Fill it in:
  record `(class, method, args)` traces from the shim under real scripts
  and, where the real gem is present, the same traces plus serialized
  trees from a mirror of real widgets (`widget.class.properties`,
  `get_property`, `children`, `notify::` for dirtiness). A script is
  certified GTK-free when its traces match. The mirror lives inside
  `lib/common/script_scope/gtk/` where GTK constants are allowed, and
  only under a `with-gtk3` bundle.
- **Remove gtk3.** After the census scripts are certified and the login
  is WebUI by default: take lich-6 PR #6 (`git show a25aade0`), which
  deletes `lib/common/gtk.rb`, `gui_login.rb`, twenty `gui/*` files,
  `gtk_compaction.rb`, the `Gtk.main` park in `lich.rbw`, and adds the
  boundary checkers to CI. That PR is the map for the deletion.

## 6. Rough edges carried from slice one

- ~~Every browser window renders every page~~ (fixed, pulled forward).
- ~~Horizontal `Box` -> `columns` with equal weights; `expand`/`fill`
  ignored~~ (fixed, `4c09a59e`).
- ~~`Adjustment#value=` accepted, does not scroll~~ (fixed, contract 2.9.0).
- `Label#set_markup` strips tags (slice 3).
- `Alignment#yalign` is dropped; the contract has no `valign`, and
  asymmetric padding collapses to the larger side (slice 4 note).
- `Frame` label widgets are flattened to text; empty labels render `' '`
  because the contract's `short_text` bound refuses empty (verify).
- `Widget#respond_to_missing?` returns `true` for everything so
  `respond_to?(:set_opacity)` guards in scripts take the supported path
  and then no-op. Revisit if a script branches on it wrongly.
- `Window#allocation`/`position` return `default_size`/`[0,0]`; wire to
  the `geometry` facility (slice 4/5).
- The shim `Session` for widgets created outside any script (no
  `Script.current`) is a shared `NullOwner`; nothing cleans it up.
- `Dialog#run` (custom dialogs) returns `DELETE_EVENT` immediately.

### Deferred map polish (observed live, 2026-09-16)

Three things `;map` still gets wrong once it works. Noted here rather than
fixed because two of them are not the shim's to fix.

- ~~**Window opacity does not make the window translucent.**~~ **Done.**
  Applied to the real OS window on native Windows through
  `lib/webui/window_presentation.rb` (`WS_EX_LAYERED` +
  `SetLayeredWindowAttributes`). The whole window including its chrome goes
  translucent, which a page cannot do -- what shows through a CSS fade is
  the browser's own background.
- ~~**`keep_above` does not raise the window.**~~ **Done**, same file
  (`SetWindowPos` + `HWND_TOPMOST`). Nine scripts asked for it.

- ~~**Borderless windows.**~~ **Done**, same file. Only `WS_CAPTION` is
  taken: `WS_THICKFRAME` stays, so a borderless window is still resizable
  by its edges, and `;kill <script>` closes any window whose title bar has
  gone. An earlier note here refused it outright on the theory that a
  frameless window strands the player; that was too cautious.
- ~~**Hide Scrollbars.**~~ **Done.** The contract already had a
  `scrollbars` facility marked supported, but the client read it nowhere
  and `ScrolledWindow#set_policy` threw the policy away, so the menu item
  did nothing. `set_policy(:never, :never)` now reports through the
  facility and the page hides its own bars; the content still scrolls by
  drag, wheel and centring.

  always_on_top and opacity stay degraded on every other host,
  deliberately: `xdotool windowstate --add ABOVE` is a no-op under Wayland
  and `_NET_WM_WINDOW_OPACITY` does nothing without a compositor, so those
  would report success while changing nothing -- worse than degrading
  honestly.
- **Changing Scale misplaces the room marker.** This one IS a shim bug.
  map redraws its Cairo marker at the new zoom and moves it with
  `Layout#move`; the marker's position and the image's scale stop agreeing,
  so the circle drifts off the room. Suspect the composite `scale` prop is
  applied to the surface as a CSS transform while layer coordinates stay in
  unscaled pixels -- check `Layout#node_props`/`composite` against
  `calculate_scale` before slice 6's canvas work lands on top of it.

## 7. Open questions for Doug

1. Where does `SPEC-WEBUI-CONTRACT` live? The prose spec the code cites
   (`SS10`, `SS14`, "Architecture section 7") is not in the lich-6 repo.
   Extensions in slices 3/4/6 should be written in its style.
2. Is the contract open to additive minor versions from this side, and
   is 2.6.0 (focus/blur) acceptable as done?
3. Free color on text markup vs the four-tone rule - what is the intended
   line?
4. Was `ScriptScope` meant to work the way slice one does (binding
   created inside the module; `extend self` for bare `def`)? The name
   suggested it; confirm.
5. Where does the shim land - `elanthia-online/lich-5` now, or wait for
   `elanthia-online/lich-6`?

## 8. Working method that worked

- Census first, from the live `C:\Gemstone\scripts\scripts` checkout,
  with `grep -ohE ... | sort | uniq -c`. Build to real usage, log the
  rest.
- Read Doug's code before assuming: `Adapter`, `Runtime`, `ViewerStore`,
  `Page`, `Dispatcher`, `Future`, `ModalCoordinator`, and the client's
  `receive`/`acceptRender`/`emit` are short and answer most questions.
- Specs drive bindings directly (`page.last_render.bindings[[cid,
  :event]].call(context)`), with `Session.browser_open` stubbed. No
  sockets, no browser, sub-second.
- Then one live check per slice with a named script, watching the Lich
  log for `webui-gtk-shim: unsupported`.
- One slice, one commit, message in the style of `6213d611`.
