# Carve out from lich.rbw
# class LimitedArray 2024-06-13

module Lich
  module Common
    # Bounded script buffer with condition-variable-backed blocking reads.
    class LimitedArray < Array
      attr_accessor :max_size

      RAW_PUSH    = Array.instance_method(:push)
      RAW_UNSHIFT = Array.instance_method(:unshift)
      RAW_SHIFT   = Array.instance_method(:shift)
      RAW_POP     = Array.instance_method(:pop)
      RAW_EMPTY   = Array.instance_method(:empty?)
      RAW_LENGTH  = Array.instance_method(:length)
      RAW_CLEAR   = Array.instance_method(:clear)
      RAW_DUP     = Array.instance_method(:dup)

      INIT_MUTEX = Mutex.new

      def initialize(size = 0, obj = nil)
        @max_size = 200
        super
      end

      def push(line)
        synchronize do
          RAW_SHIFT.bind_call(self) while RAW_LENGTH.bind_call(self) >= @max_size
          result = RAW_PUSH.bind_call(self, line)
          condition.broadcast
          result
        end
      end

      def unshift(*lines)
        synchronize do
          result = RAW_UNSHIFT.bind_call(self, *lines)
          RAW_POP.bind_call(self) while RAW_LENGTH.bind_call(self) > @max_size
          condition.broadcast unless lines.empty?
          result
        end
      end

      def shove(line)
        push(line)
      end

      def history
        Array.new
      end

      def shift(*args)
        synchronize { RAW_SHIFT.bind_call(self, *args) }
      end

      def empty?
        synchronize { RAW_EMPTY.bind_call(self) }
      end

      def clear
        synchronize { RAW_CLEAR.bind_call(self) }
      end

      def dup
        synchronize { RAW_DUP.bind_call(self) }
      end

      # Wait for and remove the next item, returning nil when timeout expires.
      def wait_shift(timeout = nil)
        mutex.synchronize do
          deadline = monotonic_time + timeout.to_f if timeout
          while RAW_EMPTY.bind_call(self)
            remaining = deadline && deadline - monotonic_time
            return nil if remaining && remaining <= 0

            condition.wait(mutex, remaining)
          end
          RAW_SHIFT.bind_call(self)
        end
      end

      def try_shift
        synchronize do
          return nil if RAW_EMPTY.bind_call(self)

          RAW_SHIFT.bind_call(self)
        end
      end

      def clear_snapshot
        synchronize do
          snapshot = RAW_DUP.bind_call(self)
          RAW_CLEAR.bind_call(self)
          snapshot
        end
      end

      private

      def initialize_synchronization
        return if @mutex && @condition

        INIT_MUTEX.synchronize do
          @mutex ||= Mutex.new
          @condition ||= ConditionVariable.new
        end
      end

      def mutex
        initialize_synchronization
        @mutex
      end

      def condition
        initialize_synchronization
        @condition
      end

      def synchronize(&block)
        mutex.synchronize(&block)
      end

      def monotonic_time
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end
