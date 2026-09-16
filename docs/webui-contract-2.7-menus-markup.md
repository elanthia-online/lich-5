# WebUI contract 2.7.0: menus, markup, pointer gestures

Proposed extension to SPEC-WEBUI-CONTRACT 2.6.0, written for Doug's review
in the schema's own terms. Implemented on `feat/webui-port` behind the
existing minor-version rules: additive, `negotiate!` still checks the major
only, every new type has `TYPES`, `ATTRIBUTE_APPLICABILITY`, and
`BASE_SCHEMAS` entries.

## Why

The script census (230 scripts under `C:\Gemstone\scripts`, 49 with GTK):

| Need | Count | Scripts |
| --- | --- | --- |
| `Gtk::Menu` / `MenuItem` / `CheckMenuItem` / `RadioMenuItem` / `SeparatorMenuItem` | 107 call sites | 28, incl. map, xnarost, orbuculum, creaturebar |
| `Label#set_markup` with bold / size / color / font | 149 call sites | creaturebar, spellson, armor, boon, sloot, bigshot |
| `button-press-event` (right-click detection, popups) | 12 scripts | map, xnarost, orbuculum ... |

Without these, the compatibility shim strips markup to plain text and has
no way to show a popup menu at all.

## New types

### `menu`

| Property | Shape | Scope | Default |
| --- | --- | --- | --- |
| `bar` | boolean | shared | `false` |
| `open` | boolean | viewer | `false` |

Children: `many`, each a `menu_item` (enforced by the tree builder).
Events: `close` (no payload) - the viewer dismissed an open popup.

A `menu` with `bar: false` renders nothing inline; the client raises it as
a popup when `open` is set, positioned at the viewer's last pointer-down.
A `menu` with `bar: true` renders as a horizontal menu bar whose top-level
items open their submenus below them. Attributes: `key hidden align margin
width`.

### `menu_item`

| Property | Shape | Scope | Default |
| --- | --- | --- | --- |
| `label` | short text | shared | required unless `kind: separator` |
| `kind` | `normal \| check \| radio \| separator` | shared | `normal` |
| `active` | boolean | viewer | `false` |
| `group` | identifier | shared | radio only |

Children: `many`, at most one, and it must be a `menu` (the submenu).
Events: `activate` (terminal, no payload), `change` (`{ value: boolean }`)
for check and radio items. Attributes: `key tooltip disabled hidden`.

Invariants (validator): a separator carries no label; every other kind
requires one; `group` is refused on non-radio items.

## New attribute

`context_menu` (identifier): the `key` of a `menu` node on the same page.
The client opens that menu on the secondary-button gesture over the
component and suppresses the browser's own context menu. Applicable to
`group stack columns grid expander overlay scroll text log image button
table composite`.

## New events

`press` and `release` on `group`, `stack`, `text`, and `image`, payload:

```
{ button: primary | middle | secondary, x: geometry, y: geometry,
  modifiers: [ctrl | shift | alt]* }
```

`x`/`y` are relative to the component's box. A wired component stops the
gesture propagating to a wired ancestor, matching a GTK handler that
returns true.

## New property on `text`

`markup` (body text, optional, alongside the required `content`). A Pango
subset, parsed by the validator as XML and refused on anything outside it:

- Elements: `b i u s tt big small span`.
- `span` attributes only: `foreground|color|fgcolor`, `background|bgcolor`
  (`#rgb`, `#rrggbb`, or a CSS colour name), `size` (Pango name or integer;
  integers of 1024 and up are 1024ths of a point), `weight` (Pango name or
  3-digit number), `style` (`normal|oblique|italic`), `underline`
  (`none|single|double|low|error`), `font_desc|font` (a Pango description
  such as `Courier Bold 9`; refused if it contains `; { } < >`).
- Attributes on any other element are refused; unknown elements are refused;
  malformed XML is refused.

`content` stays the plain-text form and is what assistive technology,
goldens, and a client without markup support read.

## Client rules kept

- The client never uses `innerHTML`. Markup is parsed with `DOMParser`
  as `text/xml` into an inert document that is never inserted; nodes are
  rebuilt with `createElement` / `createTextNode` and inline styles set
  property by property from the validated attributes.
- Menus are rendered from the component tree on demand; a re-render while a
  popup is open rebuilds it in place (a check mark the owner toggled) or
  takes it down (the owner cleared `open`). Escape and an outside click
  dismiss and emit `close`. Arrow keys move within a level; right/left
  enter/leave submenus.

## Open questions for Doug

1. Colours on text. 2.6 allows free RGBA only on composite layers. This
   extension allows `#rrggbb` and named colours inside `span` because the
   scripts' markup is exactly that. Alternative: restrict to the four tones
   and lose creaturebar's health colours.
2. Whether `tooltip` should accept the same subset. Not done here: the shim
   strips markup from tooltips.
3. `press`/`release` on `button` and inputs. Not included: those have
   `activate`/`change`; scripts only attach pointer handlers to boxes,
   labels, and drawing areas.

---

# Addendum: contract 2.8.0 — box packing

The same additive rules. Needed because GTK's box packing is how every
legacy script distributes space, and the shim was discarding it: 1,033
`pack_start`/`pack_end` call sites across 35 scripts, 602 of which say
`expand: false`.

## Child placement on `stack`

| Placement | Shape | Meaning |
| --- | --- | --- |
| `grow` | integer 0..64 | This child takes a share of the leftover space along the stack's axis. |
| `pad` | integer 0..512 | Extra space around this child. |

## Child placement on `columns`

| Placement | Shape | Meaning |
| --- | --- | --- |
| `pad` | integer 0..512 | As above. A column's *share* of the width is its weight, which `columns` already has, so there is no `grow` here. |

## A client fix that came with it

`columns` renders its weights as grid tracks. A weight of 0 means natural
width, but the client emitted `0fr`, which collapses the track to nothing.
It now emits `auto` for weight 0. No script hit this before, because
nothing ever sent a zero weight.

## How the shim maps GTK onto it

A horizontal `Gtk::Box` becomes `columns`: each child packed with
`expand: false` gets weight 0, the rest weight 1, so the expanding children
share the slack and the others keep their natural width. The weights are
omitted entirely when every child expands, which is the contract default.

A vertical `Gtk::Box` becomes `stack`: an expanding child gets `grow: 1`.
A flex column already gives the others their natural height.

`padding` becomes `pad` on either axis.

## Note for a reviewer

GTK's signature is `pack_start(child, expand = true, fill = true, padding = 0)`,
and the positional form is the GTK 2 C API where the flags are integers.
`0` is false there but truthy in Ruby, so `pack_start(w, 0, 0, 1)` — 275
call sites, the second most common form in the corpus — must be read as
*not* expanding. A bare `pack_start(w)` must default to expanding. Both
were wrong in the shim until this slice, and were invisible while the
packing was being discarded.

`fill` is parsed and carried but not yet distinguished from `expand`: in a
flex or grid track the child already fills its cell, so the two coincide
for every layout in the corpus. If a script ever needs `expand: true,
fill: false` (a child given space but not stretched into it), that becomes
an alignment on the child rather than a new placement.

---

# Addendum: contract 2.9.0 — scroll position

Additive, same rules. Needed because a GTK script scrolls by writing
pixels to an `Adjustment`, and the shim had nowhere to put them: four
scripts (vars, alias, localchat, map) scroll, and none of it reached the
browser.

## `scroll_position` on `scroll`

| Property | Shape | Scope | Meaning |
| --- | --- | --- | --- |
| `scroll_position` | record `{x, y, bottom}` | viewer | Where the viewer is scrolled. `x`/`y` are pixel offsets (0..65535); `bottom: true` means the end of the content. |

`scroll_to` already existed and names a cid to bring into view. This is
the raw offset instead, because that is what `Adjustment` speaks.

### Why `bottom` is a flag and not a number

The scripts all spell "scroll to the end" as `value = upper - page_size`,
computed from an extent only the viewer knows. The shim cannot evaluate
that — its `upper` is a constructor default — so sending the resulting
pixel value would scroll to the wrong place, and would keep being wrong
as content grew. The flag carries the intent, and the client resolves it
against the real `scrollHeight` after layout.

A write at the extent becomes `bottom: true` whether or not the viewer
has reported yet; any other value passes through as pixels.

## `upper` and `page_size` on the `scrolled` event

| Field | Shape | Meaning |
| --- | --- | --- |
| `upper` | integer 0..65535 | Content extent, i.e. `scrollHeight`. |
| `page_size` | integer 0..65535 | Visible height, i.e. `clientHeight`. |

The event already carried `position`. Scripts read `upper` and
`page_size` back to compute their target, so without them the arithmetic
runs against defaults. A reported position also clears any pending
scroll request, so the shim does not yank a viewer who scrolled by hand.

## Not in this slice

`map.lic` reads and writes both axes as pixels, and this covers the
write path, but its scroller wraps a `Gtk::Layout` that does not render
until `composite` lands in slice five. Left untested against a real
window for that reason.

---

# Addendum: contract 2.10.0 — grid column weights

Additive. `grid` gained `weights`, the same shape `columns` already has:
an array of per-column integers naming each column's share of the
leftover width, where 0 means natural width.

| Property | Shape | Meaning |
| --- | --- | --- |
| `weights` | array of integer 0.., max 24 | Per-column share of the free width. Length is the grid's `cols`. |

Without it the client emitted `repeat(cols, auto)`, so every column
shared the width equally and a label column came out as wide as the
entry beside it.

## Where the signal comes from

Narrower than it looks. Of 145 `attach` call sites, only 8 live ones
pass `Gtk::EXPAND`, and every one of them names the entry column of a
label/entry pair. `Gtk::Table` reads it from the x options at attach.

`Gtk::Grid` has no attach options; a child asks with `hexpand`, which
scripts set after attaching, so those weights are derived at render
rather than recorded at attach.

Absent any expand request the property is omitted entirely and the
client keeps `repeat(cols, auto)` — that is GTK's own default, where a
table nothing asked to expand does not distribute free space.

## What is deliberately not the signal

`Gtk::Alignment` wraps 71 of those 145 attached children, and its
`xscale` looked like a second source of truth. It is not: every
`Alignment` in the corpus is `xscale: 0`, so it can only ever say "do
not stretch", which is already the default. Reading it would have
changed nothing and added a second, conflicting path.

A `FILL`-only attach is also not an expand request. FILL says how the
child sits in a cell it has already been given; EXPAND is what asks for
a bigger cell.

---

# Addendum: contract 2.11.0 — per-side margins

Additive and backward compatible. The shared `margin` attribute now
accepts either the integer it always did, or a record naming only the
sides that differ.

| Shape | Meaning |
| --- | --- |
| `margin: 8` | Eight pixels on all four sides, as before. |
| `margin: {top, right, bottom, left}` | Only the sides given; the rest are zero. Each 0..512. |

## Why

GTK sets one edge at a time -- `margin-start`, `margin-top` -- and the
shim collapsed the four sides to their maximum. That turned a one-sided
indent into a box: bigshot's glade has 518 one-sided margins, including
a note label with `margin-start: 100` and `margin-end: 10` that rendered
inside a 100px margin on every side. It is most of why the ported
windows looked spread out, and no stylesheet could have fixed it,
because the spread was in the tree.

The shim still sends a plain integer when every side agrees, which is
the common case, so most nodes are unchanged.

---

# Addendum: contract 2.12.0 — table headers

Additive. `table` gained `headers`, a boolean defaulting to true.

| Property | Shape | Meaning |
| --- | --- | --- |
| `headers` | boolean, default true | Whether the header row is shown. |

GTK's `headers-visible`. A tree view used as a plain list still has to
name its columns -- the model needs them -- but never shows those names.
eloot has twelve such lists, and every one rendered a bare "Exclusion"
or "Spell Number" heading inside the box, which reads as content rather
than the internal label it is.

---

# Addendum: contract 2.13.0 — the horizontal scroll axis

Additive. The `scrolled` event on `scroll` gained `position_x`, `upper_x`
and `page_size_x`, mirroring the three fields it already had for the
vertical axis. All three are optional, so a client that reports only the
vertical axis stays valid.

| Field | Shape | Meaning |
| --- | --- | --- |
| `position_x` | integer | `scrollLeft` |
| `upper_x` | integer | `scrollWidth` |
| `page_size_x` | integer | `clientWidth` |

## Why

GTK's `Adjustment` is per-axis, and a `ScrolledWindow` has two of them.
The event carried one scalar `position` with no axis, so the shim could
only ever feed `@vadjustment`; `@hadjustment` kept its constructor
defaults for the life of the window.

That is not a rounding error. map.lic turns a click into a room with

    click_x = (@scroller.hadjustment.value.to_i + pointer[0] - @map_offset_x) / scale

so the horizontal term was always zero however far the viewer had
scrolled. The same value is read by `center_viewport_on` when it clamps a
target to the scroll range.

`scroll_position`, the write path, already named both axes -- only the
read-back was one-sided.

## Not a new event

`surface_activate` and the `surface_events` property were already in the
schema from 2.7 and needed no change; they simply had no implementation on
either side. A composite now asks for surface events when a script has
connected a pointer signal to it, and the client emits the event with
coordinates in the composite's own pixels.
