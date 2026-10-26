# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/common/script_scope'
require_relative '../../support/webui_browser'
require 'json'
require 'digest'
require 'timeout'

RSpec.describe 'refreshed original script setup acceptance' do
  let(:scope) { Lich::Common::ScriptScope }
  let(:gtk) { scope::Gtk }
  let(:owner) { Struct.new(:name).new('source-refresh.lic') }
  let(:service) { Lich::WebUI::Service.new }
  let(:fixture) { JSON.parse(File.read(File.expand_path('../../fixtures/webui/source-refresh.json', __dir__))) }

  before do
    scope.activate!
    stub_const('Lich::Common::Script', Class.new { def self.current; end })
    allow(Lich::Common::Script).to receive(:current).and_return(owner)
    allow(Lich::WebUI).to receive(:adapter) { |owner:, viewer: nil| Lich::WebUI::Adapter.new(owner: owner, service: service, viewer: viewer) }
    allow(Lich::WebUI).to receive(:callback_queue) { |owner:| proc { |&work| service.runtime.dispatch(owner: owner, &work) } }
    @logs, @saved, @messages, @exit_hooks = [], [], [], []
    allow(Lich).to receive(:log) { |message| @logs << message }
  end

  after do
    Lich::Common::ScriptDeath.run(owner)
    service.stop
    @runner&.join(0.1)
    @runner&.kill if @runner&.alive?
  end

  def evaluate(target, name, block)
    entry = fixture.fetch('scripts').fetch(name).fetch('blocks').fetch(block)
    expect(Digest::SHA256.hexdigest(entry.fetch('source'))).to eq(entry.fetch('sha256'))
    target.module_eval(entry.fetch('source'), "#{name}.lic", entry.fetch('line'))
  end

  def drain
    2.times do
      done = Queue.new
      service.runtime.dispatch(owner: owner) { done << true }
      expect(done.pop(timeout: 3)).to be(true)
    end
    expect(@logs.grep(/callback failed/)).to be_empty, @logs.join("\n")
    expect(@messages.grep(/setup UI error/)).to be_empty, @messages.join("\n")
  end

  def launch(target, method)
    messages = @messages
    target.define_singleton_method(:echo) { |message| messages << message }
    target.define_singleton_method(:wait_while) { |&condition| sleep 0.005 while condition.call }
    @runner = Thread.new { target.public_send(method) }
    Timeout.timeout(4) do
      loop do
        drain
        @page = service.registry.pages_for(owner).first
        break if @page&.last_render
        @runner.value unless @runner.alive?
        sleep 0.005
      end
    end
    @window = gtk.session.instance_variable_get(:@windows).find { |window| !window.destroyed? }
  end

  def abyssx(saved = {})
    sandbox = Module.new
    sandbox.const_set(:Gtk, gtk)
    sandbox.const_set(:Vars, double(lootsack: 'default sack'))
    mod = sandbox.const_set(:AbyssX, Module.new)
    # Lexical Gtk/Vars references resolve through the enclosing source module.
    mod.const_set(:Gtk, gtk)
    mod.const_set(:Vars, sandbox::Vars)
    mod.const_set(:AbyssX, mod)
    evaluate(mod, 'abyssx', 'constants')
    evaluate(mod, 'abyssx', 'setup')
    captures = @saved
    mod.define_singleton_method(:load_settings) { saved.dup }
    mod.define_singleton_method(:save_settings) { |data| captures << data.dup }
    @gui = mod::SetupGUI
    launch(@gui, :run)
  end

  def compass(saved = {})
    mod = Module.new
    mod.const_set(:Gtk, gtk)
    mod.const_set(:Char, double(name: 'Fixture'))
    store = { 'Fixture' => saved.dup }
    captures = @saved
    store.define_singleton_method(:load) {}
    store.define_singleton_method(:save) { captures << JSON.parse(JSON.generate(self)) }
    mod.const_set(:Settings, store)
    evaluate(mod, 'compass_and_wings', 'constants')
    evaluate(mod, 'compass_and_wings', 'settings_and_setup')
    mod.send(:module_function, *mod.instance_methods(false))
    hooks = @exit_hooks
    mod.define_singleton_method(:before_dying) { |&block| hooks << block }
    mod.define_singleton_method(:undo_before_dying) { hooks.pop }
    launch(mod, :launch_settings_ui)
    Timeout.timeout(3) { sleep 0.005 until @exit_hooks.any? }
  end

  def descendants(widget = @window)
    [widget] + widget.children.flat_map { |child| descendants(child) }
  end

  def button(label)
    descendants.find { |widget| widget.is_a?(gtk::Button) && widget.label == label }
  end

  def in_viewer(&block)
    unless @viewer
      connection = double('viewer', viewer_id: 'fixture', alive?: true, send_text: nil)
      address = service.registry.address_for(@page)
      service.runtime.handle(connection, type: 'attach', page: address)
      @viewer = service.runtime.instance_variable_get(:@viewers).fetch(connection_id: 'fixture', address: address).viewer_id
    end
    gtk.session.send(:with_callback_context, @viewer, @window, &block)
  end

  def set(widget, property, value)
    in_viewer { widget.public_send("#{property}=", value) }
  end

  def activate(label)
    in_viewer { gtk.queue { button(label).send(:emit_handlers, :activate) } }
    drain
  end

  def finish
    expect(@runner.join(3)).to equal(@runner)
    @runner.value
    drain
    expect(@window).to be_destroyed
    expect(service.registry.pages_for(owner)).to be_empty
  end

  def controls
    descendants.filter_map do |widget|
      handle = widget.instance_variable_get(:@handle)
      [widget, widget.session.port.send(:node!, handle).cid] if handle
    end.to_h
  end

  it 'confirms newer Bigshot still uses the identical retained Setup bytes' do
    entry = fixture.fetch('scripts').fetch('bigshot')
    source = File.binread(File.expand_path("../../fixtures/webui/#{entry.fetch('fixture')}", __dir__))
    expect(Digest::SHA256.hexdigest(source.lines[1...-1].join.lstrip.chomp)).to eq(entry.fetch('setup_sha256'))
    expect(entry.fetch('revision')).to eq('c4a96840ea2a29a445fd797c7baec0b012b0dd12')
  end

  it 'runs abyssx defaults, exclusive radio selection, source coercion and Save unchanged' do
    abyssx
    expect(@gui.instance_variable_get(:@entry_lootsack).text).to eq('default sack')
    set(@gui.instance_variable_get(:@entry_lootsack), :text, ' pack ')
    set(@gui.instance_variable_get(:@entry_spell), :text, ' 901junk ')
    set(@gui.instance_variable_get(:@radio_spell), :active, true)
    expect(@gui.instance_variable_get(:@radio_bigshot).active?).to be(false)
    activate('Save & Close')
    finish
    expect(@saved).to eq([{ 'lootsack' => 'pack', 'attack_mode' => 'spell', 'spell_number' => 901,
                           'min_mana' => 30, 'mind_pause' => 100, 'mind_resume' => 75 }])
  end

  %i[cancel close].each do |action|
    it "loads saved abyssx settings and exits without saving on #{action}" do
      abyssx('lootsack' => 'kept', 'attack_mode' => 'spell', 'spell_number' => 702)
      expect(@gui.instance_variable_get(:@radio_spell).active?).to be(true)
      set(@gui.instance_variable_get(:@entry_lootsack), :text, 'discard')
      if action == :cancel
        activate('Cancel')
      else
        gtk.queue { @window.destroy }
      end
      finish
      expect(@saved).to be_empty
    end
  end

  it 'keeps compass validation failures open, then saves through the original normalization helpers' do
    compass('energywings_use_prep_reaction' => false)
    entries = descendants.grep(gtk::Entry)
    expect(entries.length).to eq(20)
    expect(descendants.grep(gtk::CheckButton).find { |item| item.label.start_with?('React to') }.active?).to be(false)
    expect(@saved.length).to eq(1) # Source load_settings persists normalized initial settings.
    set(entries[1], :text, 'tattoo;look')
    activate('Save')
    expect(@runner).to be_alive
    expect(@saved.length).to eq(1)
    expect(descendants.grep(gtk::Label).map(&:text)).to include('Enter a tattoo name or one RUB command; no semicolons or extra lines.')
    set(entries[1], :text, 'my tattoo')
    set(entries[0], :text, '0')
    set(entries[4], :text, '1')
    set(entries[7], :text, 'bigshot; hunt3, bigshot')
    set(entries[8], :text, " incant 901\ncast  ")
    activate('Save')
    finish
    expect(@saved.length).to eq(2)
    expect(@saved.last.fetch('Fixture')).to include('energywings_mystic_tattoo_command'    => 'rub my tattoo',
                                                    'energywings_compass_t3_min_targets'   => 1,
                                                    'energywings_multi_target_threshold'   => 3,
                                                    'energywings_additional_pause_scripts' => 'bigshot, hunt3, bigshot',
                                                    'energywings_precast_shadow_barb'      => "incant 901\ncast")
    expect(@exit_hooks).to be_empty
  end

  it 'preserves compass initial normalization but does not save canceled edits' do
    compass
    before = @saved.dup
    set(descendants.grep(gtk::Entry)[1], :text, 'discarded')
    gtk.queue do
      @window.send(:emit_handlers, :close)
      @window.destroy
    end
    finish
    expect(@saved).to eq(before)
  end

  it 'runs the original compass before_dying cleanup without saving edits' do
    compass
    @exit_hooks.fetch(0).call
    drain
    expect(@window).to be_destroyed
    expect(service.registry.pages_for(owner)).to be_empty
    expect(@saved.length).to eq(1)
  end

  it 'validates abyssx setup and saving in the browser', browser: true do
    skip 'explicit browser run only' unless ENV['NATIVE_BROWSER'] == '1'
    abyssx
    fields = %i[entry_lootsack entry_spell entry_mana entry_mind_pause entry_mind_resume].to_h do |name|
      [name, controls.fetch(@gui.instance_variable_get("@#{name}"))]
    end
    WebUIBrowser.check(service: service, page: @page, scenario: 'shim-abyssx', controls: fields)
    finish
    expect(@saved.last).to include('lootsack' => 'browser sack', 'attack_mode' => 'spell', 'spell_number' => 901)
  end

  it 'validates compass scrolling, error feedback and saving in the browser', browser: true do
    skip 'explicit browser run only' unless ENV['NATIVE_BROWSER'] == '1'
    compass
    entries = descendants.grep(gtk::Entry)
    WebUIBrowser.check(service: service, page: @page, scenario: 'shim-compass', controls: { tattoo: controls.fetch(entries[1]) })
    finish
    expect(@saved.length).to eq(2)
    expect(@saved.last.fetch('Fixture')).to include('energywings_mystic_tattoo_command' => 'rub my tattoo')
  end
end
