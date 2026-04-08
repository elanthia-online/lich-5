# frozen_string_literal: true

require 'fileutils'
require_relative '../../spec_helper'

RSpec.describe 'Lich::Common GTK edge cases' do
  before(:context) do
    @tmpdir = Dir.mktmpdir('gtk-edge-spec')
    @saved_consts = {}
    @saved_gtk_hardening_consts = {}

    %i[Gtk GLib GdkPixbuf].each do |name|
      next unless Object.const_defined?(name)

      @saved_consts[name] = Object.const_get(name)
      Object.send(:remove_const, name)
    end

    %i[
      GtkSignalHandlerRetention
      GtkTimeoutRetention
      GtkIdleRetention
      GtkMainLoopGuards
    ].each do |name|
      next unless Lich::Common.const_defined?(name, false)

      @saved_gtk_hardening_consts[name] = Lich::Common.const_get(name, false)
      Lich::Common.send(:remove_const, name)
    end

    glib_mod = Module.new
    base_instantiatable = Module.new do
      def signal_connect(signal, *_args, &block)
        if signal.to_s == 'destroy' && @destroy_connect_failures_remaining.to_i.positive?
          @destroy_connect_failures_remaining -= 1
          raise 'destroy hook failed'
        end

        @signals ||= Hash.new { |hash, key| hash[key] = [] }
        @signals[signal.to_s] << block if block
        @signals[signal.to_s].length
      end

      def fail_next_destroy_connection!
        @destroy_connect_failures_remaining = @destroy_connect_failures_remaining.to_i + 1
      end

      def signal_blocks(signal)
        @signals ||= {}
        @signals[signal.to_s] || []
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
      attr_accessor :main_level, :main_calls, :main_quit_calls, :main_quit_failure

      def main(*)
        self.main_calls ||= 0
        self.main_calls += 1
        :main_called
      end

      def main_quit(*)
        raise 'main_quit boom' if main_quit_failure

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

    %i[
      GtkSignalHandlerRetention
      GtkTimeoutRetention
      GtkIdleRetention
      GtkMainLoopGuards
    ].each do |name|
      Lich::Common.send(:remove_const, name) if Lich::Common.const_defined?(name, false)
    end

    @saved_consts.each do |name, value|
      Object.const_set(name, value)
    end

    @saved_gtk_hardening_consts.each do |name, value|
      Lich::Common.const_set(name, value)
    end

    FileUtils.remove_entry(@tmpdir) if @tmpdir && File.exist?(@tmpdir)
  end

  before do
    Gtk.main_level = 0
    Gtk.main_calls = 0
    Gtk.main_quit_calls = 0
    Gtk.main_quit_failure = false
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

  it 'installs only one internal destroy cleanup handler per widget' do
    widget = Gtk::Widget.new

    widget.signal_connect('clicked') { :one }
    widget.signal_connect('button-release-event') { :two }

    destroy_blocks = widget.signal_blocks('destroy')
    retained = Lich::Common.with_gtk_registry_lock { Lich::Common.gtk_signal_handlers[widget] }

    expect(destroy_blocks.length).to eq(1)
    expect(retained[:handlers].count { |handler| destroy_blocks.include?(handler) }).to eq(1)
  end

  it 'releases retained signal handlers even if a user destroy handler raises' do
    widget = Gtk::Widget.new

    widget.signal_connect('clicked') { :clicked }
    widget.signal_connect('destroy') { raise 'user destroy boom' }

    expect { widget.emit('destroy') }.to raise_error('user destroy boom')
    expect(Lich::Common.with_gtk_registry_lock { Lich::Common.gtk_signal_handlers[widget] }).to be_nil
  end

  it 'falls back to unknown context when Script.current raises during guard logging' do
    Gtk.main_level = 1
    allow(Script).to receive(:current).and_raise('script context boom')

    Gtk.main_quit

    expect(Lich).to have_received(:log).with(/context=unknown/)
  end

  it 'restores the core-only Gtk.main_quit bypass flag after an exception' do
    Gtk.main_level = 1
    Gtk.main_quit_failure = true

    expect { Gtk.lich_main_quit }.to raise_error('main_quit boom')

    Gtk.main_quit_failure = false
    expect(Gtk.main_quit).to be_nil
    expect(Gtk.main_quit_calls).to eq(0)
  end

  it 'releases timeout callbacks that stop on their first invocation' do
    callback_id = GLib::Timeout.add(50) { false }

    expect(Lich::Common.with_gtk_registry_lock { Lich::Common.gtk_timeout_callbacks[callback_id] }).not_to be_nil
    expect(GLib::Timeout.blocks[callback_id].call).to be false
    expect(Lich::Common.with_gtk_registry_lock { Lich::Common.gtk_timeout_callbacks[callback_id] }).to be_nil
  end

  it 'releases idle callbacks that stop on their first invocation' do
    callback_id = GLib::Idle.add { nil }

    expect(Lich::Common.with_gtk_registry_lock { Lich::Common.gtk_idle_callbacks[callback_id] }).not_to be_nil
    expect(GLib::Idle.blocks[callback_id].call).to be_nil
    expect(Lich::Common.with_gtk_registry_lock { Lich::Common.gtk_idle_callbacks[callback_id] }).to be_nil
  end
end
