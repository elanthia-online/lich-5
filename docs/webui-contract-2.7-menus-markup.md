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
