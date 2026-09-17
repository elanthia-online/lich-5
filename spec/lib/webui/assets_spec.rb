# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui'

RSpec.describe 'WebUI browser assets' do
  let(:javascript) { File.read(File.join(Lich::WebUI::Service::ASSETS_DIR, 'app.js')) }
  let(:html) { File.read(File.join(Lich::WebUI::Service::ASSETS_DIR, 'index.html')) }

  it 'constructs hostile text as text nodes without string-built DOM or evaluation sinks', security_id: 'sec-escaping' do
    expect(javascript).not_to match(/innerHTML|outerHTML|document\.write|\beval\s*\(|new\s+Function/)
    expect(javascript).to include('textContent', 'document.createElement')
  end

  it 'announces only targeted status updates and focuses controls or their wrappers' do
    expect(html).to include('<main id="pages"></main>')
    expect(html).not_to match(/<main id="pages"[^>]*aria-live/)
    expect(javascript).to include('focusRoot?.matches("input, select, button, textarea")')
  end

  # A window opened for one page ignores every other page. A modal is a page
  # of its own, so a question a script asked was invisible while the script
  # blocked on the answer.
  it 'attaches to a modal raised by the same owner, even when scoped to one page' do
    expect(javascript).to include('const sameOwnerModal = descriptor.modal && scopedOwner && descriptor.owner === scopedOwner;')
    expect(javascript).to include('if (onlyPage && descriptor.address !== onlyPage && !sameOwnerModal) return;')
    # A modal borrows the window; it must not rename it.
    expect(javascript).to include('if (descriptor.title && !descriptor.modal) document.title = descriptor.title;')
  end

  # split and overlay had contract types but no client renderer, so spellson
  # and jinx rendered blank panes.
  it 'renders split panes with a draggable divider' do
    expect(javascript).to match(/^    split\(page, component\)/)
    expect(javascript).to include('emit(page, component, "move", { position })')
    # Pointer capture keeps the drag on the handle, leaving nothing on the
    # document after the tree is rebuilt.
    expect(javascript).to include('handle.setPointerCapture(event.pointerId)')
  end

  it 'stacks overlay children over the first in document order' do
    expect(javascript).to match(/^    overlay\(page, component\)/)
    expect(javascript).to include('if (index > 0) element.classList.add("overlay-layer")')
  end

  # A composite is the only surface a script can click on, and the contract
  # gates the event behind surface_events so a page opts in.
  it 'emits surface_activate from a composite that asked for it' do
    expect(javascript).to include('if (component.props.surface_events) {');
    expect(javascript).to include('emit(page, component, "surface_activate", surfacePayload(event, surface, "primary"))')
    expect(javascript).to include('emit(page, component, "surface_activate", surfacePayload(event, surface, "secondary"))')
    # The browser's own menu must not appear over a script's popup.
    expect(javascript).to include('event.preventDefault()')
    # A region is its own event; a click on one is not also a surface click.
    expect(javascript).to include('if (event.target.closest(".composite-region")) return;')
  end

  # The tree is rebuilt on every commit, so an unconditional report after
  # layout sent one of these after every render -- and a render landing in
  # that gap made it stale, which the viewer saw as a refusal.
  it 'reports a scroll extent only when it has changed' do
    expect(javascript).to include('if (page.scrollExtents?.get(component.cid) === extent) return;')
    expect(javascript).to include('(page.scrollExtents ||= new Map()).set(component.cid, extent);')
  end

  # One event is remembered for retry, so an unsolicited report must not
  # overwrite a click still in flight.
  it 'keeps unsolicited reports out of the retry slot' do
    expect(javascript).to include('const UNSOLICITED = new Set(["scrolled"]);')
    expect(javascript).to include('if (!UNSOLICITED.has(event)) {')
  end

  # A refusal must be matched to the event it names. The handler used to
  # replay whatever was in a single pending slot, so sending A then B and
  # refusing A sent A, B, B -- re-running B while losing A. And the retry
  # guard was released just before the replay, so the replay installed a
  # clean guard and the same event could be retried indefinitely.
  it 'replays only the event a refusal names, and only once' do
    expect(javascript).to include('requestKey(message.page, message.cid, message.event)')
    expect(javascript).to include('pendingEvents.get(refusedKey)')
    expect(javascript).to include('retry.attempt < MAX_EVENT_ATTEMPTS')
    expect(javascript).to include('const MAX_EVENT_ATTEMPTS = 1;')
  end

  # 2.17: shape layers are drawn as SVG sized to their own box, placed by
  # the origin they report, and never intercept a click meant for the
  # surface or a region beneath them.
  it 'draws line, rect and ellipse layers as SVG that lets clicks through' do
    expect(javascript).to include('if (layer.kind === "line" || layer.kind === "rect" || layer.kind === "ellipse") return shapeLayer(layer);')
    expect(javascript).to include('document.createElementNS("http://www.w3.org/2000/svg", tag)')
    expect(javascript).to include('svg.dataset.originX = String(x - pad);')
    css = File.read(File.join(Lich::WebUI::Service::ASSETS_DIR, 'app.css'))
    expect(css).to include('.composite-shape { pointer-events: none;')
  end

  # The contract and the shim both know a multi-selection table; the client
  # sent one row per click whatever the mode, ctrl or not, so a script that
  # asked for SELECTION_MULTIPLE could never receive more than one row.
  it 'accumulates a multi-selection with ctrl and extends it with shift' do
    expect(javascript).to include('if (mode === "multi") {')
    expect(javascript).to include('rows = current.includes(row.key) ? current.filter((key) => key !== row.key) : current.concat(row.key);')
    expect(javascript).to include('rows = keys.slice(from, to + 1);')
    expect(javascript).to include('emit(page, component, "selection_change", { rows });')
  end

  # A number field commits on change, so digits typed and not yet committed
  # are a draft. The capture excluded type=number, and a render landing in
  # that gap put the old server value back under the viewer's typing.
  it 'preserves a half-typed number across a render, except text the browser cannot parse' do
    expect(javascript).to include('!["checkbox", "radio", "range"].includes(control.type)')
    expect(javascript).not_to include('"range", "number"]')
    expect(javascript).to include('if (control.type === "number" && control.validity?.badInput) continue;')
  end

  it 'replays the payload and submission the event was sent with, not the current controls' do
    expect(javascript).to include('submission: message.submission')
    expect(javascript).to include('if (submission !== undefined) message.submission = submission;')
    expect(javascript).to include('emit(page, component, retry.event, retry.payload, retry.attempt + 1, retry.submission);')
  end

  # The server answers a stale event with the refusal first and then the
  # render that superseded it. A record the refusal marks for replay has to
  # survive until that render lands -- that tree is the one to replay into --
  # and every other record for the page is forgotten when it arrives.
  it 'replays a stale event into the render that follows its refusal, and forgets the rest' do
    expect(javascript).to include('retry.replay = true;')
    expect(javascript).to include('if (record.address !== message.page) return;')
    expect(javascript).to include('if (record.replay) replays.push(record);')
  end

  it 'still hides a stale refusal from the viewer and surfaces every other' do
    expect(javascript).to include('if (message.reason === "stale_generation") {')
    expect(javascript).to include('notify(detail ? `${text}: ${detail}` : text, "error")')
  end

  it 'reports both scroll axes, since a GTK adjustment is per-axis' do
    %w[position_x upper_x page_size_x].each do |field|
      expect(javascript.scan(/#{field}:/).size).to eq(2)
    end
  end

  # Until something reported an extent, a script centring its viewport
  # computed against a constructor default rather than the real pane.
  it 'reports a scroller extent after layout, not only when the viewer scrolls' do
    scroll = javascript[/    scroll\(page, component\) \{.*?\n    \},/m]

    expect(scroll).to include('requestAnimationFrame')
    expect(scroll).to include('if (!scroll.isConnected) return;')
    expect(scroll.scan(/page_size: Math\.round\(scroll\.clientHeight\)/).size).to eq(2)
  end

  # The shim can now build an image and a composite, but the client had no
  # renderer for either, so a map arrived as "Renderer not implemented".
  it 'renders images and every kind of composite layer' do
    expect(javascript).to match(/^    image\(_?page, component\)/)
    expect(javascript).to match(/^    composite\(page, component\)/)
    expect(javascript).to include('function compositeLayer(page, component, layer)')
    %w[image label bar region].each do |kind|
      expect(javascript).to include(%(layer.kind === "#{kind}"))
    end
    # A region that activates is the only interactive layer.
    expect(javascript).to include('emit(page, component, "region_activate", { region: layer.key })')
    # Still built from validated data, never markup.
    expect(javascript).not_to match(/innerHTML|outerHTML/)
  end

  # 2.14: a window that connected key-press-event gets keys on the page root.
  # A page key is a lifecycle event and is not in page.bindings, so it cannot
  # go through emit()'s bound() gate.
  it 'sends a page key only when the page asked for key events' do
    expect(javascript).to include('if (component.props.key_events) {')
    expect(javascript).to include('emitLifecycle(page, component, "key", { keyval, modifiers })')
    # Listening on the page root, not the document, so one window's keys do
    # not reach another's, and a focused control keeps its own keys.
    expect(javascript).to include('root.addEventListener("keydown"')
    expect(javascript).to include('if (activeCid && activeCid !== component.cid) return;')
    # The accelerator handler is on the document and would otherwise fire too.
    expect(javascript).to include('event.stopPropagation()')
  end

  it 'maps a browser key to the GTK keyval name a script compares against' do
    expect(javascript).to include('ArrowLeft: "Left"')
    expect(javascript).to include('PageUp: "Page_Up"')
    # A single printable character is its own keyval name.
    expect(javascript).to include('if (event.key.length === 1) return event.key;')
  end

  # 2.15: a GTK script converts a click with
  # (adjustment.value + pointer - offset) / scale, so the pointer has to be
  # viewport-relative and the offset has to be the live one. Sending the
  # absolute pixel while the adjustment held a stale default counted the
  # scroll twice, and a click only found the right room at the origin.
  it 'splits a surface gesture into a viewport pointer and the live scroll offset' do
    payload = javascript[/  function surfacePayload\(event, surface, button\) \{.*?\n  \}/m]

    expect(payload).to include('const scroller = surface.closest(".webui-scroll");')
    expect(payload).to include('const payload = { x: Math.round(rawX - sx), y: Math.round(rawY - sy), button, modifiers };')
    expect(payload).to include('payload.scroll_x = sx;')
    # A composite outside a scroller reports no offset rather than a zero the
    # shim would mistake for a real one.
    expect(payload).to include('if (scroller) {')
  end

  # The pointer and the scroll offset were each rounded before the
  # subtraction, which can land a pixel away from rounding the difference
  # once. The offset is an integer once rounded, so rounding (raw - offset)
  # is the same as rounding raw and then subtracting: the script's
  # `x + scroll_x` reconstructs the absolute pixel exactly. Source-level:
  # there is no browser harness for app.js.
  it 'rounds a surface gesture once, after the scroll offset is taken off' do
    payload = javascript[/  function surfacePayload\(event, surface, button\) \{.*?\n  \}/m]

    expect(payload).to include('const rawX = (event.clientX - rect.left) / s;')
    expect(payload).to include('const rawY = (event.clientY - rect.top) / s;')
    expect(payload).not_to include('Math.round((event.clientX - rect.left) / s)')
    expect(payload).not_to include('Math.round((event.clientY - rect.top) / s)')
    expect(payload.scan('Math.round(').size).to eq(4)
  end

  # The tree is rebuilt on every commit, so a commit the viewer did not cause
  # -- a right-click opening a menu, a marker moving -- threw their scroll
  # position away and snapped the map back to the corner.
  it 'puts the viewer back where they were scrolled unless the script moved them' do
    expect(javascript).to include('(page.scrollOffsets ||= new Map()).set(component.cid, {')
    expect(javascript).to include('const remembered = page.scrollOffsets?.get(component.cid);')
    # An explicit position from the script still wins for that cycle.
    expect(javascript).to include('if (position) page.pendingScrolls.push([scroll, position]);')
    expect(javascript).to include('else if (remembered) page.pendingScrolls.push([scroll, remembered]);')
  end

  # A GTK script pans by handling motion-notify-event, which the contract has
  # no equivalent for. It does not need one: the scroller can pan itself, and
  # the script only ever hears the click that did not become a drag.
  it 'pans a surface by dragging it, without sending that as a click' do
    expect(javascript).to include('surface.addEventListener("pointerdown"');
    expect(javascript).to include('drag.scroller.scrollLeft = drag.left - dx;');
    expect(javascript).to include('surface.setPointerCapture(event.pointerId)');
    # The click that ends a drag must not also walk the character.
    expect(javascript).to include('if (surface.dataset.dragged === "true") {');
  end

  # A submenu opening the instant the pointer crossed it flashed children open
  # while the viewer was only travelling down the parent menu.
  it 'waits for the pointer to settle before opening a submenu' do
    expect(javascript).to include('const SUBMENU_DWELL_MS = 300;');
    expect(javascript).to include('dwell = window.setTimeout(() => { dwell = null; open(); }, SUBMENU_DWELL_MS);');
    # Leaving no longer only cancels a pending open; it schedules the close.
    expect(javascript).to include('button.addEventListener("mouseleave", scheduleClose);');
    # A click still opens it immediately.
    expect(javascript).to include('button.addEventListener("click", () => { cancelDwell(); open(); });');
  end

  # A menu is rebuilt in place on every commit, so a second click computed
  # from the props of an older render sent the same value twice and the
  # toggle appeared not to toggle.
  it 'toggles a check menu item from what is on screen, not a stale render' do
    expect(javascript).to include('const checked = button.getAttribute("aria-checked") === "true";');
    expect(javascript).to include('emit(page, item, "change", { value: next });');
  end

  # Leaving a submenu should put it away again, but not the instant the
  # pointer crosses the parent on its way into the child.
  it 'closes a submenu on a longer dwell once the pointer leaves it' do
    expect(javascript).to include('const SUBMENU_CLOSE_MS = 450;')
    expect(javascript).to include('}, SUBMENU_CLOSE_MS);')
    # Leaving an item is also how you reach its submenu, and its submenu's
    # submenu; closing then would take the layer just walked into with it.
    expect(javascript).to include('if (pointerInMenuBelow(level)) return;')
    expect(javascript).to include('layer.addEventListener("mouseenter", () => { layer.dataset.pointerInside = "true"; });')
    expect(javascript).to include('button.addEventListener("mouseleave", scheduleClose);')
    # Arriving in the submenu itself calls the closing off.
    expect(javascript).to include('layer.addEventListener("mouseenter", () => owner.__cancelSubmenuClose());')
    expect(javascript).to include('layer.addEventListener("mouseleave", () => owner.__scheduleSubmenuClose?.());')
  end

  # A script asking for no scrollbars means the page's own furniture, and the
  # page is the only thing that can take it away. The contract declared the
  # facility supported while the client read nothing at all.
  it 'hides the page scrollbars when the script asked for none' do
    expect(javascript).to include('const bare = facilities.presentation && facilities.presentation.scrollbars === false;')
    expect(javascript).to include('document.documentElement.classList.toggle("hide-scrollbars", !!bare);')
    css = File.read(File.join(Lich::WebUI::Service::ASSETS_DIR, 'app.css'))
    expect(css).to include('.hide-scrollbars .webui-scroll { scrollbar-width: none;')
    expect(css).to include('.hide-scrollbars .webui-scroll::-webkit-scrollbar { width: 0; height: 0; }')
  end

  # A render replaces the whole tree, so every input is a new node. Without
  # this the viewer loses what they were typing whenever a script repaints
  # on a game event.
  it 'carries an unsent edit, its focus and its caret across a tree swap' do
    expect(javascript).to include('const editing = captureEditing(page);')
    expect(javascript).to include('restoreEditing(page, editing);')
    # Captured before the swap and restored after, so the comparison that
    # lets a server update win is against the previous render's value.
    expect(javascript).to match(/state\.edits\.set\(cid, \{ typed: control\.value, base: String\(rendered\), key \}\)/)
    expect(javascript).to match(/String\(rendered\) !== edit\.base\) continue/)
    expect(javascript).to include('setSelectionRange(state.selection.start, state.selection.end)')
    # restoreEditing runs first so an explicit focus facility still wins.
    # Scoped to acceptRender's body, not the whole file, so this cannot pass
    # by matching applyFacilities' own definition further up.
    accept = javascript[/function acceptRender\(message\) \{.*?\n  \}/m]
    expect(accept.index('restoreEditing(page, editing);')).to be < accept.index('applyFacilities(page);')
  end

  # The contract declares `disabled` on select and on table, the server sends
  # it, and the client read it in neither -- so a script that greyed out a
  # dropdown got a live one, and a disabled table still answered clicks.
  it 'honours disabled on the controls whose contract carries it' do
    expect(javascript).to include('control.disabled = component.props.disabled === true;')
    expect(javascript).to include('if (component.props.disabled === true) return;')
    # A div has no `disabled` of its own, so a container needs the attribute.
    expect(javascript).to include('else if (props.disabled === true) element.dataset.disabled = "true";')
  end

  it 'styles a container that carries disabled, which has no native rendering' do
    css = File.read(File.join(Lich::WebUI::Service::ASSETS_DIR, 'app.css'))

    expect(css).to include('[data-disabled="true"]')
  end

  # `socket` is module-level, so the error handler closed whatever was current
  # rather than the socket that errored: an error arriving from a superseded
  # socket closed the live one, whose close handler dialled again.
  it 'binds each socket handler to the socket it was created for' do
    expect(javascript).to include('const live = new WebSocket(')
    expect(javascript).to include('live.addEventListener("error", () => live.close());')
    expect(javascript).to include('if (socket !== live) return;')
    expect(javascript).not_to include('socket.addEventListener("error", () => socket.close());')
  end

  # Both `hello` and `pages` arrive when something like a sibling modal
  # opens, and re-attaching a page this socket already holds is refused
  # ("viewer is already attached") -- so opening a modal produced refusal
  # notifications the viewer never caused, each one consuming a retry slot.
  it 'attaches only pages this socket does not already hold' do
    expect(javascript).to include('if (attachedPages.has(descriptor.address)) return;')
    expect(javascript).to include('attachedPages.add(descriptor.address);')
  end

  it 'forgets its attachments when the socket goes, so a reconnect resumes' do
    expect(javascript).to include('attachedPages = new Set();')
    expect(javascript).to include('attachedPages.delete(message.page);')
  end

  # captureEditing only kept a draft when the last tree carried a `value`.
  # A password deliberately never does -- it is write-only -- so any
  # unrelated render (a geometry update, a tab switch) wiped a half-typed
  # password.
  it 'keeps a half-typed password across an unrelated render' do
    expect(javascript).to include('control.type === "password" && control.value')
    expect(javascript).to include('state.edits.set(cid, { typed: control.value, base: null, key });')
    # base null means the server never had an opinion, so nothing can have
    # changed under the viewer.
    expect(javascript).to include('if (edit.base !== null && rendered !== undefined && String(rendered) !== edit.base) continue;')
  end

  it 'still lets the server win when it changed an ordinary value' do
    expect(javascript).to include('state.edits.set(cid, { typed: control.value, base: String(rendered), key });')
  end

  # A script flipping Entry#visibility from false to true makes the shim
  # destroy the password_input node and create a text_input under a NEW cid
  # (adapter handles are fresh objects, and the cid is derived from the
  # handle). The draft was keyed by cid alone, so the masked typing -- which
  # never had a channel to the server -- vanished with the old control. The
  # shim's widget key (props.key) is the same on both nodes, so the draft
  # follows it. Source-level: there is no browser harness for app.js.
  it 'carries a masked draft into the text control that replaces it' do
    expect(javascript).to include('function findComponentByKey(node, key)')
    expect(javascript).to include('const key = component?.props?.key ?? null;')
    expect(javascript).to include('state.edits.set(cid, { typed: control.value, base: null, key });')
    expect(javascript).to include('function editingControl(page, cid, key)')
    expect(javascript).to include('const replacement = findComponentByKey(page.tree, key);')
    restore = javascript[/  function restoreEditing\(page, state\) \{.*?\n  \}/m]
    expect(restore).to include('const control = editingControl(page, cid, edit.key);')
    expect(restore).to include('const control = editingControl(page, state.focusCid, state.focusKey);')
    expect(restore).not_to include('page.controls?.get(cid)')
  end

  # The reverse flip (text to password) may put the typed text into the new
  # masked control in the browser, but the tree must never carry it.
  it 'never seeds a password control from the tree' do
    password = javascript[/    password_input\(page, component\) \{.*?\n    \},/m]

    expect(password).not_to include('control.value =')
    expect(password).not_to include('component.props.value')
  end

  it 'still clears a password when the server says to' do
    expect(javascript).to include('message.type === "clear_sensitive"')
  end

  # The contract declares tabs.vertical and app.css has always implemented the
  # layout; the client gated it on a hardcoded cid, so the property did nothing
  # for anyone but the accounts page. A declared property that renders nothing
  # makes the tree lie to an author reading the schema.
  it 'lays tabs out vertically because the property says so' do
    expect(javascript).to include('component.props.vertical === true')
    expect(javascript).to include('tabs.classList.add("vertical");')
  end

  it 'keeps the cid fallback so the accounts page does not regress' do
    expect(javascript).to include('component.cid.includes("saved-account-tabs")')
  end

  it 'names the vertical class for the property rather than for one page' do
    css = File.read(File.join(Lich::WebUI::Service::ASSETS_DIR, 'app.css'))

    expect(css).to include('.webui-tabs.vertical')
    expect(css).not_to include('account-tabs-left')
  end

  # The shim binds row-activated whenever a script connects to it -- ewaggle,
  # repository and jinx all do -- and advertises cell editors through
  # CellRendererText and CellRendererToggle. The client emitted neither event
  # and rendered every cell as text, so both gestures were dead on arrival.
  it 'activates a row on double-click and on Enter, as GTK does' do
    expect(javascript).to include('emit(page, component, "row_activate", { row: row.key })')
    expect(javascript).to include('tr.addEventListener("dblclick", activate)')
    expect(javascript).to include('if (event.key === "Enter") { event.preventDefault(); activate(); }')
  end

  it 'builds a control for a column that declares an editor' do
    expect(javascript).to include('if (column.editor && component.props.disabled !== true)')
    expect(javascript).to include('function editorCell(page, component, row, column, value)')
  end

  it 'covers every editor type the validator accepts' do
    %w[checkbox select number].each do |type|
      expect(javascript).to include(%(editor.type === "#{type}"))
    end
    expect(javascript).to include('emit(page, component, "cell_edit", {')
  end

  # A cell_edit per keystroke would be a render per keystroke.
  it 'sends the committed value rather than every keystroke' do
    expect(javascript).to include('control.addEventListener("change", () => {')
    expect(javascript).not_to include('control.addEventListener("input", () => send')
  end

  it 'leaves a disabled table inert' do
    expect(javascript).to include('if (component.props.disabled !== true) emit(page, component, "row_activate"')
    expect(javascript).to include('tr.tabIndex = component.props.disabled === true ? -1 : 0;')
  end

  # A stray comment terminator in app.css once left prose outside any
  # comment; the browser skipped the malformed rule that followed -- the
  # measuring rule -- and every window opened at the size of the screen.
  # Nothing in the suite parses the stylesheet, so this does the minimum.
  it 'ships a stylesheet with balanced comments and braces' do
    css = File.read(File.join(Lich::WebUI::Service::ASSETS_DIR, 'app.css'))
    stripped = css.gsub(%r{/\*.*?\*/}m, '')
    expect(stripped).not_to include('*/')
    expect(stripped).not_to include('/*')
    expect(stripped.count('{')).to eq(stripped.count('}'))
    expect(stripped.lines.grep(/\A\s*[^{}\s@.#:\[\]a-zA-Z*,>+~-]/)).to eq([])
  end

  # GTK's rule for a window: the default size is honoured unless the
  # content is larger. The harness cannot measure content in jsdom, so the
  # arithmetic is pinned here; the harness pins the geometry-only path.
  it 'opens a window at the larger of its declared geometry and its natural size, and never lets a grid group spill' do
    expect(javascript).to include('const natural = naturalPageSize() || { width: 0, height: 0 };')
    expect(javascript).to include('width: Math.max(geometry.width > 0 ? geometry.width : 0, natural.width),')
    expect(javascript).to include('height: Math.max(geometry.height > 0 ? geometry.height : 0, natural.height),')
    css = File.read(File.join(Lich::WebUI::Service::ASSETS_DIR, 'app.css'))
    expect(css).to include('.webui-grid > .webui-group { min-width: auto; }')
    expect(css).to include('.webui-page.bare { overflow: auto; }')
  end
end
