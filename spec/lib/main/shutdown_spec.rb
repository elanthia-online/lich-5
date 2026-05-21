# frozen_string_literal: true

require 'rspec'

require_relative '../../../lib/main/shutdown'

# Verifies the Lich::Main::Shutdown module coordinates orderly session
# teardown with correct phase ordering, error tolerance between phases,
# and graceful handling of missing or broken dependencies.
RSpec.describe Lich::Main::Shutdown do
  before do
    stub_const('Lich', Module.new) unless defined?(Lich)
    allow(Lich).to receive(:log)
  end

  # ---------------------------------------------------------------------------
  # Phase ordering
  # ---------------------------------------------------------------------------

  describe '.run' do
    it 'executes all phases in the correct order' do
      order = []

      allow(described_class).to receive(:unregister_sessions) { order << :unregister }
      allow(described_class).to receive(:kill_threads) { order << :kill_threads }
      allow(described_class).to receive(:stop_scripts) { order << :stop_scripts }
      allow(described_class).to receive(:save_state) { order << :save_state }
      allow(described_class).to receive(:close_connections) { order << :close_connections }
      allow(described_class).to receive(:quit_ui) { order << :quit_ui }

      reconnect = proc { order << :reconnect }

      described_class.run(
        client_thread: nil,
        detachable_client_thread: nil,
        reconnect_if_wanted: reconnect
      )

      expect(order).to eq(%i[
                            unregister kill_threads stop_scripts
                            save_state close_connections reconnect quit_ui
                          ])
    end

    it 'still calls quit_ui when reconnect_if_wanted raises' do
      allow(described_class).to receive(:unregister_sessions)
      allow(described_class).to receive(:kill_threads)
      allow(described_class).to receive(:stop_scripts)
      allow(described_class).to receive(:save_state)
      allow(described_class).to receive(:close_connections)
      allow(described_class).to receive(:quit_ui)

      reconnect = proc { raise RuntimeError, 'exec failed' }

      described_class.run(
        client_thread: nil,
        detachable_client_thread: nil,
        reconnect_if_wanted: reconnect
      )

      expect(described_class).to have_received(:quit_ui)
    end

    it 'logs a warning when reconnect_if_wanted raises' do
      allow(described_class).to receive(:unregister_sessions)
      allow(described_class).to receive(:kill_threads)
      allow(described_class).to receive(:stop_scripts)
      allow(described_class).to receive(:save_state)
      allow(described_class).to receive(:close_connections)
      allow(described_class).to receive(:quit_ui)

      reconnect = proc { raise RuntimeError, 'exec failed' }

      described_class.run(
        client_thread: nil,
        detachable_client_thread: nil,
        reconnect_if_wanted: reconnect
      )

      expect(Lich).to have_received(:log).with(/reconnect hook failed.*exec failed/)
    end
  end

  # ---------------------------------------------------------------------------
  # Phase 1: unregister_sessions
  # ---------------------------------------------------------------------------

  describe '.unregister_sessions' do
    it 'stops both lifecycle modules when defined' do
      active_lifecycle = Module.new { def self.stop; end }
      session_lifecycle = Module.new { def self.stop; end }

      stub_const('Lich::InternalAPI::ActiveSessions::Lifecycle', active_lifecycle)
      stub_const('Lich::Common::SessionLifecycle', session_lifecycle)

      allow(active_lifecycle).to receive(:stop)
      allow(session_lifecycle).to receive(:stop)

      described_class.unregister_sessions

      expect(active_lifecycle).to have_received(:stop)
      expect(session_lifecycle).to have_received(:stop)
    end

    it 'does not raise when neither lifecycle module is defined' do
      hide_const('Lich::InternalAPI::ActiveSessions::Lifecycle') if defined?(Lich::InternalAPI::ActiveSessions::Lifecycle)
      hide_const('Lich::Common::SessionLifecycle') if defined?(Lich::Common::SessionLifecycle)

      expect { described_class.unregister_sessions }.not_to raise_error
    end

    it 'still calls SessionLifecycle.stop when ActiveSessions::Lifecycle.stop raises' do
      active_lifecycle = Module.new { def self.stop; end }
      session_lifecycle = Module.new { def self.stop; end }

      stub_const('Lich::InternalAPI::ActiveSessions::Lifecycle', active_lifecycle)
      stub_const('Lich::Common::SessionLifecycle', session_lifecycle)

      allow(active_lifecycle).to receive(:stop).and_raise(RuntimeError, 'TCP service gone')
      allow(session_lifecycle).to receive(:stop)

      expect { described_class.unregister_sessions }.not_to raise_error
      expect(session_lifecycle).to have_received(:stop)
    end

    it 'logs a warning when ActiveSessions::Lifecycle.stop raises' do
      active_lifecycle = Module.new { def self.stop; end }
      stub_const('Lich::InternalAPI::ActiveSessions::Lifecycle', active_lifecycle)
      hide_const('Lich::Common::SessionLifecycle') if defined?(Lich::Common::SessionLifecycle)

      allow(active_lifecycle).to receive(:stop).and_raise(RuntimeError, 'TCP service gone')

      described_class.unregister_sessions

      expect(Lich).to have_received(:log).with(/ActiveSessions lifecycle stop failed.*TCP service gone/)
    end

    it 'does not raise when SessionLifecycle.stop raises' do
      session_lifecycle = Module.new { def self.stop; end }
      stub_const('Lich::Common::SessionLifecycle', session_lifecycle)
      hide_const('Lich::InternalAPI::ActiveSessions::Lifecycle') if defined?(Lich::InternalAPI::ActiveSessions::Lifecycle)

      allow(session_lifecycle).to receive(:stop).and_raise(RuntimeError, 'file lock')

      expect { described_class.unregister_sessions }.not_to raise_error
    end

    it 'logs a warning when SessionLifecycle.stop raises' do
      session_lifecycle = Module.new { def self.stop; end }
      stub_const('Lich::Common::SessionLifecycle', session_lifecycle)
      hide_const('Lich::InternalAPI::ActiveSessions::Lifecycle') if defined?(Lich::InternalAPI::ActiveSessions::Lifecycle)

      allow(session_lifecycle).to receive(:stop).and_raise(RuntimeError, 'file lock')

      described_class.unregister_sessions

      expect(Lich).to have_received(:log).with(/SessionLifecycle stop failed.*file lock/)
    end
  end

  # ---------------------------------------------------------------------------
  # Phase 2: kill_threads
  # ---------------------------------------------------------------------------

  describe '.kill_threads (private)' do
    it 'kills both threads when present' do
      t1 = instance_double(Thread)
      t2 = instance_double(Thread)
      allow(t1).to receive(:kill)
      allow(t2).to receive(:kill)

      described_class.send(:kill_threads, t1, t2)

      expect(t1).to have_received(:kill)
      expect(t2).to have_received(:kill)
    end

    it 'does not raise when both threads are nil' do
      expect { described_class.send(:kill_threads, nil, nil) }.not_to raise_error
    end

    it 'does not propagate when Thread#kill raises' do
      t1 = instance_double(Thread)
      allow(t1).to receive(:kill).and_raise(ThreadError, 'already dead')

      expect { described_class.send(:kill_threads, t1, nil) }.not_to raise_error
    end

    it 'still kills detachable_client_thread when client_thread.kill raises' do
      t1 = instance_double(Thread)
      t2 = instance_double(Thread)
      allow(t1).to receive(:kill).and_raise(ThreadError, 'already dead')
      allow(t2).to receive(:kill)

      expect { described_class.send(:kill_threads, t1, t2) }.not_to raise_error
      expect(t2).to have_received(:kill)
    end
  end

  # ---------------------------------------------------------------------------
  # Phase 3: stop_scripts
  # ---------------------------------------------------------------------------

  describe '.stop_scripts (private)' do
    before do
      stub_const('Script', Class.new)
    end

    it 'kills all running and hidden scripts then waits for them to drain' do
      script_a = double('script_a', kill: 'a')
      script_b = double('script_b', kill: 'b')
      hidden_script = double('hidden_script', kill: 'h')

      running_calls = 0
      allow(Script).to receive(:running) do
        running_calls += 1
        running_calls <= 2 ? [script_a, script_b] : []
      end

      hidden_calls = 0
      allow(Script).to receive(:hidden) do
        hidden_calls += 1
        hidden_calls <= 1 ? [hidden_script] : []
      end

      allow(described_class).to receive(:sleep)

      described_class.send(:stop_scripts)

      expect(script_a).to have_received(:kill).once
      expect(script_b).to have_received(:kill).once
      expect(hidden_script).to have_received(:kill).once
    end

    it 'stops polling after the timeout ceiling when scripts refuse to die' do
      stubborn_script = double('stubborn', kill: 'stubborn')
      allow(Script).to receive(:running).and_return([stubborn_script])
      allow(Script).to receive(:hidden).and_return([])

      sleep_count = 0
      allow(described_class).to receive(:sleep) { sleep_count += 1 }

      described_class.send(:stop_scripts)

      expected_iterations = (described_class::SCRIPT_KILL_TIMEOUT_SECONDS / 0.1).to_i
      expect(sleep_count).to eq(expected_iterations)
    end

    it 'does not sleep at all when no scripts are running' do
      allow(Script).to receive(:running).and_return([])
      allow(Script).to receive(:hidden).and_return([])

      expect(described_class).not_to receive(:sleep)

      described_class.send(:stop_scripts)
    end

    it 'does not propagate when Script.running raises' do
      allow(Script).to receive(:running).and_raise(RuntimeError, 'corrupted runtime')

      expect { described_class.send(:stop_scripts) }.not_to raise_error
    end

    it 'logs a warning when an exception occurs' do
      allow(Script).to receive(:running).and_raise(RuntimeError, 'corrupted runtime')

      described_class.send(:stop_scripts)

      expect(Lich).to have_received(:log).with(/stop_scripts failed.*corrupted runtime/)
    end
  end

  # ---------------------------------------------------------------------------
  # Phase 4: save_state
  # ---------------------------------------------------------------------------

  describe '.save_state (private)' do
    before do
      stub_const('Vars', Module.new { def self.save; end })
      allow(Vars).to receive(:save)
    end

    it 'calls Vars.save' do
      described_class.send(:save_state)

      expect(Vars).to have_received(:save)
    end

    it 'does not call Settings.save' do
      settings = Module.new { def self.save; end }
      stub_const('Settings', settings)
      allow(settings).to receive(:save)

      described_class.send(:save_state)

      expect(settings).not_to have_received(:save)
    end

    it 'does not propagate when Vars.save raises' do
      allow(Vars).to receive(:save).and_raise(RuntimeError, 'database locked')

      expect { described_class.send(:save_state) }.not_to raise_error
    end

    it 'logs a warning when Vars.save raises' do
      allow(Vars).to receive(:save).and_raise(RuntimeError, 'database locked')

      described_class.send(:save_state)

      expect(Lich).to have_received(:log).with(/Vars\.save failed.*database locked/)
    end
  end

  # ---------------------------------------------------------------------------
  # Phase 5: close_connections
  # ---------------------------------------------------------------------------

  describe '.close_connections (private)' do
    let(:game) { Module.new { def self.close; end } }
    let(:client) { double('client') }
    let(:db) { double('db') }

    before do
      stub_const('Game', game)
      allow(game).to receive(:close)
      allow(client).to receive(:close)
      allow(db).to receive(:close)
      allow(Lich).to receive(:db).and_return(db)
      $_CLIENT_ = client
    end

    after { $_CLIENT_ = nil }

    it 'closes game, client, and database' do
      described_class.send(:close_connections)

      expect(game).to have_received(:close)
      expect(client).to have_received(:close)
      expect(db).to have_received(:close)
    end

    it 'does not raise when $_CLIENT_ is nil' do
      $_CLIENT_ = nil

      expect { described_class.send(:close_connections) }.not_to raise_error
      expect(game).to have_received(:close)
      expect(db).to have_received(:close)
    end

    it 'still closes client and db when Game.close raises' do
      allow(game).to receive(:close).and_raise(IOError, 'socket error')

      expect { described_class.send(:close_connections) }.not_to raise_error
      expect(client).to have_received(:close)
      expect(db).to have_received(:close)
    end

    it 'logs a warning when Game.close raises' do
      allow(game).to receive(:close).and_raise(IOError, 'socket error')

      described_class.send(:close_connections)

      expect(Lich).to have_received(:log).with(/Game\.close failed.*socket error/)
    end

    it 'still closes game and client when Lich.db.close raises' do
      allow(db).to receive(:close).and_raise(RuntimeError, 'already closed')

      expect { described_class.send(:close_connections) }.not_to raise_error
      expect(game).to have_received(:close)
      expect(client).to have_received(:close)
    end

    it 'logs a warning when Lich.db.close raises' do
      allow(db).to receive(:close).and_raise(RuntimeError, 'already closed')

      described_class.send(:close_connections)

      expect(Lich).to have_received(:log).with(/Lich\.db\.close failed.*already closed/)
    end

    it 'still closes game and db when $_CLIENT_.close raises' do
      allow(client).to receive(:close).and_raise(IOError, 'broken pipe')

      expect { described_class.send(:close_connections) }.not_to raise_error
      expect(game).to have_received(:close)
      expect(db).to have_received(:close)
    end

    it 'logs a warning when $_CLIENT_.close raises' do
      allow(client).to receive(:close).and_raise(IOError, 'broken pipe')

      described_class.send(:close_connections)

      expect(Lich).to have_received(:log).with(/\$_CLIENT_\.close failed.*broken pipe/)
    end

    it 'does not raise when Lich.db is nil' do
      allow(Lich).to receive(:db).and_return(nil)

      expect { described_class.send(:close_connections) }.not_to raise_error
      expect(game).to have_received(:close)
      expect(client).to have_received(:close)
    end

    it 'survives and logs when all three close calls raise' do
      allow(game).to receive(:close).and_raise(IOError, 'game socket')
      allow(client).to receive(:close).and_raise(IOError, 'client socket')
      allow(db).to receive(:close).and_raise(IOError, 'db locked')

      expect { described_class.send(:close_connections) }.not_to raise_error
      expect(Lich).to have_received(:log).with(/Game\.close failed/)
      expect(Lich).to have_received(:log).with(/\$_CLIENT_\.close failed/)
      expect(Lich).to have_received(:log).with(/Lich\.db\.close failed/)
    end
  end

  # ---------------------------------------------------------------------------
  # Phase 6: quit_ui
  # ---------------------------------------------------------------------------

  describe '.quit_ui (private)' do
    it 'calls exit' do
      expect { described_class.send(:quit_ui) }.to raise_error(SystemExit)
    end

    it 'queues Gtk.main_quit when Gtk is defined' do
      gtk = Module.new { def self.queue; end; def self.main_quit; end }
      stub_const('Gtk', gtk)
      allow(gtk).to receive(:queue).and_yield

      expect { described_class.send(:quit_ui) }.to raise_error(SystemExit)
      expect(gtk).to have_received(:queue)
    end
  end
end
