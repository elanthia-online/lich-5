# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/common/script_scope'
require_relative '../../support/webui_browser'
require 'digest'
require 'json'
require 'timeout'

RSpec.describe 'Original tpick setup acceptance' do
  let(:scope) { Lich::Common::ScriptScope }
  let(:gtk) { scope.const_get(:Gtk, false) }
  let(:owner) { Struct.new(:name).new('tpick.lic') }
  let(:service) { Lich::WebUI::Service.new }

  before do
    scope.activate!
    stub_const('Lich::Common::Script', Class.new { def self.current; end })
    allow(Lich::Common::Script).to receive(:current).and_return(owner)
    allow(Lich::WebUI).to receive(:adapter) { |owner:, viewer: nil| Lich::WebUI::Adapter.new(owner: owner, service: service, viewer: viewer) }
    allow(Lich::WebUI).to receive(:callback_queue) { |owner:| proc { |&work| service.runtime.dispatch(owner: owner, &work) } }
    @diagnostics = []
    allow(Lich).to receive(:log) { |message| @diagnostics << message }
    @directory = Dir.mktmpdir('tpick-acceptance-')
    @saved_globals = [$tpick_stats_data, $tpick_session_data, $tpick_worn_containers, $tpick_vars, $tpick_commands_set]
  end

  after do
    Lich::Common::ScriptDeath.run(owner)
    service.stop
    FileUtils.remove_entry(@directory)
    $tpick_stats_data, $tpick_session_data, $tpick_worn_containers, $tpick_vars, $tpick_commands_set = @saved_globals
  end

  def drain
    3.times do
      barrier = Queue.new
      service.runtime.dispatch(owner: owner) { barrier << true }
      expect(barrier.pop(timeout: 5)).to be(true)
    end
    expect(@diagnostics.grep(/callback failed|refresh failed|cleanup failed|operation=queue.*error=/)).to be_empty
  end

  def page_for(widget)
    page = nil
    Timeout.timeout(5) do
      sleep 0.005 until (page = service.registry.pages_for(owner).find { |p| p.title == widget.title })&.last_render
    end
    page
  end

  def original(profession: 'Rogue', spells: true)
    record = JSON.parse(File.read(File.expand_path('../../fixtures/webui/tpick-titlebar.json', __dir__)))
    mod = Module.new
    mod.const_set(:Gtk, gtk)
    mod.const_set(:Gdk, scope.const_get(:Gdk, false))
    mod.const_set(:Char, Struct.new(:name).new('Fixture'))
    mod.const_set(:Stats, Struct.new(:prof).new(profession))
    mod.const_set(:Spell, Hash.new(Struct.new(:known?).new(spells)))
    mod.const_set(:UserVars, Struct.new(:tpick).new(nil))
    mod.const_set(:TpickMain, mod)
    %w[windows grids entries buttons menus non_settings_menus check_boxes labels spin_buttons adjustments
       all_textviews all_buffers scrolled_windows all_notebooks needed_values window_assets].each do |name|
      mod.instance_variable_set("@#{name}", {})
    end
    (record.fetch('blocks') + record.fetch('methods')).each do |item|
      expect(Digest::SHA256.hexdigest(item.fetch('source'))).to eq(item.fetch('sha256'))
      mod.module_eval(item.fetch('source'), 'tpick.lic', item.fetch('line'))
    end
    defaults = mod.instance_variable_get(:@defaults).dup
    mod.instance_variable_set(:@needed_values, defaults.dup)
    mod.instance_variable_set(:@load_data, defaults.dup)
    mod.instance_variable_set(:@all_load_data, { 'Fixture' => defaults.dup, 'Second' => defaults.merge('Vaalin' => 'second pick') })
    mod.instance_variable_set(:@all_characters, %w[Fixture Second])
    mod.instance_variable_set(:@save_file, File.join(@directory, 'settings.json'))
    mod.instance_variable_set(:@script_name, 'tpick')
    mod.instance_variable_set(:@script_version, '48')
    mod.instance_variable_set(:@current_session_picking, 0)
    mod.instance_variable_set(:@show_images, false)
    # Game-facing boundaries only: retain original GUI, data and persistence methods.
    allow(mod).to receive(:message)
    allow(mod).to receive(:running?).with('tpick').and_return(false)
    $tpick_worn_containers = { 'fixture sack' => '1' }
    $tpick_stats_data = Hash.new(0).merge('Loot Total' => {}, 'Opened/Broke For Each Pick' => {})
    $tpick_session_data = Hash.new(0).merge('Session Start Time' => Time.now, 'Loot Session' => {})
    $tpick_vars = {}
    mod
  end

  %w[Rogue Warrior Bard Wizard].each do |profession|
    it "constructs every original settings tab for #{profession} and preserves required cues" do
      tpick = original(profession: profession)
      tpick.create_settings_window
      window = tpick.instance_variable_get(:@windows).fetch('Settings')
      expect(page_for(window).last_render).not_to be_nil
      labels = tpick.instance_variable_get(:@labels)
      tpick.instance_variable_get(:@required_settings).each do |name|
        expect(labels.fetch(name).send(:component_props)[:foreground]).to eq(r: 255, g: 77, b: 77, a: 1.0)
      end
      expect(tpick.instance_variable_get(:@grids).key?('Repair Main')).to eq(profession == 'Rogue')
      expect(tpick.instance_variable_get(:@buttons).key?('Scan')).to eq(profession == 'Rogue')
      window.close
      drain
      expect(tpick.instance_variable_get(:@windows).values.compact).to be_empty
    end
  end

  %w[Monk Paladin].each do |profession|
    it "retains the source's missing Spells grid defect for spell-less #{profession}" do
      tpick = original(profession: profession, spells: false)
      expect { tpick.create_settings_window }.to raise_error(NoMethodError, /attach/)
      expect(tpick.instance_variable_get(:@grids)).not_to have_key('Spells Main')
    end
  end

  it 'runs original profile/default callbacks and saves values to an isolated settings file' do
    tpick = original
    tpick.create_settings_window
    controls = tpick.instance_variable_get(:@buttons)
    menus = tpick.instance_variable_get(:@non_settings_menus)
    entry = tpick.instance_variable_get(:@entries).fetch('Vaalin')
    menus.fetch('Profiles').set_active(1)
    controls.fetch('Load').send(:emit_handlers, :activate)
    expect(entry.text).to eq('second pick')
    controls.fetch('Defaults').send(:emit_handlers, :activate)
    expect(entry.text).to eq('')
    entry.text = 'a fixture lockpick'
    controls.fetch('Save').send(:emit_handlers, :activate)
    saved = JSON.parse(File.read(tpick.instance_variable_get(:@save_file)))
    expect(saved.dig('Fixture', 'Vaalin')).to eq('fixture lockpick')
    expect(tpick).not_to have_received(:message).with(/Save error/)
  end

  it 'constructs the original information window, updates messages/stats and closes cleanly' do
    tpick = original
    tpick.create_information_window
    drain
    window = tpick.instance_variable_get(:@windows).fetch('Information')
    expect(page_for(window).last_render).not_to be_nil
    $tpick_vars['Window Message'] = 'Fixture update'
    tpick.update_box_for_window
    expect(tpick.instance_variable_get(:@all_buffers).fetch('Messages').text).to include('Fixture update')
    tpick.instance_variable_get(:@buttons).fetch('Start').send(:emit_handlers, :activate)
    expect($tpick_commands_set).to be(true)
    window.close
    drain
    expect(tpick.instance_variable_get(:@windows)['Information']).to be_nil
    expect(JSON.parse(File.read(tpick.instance_variable_get(:@save_file))).fetch('Fixture')).to have_key('Picking Mode')
  end

  it 'retains the explicit optional image-window boundary' do
    tpick = original
    tpick.instance_variable_set(:@show_images, true)
    expect { tpick.create_information_window }.to raise_error(gtk::UnsupportedOperation, /operation=Justification source=tpick.lic:2771/)
  end

  it 'opens complete information for live browser acceptance', browser: true do
    skip 'explicit browser run only' unless ENV['NATIVE_BROWSER'] == '1'
    tpick = original
    tpick.create_information_window
    drain
    $tpick_vars['Window Message'] = 'Fixture update'
    tpick.update_box_for_window
    window = tpick.instance_variable_get(:@windows).fetch('Information')
    WebUIBrowser.check(service: service, page: page_for(window), scenario: 'shim-tpick-information')
    drain
    expect($tpick_commands_set).to be(true)
    expect(window).to be_destroyed
    expect(JSON.parse(File.read(tpick.instance_variable_get(:@save_file))).fetch('Fixture')).to have_key('Picking Mode')
  end

  it 'opens complete settings for live browser acceptance', browser: true do
    skip 'explicit browser run only' unless ENV['NATIVE_BROWSER'] == '1'
    tpick = original
    tpick.create_settings_window
    window = tpick.instance_variable_get(:@windows).fetch('Settings')
    page = page_for(window)
    entry = tpick.instance_variable_get(:@entries).fetch('Vaalin')
    node = entry.session.port.instance_variable_get(:@nodes).fetch(entry.materialize)
    WebUIBrowser.check(service: service, page: page, scenario: 'shim-tpick-settings', controls: { vaalin: node.cid })
    drain
    saved = JSON.parse(File.read(tpick.instance_variable_get(:@save_file)))
    expect(saved.dig('Fixture', 'Vaalin')).to eq('WebKit acceptance pick')
    expect(window).to be_destroyed
  end
end
