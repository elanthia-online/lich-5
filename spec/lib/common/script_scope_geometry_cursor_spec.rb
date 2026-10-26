# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/common/script_scope'
require 'json'
require 'digest'
require 'timeout'
require_relative '../../support/webui_browser'

RSpec.describe 'bounded display geometry and cursor compatibility' do
  let(:scope) { Lich::Common::ScriptScope }
  let(:gtk) { scope.const_get(:Gtk, false) }
  let(:gdk) { scope.const_get(:Gdk, false) }
  let(:owner) { Struct.new(:name).new('geometry.lic') }
  let(:service) { Lich::WebUI::Service.new }

  before do
    scope.activate!
    stub_const('Lich::Common::Script', Class.new { def self.current; end })
    allow(Lich::Common::Script).to receive(:current).and_return(owner)
    allow(Lich::WebUI).to receive(:adapter) { |owner:, viewer: nil| Lich::WebUI::Adapter.new(owner: owner, service: service, viewer: viewer) }
    allow(Lich::WebUI).to receive(:callback_queue) { |owner:| proc { |&work| service.runtime.dispatch(owner: owner, &work) } }
    allow(service).to receive(:monitor_geometry).and_return(x: -1280, y: -100, width: 1280, height: 800, source: 'native', fallback: false)
    @logs = []
    allow(Lich).to receive(:log) { |message| @logs << message }
  end

  after do
    Lich::Common::ScriptDeath.run(owner)
    Lich::Common::ScriptDeath.run(@other) if @other
    service.stop
  end

  def source_block(name, block, source)
    fixture = JSON.parse(File.read(File.expand_path('../../fixtures/webui/geometry-cursors.json', __dir__)))
    entry = fixture.fetch('scripts').fetch(name).fetch('blocks').fetch(block)
    expect(Digest::SHA256.hexdigest(entry.fetch('source'))).to eq(entry.fetch('sha256'))
    source.module_eval(entry.fetch('source'), "#{name}.lic", entry.fetch('line'))
  end

  it 'runs gemstonev geometry and cursor calls and highlight-manager guarded helper unchanged' do
    source = Module.new
    source.const_set(:Gdk, gdk)
    source.const_set(:Gtk, gtk)
    source_block('gemstonev', 'geometry', source)
    expect(source.instance_variable_get(:@screen_width)).to eq(1280)
    expect(source.instance_variable_get(:@screen_height)).to eq(800)
    source_block('gemstonev', 'cursor_names', source)
    source_block('gemstonev', 'set_cursor', source)
    widget = gtk::Window.new('Cursor modes')
    %i[default execute ability].zip(%w[pointer cell copy]).each do |key, expected|
      source.set_cursor(widget, source.instance_variable_get("@#{key}_cursor"))
      expect(widget.send(:component_props)[:cursor_hint]).to eq(expected)
    end
    source.extend(source)
    source_block('highlight-manager', 'cursor_helpers', source)
    text = gtk::TextView.new
    source.set_clickable_text_view_cursor(text)
    expect(text.send(:component_props)[:cursor_hint]).to eq('pointer')
  end

  it 'supports repeated display chains, signed coordinates and explicit unavailable/selection fallback' do
    screen = gdk::Display.default.default_screen
    token = gdk::Display.default.default_screen.get_monitor_at_point(-100, 20)
    40.times { expect(screen.get_monitor_at_point(-100, 20)).to eq(token) }
    expect(screen.get_monitor_at_point(-99, 20)).not_to eq(token)
    expect(screen.get_monitor_geometry(token).x).to eq(-1280)
    expect(screen.get_monitor_geometry(token).y).to eq(-100)
    allow(service).to receive(:monitor_geometry).and_return(source: 'unavailable', fallback: true)
    2.times { expect(screen.get_monitor_geometry(token).width).to eq(1024) }
    expect(@logs.grep(/nominal 1024x768/).length).to eq(1)
    expect { screen.get_monitor_at_point(Float::NAN, 0) }.to raise_error(gtk::UnsupportedOperation)
    expect { screen.get_monitor_geometry(99) }.to raise_error(gtk::UnsupportedOperation)
  end

  it 'preserves handles and removes cursor hints, with unknown names falling back once' do
    widget = gtk::Button.new('Input')
    handle = widget.materialize
    widget.window.cursor = gdk::Cursor.new(:hand2)
    expect(widget.session.port.get(handle, :cursor_hint)).to eq('pointer')
    widget.window.set_cursor(nil)
    expect(widget.session.port.get(handle, :cursor_hint)).to be_nil
    expect(widget.send(:component_props)).not_to have_key(:cursor_hint)
    expect(widget.materialize).to equal(handle)
    2.times { widget.window.cursor = gdk::Cursor.new('unsupported-theme-name') }
    expect(widget.session.port.get(handle, :cursor_hint)).to eq('default')
    expect(@logs.grep(/unsupported named cursor/).length).to eq(1)
    expect { gdk::Cursor.new(Object.new) }.to raise_error(gtk::UnsupportedOperation)
    expect { widget.window.pointer }.to raise_error(gtk::UnsupportedOperation)
    device = gdk::Display.default.default_seat.pointer
    expect(device).to equal(gdk::Display.default.default_seat.pointer)
    expect { widget.window.get_device_position(device) }.to raise_error(gtk::UnsupportedOperation)
  end

  it 'supplies measured screen dimensions and requested window size before publication' do
    window = gtk::Window.new('Planner')
    window.resize(600, 400)
    expect(window.size).to eq([600, 400])
    expect(window.screen.width).to eq(1280)
    expect(window.screen.height).to eq(800)
    expect(window.screen).to equal(window.screen)
    expect(service.registry.pages_for(owner)).to be_empty
    allow(service).to receive(:monitor_geometry).and_return(source: 'unavailable', fallback: true)
    expect([window.screen.width, window.screen.height]).to eq([1024, 768])
    expect(@logs.grep(/nominal 1024x768/).length).to eq(1)
    screen = window.screen
    @other = Struct.new(:name).new('other.lic')
    allow(Lich::Common::Script).to receive(:current).and_return(@other)
    expect { window.screen }.to raise_error(gtk::UnsupportedOperation)
    expect { screen.width }.to raise_error(gtk::UnsupportedOperation)
    allow(Lich::Common::Script).to receive(:current).and_return(owner)
    window.destroy
    expect { window.screen }.to raise_error(gtk::UnsupportedOperation)
  end

  it 'refuses cross-owner and destroyed cursor/window/display use' do
    cursor = gdk::Cursor.new('copy')
    display = gdk::Display.default
    window = gtk::Window.new
    facade = window.window
    @other = Struct.new(:name).new('other.lic')
    allow(Lich::Common::Script).to receive(:current).and_return(@other)
    expect { gtk::Button.new.window.cursor = cursor }.to raise_error(gtk::UnsupportedOperation)
    expect { display.primary_monitor }.to raise_error(gtk::UnsupportedOperation)
    allow(Lich::Common::Script).to receive(:current).and_return(owner)
    window.destroy
    expect { facade.cursor = cursor }.to raise_error(gtk::UnsupportedOperation)
    Lich::Common::ScriptDeath.run(owner)
    expect { display.default_screen }.to raise_error(gtk::UnsupportedOperation)
  end

  it 'renders inherited cursor modes and measures the submitting viewer in the browser', browser: true do
    skip 'explicit browser run only' unless ENV['NATIVE_BROWSER'] == '1'
    allow(service).to receive(:monitor_geometry).and_call_original
    window = gtk::Window.new('Geometry and cursor acceptance')
    box = gtk::VBox.new
    status = gtk::Label.new('Choose a cursor mode')
    box.add(status)
    %w[pointer cell copy].each do |name|
      button = gtk::Button.new(name.capitalize)
      button.signal_connect('clicked') do
        window.window.cursor = gdk::Cursor.new(name)
        status.text = "Cursor: #{name}"
      end
      box.add(button)
    end
    reset = gtk::Button.new('Reset cursor')
    reset.signal_connect('clicked') { window.window.cursor = nil; status.text = 'Cursor: inherited' }
    box.add(reset)
    measurement = nil
    measure = gtk::Button.new('Measure screen')
    measure.signal_connect('clicked') do
      measurement = gtk.session.port.monitor_geometry
      status.text = "Screen: #{measurement[:width]} x #{measurement[:height]} (#{measurement[:source]})"
    end
    box.add(measure)
    finish = gtk::Button.new('Finish')
    finish.signal_connect('clicked') { window.destroy }
    box.add(finish)
    window.add(box)
    window.set_default_size(400, 300)
    window.show_all
    page = nil
    Timeout.timeout(4) { sleep 0.005 until (page = service.registry.pages_for(owner).first)&.last_render }
    WebUIBrowser.check(service: service, page: page, scenario: 'shim-geometry-cursors')
    expect(measurement).to include(source: a_string_matching(/native|browser/), width: be > 0, height: be > 0)
    expect(window).to be_destroyed
    expect(@logs.grep(/callback failed|refresh failed/)).to be_empty
  end
end
