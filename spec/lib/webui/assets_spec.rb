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

  it 'does not show the viewer a stale report they never sent' do
    refusal = javascript[/} else if \(message\.type === "refusal"\) \{.*?\n    \}/m]

    # The retry still comes first; only an already-retried event falls through.
    expect(refusal.index('if (message.reason === "stale_generation" && pendingEvent)'))
      .to be < refusal.index('console.warn("webui refusal", message);')
    expect(refusal).to include('if (message.reason === "stale_generation") {')
    # Any other refusal is still surfaced.
    expect(refusal).to include('notify(detail ? `${text}: ${detail}` : text, "error")')
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
    expect(payload).to include('const payload = { x: absX - sx, y: absY - sy, button, modifiers };')
    expect(payload).to include('payload.scroll_x = sx;')
    # A composite outside a scroller reports no offset rather than a zero the
    # shim would mistake for a real one.
    expect(payload).to include('if (scroller) {')
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
    expect(javascript).to match(/state\.edits\.set\(cid, \{ typed: control\.value, base: String\(rendered\) \}\)/)
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
end
