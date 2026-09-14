# Carve out from lich.rbw
# class LimitedArray 2024-06-13

module Lich
  module Common
    # Bounded script buffer with condition-variable-backed blocking reads.
    class LimitedArray < Array
      SYNCHRONIZED_ARRAY_MUTATORS = %i[
        collect! compact! delete delete_at delete_if filter! keep_if map! pop
        reject! reverse! rotate! select! shuffle! slice! sort! sort_by! uniq!
      ].freeze
      ENUMERATOR_MUTATORS = %i[collect! delete_if filter! keep_if map! reject! select! sort_by!].freeze

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
        trim_front_locked
      end

      def max_size
        synchronize { @max_size }
      end

      def max_size=(value)
        unless value.is_a?(Integer) && value.positive?
          raise ArgumentError, 'max_size must be a positive Integer'
        end

        synchronize do
          @max_size = value
          trim_front_locked
        end
      end

      def push(*lines)
        synchronize do
          result = RAW_PUSH.bind_call(self, *lines)
          trim_front_locked
          condition.broadcast unless lines.empty?
          result
        end
      end
      alias_method :<<, :push
      alias_method :append, :push

      def unshift(*lines)
        synchronize do
          result = RAW_UNSHIFT.bind_call(self, *lines)
          RAW_POP.bind_call(self) while RAW_LENGTH.bind_call(self) > @max_size
          condition.broadcast unless lines.empty?
          result
        end
      end
      alias_method :prepend, :unshift

      def concat(other)
        bounded_mutation(:concat, other)
      end

      def replace(other)
        bounded_mutation(:replace, other)
      end

      def insert(index, *objects)
        bounded_mutation(:insert, index, *objects)
      end

      def []=(*args)
        bounded_mutation(:[]=, *args)
      end

      def fill(*args, &block)
        bounded_mutation(:fill, *args, &block)
      end

      def flatten!(*args)
        bounded_mutation(:flatten!, *args)
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

      SYNCHRONIZED_ARRAY_MUTATORS.each do |method_name|
        define_method(method_name) do |*args, &block|
          return enum_for(method_name, *args) if block.nil? && ENUMERATOR_MUTATORS.include?(method_name)

          synchronize do
            Array.instance_method(method_name).bind_call(self, *args, &block)
          end
        end
      end

      private

      def initialize_copy(original)
        super
        @mutex = Mutex.new
        @condition = ConditionVariable.new
      end

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

      def bounded_mutation(method_name, *args, &block)
        synchronize do
          result = Array.instance_method(method_name).bind_call(self, *args, &block)
          trim_front_locked
          condition.broadcast unless RAW_EMPTY.bind_call(self)
          result
        end
      end

      def trim_front_locked
        RAW_SHIFT.bind_call(self) while RAW_LENGTH.bind_call(self) > @max_size
      end

      def monotonic_time
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end
