# frozen_string_literal: true

# Standalone synthetic process: no game boot, credentials, or user settings.
require 'json'

ACTIVE_SESSION_DIR = ARGV.fetch(0)
require_relative '../../lib/internal_api/active_sessions'

module CoordinationHandoffChild
  SERVICE = Lich::InternalAPI::ActiveSessions
  DISCOVERY = File.join(ACTIVE_SESSION_DIR, SERVICE::DISCOVERY_FILENAME)

  class << self
    attr_accessor :publication_barrier, :cleanup_barrier, :sharing_violation_barrier, :read_sharing_violation

    def emit(event, fields = {})
      STDOUT.puts(JSON.dump(fields.merge(event: event)))
    end

    def barrier(event)
      emit(event)
      raise 'barrier release missing' unless STDIN.gets&.strip == 'release'
    end

    def observe
      record = JSON.parse(File.read(DISCOVERY))
      valid = record.is_a?(Hash) && record['owner_pid'].is_a?(Integer) &&
              record['port'].is_a?(Integer) && record['port'].positive? &&
              record['auth_token'].is_a?(String) && !record['auth_token'].empty? &&
              record['updated_at'].is_a?(Integer)
      { record: record, malformed: !valid }
    rescue Errno::ENOENT
      { missing: true }
    rescue Errno::EACCES
      { inaccessible: true }
    rescue JSON::ParserError
      { malformed: true }
    end

    def state
      {
        owns_lock: SERVICE.send(:own_lock?),
        owns_server: SERVICE.send(:owns_running_server?),
        observation: observe
      }
    end
  end

  # Pause the real publication after its temporary file is complete, and the
  # real cleanup after its ownership check. Election, locks, TCP and JSON are
  # otherwise the production implementations in independent Ruby processes.
  module FileBarriers
    def read(path, *args, **kwargs)
      if path == CoordinationHandoffChild::DISCOVERY && CoordinationHandoffChild.read_sharing_violation
        CoordinationHandoffChild.read_sharing_violation = false
        raise Errno::EACCES, 'synthetic read sharing violation'
      end

      super
    end

    def rename(source, destination)
      if destination == CoordinationHandoffChild::DISCOVERY && CoordinationHandoffChild.publication_barrier
        CoordinationHandoffChild.publication_barrier = false
        CoordinationHandoffChild.barrier('publication_pending')
      end
      super
    rescue Errno::EACCES
      if destination == CoordinationHandoffChild::DISCOVERY && CoordinationHandoffChild.sharing_violation_barrier
        CoordinationHandoffChild.sharing_violation_barrier = false
        CoordinationHandoffChild.barrier('sharing_violation')
      end
      raise
    end

    def delete(*paths)
      if paths.include?(CoordinationHandoffChild::DISCOVERY) && CoordinationHandoffChild.cleanup_barrier
        CoordinationHandoffChild.cleanup_barrier = false
        CoordinationHandoffChild.barrier('cleanup_pending')
      end
      super
    rescue Errno::EACCES
      if paths.include?(CoordinationHandoffChild::DISCOVERY) && CoordinationHandoffChild.sharing_violation_barrier
        CoordinationHandoffChild.sharing_violation_barrier = false
        CoordinationHandoffChild.barrier('sharing_violation')
      end
      raise
    end
  end
end

File.singleton_class.prepend(CoordinationHandoffChild::FileBarriers)
STDOUT.sync = true
worker = CoordinationHandoffChild
watcher = nil
watch_mutex = Mutex.new
observations = { reads: 0, valid: 0, malformed: 0, missing: 0, inaccessible: 0, owners: [], errors: [] }
worker.emit('ready', pid: Process.pid)

begin
  while (command = STDIN.gets&.strip)
    case command
    when 'arm_publication'
      worker.publication_barrier = true
      worker.emit('armed')
    when 'arm_cleanup'
      worker.cleanup_barrier = true
      worker.emit('armed')
    when 'arm_sharing_violation'
      worker.sharing_violation_barrier = true
      worker.emit('armed')
    when 'arm_read_sharing_violation'
      worker.read_sharing_violation = true
      worker.emit('armed')
    when 'hold_discovery'
      File.open(worker::DISCOVERY, 'rb') do
        worker.barrier('discovery_held')
      end
      worker.emit('discovery_released')
    when 'probe_lock'
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      acquired = worker::SERVICE.send(:acquire_ownership_lock)
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
      worker.emit('lock_probed', acquired: acquired, elapsed: elapsed)
    when 'ensure'
      available = worker::SERVICE.ensure_service!
      worker.emit('ensured', worker.state.merge(available: available))
    when 'state'
      worker.emit('state', worker.state)
    when 'sample'
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      snapshot = worker::SERVICE.query_snapshot
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
      worker.emit('sample', worker.state.merge(snapshot: snapshot, elapsed: elapsed))
    when 'watch'
      raise 'watch already started' if watcher

      watcher = Thread.new do
        begin
          loop do
            observation = worker.observe
            watch_mutex.synchronize do
              observations[:reads] += 1
              observations[:valid] += 1 if observation[:record] && !observation[:malformed]
              observations[:malformed] += 1 if observation[:malformed]
              observations[:missing] += 1 if observation[:missing]
              observations[:inaccessible] += 1 if observation[:inaccessible]
              owner = observation.dig(:record, 'owner_pid')
              observations[:owners] |= [owner] if owner
            end
            sleep 0.001
          end
        rescue StandardError => e
          watch_mutex.synchronize { observations[:errors] << "#{e.class}: #{e.message}" }
        end
      end
      worker.emit('watching')
    when 'observations'
      watch_mutex.synchronize { worker.emit('observations', observations) }
    when 'stop'
      worker::SERVICE.stop_service!
      worker.emit('stopped', worker.state)
    when 'quit'
      break
    else
      raise "unknown fixture command: #{command.inspect}"
    end
  end
ensure
  watcher&.kill
  watcher&.join
end
