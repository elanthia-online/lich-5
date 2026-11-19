# frozen_string_literal: true

module GenieSpecSupport
  # A fake Interpreter input on a virtual clock (a one-element Array the spec's clock port
  # reads), modelled on Lich's LimitedArray#wait_shift: the queued items arrive +gap+ seconds
  # apart (the first one +gap+ after the start); a read returns the next item once it has
  # arrived within the read's timeout (moving the clock to its arrival), else moves the clock
  # by the timeout and returns nil. A read with no timeout and nothing left raises (the script
  # would block forever), as does the +limit+-th empty read.
  #
  # A game line opens a DR packet and the interpreter resumes only once the packet is
  # over (its prompt, or Interpreter::CHUNK_IDLE_SECONDS with no further game item): a +gap+
  # above that makes every line its own packet; 0 makes them all one packet.
  class TimedInput
    # @return [Array] the items not read yet
    attr_reader :items

    # @param items [Array]
    # @param clock [Array<Float>]
    # @param gap [Float]
    # @param limit [Integer]
    def initialize(items, clock:, gap: 0.0, limit: 1000)
      @items = items.dup
      @clock = clock
      @gap = gap
      @limit = limit
      @arrival = clock[0] + gap
      @empty_reads = 0
    end

    def next_line(timeout: nil)
      if !@items.empty? && (timeout.nil? || @arrival <= @clock[0] + timeout)
        @clock[0] = [@clock[0], @arrival].max
        @arrival = @clock[0] + @gap
        return @items.shift
      end

      @empty_reads += 1
      raise 'input exhausted (script waited with no more input)' if timeout.nil? || @empty_reads > @limit

      @clock[0] += timeout
      nil
    end
  end
end
