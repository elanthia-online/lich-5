# frozen_string_literal: true

require 'fileutils'
require_relative '../../spec_helper'

RSpec.describe 'Lich::Common GTK hardening' do
  include_context 'mock GTK hardening environment'

  def tmpdir_prefix
    'gtk-spec'
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
    allow(Script).to receive(:current).and_return(Struct.new(:name).new('gemstone-tracker'))

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

  it 'rolls back retained signal handlers if destroy cleanup registration fails' do
    widget = Gtk::Widget.new
    handler = proc { :clicked }
    widget.fail_next_destroy_connection!

    widget.signal_connect('clicked', &handler)

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

  it 'releases retained timeout callbacks if the wrapped block raises' do
    callback_id = GLib::Timeout.add(50) { raise 'timeout boom' }

    expect { GLib::Timeout.blocks[callback_id].call }.to raise_error('timeout boom')
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

  it 'releases retained idle callbacks if the wrapped block raises' do
    callback_id = GLib::Idle.add { raise 'idle boom' }

    expect { GLib::Idle.blocks[callback_id].call }.to raise_error('idle boom')
    expect(Lich::Common.with_gtk_registry_lock { Lich::Common.gtk_idle_callbacks[callback_id] }).to be_nil
  end
end
