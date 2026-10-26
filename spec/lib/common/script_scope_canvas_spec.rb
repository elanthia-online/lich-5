# frozen_string_literal: true

require_relative '../../spec_helper'
require 'timeout'
require_relative '../../../lib/common/script_scope'
require_relative '../../support/webui_browser'

RSpec.describe 'script canvas interaction' do
  let(:scope) { Lich::Common::ScriptScope }
  let(:owner) { Struct.new(:name).new('canvas.lic') }
  let(:service) { Lich::WebUI::Service.new }
  let(:gtk) { scope.const_get(:Gtk, false) }

  before do
    scope.activate!
    stub_const('Lich::Common::Script', Class.new { def self.current; end })
    allow(Lich::Common::Script).to receive(:current).and_return(owner)
    allow(Lich::WebUI).to receive(:adapter) { |owner:, viewer: nil| Lich::WebUI::Adapter.new(owner: owner, service: service, viewer: viewer) }
    allow(Lich::WebUI).to receive(:callback_queue) { |owner:| proc { |&work| service.runtime.dispatch(owner: owner, &work) } }
    allow(Lich::WebUI).to receive(:callback_scheduler) { |owner:| service.runtime.scheduler.for_owner(owner) }
    allow(Lich).to receive(:log)
  end

  after do
    Lich::Common::ScriptDeath.run(owner)
    service.stop
  end

  it 'validates virtual extents atomically and distinguishes release events' do
    layout = gtk::Layout.new
    layout.set_size(1200, 900)
    expect { layout.set_size(100, Float::NAN) }.to raise_error(gtk::UnsupportedOperation)
    expect([layout.width, layout.height]).to eq([1200, 900])
    expect { layout.add_events(:button_press_mask); layout.add_events(:button_release_mask) }.not_to raise_error
    event = gtk::PointerEvent.new(x: 1, y: 2, button: 1, time: 0, state: 0, released: true)
    expect(event.event_type).to eq(scope::Gdk::Event::Type::BUTTON_RELEASE)
  end

  it 'keeps background pointer reads on the drag viewer and cancels once on disconnect' do
    window, layout = gtk::Window.new, gtk::Layout.new
    layout.set_size(1200, 900)
    pressed, released = Queue.new, Queue.new
    layout.signal_connect('button-press-event') { pressed << true }
    layout.signal_connect('button-release-event') { |_widget, event| released << event.event_type }
    window.add(layout)
    window.show_all
    page = nil
    Timeout.timeout(2) { sleep 0.001 until (page = service.registry.pages_for(owner).first)&.last_render }
    connection = double('canvas viewer', viewer_id: 'canvas', alive?: true, send_text: true)
    address = service.registry.address_for(page)
    service.runtime.handle(connection, type: 'attach', page: address)
    canvas = page.last_render.tree.each.find { |node| node.type == :overlay }
    service.runtime.handle(connection, type: 'event', page: address, generation: page.generation,
                           cid: canvas.cid, event: 'pointer_press', payload: { x: 70, y: 80, button: 1, time: 0, state: 4 })
    expect(pressed.pop(timeout: 2)).to be(true)
    viewer = layout.pointer_viewer
    layout.session.callback(Struct.new(:viewer_id).new('other-viewer'), widget: window) {}
    expect(layout.session.with_widget(layout) { layout.session.viewer_id }).to eq(viewer)
    device = scope::Gdk::Display.default.default_seat.pointer
    expect(window.window.get_device_position(device).drop(1)).to eq([70, 80, 4])
    service.runtime.disconnect(connection)
    expect(released.pop(timeout: 2)).to eq(:button_release)
    expect(layout.pointer_viewer).to be_nil
    service.runtime.disconnect(connection)
    expect(released).to be_empty
  end

  it 'scrolls a live canvas while polling the pointer across redraws in Chrome', browser: true do
    skip 'explicit browser run only' unless ENV['NATIVE_BROWSER'] == '1'

    window = gtk::Window.new('Canvas interaction')
    window.resize(500, 400)
    box = gtk::VBox.new(false, 0)
    status = gtk::Label.new('Ready')
    scroller = gtk::ScrolledWindow.new
    scroller.set_size_request(400, 250)
    layout = gtk::Layout.new
    layout.set_size(1600, 1200)
    label = gtk::Label.new('Map marker')
    layout.put(label, 600, 500)
    scroller.add(layout)
    box.add(status)
    box.add(scroller)
    window.add(box)
    pointer = -> { window.window.get_device_position(scope::Gdk::Display.default.default_seat.pointer).values_at(1, 2) }
    dragging = false
    releases = []
    layout.signal_connect('button-press-event') do |_widget, event|
      next unless event.button == 1
      start_x, start_y = pointer.call
      left, top = scroller.hadjustment.value, scroller.vadjustment.value
      dragging = true
      gtk.session.schedule(layout, :drag, 25) do
        next false unless dragging
        x, y = pointer.call
        scroller.hadjustment.value = left + start_x - x
        scroller.vadjustment.value = top + start_y - y
        layout.move(label, 601, 501)
        true
      end
    end
    layout.signal_connect('button-release-event') do |_widget, event|
      dragging = false
      releases << event.event_type
      status.text = "Released #{releases.length}"
    end
    layout.signal_connect('scroll-event') do |_widget, event|
      if event.state.control_mask?
        status.text = "Anchor #{event.x},#{event.y}"
        true
      elsif event.state.shift_mask?
        event.direction = :right
        event.put
        true
      else
        false
      end
    end
    window.show_all
    page = nil
    Timeout.timeout(2) { sleep 0.001 until (page = service.registry.pages_for(owner).first)&.last_render }
    WebUIBrowser.check(service: service, page: page, scenario: 'shim-canvas')
    expect(releases).to all(eq(:button_release))
    expect(releases.size).to be >= 2
    expect(dragging).to be(false)
  end
end
