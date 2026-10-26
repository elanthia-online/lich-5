# frozen_string_literal: true

require_relative '../../spec_helper'
require 'timeout'
require_relative '../../../lib/common/script_scope'
require_relative '../../support/webui_browser'

RSpec.describe 'bounded Combatical drawing and successor controls' do
  let(:scope) { Lich::Common::ScriptScope }
  let(:owner) { Struct.new(:name).new('drawing.lic') }
  let(:service) { Lich::WebUI::Service.new }
  let(:gtk) { scope.const_get(:Gtk, false) }

  before do
    scope.activate!
    stub_const('Lich::Common::Script', Class.new { def self.current; end })
    allow(Lich::Common::Script).to receive(:current).and_return(owner)
    allow(Lich::WebUI).to receive(:adapter) { |owner:, viewer: nil| Lich::WebUI::Adapter.new(owner: owner, service: service, viewer: viewer) }
    allow(Lich::WebUI).to receive(:callback_queue) { |owner:| proc { |&work| service.runtime.dispatch(owner: owner, &work) } }
    allow(Lich).to receive(:log)
  end

  after do
    Lich::Common::ScriptDeath.run(owner)
    service.stop
  end

  def wait_for(&block) = Timeout.timeout(3) { sleep 0.005 until block.call }

  def show(widget)
    window = gtk::Window.new('Drawing fixture')
    window.add(widget)
    window.show_all
    page = nil
    wait_for { (page = service.registry.pages_for(owner).first)&.last_render }
    [window, page]
  end

  def shapes(page)
    page.last_render.tree.each.find { |node| node.type == :composite }.props[:layers]
  end

  def bar(area, state)
    area.set_size_request(120, 8)
    area.signal_connect('draw') do |widget, context|
      width, height = widget.allocated_width, widget.allocated_height
      fraction = state[:max].positive? ? (state[:current].fdiv(state[:max])).clamp(0, 1) : 0
      context.set_source_rgb(0.3, 0, 0); context.rectangle(0, 0, width, height); context.fill
      if fraction.positive?
        context.set_source_rgb(0.8, 0, 0); context.rectangle(0, 0, width * fraction, height); context.fill
      end
      context.set_source_rgb(0.5, 0.5, 0.5); context.rectangle(0, 0, width, height)
      context.set_line_width(1); context.stroke
    end
  end

  it 'publishes initial zero-maximum bars and replaces ordered fractional fills on redraw' do
    area = gtk::DrawingArea.new
    state = { current: 0, max: 0 }
    bar(area, state)
    _window, page = show(area)
    expect(shapes(page).map { |shape| shape[:mode] }).to eq(%w[fill stroke])
    [[25, 100, 30.0], [1, 7, 120.0 / 7], [200, 100, 120.0], [-1, 100, nil]].each do |current, max, width|
      previous = page.last_render
      state.update(current: current, max: max)
      area.queue_draw
      wait_for { !page.last_render.equal?(previous) }
      layers = shapes(page)
      expect(layers.last).to include(mode: 'stroke', line_width: 1, color: { r: 128, g: 128, b: 128, a: 1.0 })
      if width
        expect(layers[1][:w]).to be_within(0.00001).of(width)
        expect(layers[1][:color]).to eq(r: 204, g: 0, b: 0, a: 1.0)
      else
        expect(layers.length).to eq(2)
      end
    end
  end

  it 'retires draw contexts and preserves the previous frame on invalid drawing' do
    area = gtk::DrawingArea.new
    context = nil
    connection = area.signal_connect('draw') { |_widget, cr| context = cr; cr.rectangle(0, 0, 1, 1); cr.fill }
    _window, page = show(area)
    retained = shapes(page)
    expect { context.rectangle(0, 0, 1, 1) }.to raise_error(gtk::UnsupportedOperation)
    area.signal_handler_disconnect(connection)
    invalid = area.signal_connect('draw') { |_widget, cr| cr.rectangle(0, 0, Float::NAN, 1) }
    expect { area.queue_draw }.to raise_error(gtk::UnsupportedOperation)
    expect(shapes(page)).to eq(retained)
    area.signal_handler_disconnect(invalid)
    area.signal_connect('draw') { |_widget, cr| cr.arc(0, 0, 1) }
    expect { area.queue_draw }.to raise_error(gtk::UnsupportedOperation)
  end

  it 'bounds operation counts, dimensions, ownership and destroyed surfaces' do
    area = gtk::DrawingArea.new
    expect { area.set_size_request(0, 8) }.to raise_error(gtk::UnsupportedOperation)
    area.signal_connect('draw') { |_widget, cr| 513.times { cr.set_source_rgb(0, 0, 0) } }
    expect { area.queue_draw }.to raise_error(gtk::UnsupportedOperation)
    allow(Lich::Common::Script).to receive(:current).and_return(Struct.new(:name).new('foreign'))
    expect { area.queue_draw }.to raise_error(gtk::UnsupportedOperation)
    allow(Lich::Common::Script).to receive(:current).and_return(owner)
    area.destroy
    expect { area.queue_draw }.to raise_error(gtk::UnsupportedOperation)
  end

  it 'keeps live Frame and Expander caption facades distinct from content children' do
    frame, expander = gtk::Frame.new('<small>Enemy targets</small>'), gtk::Expander.new('<b>Fixture</b> (1)')
    [frame, expander].each { |widget| widget.label_widget.set_use_markup(true) }
    root = gtk::Box.new(:vertical)
    root.add(frame); root.add(expander)
    window, page = show(root)
    expect(frame.label).to eq('Enemy targets')
    expect(expander.label).to eq('Fixture (1)')
    expect(frame.children).to be_empty
    frame.label_widget.text = 'Players'
    expander.label_widget.text = 'Updated'
    wait_for { page.last_render.tree.each.any? { |node| node.props[:label] == 'Updated' } }
    expect(frame.label).to eq('Players')
    window.destroy
    expect(frame.label_widget.destroyed?).to be(true)
    expect(expander.label_widget.destroyed?).to be(true)
  end

  it 'retains reveal state through recursive show and preserves its child identity' do
    reveal = gtk::Revealer.new
    reveal.set_transition_type(:slide_down).set_transition_duration(250)
    child = gtk::Label.new('Pool content')
    reveal.add(child)
    expect { reveal.add(gtk::Label.new('Extra')) }.to raise_error(gtk::UnsupportedOperation)
    _window, page = show(reveal)
    expect(reveal.reveal_child?).to be(false)
    expect(reveal.visible?).to be(false)
    reveal.set_reveal_child(true)
    wait_for { page.last_render.tree.each.any? { |node| node.type == :text && node.props[:content] == 'Pool content' } }
    expect(reveal.visible?).to be(true)
    reveal.set_reveal_child(false)
    reveal.show_all
    expect(reveal.visible?).to be(false)
    expect(reveal.children).to eq([child])
    expect { reveal.set_reveal_child(1) }.to raise_error(gtk::UnsupportedOperation)
    expect { reveal.set_transition_duration(-1) }.to raise_error(gtk::UnsupportedOperation)
  end

  it 'delegates the Grid and FlowBox spellings and validates their measured bounds' do
    grid, flow = gtk::Grid.new, gtk::FlowBox.new
    grid.set_column_homogeneous(true)
    flow.set_selection_mode(:none)
    flow.set_min_children_per_line(1)
    expect(grid.send(:component_props)[:homogeneous]).to be(true)
    expect { grid.set_column_homogeneous('true') }.to raise_error(gtk::UnsupportedOperation)
    expect { flow.set_selection_mode(:single) }.to raise_error(gtk::UnsupportedOperation)
    expect { flow.set_min_children_per_line(2) }.to raise_error(gtk::UnsupportedOperation)
  end

  it 'routes bounded release callbacks to their owner and refuses hidden targets' do
    box = gtk::EventBox.new
    calls = []
    box.signal_connect('button-release-event') { |_widget, event| calls << [event.button, event.x, event.y] }
    _window, page = show(box)
    connection = Struct.new(:viewer_id, :messages).new('release', [])
    def connection.alive? = true
    def connection.send_text(text) = messages << JSON.parse(text)
    service.runtime.handle(connection, type: 'attach', page: service.registry.address_for(page))
    deliver = lambda do
      render = connection.messages.reverse.find { |message| message['type'] == 'render' }
      node = render['tree']['children'][0]
      service.runtime.handle(connection, type: 'event', page: service.registry.address_for(page), generation: render['generation'],
                             cid: node['cid'], event: 'pointer_release', payload: { x: 4, y: 5, button: 1, time: 0, state: 4 })
    end
    deliver.call
    wait_for { calls.length == 1 }
    expect(calls).to eq([[1, 4, 5]])
    box.hide
    wait_for { connection.messages.reverse.find { |message| message['type'] == 'render' }['tree']['children'][0]['props']['hidden'] }
    deliver.call
    expect(connection.messages.last['type']).to eq('refusal')
    expect(calls.size).to eq(1)
  end

  it 'renders resource redraws, reveal state and aligned EventBox content in Chrome', browser: true do
    skip 'explicit browser run only' unless ENV['NATIVE_BROWSER'] == '1'
    area, reveal, event_box = gtk::DrawingArea.new, gtk::Revealer.new, gtk::EventBox.new
    state = { current: 25, max: 100 }
    bar(area, state)
    reveal.add(gtk::Label.new('Revealed pool'))
    content = gtk::Label.new('Centered target')
    content.set_valign(:center)
    event_box.set_size_request(160, 60)
    event_box.add(content)
    redraw = gtk::Button.new('Update resources')
    redraw.signal_connect('clicked') { state[:current] = 75; area.queue_draw; reveal.set_reveal_child(true) }
    root = gtk::Box.new(:vertical)
    [area, reveal, event_box, redraw].each { |widget| root.add(widget) }
    _window, page = show(root)
    WebUIBrowser.check(service: service, page: page, scenario: 'priority17-drawing')
  end
end
