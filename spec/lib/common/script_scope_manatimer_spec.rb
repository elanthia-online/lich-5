# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/common/script_scope'
require_relative '../../support/webui_browser'
require 'json'
require 'digest'
require 'timeout'

RSpec.describe 'manatimer progress and overlay acceptance' do
  let(:scope) { Lich::Common::ScriptScope }
  let(:gtk) { scope.const_get(:Gtk, false) }
  let(:gdk) { scope.const_get(:Gdk, false) }
  let(:owner) { Struct.new(:name).new('manatimer.lic') }
  let(:service) { Lich::WebUI::Service.new }
  let(:bar) { gtk::ProgressBar.new }
  let(:overlay) { gtk::Overlay.new }
  let(:window) { gtk::Window.new('Overlay acceptance') }
  let(:label) { gtk::Label.new('00:30') }
  let(:record) { JSON.parse(File.read(File.expand_path('../../fixtures/webui/manatimer.json', __dir__))) }

  before do
    scope.activate!
    stub_const('Lich::Common::Script', Class.new { def self.current; end })
    allow(Lich::Common::Script).to receive(:current).and_return(owner)
    allow(Lich::WebUI).to receive(:adapter) { |owner:, viewer: nil| Lich::WebUI::Adapter.new(owner: owner, service: service, viewer: viewer) }
    allow(Lich::WebUI).to receive(:callback_queue) { |owner:| proc { |&work| service.runtime.dispatch(owner: owner, &work) } }
    @diagnostics = []
    allow(Lich).to receive(:log) { |message| @diagnostics << message }
  end

  after do
    Lich::Common::ScriptDeath.run(owner)
    Lich::Common::ScriptDeath.run(@other_owner) if @other_owner
    service.stop
  end

  def drain(check: true)
    2.times do
      barrier = Queue.new
      service.runtime.dispatch(owner: owner) { barrier << true }
      expect(barrier.pop(timeout: 3)).to be(true)
    end
    expect(@diagnostics.grep(/callback failed|refresh failed|operation=queue.*error=/)).to be_empty if check
  end

  def source_binding
    @source_binding ||= begin
      @source = Module.new
      @source.const_set(:Gtk, gtk)
      @source.const_set(:Gdk, gdk)
      @source.const_set(:Char, Struct.new(:name).new('Fixture'))
      @settings = { 'window_width' => 240, 'window_height' => 48, 'window_position' => [20, 20] }
      @source.const_set(:CharSettings, @settings)
      @source.define_singleton_method(:before_dying) { |&block| @cleanup = block }
      @source.define_singleton_method(:wait_until) do |&block|
        Timeout.timeout(3) { sleep 0.005 until block.call }
      end
      @source.module_eval('binding', 'manatimer.lic', 1)
    end
  end

  def original(name)
    block = record.fetch('blocks').fetch(name)
    expect(Digest::SHA256.hexdigest(block.fetch('source'))).to eq(block.fetch('sha256'))
    eval(block.fetch('source'), source_binding, 'manatimer.lic', block.fetch('line'))
  end

  def partial_controls
    original('defaults')
    original('locals')
    gtk.queue do
      original('controls')
      original('providers')
    end
    drain
    source_binding.local_variable_get(:window)
  end

  def page_for(widget)
    page = nil
    Timeout.timeout(4) do
      sleep 0.005 until (page = service.registry.pages_for(owner).find { |p| p.title == widget.title })&.last_render
    end
    page
  end

  it 'retains authored text while hidden and restores percentage text without replacing the handle' do
    handle = bar.materialize
    expect(bar.show_text?).to be false
    bar.text = 'Authored'
    expect(bar.text).to eq('Authored')
    expect(bar.session.port.get(handle, :label)).to be_nil
    bar.show_text = true
    expect(bar.session.port.get(handle, :label)).to eq('Authored')
    bar.fraction = 0.375
    expect(bar.fraction).to eq(0.375)
    bar.text = nil
    expect(bar.session.port.get(handle, :label)).to eq('38%')
    bar.set_fraction(0.5)
    expect(bar.session.port.get(handle, :label)).to eq('50%')
    bar.show_text = false
    expect(bar.session.port.get(handle, :label)).to be_nil
    expect(bar.materialize).to equal(handle)
    expect(bar.fraction).to eq(0.5)
    expect { bar.show_text = nil }.to raise_error(gtk::UnsupportedOperation)
    expect { bar.text = 'x' * 513 }.to raise_error(gtk::UnsupportedOperation)
    expect(bar.text).to be_nil
  end

  it 'preserves bounded fraction handling through the property spelling' do
    bar.show_text = true
    bar.fraction = Float::INFINITY
    expect(bar.fraction).to eq(1.0)
    bar.fraction = Float::NAN
    expect(bar.fraction).to eq(1.0)
    bar.fraction = -2
    expect(bar.fraction).to eq(0.0)
    expect { bar.fraction = 'bad' }.to raise_error(gtk::UnsupportedOperation)
  end

  it 'applies and toggles hit testing on previously materialized children, and clears it on reparenting' do
    overlay.add(bar)
    handle = label.materialize
    label.valign = :center
    overlay.add_overlay(label)
    overlay.set_overlay_pass_through(label, true)
    overlay.materialize
    nodes = overlay.session.port.instance_variable_get(:@nodes)
    expect(nodes.fetch(handle).placement[:pass_through]).to be true
    overlay.set_overlay_pass_through(label, false)
    expect(nodes.fetch(handle).placement[:pass_through]).to be false
    overlay.set_overlay_pass_through(label, true)
    sibling = gtk::Label.new('Another layer')
    overlay.add_overlay(sibling)
    overlay.reorder_child(label, -1)
    expect(nodes.fetch(handle).placement[:pass_through]).to be true
    overlay.remove(label)
    expect(nodes.fetch(handle).placement).not_to have_key(:pass_through)
    expect { overlay.get_overlay_pass_through(label) }.to raise_error(gtk::UnsupportedOperation)
    second = gtk::Overlay.new
    second.add_overlay(label)
    second.materialize
    expect(second.get_overlay_pass_through(label)).to be false
    expect(label.materialize).to equal(handle)
    label.destroy
    expect(second.instance_variable_get(:@overlays)).to be_empty
  end

  it 'refuses nonlayers, foreign owners, invalid flags and retired layers' do
    overlay.add(bar)
    expect { overlay.set_overlay_pass_through(bar, true) }.to raise_error(gtk::UnsupportedOperation)
    expect { overlay.add_overlay(bar) }.to raise_error(gtk::UnsupportedOperation)
    overlay.add_overlay(label)
    expect { overlay.set_overlay_pass_through(label, 1) }.to raise_error(gtk::UnsupportedOperation)
    expect(overlay.get_overlay_pass_through(label)).to be false
    @other_owner = Struct.new(:name).new('other.lic')
    allow(Lich::Common::Script).to receive(:current).and_return(@other_owner)
    other = gtk::Label.new('Other')
    allow(Lich::Common::Script).to receive(:current).and_return(owner)
    expect { overlay.add_overlay(other) }.to raise_error(gtk::UnsupportedOperation)
    overlay.destroy
    expect(overlay.instance_variable_get(:@overlays)).to be_empty
    expect { overlay.set_overlay_pass_through(label, true) }.to raise_error(gtk::UnsupportedOperation)
    expect { overlay.add_overlay(gtk::Label.new('Late')) }.to raise_error(gtk::UnsupportedOperation)
  end

  it 'retains decoration requests alongside existing presentation properties' do
    expect(window.decorated?).to be true
    window.set_keep_above(true)
    window.decorated = false
    handle = window.materialize
    expect(window.session.port.get(handle, :presentation)).to include(always_on_top: true, borderless: true)
    window.decorated = true
    expect(window.decorated?).to be true
    expect(window.session.port.get(handle, :presentation)).to include(always_on_top: true, borderless: false)
    expect { window.decorated = nil }.to raise_error(gtk::UnsupportedOperation)
  end

  it 'replays original controls, providers, countdown and cleanup without monitor or game code' do
    widget = partial_controls
    source_binding.local_variable_set(:ticks, 60)
    original('tick')
    drain
    progress = source_binding.local_variable_get(:bar)
    expect(progress.fraction).to eq(0.5)
    expect(source_binding.local_variable_get(:label).text).to eq('01:00')
    expect(progress.show_text?).to be false
    expect(progress.send(:component_props)).not_to have_key(:fill_color)
    original('cleanup')
    @source.instance_variable_get(:@cleanup).call
    drain
    expect(widget).to be_destroyed
    expect(@settings['window_decorated']).to be true
    expect(@settings['window_position']).to eq([0, 0])
    expect(@diagnostics.grep(/operation=css_decoration/).size).to eq(1)
  end

  it 'completes unchanged setup through measured monitor geometry and updates progress' do
    allow(service).to receive(:monitor_geometry).and_return(x: -1280, y: 0, width: 1280, height: 800, source: 'native', fallback: false)
    original('defaults')
    original('locals')
    original('setup')
    drain
    expect(source_binding.local_variable_get(:done)).to be true
    expect(service).to have_received(:monitor_geometry).with(owner: owner, viewer: nil, target: :point, point: [20, 20])
    progress = source_binding.local_variable_get(:bar)
    progress.fraction = 0.5
    expect(progress.fraction).to eq(0.5)
  end

  it 'exercises the source controls and right-click callback in the browser', browser: true do
    skip 'explicit browser run only' unless ENV['NATIVE_BROWSER'] == '1'
    original('defaults')
    original('locals')
    original('setup')
    drain
    expect(source_binding.local_variable_get(:done)).to be true
    widget = source_binding.local_variable_get(:window)
    progress = source_binding.local_variable_get(:bar)
    layer = source_binding.local_variable_get(:label)
    layers = source_binding.local_variable_get(:overlay)
    # Harness controls drive the original update block; no pulse catcher/game loop.
    buttons = gtk::HBox.new
    tick = gtk::Button.new('Next tick')
    tick.signal_connect('clicked') do
      source_binding.local_variable_set(:ticks, 60)
      original('tick')
    end
    toggle = gtk::Button.new('Toggle pass-through')
    toggle.signal_connect('clicked') { layers.set_overlay_pass_through(layer, !layers.get_overlay_pass_through(layer)) }
    close = gtk::Button.new('Finish')
    close.signal_connect('clicked') { widget.destroy }
    [tick, toggle, close].each { |button| buttons.add(button) }
    widget.add(buttons)
    original('cleanup')
    page = page_for(widget)
    WebUIBrowser.check(service: service, page: page, scenario: 'shim-manatimer')
    drain
    expect(progress.fraction).to eq(0.5)
    expect(widget.decorated?).to be false
    expect(widget).to be_destroyed
  end
end
