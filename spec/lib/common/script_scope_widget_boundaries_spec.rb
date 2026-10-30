# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui'
require 'open3'
require 'rbconfig'
require_relative '../../../lib/common/script_scope/gtk/session'
require_relative '../../../lib/common/script_scope/gtk/widgets'
require_relative '../../../lib/common/script_scope/gtk/size_group'

# Shim callback, lifecycle and classification boundaries: the P12 shares of
# 1832:RC1 and 1853:RC1, plus 1843:RC2, RC3, RC5, RC8, RC9, RC10, RC13 and RC14.
# Exit and LoadError paths run in a fresh process; the rest use a recording port.
RSpec.describe 'script compatibility widget boundaries' do
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
    Open3.capture3(RbConfig.ruby, '-I', LIB_DIR, '-e', prelude + body + "\nSERVICE.stop\nputs 'ready'\n")
  end

  it 'routes a queued or timed exit to the owner-stop hook and contains other script errors (1843:RC3, 1832:RC1)' do
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

  it 'completes a refused presentation close despite a failing handler, honors a veto and stops an exiting owner (1843:RC2, 1853:RC1)' do
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

  it 'refuses native GTK entrypoints while unrelated helpers named like GTK packages load (1843:RC10)' do
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

  it 'contains non-StandardError cleanup failures so every window still closes (1832:RC1)' do
    first = gtk::Window.new('one')
    second = gtk::Window.new('two')
    closed = []
    first.signal_connect('destroy') { raise SecurityError, 'denied' }
    second.signal_connect('destroy') { closed << :second }

    expect { session.close }.not_to raise_error
    expect([first.destroyed?, second.destroyed?, closed]).to eq([true, true, [:second]])
    expect(logs.grep(/operation=destroy .*cleanup failed error=SecurityError/).size).to eq(1)
  end

  it 'keeps accumulated scroll requests within the contract range (1843:RC5)' do
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

  it 'retires widget shadow state when port teardown fails, keeping the diagnostic (1843:RC8)' do
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

  it 'keeps text= literal on a link label instead of writing new Markdown links (1843:RC9)' do
    label = gtk::Label.new
    label.set_markup('<a href="https://example.com/">site</a>')

    expect { label.text = '[prize](https://spoof.example/)' }.to raise_error(gtk::UnsupportedOperation, /operation=text=/)
    expect(label.text).to eq('[site](https://example.com/)')
    label.text = 'plain words (no link)'
    expect(label.text).to eq('plain words (no link)')
  end

  it 'bounds SizeGroup creation over the session lifetime (1843:RC13)' do
    keys = Array.new(gtk::SizeGroup::LIFETIME_LIMIT) { gtk::SizeGroup.new(:horizontal).key }

    expect(keys.uniq.size).to eq(512)
    expect(keys.last).to eq('sizegroup-512')
    expect { gtk::SizeGroup.new(:horizontal) }.to raise_error(gtk::UnsupportedOperation, /class=\S*SizeGroup operation=new/)
  end

  it 'ignores activation of a destroyed radio member without deselecting its group (1843:RC14)' do
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
end
