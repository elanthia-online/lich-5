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
