# Carve out class SharedBuffer
# 2024-06-13
# has rubocop Lint/HashCompareByIdentity errors that require research - temporarily disabled

require_relative 'throttle'

module Lich
  module Common
    class SharedBuffer
      attr_accessor :max_size

      def initialize(args = {})
        @buffer = Array.new
        @buffer_offset = 0
        @buffer_index = Hash.new
        @buffer_mutex = Mutex.new
        @max_size = args[:max_size] || 500
        # Sweeps dead-thread entries from @buffer_index (keyed by
        # Thread#object_id, previously never pruned) at most once every 60s.
        @cleanup_throttle = Throttle.new(60.0)
        # return self # rubocop does not like this - Lint/ReturnInVoidContext
      end

      def gets
        thread_id = Thread.current.object_id
        if @buffer_index[thread_id].nil?
          @buffer_mutex.synchronize { @buffer_index[thread_id] = (@buffer_offset + @buffer.length) }
          maybe_cleanup_threads
        end
        if (@buffer_index[thread_id] - @buffer_offset) >= @buffer.length
          sleep 0.05 while ((@buffer_index[thread_id] - @buffer_offset) >= @buffer.length)
        end
        line = nil
        @buffer_mutex.synchronize {
          if @buffer_index[thread_id] < @buffer_offset
            @buffer_index[thread_id] = @buffer_offset
          end
          line = @buffer[@buffer_index[thread_id] - @buffer_offset]
        }
        @buffer_index[thread_id] += 1
        return line
      end

      def gets?
        thread_id = Thread.current.object_id
        if @buffer_index[thread_id].nil?
          @buffer_mutex.synchronize { @buffer_index[thread_id] = (@buffer_offset + @buffer.length) }
          maybe_cleanup_threads
        end
        if (@buffer_index[thread_id] - @buffer_offset) >= @buffer.length
          return nil
        end

        line = nil
        @buffer_mutex.synchronize {
          if @buffer_index[thread_id] < @buffer_offset
            @buffer_index[thread_id] = @buffer_offset
          end
          line = @buffer[@buffer_index[thread_id] - @buffer_offset]
        }
        @buffer_index[thread_id] += 1
        return line
      end

      def clear
        thread_id = Thread.current.object_id
        if @buffer_index[thread_id].nil?
          @buffer_mutex.synchronize { @buffer_index[thread_id] = (@buffer_offset + @buffer.length) }
          maybe_cleanup_threads
          return Array.new
        end
        if (@buffer_index[thread_id] - @buffer_offset) >= @buffer.length
          return Array.new
        end

        lines = Array.new
        @buffer_mutex.synchronize {
          if @buffer_index[thread_id] < @buffer_offset
            @buffer_index[thread_id] = @buffer_offset
          end
          lines = @buffer[(@buffer_index[thread_id] - @buffer_offset)..-1]
          @buffer_index[thread_id] = (@buffer_offset + @buffer.length)
        }
        return lines
      end

      # rubocop:disable Lint/HashCompareByIdentity
      def rewind
        # Hold the mutex: a first-call rewind adds a new key, which must not
        # race a concurrent cleanup_threads delete_if.
        @buffer_mutex.synchronize { @buffer_index[Thread.current.object_id] = @buffer_offset }
        return self
      end

      # rubocop:enable Lint/HashCompareByIdentity
      def update(line)
        @buffer_mutex.synchronize {
          fline = line.dup
          fline.freeze
          @buffer.push(fline)
          while (@buffer.length > @max_size)
            @buffer.shift
            @buffer_offset += 1
          end
        }
        return self
      end

      # Removes @buffer_index entries whose thread is no longer alive.
      # Snapshots the live thread ids once rather than recomputing them per
      # entry, and holds the mutex so it cannot race with a concurrent reader
      # mutating the hash.
      def cleanup_threads
        @buffer_mutex.synchronize {
          live_ids = Thread.list.map(&:object_id)
          @buffer_index.delete_if { |k, _v| !live_ids.include?(k) }
        }
        return self
      end

      # Throttled automatic {#cleanup_threads}, invoked from the
      # thread-registration path so dead-thread entries do not accumulate over a
      # long session. Must be called outside @buffer_mutex (cleanup_threads
      # acquires it; Ruby mutexes are not reentrant).
      def maybe_cleanup_threads
        @cleanup_throttle.run { cleanup_threads }
      end
      private :maybe_cleanup_threads
    end
  end
end
