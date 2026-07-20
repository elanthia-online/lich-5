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

  it 'retains signal handlers even if destroy cleanup registration fails' do
    widget = Gtk::Widget.new
    handler = proc { :clicked }
    widget.fail_next_destroy_connection!

    widget.signal_connect('clicked', &handler)

    retained = Lich::Common.with_gtk_registry_lock { Lich::Common.gtk_signal_handlers[widget] }
    expect(retained[:handlers]).to include(handler)
  end

  it 'rolls back retained signal handlers if signal registration fails after retention' do
    widget = Gtk::Widget.new
    handler = proc { :clicked }
    widget.fail_next_signal_connection!

    expect { widget.signal_connect('clicked', &handler) }.to raise_error('signal registration failed')
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

  it 'destroys retained GTK receivers and clears callback registries during shutdown' do
    widget = Gtk::Widget.new
    timeout_id = GLib::Timeout.add(50) { true }
    idle_id = GLib::Idle.add { true }

    widget.signal_connect('clicked') { :clicked }

    expect(widget.destroyed?).to be false
    expect(Lich::Common.with_gtk_registry_lock { Lich::Common.gtk_signal_handlers[widget] }).not_to be_nil
    expect(Lich::Common.with_gtk_registry_lock { Lich::Common.gtk_timeout_callbacks[timeout_id] }).not_to be_nil
    expect(Lich::Common.with_gtk_registry_lock { Lich::Common.gtk_idle_callbacks[idle_id] }).not_to be_nil

    expect(Lich::Common.shutdown_gtk!).to eq(:main_quit_called)

    expect(widget.destroyed?).to be true
    expect(Gtk.main_quit_calls).to eq(1)
    expect(Lich::Common.with_gtk_registry_lock { Lich::Common.gtk_signal_handlers }).to be_empty
    expect(Lich::Common.with_gtk_registry_lock { Lich::Common.gtk_timeout_callbacks }).to be_empty
    expect(Lich::Common.with_gtk_registry_lock { Lich::Common.gtk_idle_callbacks }).to be_empty
  end

  it 'routes shared GTK shutdown through the guarded helper' do
    expect(Lich::Common.quit_gtk_main_loop).to eq(:main_quit_called)
    expect(Gtk.main_quit_calls).to eq(1)
  end

  it 'quits the GTK main loop when no retained GTK cleanup remains' do
    expect(Lich::Common.cleanup_gtk!).to be(false)
    expect(Lich::Common.shutdown_gtk!).to eq(:main_quit_called)
    expect(Gtk.main_quit_calls).to eq(1)
  end

  describe 'shutdown_gtk_before_exit' do
    context 'while the GTK main loop is running' do
      # The launcher and the main game loop call this from a thread other than
      # the GTK thread, so teardown is queued onto the GTK thread and awaited.
      before { Gtk.main_level = 1 }

      it 'queues core GTK teardown and returns once it signals completion' do
        widget = Gtk::Widget.new
        widget.signal_connect('clicked') { :clicked }
        # Run the queued block synchronously so the barrier is satisfied in-test;
        # the production path runs it on the GTK thread and waits the same way.
        allow(Gtk).to receive(:queue) { |&block| block.call; 1 }

        Lich::Common.shutdown_gtk_before_exit

        expect(widget.destroyed?).to be true
        expect(Gtk.main_quit_calls).to eq(1)
        expect(Lich::Common.with_gtk_registry_lock { Lich::Common.gtk_signal_handlers }).to be_empty
      end

      it 'clears retention registries when the teardown cannot be queued' do
        widget = Gtk::Widget.new
        timeout_id = GLib::Timeout.add(50) { true }
        idle_id = GLib::Idle.add { true }
        widget.signal_connect('clicked') { :clicked }
        allow(Gtk).to receive(:queue).and_return(nil)

        Lich::Common.shutdown_gtk_before_exit

        expect(Lich::Common.with_gtk_registry_lock { Lich::Common.gtk_signal_handlers[widget] }).to be_nil
        expect(Lich::Common.with_gtk_registry_lock { Lich::Common.gtk_timeout_callbacks[timeout_id] }).to be_nil
        expect(Lich::Common.with_gtk_registry_lock { Lich::Common.gtk_idle_callbacks[idle_id] }).to be_nil
        # The teardown body never ran, so the GTK loop was not quit.
        expect(Gtk.main_quit_calls).to eq(0)
      end

      it 'clears retention registries when GTK shutdown cannot be scheduled' do
        widget = Gtk::Widget.new
        timeout_id = GLib::Timeout.add(50) { true }
        idle_id = GLib::Idle.add { true }
        widget.signal_connect('clicked') { :clicked }
        allow(Gtk).to receive(:queue).and_raise('queue boom')

        expect { Lich::Common.shutdown_gtk_before_exit }.not_to raise_error

        expect(Lich).to have_received(:log).with(/Failed to queue GTK shutdown before exit/)
        expect(Lich::Common.with_gtk_registry_lock { Lich::Common.gtk_signal_handlers[widget] }).to be_nil
        expect(Lich::Common.with_gtk_registry_lock { Lich::Common.gtk_timeout_callbacks[timeout_id] }).to be_nil
        expect(Lich::Common.with_gtk_registry_lock { Lich::Common.gtk_idle_callbacks[idle_id] }).to be_nil
        expect(Gtk.main_quit_calls).to eq(0)
      end

      it 'warns and clears registries when the queued teardown does not finish in time' do
        widget = Gtk::Widget.new
        timeout_id = GLib::Timeout.add(50) { true }
        idle_id = GLib::Idle.add { true }
        widget.signal_connect('clicked') { :clicked }
        # Queued (truthy) but the block never runs, so completion is never signaled.
        allow(Gtk).to receive(:queue).and_return(1)

        Lich::Common.shutdown_gtk_before_exit(timeout: 0.05)

        expect(Lich).to have_received(:log).with(/GTK shutdown queue did not complete/)
        expect(Lich::Common.with_gtk_registry_lock { Lich::Common.gtk_signal_handlers[widget] }).to be_nil
        expect(Lich::Common.with_gtk_registry_lock { Lich::Common.gtk_timeout_callbacks[timeout_id] }).to be_nil
        expect(Lich::Common.with_gtk_registry_lock { Lich::Common.gtk_idle_callbacks[idle_id] }).to be_nil
      end
    end

    context 'after the GTK main loop has returned (terminal exit backstop)' do
      # The loop is unwound, so a queued block would never run. Only the terminal
      # GTK-thread backstop may destroy widgets directly in place.
      before { Gtk.main_level = 0 }

      it 'runs teardown directly without queuing when direct backstop is requested' do
        widget = Gtk::Widget.new
        widget.signal_connect('clicked') { :clicked }
        expect(Gtk).not_to receive(:queue)

        Lich::Common.shutdown_gtk_before_exit(direct: true)

        expect(widget.destroyed?).to be true
        expect(Lich::Common.with_gtk_registry_lock { Lich::Common.gtk_signal_handlers }).to be_empty
        expect(Gtk.main_quit_calls).to eq(0)
      end

      it 'clears retained Ruby references without direct widget teardown for non-terminal callers' do
        widget = Gtk::Widget.new
        timeout_id = GLib::Timeout.add(50) { true }
        idle_id = GLib::Idle.add { true }
        widget.signal_connect('clicked') { :clicked }
        expect(Gtk).not_to receive(:queue)

        Lich::Common.shutdown_gtk_before_exit

        expect(widget.destroyed?).to be false
        expect(Lich::Common.with_gtk_registry_lock { Lich::Common.gtk_signal_handlers[widget] }).to be_nil
        expect(Lich::Common.with_gtk_registry_lock { Lich::Common.gtk_timeout_callbacks[timeout_id] }).to be_nil
        expect(Lich::Common.with_gtk_registry_lock { Lich::Common.gtk_idle_callbacks[idle_id] }).to be_nil
      end

      it 'is a clean no-op when nothing remains to tear down' do
        expect(Gtk).not_to receive(:queue)

        expect { Lich::Common.shutdown_gtk_before_exit(direct: true) }.not_to raise_error
        expect(Lich::Common.with_gtk_registry_lock { Lich::Common.gtk_signal_handlers }).to be_empty
        expect(Gtk.main_quit_calls).to eq(0)
      end
    end

    it 'clears retention registries directly when GTK is unavailable' do
      hide_const('Gtk')
      allow(Lich::Common).to receive(:clear_gtk_retention_registries)

      expect { Lich::Common.shutdown_gtk_before_exit }.not_to raise_error
      expect(Lich::Common).to have_received(:clear_gtk_retention_registries)
    end
  end

  describe 'gtk_main_loop_running?' do
    it 'is true while a GTK main loop is active' do
      Gtk.main_level = 1
      expect(Lich::Common.gtk_main_loop_running?).to be true
    end

    it 'is false once the loop has unwound' do
      Gtk.main_level = 0
      expect(Lich::Common.gtk_main_loop_running?).to be false
    end

    it 'is false when GTK is unavailable' do
      hide_const('Gtk')
      expect(Lich::Common.gtk_main_loop_running?).to be false
    end
  end
end
