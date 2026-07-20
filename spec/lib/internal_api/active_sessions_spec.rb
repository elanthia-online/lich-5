# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'

require_relative '../../spec_helper'
require_relative '../../../lib/internal_api/active_sessions'

RSpec.describe Lich::InternalAPI::ActiveSessions do
  let(:temp_dir) { Dir.mktmpdir('active-sessions-spec') }
  let(:discovery_file) { File.join(temp_dir, 'lich-active-sessions.json') }

  before do
    stub_const('TEMP_DIR', temp_dir)
    described_class.instance_variable_set(:@registry, nil)
    described_class.instance_variable_set(:@server, nil)
    described_class.instance_variable_set(:@lock_file, nil)
    described_class.instance_variable_set(:@service_client, nil)
    described_class.instance_variable_set(:@service_client_token, nil)
    described_class.instance_variable_set(:@service_client_port, nil)
    described_class.instance_variable_set(:@mutex, Mutex.new)
    described_class.instance_variable_set(:@service_client_mutex, Mutex.new)
    allow(described_class).to receive(:enabled?).and_return(true)
  end

  after do
    described_class.stop_service!
    FileUtils.rm_rf(temp_dir)
  end

  # Builds a Server test double with the fields the election path reads back.
  #
  # @return [RSpec::Mocks::InstanceVerifyingDouble]
  def server_double(auth_token:, port:, start: true, running: true)
    instance_double(
      Lich::InternalAPI::ActiveSessions::Server,
      start: start,
      stop: nil,
      running?: running,
      auth_token: auth_token,
      port: port
    )
  end

  # Writes a discovery file with the given fields.
  #
  # @return [void]
  def write_discovery_file(owner_pid:, auth_token:, port:, updated_at: Time.now.to_i)
    File.write(discovery_file, JSON.dump(owner_pid: owner_pid, auth_token: auth_token, port: port, updated_at: updated_at))
  end

  # Reads and symbolizes the on-disk discovery file.
  #
  # @return [Hash]
  def read_discovery
    JSON.parse(File.read(discovery_file), symbolize_names: true)
  end

  describe 'ownership election' do
    it 'acquires the lock, binds an ephemeral port, and publishes it in discovery' do
      dead_client = instance_double(Lich::InternalAPI::ActiveSessions::Client, ping: false)
      allow(Lich::InternalAPI::ActiveSessions::Client).to receive(:new).and_return(dead_client)
      allow(Lich::InternalAPI::ActiveSessions::Server).to receive(:new)
        .with(hash_including(port: Lich::InternalAPI::ActiveSessions::EPHEMERAL_PORT))
        .and_return(server_double(auth_token: 'generated-token', port: 54_321))

      expect(described_class.ensure_service!).to be(true)

      discovery = read_discovery
      expect(discovery[:owner_pid]).to eq(Process.pid)
      expect(discovery[:auth_token]).to eq('generated-token')
      expect(discovery[:port]).to eq(54_321)
      expect(File.stat(discovery_file).mode & 0o777).to eq(0o600)
      expect(File.exist?(File.join(temp_dir, 'lich-active-sessions.lock'))).to be(true)
    end

    it 'reuses a healthy peer owner at the published port without binding' do
      healthy_client = instance_double(Lich::InternalAPI::ActiveSessions::Client, ping: true)
      allow(Lich::InternalAPI::ActiveSessions::Client).to receive(:new).and_return(healthy_client)
      write_discovery_file(owner_pid: 123, auth_token: 'shared-token', port: 49_000)

      expect(Lich::InternalAPI::ActiveSessions::Server).not_to receive(:new)
      expect(described_class.ensure_service!).to be(true)
      expect(Lich::InternalAPI::ActiveSessions::Client).to have_received(:new).with(hash_including(port: 49_000))
    end

    it 'reuses the peer when the ownership lock is held by a live peer' do
      # Fast-path probe misses, then the peer answers after we decline to bind.
      peer_client = instance_double(Lich::InternalAPI::ActiveSessions::Client)
      allow(peer_client).to receive(:ping).and_return(false, true)
      allow(Lich::InternalAPI::ActiveSessions::Client).to receive(:new).and_return(peer_client)
      write_discovery_file(owner_pid: 4242, auth_token: 'peer-token', port: 51_000)
      allow(described_class).to receive(:acquire_ownership_lock).and_return(false)

      expect(Lich::InternalAPI::ActiveSessions::Server).not_to receive(:new)
      expect(described_class.ensure_service!).to be(true)
    end

    it 'takes over a stale discovery from a departed owner by re-acquiring the free lock' do
      dead_client = instance_double(Lich::InternalAPI::ActiveSessions::Client, ping: false)
      allow(Lich::InternalAPI::ActiveSessions::Client).to receive(:new).and_return(dead_client)
      write_discovery_file(owner_pid: 99_999_999, auth_token: 'departed-token', port: 40_000)
      allow(Lich::InternalAPI::ActiveSessions::Server).to receive(:new)
        .and_return(server_double(auth_token: 'takeover-token', port: 55_555))

      expect(described_class.ensure_service!).to be(true)

      discovery = read_discovery
      expect(discovery[:owner_pid]).to eq(Process.pid)
      expect(discovery[:auth_token]).to eq('takeover-token')
      expect(discovery[:port]).to eq(55_555)
    end

    it 'degrades to unavailable (no bind, no split-brain) when the lock cannot be opened' do
      dead_client = instance_double(Lich::InternalAPI::ActiveSessions::Client, ping: false)
      allow(Lich::InternalAPI::ActiveSessions::Client).to receive(:new).and_return(dead_client)
      allow(File).to receive(:open).and_call_original
      allow(File).to receive(:open)
        .with(File.join(temp_dir, 'lich-active-sessions.lock'), anything, anything)
        .and_raise(Errno::EACCES, 'locked down')

      expect(Lich::InternalAPI::ActiveSessions::Server).not_to receive(:new)
      expect(described_class.ensure_service!).to be(false)
      expect(File.exist?(discovery_file)).to be(false)
    end

    it 'treats discovery without a published port as no service and bootstraps' do
      dead_client = instance_double(Lich::InternalAPI::ActiveSessions::Client, ping: false)
      allow(Lich::InternalAPI::ActiveSessions::Client).to receive(:new).and_return(dead_client)
      # Legacy/partial discovery: token present but no port.
      File.write(discovery_file, JSON.dump(owner_pid: 777, auth_token: 'portless-token', updated_at: Time.now.to_i))
      allow(Lich::InternalAPI::ActiveSessions::Server).to receive(:new)
        .and_return(server_double(auth_token: 'fresh-token', port: 56_000))

      expect(described_class.ensure_service!).to be(true)
      expect(read_discovery[:port]).to eq(56_000)
    end

    it 'rolls back the lock and clears @server when the bind fails, so a successor can take over' do
      dead_client = instance_double(Lich::InternalAPI::ActiveSessions::Client, ping: false)
      allow(Lich::InternalAPI::ActiveSessions::Client).to receive(:new).and_return(dead_client)
      allow(Lich::InternalAPI::ActiveSessions::Server).to receive(:new)
        .and_return(server_double(auth_token: 'doomed-token', port: 0, start: false))

      expect(described_class.ensure_service!).to be(false)
      expect(described_class.instance_variable_get(:@server)).to be_nil
      expect(File.exist?(discovery_file)).to be(false)
      # Regression: a failed bind must release the ownership lock so a peer
      # (or this process on a later tick) can win it -- not strand it.
      expect(described_class.instance_variable_get(:@lock_file)).to be_nil
      expect(described_class.send(:acquire_ownership_lock)).to be(true)
    end

    it 'rolls back the server and lock when discovery publication fails' do
      dead_client = instance_double(Lich::InternalAPI::ActiveSessions::Client, ping: false)
      allow(Lich::InternalAPI::ActiveSessions::Client).to receive(:new).and_return(dead_client)
      doomed = server_double(auth_token: 'started-token', port: 45_000, start: true)
      allow(Lich::InternalAPI::ActiveSessions::Server).to receive(:new).and_return(doomed)
      # Simulate a discovery write failure (e.g. File.rename over an existing
      # file failing on Windows) after the server has already started.
      allow(described_class).to receive(:write_discovery).and_raise(Errno::EACCES, 'rename failed')

      expect(described_class.ensure_service!).to be(false)
      expect(doomed).to have_received(:stop)
      expect(described_class.instance_variable_get(:@server)).to be_nil
      expect(described_class.instance_variable_get(:@lock_file)).to be_nil
      expect(described_class.send(:acquire_ownership_lock)).to be(true)
    end
  end

  describe 'in-process recovery' do
    it 'reuses its own healthy server without touching discovery or the lock' do
      described_class.instance_variable_set(:@server, server_double(auth_token: 'live-token', port: 47_000, running: true))

      expect(described_class).not_to receive(:service_available?)
      expect(Lich::InternalAPI::ActiveSessions::Server).not_to receive(:new)
      expect(described_class.ensure_service!).to be(true)

      described_class.instance_variable_set(:@server, nil)
    end

    it 'rebinds a fresh ephemeral listener when its own accept loop has died' do
      dead_client = instance_double(Lich::InternalAPI::ActiveSessions::Client, ping: false)
      allow(Lich::InternalAPI::ActiveSessions::Client).to receive(:new).and_return(dead_client)
      zombie = server_double(auth_token: 'zombie-token', port: 41_000, running: false)
      described_class.instance_variable_set(:@server, zombie)
      allow(Lich::InternalAPI::ActiveSessions::Server).to receive(:new)
        .and_return(server_double(auth_token: 'rebound-token', port: 42_000))

      expect(zombie).to receive(:stop)
      expect(described_class.ensure_service!).to be(true)
      expect(read_discovery[:port]).to eq(42_000)

      described_class.instance_variable_set(:@server, nil)
    end

    it 'clears the dead server and recovers on retry when stopping it raises' do
      dead_client = instance_double(Lich::InternalAPI::ActiveSessions::Client, ping: false)
      allow(Lich::InternalAPI::ActiveSessions::Client).to receive(:new).and_return(dead_client)
      zombie = instance_double(
        Lich::InternalAPI::ActiveSessions::Server,
        running?: false,
        auth_token: 'zombie-token',
        port: 41_000
      )
      allow(zombie).to receive(:stop).and_raise(Errno::EBADF, 'bad fd during stop')
      described_class.instance_variable_set(:@server, zombie)

      # The attempt that trips over the raising stop surfaces false...
      expect(described_class.ensure_service!).to be(false)
      # ...but the dead reference must be cleared, or every future attempt would
      # re-enter the same raising stop and the process could never rebind.
      expect(described_class.instance_variable_get(:@server)).to be_nil

      # A subsequent attempt binds a fresh listener instead of reusing the corpse.
      allow(Lich::InternalAPI::ActiveSessions::Server).to receive(:new)
        .and_return(server_double(auth_token: 'rebound-token', port: 42_000))
      expect(described_class.ensure_service!).to be(true)
      expect(read_discovery[:port]).to eq(42_000)
    end

    it 'closes the opened lock file (no fd leak) when flock raises' do
      # File.open succeeds but flock blows up (e.g. a filesystem without record
      # locking). The handle must be closed since it was never recorded as the
      # owning lock.
      leaked = instance_double(File, closed?: false)
      allow(leaked).to receive(:flock).and_raise(Errno::ENOLCK, 'no locks available')
      allow(leaked).to receive(:close)
      allow(File).to receive(:open).and_call_original
      allow(File).to receive(:open)
        .with(File.join(temp_dir, 'lich-active-sessions.lock'), anything, anything)
        .and_return(leaked)
      allow(Lich).to receive(:log)

      expect(described_class.send(:acquire_ownership_lock)).to be(false)
      expect(leaked).to have_received(:close)
      expect(described_class.instance_variable_get(:@lock_file)).to be_nil
    end
  end

  describe '.service_info' do
    it 'reports the discovered owner and port without exposing the auth token' do
      allow(Lich::InternalAPI::ActiveSessions::Client).to receive(:new)
        .and_return(instance_double(Lich::InternalAPI::ActiveSessions::Client, ping: true))
      write_discovery_file(owner_pid: 321, auth_token: 'shared-token', port: 45_000, updated_at: 1_700_000_000)

      expect(described_class.service_info).to eq(
        source: 'ActiveSessionsAPI',
        owner_pid: 321,
        port: 45_000,
        updated_at: 1_700_000_000,
        service_available: true
      )
    end
  end

  describe '.stop_service! and discovery cleanup' do
    it 'removes the discovery file when the owner is also the last remaining session' do
      write_discovery_file(owner_pid: Process.pid, auth_token: 'shared-token', port: 46_000)
      allow(described_class).to receive(:query_snapshot).and_return(
        source: 'ActiveSessionsAPI', total: 0, connected: 0, detachable: 0, sessions: []
      )

      described_class.cleanup_discovery_if_last_session!

      expect(File.exist?(discovery_file)).to be(false)
    end

    it 'keeps the discovery file when the snapshot is a fallback error' do
      write_discovery_file(owner_pid: Process.pid, auth_token: 'shared-token', port: 46_000)
      allow(described_class).to receive(:query_snapshot).and_return(
        source: 'ActiveSessionsAPI', total: 0, connected: 0, detachable: 0, sessions: [], error: 'service unavailable'
      )

      described_class.cleanup_discovery_if_last_session!

      expect(File.exist?(discovery_file)).to be(true)
    end

    it 'keeps discovery when other sessions remain registered' do
      write_discovery_file(owner_pid: Process.pid, auth_token: 'shared-token', port: 46_000)
      allow(described_class).to receive(:query_snapshot).and_return(
        source: 'ActiveSessionsAPI', total: 2, connected: 2, detachable: 1,
        sessions: [{ session_name: 'Tsetem' }, { session_name: 'Another' }]
      )

      described_class.cleanup_discovery_if_last_session!

      expect(File.exist?(discovery_file)).to be(true)
    end

    it 'releases the ownership lock so a successor can acquire it' do
      dead_client = instance_double(Lich::InternalAPI::ActiveSessions::Client, ping: false)
      allow(Lich::InternalAPI::ActiveSessions::Client).to receive(:new).and_return(dead_client)
      allow(Lich::InternalAPI::ActiveSessions::Server).to receive(:new)
        .and_return(server_double(auth_token: 'first-token', port: 43_000))
      expect(described_class.ensure_service!).to be(true)
      expect(described_class.instance_variable_get(:@lock_file)).not_to be_nil

      described_class.stop_service!

      expect(described_class.instance_variable_get(:@lock_file)).to be_nil
      # The lock file object must be closed (fd released) after stop.
      lock = File.open(File.join(temp_dir, 'lich-active-sessions.lock'), File::RDWR | File::CREAT, 0o600)
      expect(lock.flock(File::LOCK_EX | File::LOCK_NB)).to be_truthy
      lock.flock(File::LOCK_UN)
      lock.close
    end
  end

  describe 'admitted lifecycle paths' do
    it 'registers via an already-admitted path without re-reading the flag' do
      client = instance_double(Lich::InternalAPI::ActiveSessions::Client, ping: true, upsert: { ok: true })
      allow(Lich::InternalAPI::ActiveSessions::Client).to receive(:new).and_return(client)
      write_discovery_file(owner_pid: 123, auth_token: 'shared-token', port: 48_000)

      expect(described_class).not_to receive(:enabled?)
      expect(described_class.send(:register_session_admitted, { pid: 12_345 })).to be(true)
    end

    it 'bootstraps a replacement owner from admitted registration when no service remains' do
      client = instance_double(Lich::InternalAPI::ActiveSessions::Client, ping: false, upsert: { ok: true })
      allow(Lich::InternalAPI::ActiveSessions::Client).to receive(:new).and_return(client)
      allow(Lich::InternalAPI::ActiveSessions::Server).to receive(:new)
        .and_return(server_double(auth_token: 'failover-token', port: 44_000))

      expect(described_class).to receive(:enabled?).and_return(true)
      expect(described_class.send(:register_session_admitted, { pid: Process.pid })).to be(true)

      discovery = read_discovery
      expect(discovery[:owner_pid]).to eq(Process.pid)
      expect(discovery[:auth_token]).to eq('failover-token')
      expect(discovery[:port]).to eq(44_000)
    end

    it 'does not bootstrap from an admitted path when the kill switch is off' do
      allow(described_class).to receive(:enabled?).and_return(false)

      expect(Lich::InternalAPI::ActiveSessions::Server).not_to receive(:new)
      expect(described_class.send(:register_session_admitted, { pid: Process.pid })).to be(false)
    end

    it 'reuses an existing service from a non-bootstrapping admitted path' do
      allow(Lich::InternalAPI::ActiveSessions::Client).to receive(:new)
        .and_return(instance_double(Lich::InternalAPI::ActiveSessions::Client, ping: true))
      write_discovery_file(owner_pid: 123, auth_token: 'shared-token', port: 48_000)

      expect(described_class).not_to receive(:enabled?)
      expect(Lich::InternalAPI::ActiveSessions::Server).not_to receive(:new)
      expect(described_class.send(:ensure_service_internal!, allow_bootstrap: false)).to be(true)
    end

    it 'does not bootstrap from a non-bootstrapping admitted path when unreachable' do
      allow(Lich::InternalAPI::ActiveSessions::Client).to receive(:new)
        .and_return(instance_double(Lich::InternalAPI::ActiveSessions::Client, ping: false))

      expect(described_class).not_to receive(:enabled?)
      expect(Lich::InternalAPI::ActiveSessions::Server).not_to receive(:new)
      expect(described_class.send(:ensure_service_internal!, allow_bootstrap: false)).to be(false)
    end

    it 'unregisters via an already-admitted path without re-reading the flag' do
      client = instance_double(Lich::InternalAPI::ActiveSessions::Client, ping: true, remove: { ok: true })
      allow(Lich::InternalAPI::ActiveSessions::Client).to receive(:new).and_return(client)
      write_discovery_file(owner_pid: 123, auth_token: 'shared-token', port: 48_000)

      expect(described_class).not_to receive(:enabled?)
      expect(Lich::InternalAPI::ActiveSessions::Server).not_to receive(:new)
      expect(described_class.send(:unregister_session_admitted, pid: 12_345)).to be(true)
    end
  end

  describe 'public gate + read-only query' do
    it 'honors the disabled gate on the public API surface' do
      allow(described_class).to receive(:enabled?).and_return(false)

      expect(described_class.register_session({ pid: 12_345 })).to be(false)
      expect(described_class.unregister_session(pid: 12_345)).to be(false)
      expect(described_class.ensure_service!).to be(false)
    end

    it 'queries a discovered service without consulting the feature flag' do
      client = instance_double(Lich::InternalAPI::ActiveSessions::Client)
      allow(client).to receive(:snapshot).and_return(
        ok: true,
        payload: { source: 'ActiveSessionsAPI', total: 1, connected: 1, detachable: 1, sessions: [{ session_name: 'Char1' }] }
      )
      allow(Lich::InternalAPI::ActiveSessions::Client).to receive(:new).and_return(client)
      write_discovery_file(owner_pid: 123, auth_token: 'shared-token', port: 48_000)

      allow(described_class).to receive(:enabled?).and_return(false)
      expect(described_class.query_snapshot[:total]).to eq(1)
    end

    it 'reports unavailable when discovery lacks a published port' do
      File.write(discovery_file, JSON.dump(owner_pid: 123, auth_token: 'portless', updated_at: Time.now.to_i))

      expect(described_class.query_snapshot[:error]).to eq('active sessions service unavailable')
    end
  end

  describe 'ownership lock is close-on-exec' do
    it 'holds the lock file close-on-exec so a reconnect exec cannot inherit it' do
      allow(Lich::InternalAPI::ActiveSessions::Client)
        .to receive(:new).and_return(instance_double(Lich::InternalAPI::ActiveSessions::Client, ping: false))
      allow(Lich::InternalAPI::ActiveSessions::Server)
        .to receive(:new).and_return(server_double(auth_token: 'owner-token', port: 40_000))

      expect(described_class.ensure_service!).to be(true)

      lock_file = described_class.instance_variable_get(:@lock_file)
      expect(lock_file).not_to be_nil
      expect(lock_file.close_on_exec?).to be(true)
    end
  end

  # Exercises the crash-safety guarantee the whole design rests on: the kernel
  # releases an advisory lock when its holder dies, so a successor can take over
  # a lock a departed owner never got to release. This needs a real second
  # process, so it is skipped where process spawning/signals are unavailable.
  describe 'cross-process ownership handoff (integration)' do
    it 'grants the lock to a successor after the holder is killed' do
      skip 'requires process spawn + signals' unless Process.respond_to?(:kill)

      lock = File.join(temp_dir, 'lich-active-sessions.lock')
      reader, writer = IO.pipe
      holder = spawn(
        RbConfig.ruby, '-e',
        "f = File.open(#{lock.inspect}, File::RDWR | File::CREAT, 0o600); " \
        "f.flock(File::LOCK_EX); $stdout.puts('locked'); $stdout.flush; sleep 30",
        out: writer
      )
      writer.close
      # Normalize the line ending: a child on a CRLF platform emits "locked\r\n".
      expect(reader.gets.to_s.chomp).to eq('locked')

      # Denied while the external holder is alive.
      expect(described_class.send(:acquire_ownership_lock)).to be(false)

      Process.kill('KILL', holder)
      Process.wait(holder)
      holder = nil

      # Granted once the kernel releases the dead holder's lock.
      expect(described_class.send(:acquire_ownership_lock)).to be(true)
    ensure
      reader&.close
      if holder
        Process.kill('KILL', holder) rescue nil
        Process.wait(holder) rescue nil
      end
    end
  end
end
