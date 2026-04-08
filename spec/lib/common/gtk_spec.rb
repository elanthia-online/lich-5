# frozen_string_literal: true

require 'fileutils'
require_relative '../../spec_helper'

RSpec.describe 'Lich::Common GTK hardening' do
  before(:context) do
    @tmpdir = Dir.mktmpdir('gtk-spec')
    @saved_consts = {}

    %i[Gtk GLib GdkPixbuf].each do |name|
      next unless Object.const_defined?(name)

      @saved_consts[name] = Object.const_get(name)
      Object.send(:remove_const, name)
    end

    glib_mod = Module.new
    base_instantiatable = Module.new do
      def signal_connect(signal, *_args, &block)
        @signals ||= Hash.new { |hash, key| hash[key] = [] }
        @signals[signal.to_s] << block if block
        @signals[signal.to_s].length
      end

      def emit(signal, *args)
        @signals ||= {}
        (@signals[signal.to_s] || []).map { |block| block.call(*args) }
      end
    end
    instantiatable_mod = Module.new
    instantiatable_mod.include(base_instantiatable)
    glib_mod.const_set(:Instantiatable, instantiatable_mod)

    timeout_mod = Module.new
    timeout_mod.singleton_class.class_eval do
      attr_accessor :blocks, :next_id

      def add(*_args, &block)
        self.blocks ||= {}
        self.next_id ||= 0
        self.next_id += 1
        self.blocks[self.next_id] = block
        self.next_id
      end
    end
    glib_mod.const_set(:Timeout, timeout_mod)

    idle_mod = Module.new
    idle_mod.singleton_class.class_eval do
      attr_accessor :blocks, :next_id

      def add(*_args, &block)
        self.blocks ||= {}
        self.next_id ||= 0
        self.next_id += 1
        self.blocks[self.next_id] = block
        self.next_id
      end
    end
    glib_mod.const_set(:Idle, idle_mod)
    Object.const_set(:GLib, glib_mod)

    gtk_mod = Module.new
    gtk_mod.singleton_class.class_eval do
      attr_accessor :main_level, :main_calls, :main_quit_calls

      def main(*)
        self.main_calls ||= 0
        self.main_calls += 1
        :main_called
      end

      def main_quit(*)
        self.main_quit_calls ||= 0
        self.main_quit_calls += 1
        :main_quit_called
      end
    end

    widget_class = Class.new do
      include GLib::Instantiatable
    end
    gtk_mod.const_set(:Widget, widget_class)
    Object.const_set(:Gtk, gtk_mod)

    pixbuf_mod = Module.new
    pixbuf_class = Class.new do
      def self.new(*)
        Object.new
      end
    end
    pixbuf_mod.const_set(:Pixbuf, pixbuf_class)
    Object.const_set(:GdkPixbuf, pixbuf_mod)

    @original_dir = Dir.pwd
    Dir.chdir(@tmpdir)
    load File.expand_path('../../../lib/common/gtk.rb', __dir__)
  end

  after(:context) do
    Dir.chdir(@original_dir) if @original_dir

    %i[Gtk GLib GdkPixbuf].each do |name|
      Object.send(:remove_const, name) if Object.const_defined?(name)
    end

    @saved_consts.each do |name, value|
      Object.const_set(name, value)
    end

    FileUtils.remove_entry(@tmpdir) if @tmpdir && File.exist?(@tmpdir)
  end

  before do
    Gtk.main_level = 0
    Gtk.main_calls = 0
    Gtk.main_quit_calls = 0
    GLib::Timeout.blocks = {}
    GLib::Timeout.next_id = 0
    GLib::Idle.blocks = {}
    GLib::Idle.next_id = 0
    Lich::Common.with_gtk_registry_lock do
      Lich::Common.gtk_signal_handlers.clear
      Lich::Common.gtk_timeout_callbacks.clear
      Lich::Common.gtk_idle_callbacks.clear
    end
    stub_const('Script', Class.new) unless defined?(Script)
    allow(Script).to receive(:current).and_return(nil)
    allow(Lich).to receive(:log)
  end

  it 'ignores redundant Gtk.main calls while the shared loop is already running' do
    Gtk.main_level = 1

    expect(Gtk.main).to be_nil
    expect(Gtk.main_calls).to eq(0)
  end

  it 'allows Gtk.main when no loop is running yet' do
    expect(Gtk.main).to eq(:main_called)
    expect(Gtk.main_calls).to eq(1)
  end

  it 'blocks script-level Gtk.main_quit while GTK is active' do
    Gtk.main_level = 1

    expect(Gtk.main_quit).to be_nil
    expect(Gtk.main_quit_calls).to eq(0)
  end

  it 'names the offending script in blocked Gtk.main_quit logs when available' do
    Gtk.main_level = 1
    allow(Script).to receive(:current).and_return(OpenStruct.new(name: 'gemstone-tracker'))

    Gtk.main_quit

    expect(Lich).to have_received(:log).with(/script=gemstone-tracker/)
  end

  it 'allows core-owned Gtk shutdown through Gtk.lich_main_quit' do
    expect(Gtk.lich_main_quit).to eq(:main_quit_called)
    expect(Gtk.main_quit_calls).to eq(1)
  end

  it 'retains signal handlers until the widget emits destroy' do
    widget = Gtk::Widget.new
    handler = proc { :clicked }

    widget.signal_connect('clicked', &handler)

    retained = Lich::Common.with_gtk_registry_lock { Lich::Common.gtk_signal_handlers[widget] }
    expect(retained[:receiver]).to equal(widget)
    expect(retained[:handlers]).to include(handler)

    widget.emit('destroy')
    expect(Lich::Common.with_gtk_registry_lock { Lich::Common.gtk_signal_handlers[widget] }).to be_nil
  end

  it 'releases destroy-only retained handlers when the widget emits destroy' do
    widget = Gtk::Widget.new
    handler = proc { :destroyed }

    widget.signal_connect('destroy', &handler)

    retained = Lich::Common.with_gtk_registry_lock { Lich::Common.gtk_signal_handlers[widget] }
    expect(retained[:handlers]).to include(handler)

    widget.emit('destroy')
    expect(Lich::Common.with_gtk_registry_lock { Lich::Common.gtk_signal_handlers[widget] }).to be_nil
  end

  it 'retains timeout callbacks until they stop repeating' do
    count = 0
    callback_id = GLib::Timeout.add(50) do
      count += 1
      count < 2
    end

    expect(Lich::Common.with_gtk_registry_lock { Lich::Common.gtk_timeout_callbacks[callback_id] }).not_to be_nil

    expect(GLib::Timeout.blocks[callback_id].call).to be true
    expect(Lich::Common.with_gtk_registry_lock { Lich::Common.gtk_timeout_callbacks[callback_id] }).not_to be_nil

    expect(GLib::Timeout.blocks[callback_id].call).to be false
    expect(Lich::Common.with_gtk_registry_lock { Lich::Common.gtk_timeout_callbacks[callback_id] }).to be_nil
  end

  it 'retains idle callbacks until they stop repeating' do
    count = 0
    callback_id = GLib::Idle.add do
      count += 1
      count < 2
    end

    expect(Lich::Common.with_gtk_registry_lock { Lich::Common.gtk_idle_callbacks[callback_id] }).not_to be_nil

    expect(GLib::Idle.blocks[callback_id].call).to be true
    expect(Lich::Common.with_gtk_registry_lock { Lich::Common.gtk_idle_callbacks[callback_id] }).not_to be_nil

    expect(GLib::Idle.blocks[callback_id].call).to be false
    expect(Lich::Common.with_gtk_registry_lock { Lich::Common.gtk_idle_callbacks[callback_id] }).to be_nil
  end
end
