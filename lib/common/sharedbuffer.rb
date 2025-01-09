# Carve out class SharedBuffer
# 2024-06-13
# has rubocop Lint/HashCompareByIdentity errors that require research - temporarily disabled

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
        # return self # rubocop does not like this - Lint/ReturnInVoidContext
      end

      def gets
        thread_id = Thread.current.object_id
        if @buffer_index[thread_id].nil?
          @buffer_mutex.synchronize { @buffer_index[thread_id] = (@buffer_offset + @buffer.length) }
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
        @buffer_index[Thread.current.object_id] = @buffer_offset
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

      def cleanup_threads
        @buffer_index.delete_if { |k, _v| not Thread.list.any? { |t| t.object_id == k } }
        return self
      end
    end
  end
end
