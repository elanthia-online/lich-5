# Carve out module Buffer
# 2024-06-13
# has rubocop error Lint/HashCompareByIdentity - cop disabled until reviewed

require_relative 'throttle'

module Lich
  module Common
    module Buffer
      DOWNSTREAM_STRIPPED = 1
      DOWNSTREAM_RAW      = 2
      DOWNSTREAM_MOD      = 4
      UPSTREAM            = 8
      UPSTREAM_MOD        = 16
      SCRIPT_OUTPUT       = 32
      @@index             = Hash.new
      @@streams           = Hash.new
      @@mutex             = Mutex.new
      @@offset            = 0
      @@buffer            = Array.new
      @@max_size          = 3000
      # @@index / @@streams are keyed by Thread#object_id and were never pruned,
      # so every thread that ever read the buffer leaked an entry that outlived
      # it. maybe_cleanup sweeps dead-thread entries from the registration path,
      # at most once every 60s via this throttle.
      @@cleanup_throttle  = Throttle.new(60.0)
      def Buffer.gets
        thread_id = Thread.current.object_id
        if @@index[thread_id].nil?
          @@mutex.synchronize {
            @@index[thread_id] = (@@offset + @@buffer.length)
            @@streams[thread_id] ||= DOWNSTREAM_STRIPPED
          }
          maybe_cleanup
        end
        line = nil
        loop {
          if (@@index[thread_id] - @@offset) >= @@buffer.length
            sleep 0.05 while ((@@index[thread_id] - @@offset) >= @@buffer.length)
          end
          @@mutex.synchronize {
            if @@index[thread_id] < @@offset
              @@index[thread_id] = @@offset
            end
            line = @@buffer[@@index[thread_id] - @@offset]
          }
          @@index[thread_id] += 1
          break if ((line.stream & @@streams[thread_id]) != 0)
        }
        return line
      end

      def Buffer.gets?
        thread_id = Thread.current.object_id
        if @@index[thread_id].nil?
          @@mutex.synchronize {
            @@index[thread_id] = (@@offset + @@buffer.length)
            @@streams[thread_id] ||= DOWNSTREAM_STRIPPED
          }
          maybe_cleanup
        end
        line = nil
        loop {
          if (@@index[thread_id] - @@offset) >= @@buffer.length
            return nil
          end

          @@mutex.synchronize {
            if @@index[thread_id] < @@offset
              @@index[thread_id] = @@offset
            end
            line = @@buffer[@@index[thread_id] - @@offset]
          }
          @@index[thread_id] += 1
          break if ((line.stream & @@streams[thread_id]) != 0)
        }
        return line
      end

      def Buffer.rewind
        thread_id = Thread.current.object_id
        # Hold the mutex: for a thread whose first Buffer call is rewind this
        # adds new keys, which must not race a concurrent cleanup delete_if
        # (Ruby raises on a key added during iteration).
        @@mutex.synchronize {
          @@index[thread_id] = @@offset
          @@streams[thread_id] ||= DOWNSTREAM_STRIPPED
        }
        return self
      end

      def Buffer.clear
        thread_id = Thread.current.object_id
        if @@index[thread_id].nil?
          @@mutex.synchronize {
            @@index[thread_id] = (@@offset + @@buffer.length)
            @@streams[thread_id] ||= DOWNSTREAM_STRIPPED
          }
          maybe_cleanup
        end
        lines = Array.new
        loop {
          if (@@index[thread_id] - @@offset) >= @@buffer.length
            return lines
          end

          line = nil
          @@mutex.synchronize {
            if @@index[thread_id] < @@offset
              @@index[thread_id] = @@offset
            end
            line = @@buffer[@@index[thread_id] - @@offset]
          }
          @@index[thread_id] += 1
          lines.push(line) if ((line.stream & @@streams[thread_id]) != 0)
        }
        return lines
      end

      def Buffer.update(line, stream = nil)
        @@mutex.synchronize {
          frozen_line = line.dup
          unless stream.nil?
            frozen_line.stream = stream
          end
          frozen_line.freeze
          @@buffer.push(frozen_line)
          while (@@buffer.length > @@max_size)
            @@buffer.shift
            @@offset += 1
          end
        }
        return self
      end

      # rubocop:disable Lint/HashCompareByIdentity
      def Buffer.streams
        @@streams[Thread.current.object_id]
      end

      def Buffer.streams=(val)
        if (!val.is_a?(Integer)) or ((val & 63) == 0)
          respond "--- Lich: error: invalid streams value\n\t#{$!.caller[0..2].join("\n\t")}"
        else
          @@streams[Thread.current.object_id] = val
        end
      end

      # rubocop:enable Lint/HashCompareByIdentity
      # Removes @@index / @@streams entries whose thread is no longer alive.
      # Snapshots the live thread ids once rather than recomputing them per
      # entry, and holds the mutex so it cannot race with a concurrent reader
      # mutating the same hashes.
      def Buffer.cleanup
        @@mutex.synchronize {
          live_ids = Thread.list.map(&:object_id)
          @@index.delete_if { |k, _v| !live_ids.include?(k) }
          @@streams.delete_if { |k, _v| !live_ids.include?(k) }
        }
        return self
      end

      # Throttled automatic {Buffer.cleanup}, invoked from the thread-registration
      # path so dead-thread entries do not accumulate over a long session. Must
      # be called outside @@mutex (cleanup acquires it; Ruby mutexes are not
      # reentrant).
      def Buffer.maybe_cleanup
        @@cleanup_throttle.run { cleanup }
      end
      private_class_method :maybe_cleanup
    end
  end
end
