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
end
