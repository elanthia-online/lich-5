# frozen_string_literal: true

require 'fileutils'
require_relative '../../spec_helper'

RSpec.describe 'Lich::Common GTK edge cases' do
  include_context 'mock GTK hardening environment'

  def tmpdir_prefix
    'gtk-edge-spec'
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

  it 'blocks Gtk.main_quit even before the shared loop starts' do
    Gtk.main_level = 0

    expect(Gtk.main_quit).to be_nil
    expect(Gtk.main_quit_calls).to eq(0)
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
