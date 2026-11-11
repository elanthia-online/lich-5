# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../support/webui_fresh_process'
require 'webui'
require_relative '../../../lib/common/script_scope/gtk/session'
require_relative '../../../lib/common/script_scope/gtk/widgets'
require_relative '../../../lib/common/script_scope/gtk/size_group'
require_relative '../../../lib/common/script_scope/gtk/scheduling'
require_relative '../../../lib/common/script_scope/gtk/style'
require_relative '../../../lib/common/script_scope/gtk/display_geometry'

# Shim callback, lifecycle and classification boundaries.
# Exit and LoadError paths run in a fresh process; the rest use a recording port.
RSpec.describe 'script compatibility widget boundaries' do
  include WebUIFreshProcess

  port_class = Class.new do
    attr_reader :sets, :bindings, :destroyed
    attr_accessor :fail_destroy

    def initialize
      @sets = []
      @bindings = {}
      @values = {}
      @destroyed = 0
    end

    def create(_type, _props) = Object.new
    def attach(*) = nil
    def detach(*) = nil
    def schema(type) = Lich::WebUI::Contract.schema(type)

    def bind(handle, event, callback)
      @bindings[[handle, event]] = callback
      "binding-#{@bindings.size}"
    end

    def set(handle, property, value)
      @sets << [property, value]
      @values[[handle, property]] = value
    end

    def seed(handle, property, value) = @values[[handle, property]] = value
    def get(handle, property) = @values[[handle, property]]

    def destroy(_handle)
      @destroyed += 1
      raise Lich::WebUI::Error, 'host teardown failed' if fail_destroy
    end
  end
  event_context = Struct.new(:viewer_id, :payload)

  let(:gtk) { Lich::Common::ScriptScope::Gtk }
  let(:owner) { Struct.new(:name, :thread_group).new('boundaries.lic', ThreadGroup.new) }
  let(:port) { port_class.new }
  let(:session) { gtk::Session.new(owner) }
  let(:logs) { [] }

  before do
    stub_const('Lich::Common::Script', Class.new { def self.current; end })
    allow(Lich::Common::Script).to receive(:current).and_return(owner)
    allow(Lich::WebUI).to receive(:adapter).and_return(port)
    allow(Lich::WebUI).to receive(:callback_queue).and_return(proc { |&work| work.call })
    allow(Lich).to receive(:log) { |message| logs << message }
    allow(gtk).to receive(:session) { session }
  end

  def run_fresh(body)
    prelude = <<~RUBY_CODE
      require 'webui'
      require 'timeout'
      require 'tmpdir'
      LOGS = Queue.new
      module Lich
        def self.log(message) = LOGS << message
        module Common
          class Script
            class << self
              attr_accessor :current
            end
          end
        end
      end
      def respond(*) = nil
      require 'common/script_scope/gtk/session'
      require 'common/script_scope/gtk/widgets'
      GTK = Lich::Common::ScriptScope::Gtk
      SERVICE = Lich::WebUI::Service.new(logger: ->(*) {})
      Lich::WebUI.define_singleton_method(:service) { SERVICE }
      SESSIONS = {}.compare_by_identity
      GTK.define_singleton_method(:session) do
        SESSIONS[Lich::Common::Script.current] ||= GTK::Session.new(Lich::Common::Script.current)
      end
      def new_owner(name) = Struct.new(:name, :thread_group).new(name, ThreadGroup.new)
      def stopped?(owner) = (SERVICE.registry.ensure_active!(owner) rescue :stopped) == :stopped
      def logs = Array.new(LOGS.size) { LOGS.pop }
    RUBY_CODE
    output, errors, status = run_ruby_with_deadline(prelude + body + "\nSERVICE.stop\nputs 'ready'\n")
    expect_child_within_deadline(status, output, errors, RSpec.current_example.full_description)
    [output, errors, status]
  end

  it 'routes a queued or timed exit to the owner-stop hook and contains other script errors' do
    output, errors, status = run_fresh(<<~RUBY_CODE)
      queued, timed, survivor = new_owner('queued.lic'), new_owner('timed.lic'), new_owner('survivor.lic')
      Lich::Common::Script.current = queued
      GTK.session.queue { exit 3 }
      Lich::Common::Script.current = timed
      GTK.session.schedule(GTK, :add, 0) { exit 4 }
      Lich::Common::Script.current = survivor
      done = Queue.new
      GTK.session.queue { raise LoadError, 'missing' }
      GTK.session.queue { raise NotImplementedError, 'todo' }
      GTK.session.queue { done << :ran }
      Timeout.timeout(3) { sleep 0.02 until stopped?(queued) && stopped?(timed) }
      abort 'later work did not run' unless done.pop(timeout: 3) == :ran
      abort 'a contained failure stopped its owner' if stopped?(survivor)
      failures = logs.grep(/operation=queue .*callback failed/)
      abort "failures not attributed: \#{failures.inspect}" unless failures.size == 2 &&
                                                                  failures.any? { |line| line.include?('error=LoadError') } &&
                                                                  failures.any? { |line| line.include?('error=NotImplementedError') }
    RUBY_CODE

    expect([errors, status.success?]).to eq(['', true])
    expect(output).to eq("ready\n")
  end

  it 'completes a refused presentation close despite a failing handler, honors a veto and stops an exiting owner' do
    output, errors, status = run_fresh(<<~RUBY_CODE)
      failing, vetoing, exiting = new_owner('failing.lic'), new_owner('vetoing.lic'), new_owner('exiting.lic')
      results = {}
      vetoed = Queue.new
      [[failing, -> { raise LoadError, 'missing' }], [vetoing, -> { vetoed << true; true }], [exiting, -> { exit 5 }]].each do |owner, handler|
        Lich::Common::Script.current = owner
        window = GTK::Window.new(owner.name)
        destroyed = Queue.new
        window.signal_connect('delete_event') { handler.call }
        window.signal_connect('destroy') { destroyed << true }
        window.show_all
        results[owner] = [window, destroyed]
      end
      window, destroyed = results.fetch(failing)
      abort 'failing close left the window live' unless destroyed.pop(timeout: 3) && window.destroyed?
      window, destroyed = results.fetch(exiting)
      abort 'exiting close left the window live' unless destroyed.pop(timeout: 3) && window.destroyed?
      Timeout.timeout(3) { sleep 0.02 until stopped?(exiting) }
      abort 'failing handler stopped its owner' if stopped?(failing)
      window, destroyed = results.fetch(vetoing)
      abort 'veto handler did not run' unless vetoed.pop(timeout: 3)
      drained = Queue.new
      SERVICE.runtime.dispatch(owner: vetoing) { drained << true }
      abort 'veto callback did not finish' unless drained.pop(timeout: 3)
      abort 'veto was not honored' if !destroyed.empty? || window.destroyed?
      abort 'signal failure not attributed' unless logs.any? { |line| line.include?('operation=signal') && line.include?('error=LoadError') }
    RUBY_CODE

    expect([errors, status.success?]).to eq(['', true])
    expect(output).to eq("ready\n")
  end

  it 'refuses native GTK entrypoints while unrelated helpers named like GTK packages load' do
    output, errors, status = run_fresh(<<~RUBY_CODE)
      require 'common/script_scope/gtk/require_boundary'
      boundary = GTK::RequireBoundary
      root = File.expand_path($LOAD_PATH.first).tr('\\\\', '/')
      refused = ['gtk3', 'gtk3/base', 'gi', './pango.rb', "\#{root}/glib2.rb", '/opt/gems/glib2/lib/glib2.so', 'C:/gems/lib/cairo.dll']
      allowed = ['helpers/gi', 'lib/pango', '/scripts/lib/cairo.rb', '/scripts/gi', 'C:/scripts/atk.rb', '/scripts/gtk.rb']
      wrong = refused.reject { |path| boundary.native_feature?(path) } + allowed.select { |path| boundary.native_feature?(path) }
      abort "misclassified: \#{wrong.inspect}" unless wrong.empty?
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, 'gi.rb'), "HELPER_LOADED = true\\n")
        require File.join(dir, 'gi.rb')
        abort 'absolute helper did not load' unless defined?(HELPER_LOADED)
      end
    RUBY_CODE

    expect([errors, status.success?]).to eq(['', true])
    expect(output).to eq("ready\n")
  end

  it 'contains non-StandardError cleanup failures so every window still closes' do
    first = gtk::Window.new('one')
    second = gtk::Window.new('two')
    closed = []
    first.signal_connect('destroy') { raise SecurityError, 'denied' }
    second.signal_connect('destroy') { closed << :second }

    expect { session.close }.not_to raise_error
    expect([first.destroyed?, second.destroyed?, closed]).to eq([true, true, [:second]])
    expect(logs.grep(/operation=destroy .*cleanup failed error=SecurityError/).size).to eq(1)
  end

  it 'keeps accumulated scroll requests within the contract range' do
    max = 2_147_483_647
    stub_const('Lich::Common::ScriptScope::Gtk::ScrollEvent', Class.new do
      def initialize(_payload); end
      def deltas = [100, -100]
      def replayed? = false
    end)
    frame = gtk::Frame.new
    frame.signal_connect('scroll_event') { false }
    handle = frame.materialize
    port.seed(handle, :scroll_request, { x: max - 10, y: -max + 5 })

    port.bindings.fetch([handle, :scroll]).call(event_context.new('viewer', {}))

    expect(port.sets.last).to eq([:scroll_request, { x: max, y: -max }])
    expect(logs.grep(/callback failed/)).to be_empty
  end

  it 'retires widget shadow state when port teardown fails, keeping the diagnostic' do
    window = gtk::Window.new('setup')
    child = gtk::Label.new('field')
    window.add(child)
    window.materialize
    destroyed = []
    window.signal_connect('destroy') { destroyed << :window }
    port.fail_destroy = true

    expect { window.destroy }.to raise_error(Lich::WebUI::Error, 'host teardown failed')
    expect([window.destroyed?, child.destroyed?, destroyed]).to eq([true, true, [:window]])
    session.close
    expect(window.destroy).to equal(window)
    expect(port.destroyed).to eq(1)
  end

  it 'keeps text= literal on a link label instead of writing new Markdown links' do
    label = gtk::Label.new
    label.set_markup('<a href="https://example.com/">site</a>')

    expect { label.text = '[prize](https://spoof.example/)' }.to raise_error(gtk::UnsupportedOperation, /operation=text=/)
    expect(label.text).to eq('[site](https://example.com/)')
    label.text = 'plain words (no link)'
    expect(label.text).to eq('plain words (no link)')
  end

  it 'bounds SizeGroup creation over the session lifetime' do
    keys = Array.new(gtk::SizeGroup::LIFETIME_LIMIT) { gtk::SizeGroup.new(:horizontal).key }

    expect(keys.uniq.size).to eq(512)
    expect(keys.last).to eq('sizegroup-512')
    expect { gtk::SizeGroup.new(:horizontal) }.to raise_error(gtk::UnsupportedOperation, /class=\S*SizeGroup operation=new/)
  end

  it 'converts SizeGroup and the GLib boundary implicitly without a refusal' do
    group = gtk::SizeGroup.new(:horizontal)
    glib = Lich::Common::ScriptScope::GLib

    [group, glib].each do |object|
      expect(object.respond_to?(:to_ary)).to be(false)
      expect(Array(object)).to eq([object])
      expect([object].flatten).to eq([object])
      expect([*object]).to eq([object])
    end
    expect { group.unsupported_native_call }.to raise_error(gtk::UnsupportedOperation, /operation=unsupported_native_call/)
    expect { glib.unsupported_native_call }.to raise_error(gtk::UnsupportedOperation, /operation=unsupported_native_call/)
  end

  it 'converts display objects and their classes implicitly without a refusal' do
    gdk = Lich::Common::ScriptScope::Gdk
    objects = [gdk::Screen.default, gdk::Display.default, gdk::Screen, gdk::Display]

    objects.each do |object|
      expect(object.respond_to?(:to_ary)).to be(false)
      expect(Array(object)).to eq([object])
      expect([object].flatten).to eq([object])
      expect { expect { puts object }.to output.to_stdout }.not_to raise_error
    end
    expect { gdk::Screen.default.unsupported_native_call }.to raise_error(gtk::UnsupportedOperation, /operation=unsupported_native_call/)
    expect { gdk::Display.unsupported_native_call }.to raise_error(gtk::UnsupportedOperation, /operation=unsupported_native_call/)
  end

  it 'ignores activation of a destroyed radio member without deselecting its group' do
    first = gtk::RadioButton.new('a')
    second = gtk::RadioButton.new(first, 'b')
    third = gtk::RadioButton.new(first, 'c')
    toggled = []
    [first, second, third].each { |button| button.signal_connect('toggled') { toggled << button } }
    second.destroy

    expect(second.set_active(true)).to equal(second)
    expect([first.active?, second.active?, third.active?]).to eq([true, false, false])
    expect(toggled).to be_empty
  end

  it 'appends a notebook page with a Label header before EventBox exists' do
    # EventBox first loads with the layout layer, so this must hold without it.
    hide_const('Lich::Common::ScriptScope::Gtk::EventBox')
    notebook = gtk::Notebook.new
    page = gtk::Label.new('page')
    header = gtk::Label.new('one')

    expect(notebook.append_page(page, header)).to eq(0)
    expect([notebook.n_pages, notebook.get_nth_page(0)]).to eq([1, page])
    expect { notebook.append_page(gtk::Label.new('p2'), gtk::Button.new('b')) }.to raise_error(gtk::UnsupportedOperation, /operation=append_page/)
    expect(notebook.n_pages).to eq(1)
  end

  it 'still takes an EventBox-wrapped Label header once EventBox exists' do
    stub_const('Lich::Common::ScriptScope::Gtk::EventBox', gtk::Box)
    notebook = gtk::Notebook.new
    wrapper = gtk::Box.new
    wrapper.add(gtk::Label.new('wrapped'))

    expect(notebook.append_page(gtk::Label.new('page'), wrapper)).to eq(0)
    expect(notebook.n_pages).to eq(1)
  end

  # Classes that a later layer defines (layout, style, header bar, image). hide_const
  # makes any layer behave as P12 and P13 do, where none of them exist.
  later_layer = %w[
    Table EventBox Overlay ScrolledWindow StateFlags CssProvider Color Image HeaderBar StyleContext
  ].map { |name| "Lich::Common::ScriptScope::Gtk::#{name}" } +
                %w[Screen Color RGBA EventMask WindowTypeHint].map { |name| "Lich::Common::ScriptScope::Gdk::#{name}" } +
                ['Lich::Common::ScriptScope::Pango::FontDescription']

  context 'without the classes a later layer defines' do
    before { later_layer.each { |name| hide_const(name) } }

    it 'valigns a widget inside a parent without raising NameError' do
      box = gtk::VBox.new
      child = gtk::Label.new('x')
      box.add(child)
      frame = gtk::Frame.new('f')
      framed = gtk::Label.new('y')
      frame.add(framed)

      expect { child.valign = :start }.not_to raise_error
      expect { framed.valign = :center }.not_to raise_error
      expect([child.send(:read, :vertical_align), framed.send(:read, :vertical_align)]).to eq(%i[start center])
    end

    it 'refuses a valign parent that is neither supported nor defined yet' do
      window = gtk::Window.new('w')
      child = gtk::Label.new('x')
      window.add(child)

      expect { child.valign = :start }.to raise_error(gtk::UnsupportedOperation, /operation=valign_parent/)
    end

    # [description, refused operation, call against fresh widgets]
    [
      ['Widget#override_font', 'override_font', ->(w) { w[:label].override_font(Object.new) }],
      ['Widget#style_context', 'style_context', ->(w) { w[:label].style_context }],
      ['Widget#override_color', 'override_color', ->(w) { w[:label].override_color(:normal, Object.new) }],
      ['Widget#override_background_color', 'override_background_color', ->(w) { w[:label].override_background_color(:normal, Object.new) }],
      ['Entry#modify_base', 'modify_base', ->(w) { w[:entry].modify_base(:normal, Object.new) }],
      ['Button#set_image', 'image=', ->(w) { w[:button].set_image(Object.new) }],
      ['Window#set_titlebar', 'set_titlebar', ->(w) { w[:window].set_titlebar(Object.new) }],
      ['Window#set_type_hint', 'set_type_hint', ->(w) { w[:window].set_type_hint(:utility) }],
      ['Widget#add_events', 'add_events', ->(w) { w[:label].add_events(:scroll_mask) }],
      ['Label#set_markup background span', 'set_markup', ->(w) { w[:label].set_markup('<span background="red">x</span>') }],
      ['Label#set_markup blue bold tip', 'set_markup', ->(w) { w[:label].set_markup('<span color="blue" weight="bold">x</span>') }],
      ['Label#set_markup foreground span', 'set_markup', ->(w) { w[:label].set_markup('<span foreground="#ff0000">x</span>') }],
      ['Label#set_markup font_desc span', 'set_markup', ->(w) { w[:label].set_markup('<i><span font_desc="Sans 10">x</span></i>') }],
      ['Session#screen_style_operation', 'screen_probe', ->(w) { w[:session].screen_style_operation(w[:label], :screen_probe, Object.new, Object.new) { nil } }]
    ].each do |description, operation, call|
      it "#{description} refuses instead of raising NameError" do
        widgets = { label: gtk::Label.new('x'), entry: gtk::Entry.new, button: gtk::Button.new('b'), window: gtk::Window.new('w'), session: session }

        expect { call.call(widgets) }.to raise_error(gtk::UnsupportedOperation, /operation=#{Regexp.escape(operation)}/)
      end
    end

    it 'checks each later-layer class on its own when only some are loaded' do
      session_ref = session
      screen_class = Class.new { define_method(:session) { session_ref } }
      stub_const('Lich::Common::ScriptScope::Gdk::Screen', screen_class)
      stub_const('Lich::Common::ScriptScope::Gtk::StateFlags::NORMAL', :normal)
      label = gtk::Label.new('x')

      expect { session.screen_style_operation(label, :screen_probe, screen_class.new, Object.new) { nil } }
        .to raise_error(gtk::UnsupportedOperation, /operation=screen_probe/)
      expect { label.override_color(:normal, Object.new) }.to raise_error(gtk::UnsupportedOperation, /operation=override_color/)
    end

    it 'still removes a titlebar with nil' do
      window = gtk::Window.new('w')

      expect(window.set_titlebar(nil)).to equal(window)
    end
  end
end
