# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'webui'
require 'common/script_scope'
require 'common/script_scope/gtk/boot'

# The four ways ";map" came apart in the browser once it rendered: it
# re-centred to the corner instead of the room, a click found no room, a
# right-click threw the scroll position away, and the interior never tracked
# the window. Each is a seam between what map.lic computes and what the
# contract carries.
RSpec.describe 'GTK compatibility shim: map interaction' do
  let(:gtk) { Lich::Common::ScriptScope::Gtk }
  let(:owner) { Struct.new(:name) { def at_exit(&_block) = true }.new('map') }
  let(:service) { Lich::WebUI::Service.new }
  let(:session) { gtk::Session.new(owner, service: service) }
  let(:validator) { Lich::WebUI::Validator.new }

  before do
    gtk::Session.browser_open = proc { |_url, geometry:, on_start:, on_exit:| [geometry, on_exit]; on_start.call(1); true }
    gtk::Session.browser_kill = proc { |_pid| nil }
    allow(gtk::Session).to receive(:for).with(anything).and_return(session)
  end

  after do
    gtk::Session.browser_open = nil
    gtk::Session.browser_kill = nil
    session.shutdown
    service.stop
  end

  # window > scroll > layout, which is exactly what map.lic builds.
  def build_map_window
    window = scroller = layout = nil
    session.sync do
      window = gtk::Window.new('Map')
      window.set_default_size(400, 300)
      scroller = gtk::ScrolledWindow.new
      layout = gtk::Layout.new
      layout.set_size(2000, 1600)
      layout.signal_connect('button_press_event') { |_w, _e| nil }
      scroller.add(layout)
      window.add(scroller)
      window.show_all
    end
    session.commit
    [window, scroller, layout]
  end

  describe 'keeping the room marker centred as the player walks' do
    # scroll_position is viewer-scoped, and ViewerStore seeds a viewer-scoped
    # property into the viewer's overlay only once -- `unless values.key?`.
    # After that the viewer's own stale copy wins forever, so re-rendering
    # could not move the scroller a second time: map centred on the first room
    # and every later walk was discarded, which looked like the map snapping
    # back to the corner.
    it 'pushes every scroll write to the viewer, not just the first' do
      _window, scroller, = build_map_window
      writes = []
      allow(session).to receive(:viewer_write) do |_window, _widget, name, value|
        writes << [name, value]
      end

      session.sync { scroller.vadjustment.value = 400 }
      session.sync { scroller.vadjustment.value = 900 }

      expect(writes.map(&:first)).to eq(%i[scroll_position scroll_position])
      expect(writes.map { |(_name, value)| value[:y] }).to eq([400, 900])
    end

    # "value = upper - page_size" is how a log window spells "the bottom", and
    # the shim passes that intent on rather than a pixel. Recognising it by
    # magnitude alone is what broke map: against the constructor's 100/0 every
    # offset past 99 looked like the bottom, so centring on a room at y=900
    # was rewritten to "scroll to the end" and parked the map at the foot of
    # the canvas. A write past the extent is a pixel computed against a canvas
    # the shim has not been told about yet.
    it 'does not mistake an offset past the known extent for the bottom' do
      _window, scroller, = build_map_window
      session.sync { scroller.vadjustment.value = 900 }

      expect(scroller.send(:node_props)[:scroll_position]).to include(y: 900)
      expect(scroller.send(:node_props)[:scroll_position]).not_to include(:bottom)
    end

    it 'still recognises the bottom once the viewer has reported the extent' do
      _window, scroller, = build_map_window
      session.sync { scroller.vadjustment.note_viewport(upper: 2000, page_size: 400) }
      session.sync { scroller.vadjustment.value = 1600 }

      expect(scroller.send(:node_props)[:scroll_position]).to include(bottom: true)
    end

    # A script centres with `target = point - viewport / 2`, reading viewport
    # from allocation. Before the viewer reports, allocation answers with the
    # window's default size rather than the real pane, so the first centre
    # lands half the error away -- the map opened uncentred and only came
    # right on the first walk.
    it 'centres again on the real pane once the viewer first reports its size' do
      _window, scroller, = build_map_window
      # The window is 400x300, so the script believes the pane is 300 tall and
      # aims at y=1000 by asking for 1000 - 150 = 850.
      session.sync { scroller.vadjustment.value = 850 }

      # The pane is really 600 tall; centring on y=1000 means an offset of 700.
      session.sync do
        scroller.receive_event(:scrolled, Struct.new(:payload).new(
          { position: 0, upper: 3000, page_size: 600, position_x: 0, upper_x: 2000, page_size_x: 400 }
        ))
      end

      expect(scroller.vadjustment.value).to eq(700)
    end

    it 'leaves a viewer who has scrolled somewhere alone' do
      _window, scroller, = build_map_window
      session.sync { scroller.vadjustment.value = 850 }

      # The viewer is already at 120: their position wins, and the pending
      # request is theirs to cancel rather than ours to replay.
      session.sync do
        scroller.receive_event(:scrolled, Struct.new(:payload).new(
          { position: 120, upper: 3000, page_size: 600 }
        ))
      end

      expect(scroller.vadjustment.value).to eq(120)
      expect(scroller.send(:node_props)).not_to have_key(:scroll_position)
    end

    # Before the viewer reports, `upper - page_size` is the constructor's 100.
    # A log window writing exactly that means "the bottom" and is honoured. A
    # script centring on a point far outside that guessed range has its target
    # clamped down to the same number by arithmetic rather than intent, and
    # sending the leftover pixel parked map in the empty quadrant of its 2x
    # canvas -- a window with no map in it.
    it 'says nothing when a centring was clamped to a guessed extent on both axes' do
      _window, scroller, = build_map_window
      session.sync do
        vertical = scroller.vadjustment
        horizontal = scroller.hadjustment
        vertical.value = [[1000, 0].max, vertical.upper - vertical.page_size].min
        horizontal.value = [[900, 0].max, horizontal.upper - horizontal.page_size].min
      end

      expect(scroller.send(:node_props)).not_to have_key(:scroll_position)
    end

    it 'still honours a one-axis write at the extent as the bottom' do
      # A log window only ever asks for the vertical axis, so it is not
      # mistaken for a clamped centring.
      scroller = session.sync do
        pane = gtk::ScrolledWindow.new
        adjustment = pane.vadjustment
        adjustment.value = adjustment.upper - adjustment.page_size
        pane
      end

      expect(scroller.send(:node_props)[:scroll_position]).to eq(bottom: true)
    end

    it 'sends the position as the contract record the client applies' do
      _window, scroller, = build_map_window
      session.sync do
        scroller.hadjustment.value = 120
        scroller.vadjustment.value = 340
      end

      props = scroller.send(:node_props)

      expect(props[:scroll_position]).to include(x: 120, y: 340)
      expect { validator.validate_component!(:scroll, props, owner: 'o', page_id: 'p', cid: 'c') }.not_to raise_error
    end
  end

  describe 'translating a click into a map coordinate' do
    # map.lic computes (adjustment.value + pointer - offset) / scale. For that
    # to land on the true pixel the pointer must be viewport-relative and the
    # adjustment must hold the viewer's live offset, so the gesture carries
    # both halves.
    it 'records the scroller offset the gesture reported' do
      _window, scroller, layout = build_map_window
      context = Struct.new(:payload).new(
        { x: 40, y: 30, button: 'primary', modifiers: [], scroll_x: 500, scroll_y: 600 }
      )

      session.sync { layout.send(:receive_event, :surface_activate, context) }

      expect(scroller.hadjustment.value).to eq(500)
      expect(scroller.vadjustment.value) .to eq(600)
      # The pointer stays viewport-relative; the script adds the offset back.
      expect(layout.window.pointer[1, 2]).to eq([40, 30])
    end

    it 'reconstructs the layout-absolute pixel the viewer clicked' do
      _window, scroller, layout = build_map_window
      # The viewer clicked 40,30 into a viewport scrolled to 500,600, so the
      # pixel under the cursor is 540,630 in the layout's own coordinates.
      context = Struct.new(:payload).new(
        { x: 40, y: 30, button: 'primary', modifiers: [], scroll_x: 500, scroll_y: 600 }
      )

      session.sync { layout.send(:receive_event, :surface_activate, context) }

      pointer = layout.window.pointer
      absolute_x = scroller.hadjustment.value.to_i + pointer[1]
      absolute_y = scroller.vadjustment.value.to_i + pointer[2]
      expect([absolute_x, absolute_y]).to eq([540, 630])
    end

    it 'leaves the adjustments alone when the gesture carried no offset' do
      _window, scroller, layout = build_map_window
      session.sync { scroller.hadjustment.note_viewport(value: 75) }
      context = Struct.new(:payload).new({ x: 10, y: 10, button: 'primary', modifiers: [] })

      session.sync { layout.send(:receive_event, :surface_activate, context) }

      expect(scroller.hadjustment.value).to eq(75)
    end

    it 'accepts the offsets as part of the contract gesture' do
      payload = { x: 40, y: 30, button: 'primary', modifiers: [], scroll_x: 500, scroll_y: 600 }
      expect do
        validator.validate_event!(:composite, :surface_activate, payload,
                                  props: { surface_events: true, layers: [], width: 10, height: 10 },
                                  owner: 'o', page_id: 'p', cid: 'c')
      end.not_to raise_error
    end
  end

  describe 'sizing the interior to the window' do
    # A pixel max_height taken from the startup default never grew when the
    # window was resized, and when the window opened smaller than it the page
    # scrolled as well as the scroller -- the second scrollbar.
    it 'leaves a window-filling scroller to the stylesheet' do
      _window, scroller, = build_map_window

      expect(scroller.send(:node_props)).not_to include(:max_height)
    end

    it 'still bounds a scroller nested inside other widgets' do
      nested = nil
      session.sync do
        window = gtk::Window.new('Nested')
        window.set_default_size(400, 300)
        box = gtk::Box.new(:vertical)
        nested = gtk::ScrolledWindow.new
        box.add(nested)
        window.add(box)
        window.show_all
      end
      session.commit

      expect(nested.send(:node_props)[:max_height]).to eq(252)
    end
  end

  describe 'the right-click menu' do
    def build_menu_window
      menu = item = nil
      session.sync do
        window = gtk::Window.new('Map')
        window.set_default_size(400, 300)
        layout = gtk::Layout.new
        layout.set_size(100, 100)
        layout.signal_connect('button_press_event') { |_w, _e| nil }
        window.add(layout)
        menu = gtk::Menu.new
        item = gtk::CheckMenuItem.new(label: 'Expanded Canvas')
        item.active = true
        menu.append(item)
        window.show_all
      end
      session.commit
      [menu, item]
    end

    def menu_props
      page = service.registry.pages_for(owner).first
      page.last_render.tree.each.find { |component| component.type == :menu }&.props
    end

    # `open` is viewer-scoped, so the viewer's overlay copy shadows the shared
    # prop. Nothing cleared that copy when the menu closed, so every later
    # render re-raised it -- and because a room change now re-renders, the
    # menu reappeared on every step the player took.
    it 'stays shut once the viewer closes it, however often the page redraws' do
      menu, = build_menu_window
      session.sync { menu.popup_at_pointer(nil) }
      session.commit
      expect(menu_props[:open]).to be(true)

      session.sync { menu.send(:receive_event, :close, Struct.new(:payload).new({})) }
      session.commit
      expect(menu_props[:open]).to be(false)

      session.sync { menu.changed! }
      session.commit
      expect(menu_props[:open]).to be(false)
    end

    # A check item's `active` is viewer-scoped too. The viewer's click has to
    # reach the owner and the owner's answer has to come back, or the tick
    # never moves -- which is what kept map's Follow and Expanded Canvas from
    # toggling.
    it 'carries a toggle through to the script and back to the tick' do
      menu, item = build_menu_window
      chosen = []
      session.sync { item.signal_connect('activate') { chosen << item.active? } }
      session.sync { menu.popup_at_pointer(nil) }
      session.commit

      session.sync { item.send(:receive_event, :change, Struct.new(:payload).new({ value: false })) }
      session.sync { item.send(:receive_event, :activate, Struct.new(:payload).new({})) }
      session.commit

      expect(item.active?).to be(false)
      expect(chosen).to eq([false])
      page = service.registry.pages_for(owner).first
      node = page.last_render.tree.each.find { |component| component.type == :menu_item }
      expect(node.props[:active]).to be(false)
    end
  end
end
