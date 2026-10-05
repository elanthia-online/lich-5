# frozen_string_literal: true

module Lich
  module Common
    # Prompt-acked flow control for commands sent to the game server.
    #
    # The server counts typed-ahead commands per connection and discards any
    # beyond its cap ("Sorry, you may only type ahead N commands."). Scripts,
    # the frontend, and fput all share that one cap, so one window sits at the
    # single choke point (Game._puts). Commands are released in FIFO order,
    # never reordered or dropped; each game prompt retires the oldest
    # in-flight command, and a command that draws no prompt expires.
    #
    # Callers pass a writer block that performs the real socket write.
    # Waiting callers (script threads) run their own writer once granted a
    # turn, so per-script execution guards still run on the script's thread.
    # Non-waiting callers (game reader/parser and client threads) return at
    # once and their writer runs on the gate thread.
    #
    # The window starts at MAX_WINDOW and only learns down: the first
    # "type ahead N" refusal sets it to N+1. Learning up would need repeated
    # over-cap probes, each costing a refused command; starting high costs at
    # most one refusal per connection on low-cap accounts.
    #
    # Deliberately no roundtime hold and no resend: the cap is pure queue flow
    # control, and resending a command another sender's overflow got rejected
    # would double-execute it.
    class UpstreamGate
      MAX_WINDOW = 4
      DEFAULT_WINDOW = MAX_WINDOW
      EXPIRY_SECONDS = 2.0
      # Anchored (past any leading tags) so room speech quoting the line
      # cannot resize the window.
      TYPEAHEAD_REJECT = /\A(?:<[^>]*>|&gt;|\s)*Sorry, you may only type ahead (\d+) command/

      Entry = Struct.new(:writer, :exempt, :wait, :state, :sent_at)

      attr_reader :window

      # @param expiry [Numeric] seconds before an unacked command stops counting
      def initialize(expiry: EXPIRY_SECONDS)
        @expiry = expiry
        @lock = Mutex.new
        @cond = ConditionVariable.new
        @queue = []
        @in_flight = []
        @window = DEFAULT_WINDOW
        @primed = false
        @stopped = false
        @thread = Thread.new { run }
        @thread.name = 'upstream gate' if @thread.respond_to?(:name=)
      end

      # Whether a command skips the window: the server does not count
      # underscore commands, and blank/raw-XML lines are not typed commands.
      #
      # @param command [String]
      # @return [Boolean]
      def self.exempt?(command)
        cmd = command.to_s.sub(/\A<c>/, '').strip
        cmd.empty? || cmd.start_with?('_', '<')
      end

      # Send a command through the window.
      #
      # @param command [String] the wire command (used only for classification)
      # @param wait [Boolean] block until this command's writer has run
      # @yieldreturn [true, nil] the writer's result
      # @return [true, nil] the writer's result, or true when queued for later
      def submit(command, wait:, &writer)
        exempt = self.class.exempt?(command)
        wait &&= !exempt # exempt sends may come from lock holders; never park them
        entry = Entry.new(writer, exempt, wait, :queued, nil)

        direct = @lock.synchronize do
          next true if !@primed || @stopped

          expire
          if @queue.empty? && slot_for?(entry)
            count(entry)
            true
          else
            @queue << entry
            @cond.broadcast
            false
          end
        end
        return write(entry) if direct
        return true unless wait

        await(entry)
      end

      # Feed one raw server line (called from the game socket reader thread).
      #
      # @param line [String]
      # @return [void]
      def observe(line)
        prompt = line.include?('<prompt')
        reject = TYPEAHEAD_REJECT.match(line) if line.include?('type ahead')
        return unless prompt || reject

        @lock.synchronize do
          @window = (reject[1].to_i + 1).clamp(1, MAX_WINDOW) if reject
          if prompt
            @primed = true
            @in_flight.shift
          end
          @cond.broadcast
        end
      end

      # Stop the gate thread and release any waiting callers.
      #
      # @return [void]
      def stop
        @lock.synchronize do
          @stopped = true
          @cond.broadcast
        end
        @thread.join(1) unless Thread.current == @thread
      end

      private

      def run
        @lock.synchronize do
          until @stopped
            expire
            entry = @queue.first
            if entry && slot_for?(entry)
              count(entry)
              if entry.wait
                entry.state = :granted
                @cond.broadcast
                @cond.wait(@lock) until entry.state == :done || @stopped
                @queue.shift
              else
                # Stays queue head while writing so a concurrent submit queues
                # behind it instead of racing it to the socket.
                @lock.unlock
                begin
                  write(entry)
                ensure
                  @lock.lock
                  @queue.shift
                end
              end
            else
              @cond.wait(@lock, next_wakeup)
            end
          end
        end
      rescue Exception => e # rubocop:disable Lint/RescueException
        # A dead gate must not park every script's put: fall back to pass-through.
        Lich.log "error: upstream gate stopped: #{e.class}: #{e.message}" if defined?(Lich.log)
        @lock.synchronize do
          @stopped = true
          @cond.broadcast
        end
      end

      # Runs on a waiting caller's thread until its turn, then writes.
      def await(entry)
        @lock.synchronize do
          @cond.wait(@lock) until entry.state == :granted || @stopped
        end
        write(entry)
      ensure
        # Killed or interrupted before writing: never leave the gate parked.
        # A granted entry is still the gate thread's queue head; it shifts it.
        @lock.synchronize do
          unless entry.state == :done
            @queue.delete_if { |e| e.equal?(entry) } if entry.state == :queued
            @in_flight.delete_if { |e| e.equal?(entry) }
            entry.state = :done
            @cond.broadcast
          end
        end
      end

      def write(entry)
        ok = false
        result = entry.writer.call
        ok = !result.nil?
        result
      rescue StandardError => e
        raise unless Thread.current == @thread

        Lich.log "error: upstream gate: #{e.class}: #{e.message}" if defined?(Lich.log)
        nil
      ensure
        @lock.synchronize do
          @in_flight.delete_if { |e| e.equal?(entry) } unless ok
          entry.state = :done
          @cond.broadcast
        end
      end

      def slot_for?(entry)
        entry.exempt || @in_flight.length < @window
      end

      def count(entry)
        return if entry.exempt

        entry.sent_at = now
        @in_flight << entry
      end

      def expire
        cutoff = now - @expiry
        # ponytail: every unsolicited prompt (combat, arrivals) retires a slot
        # early, so prompt spam leaks one over-cap command per stray prompt
        # until the window drains; fput/move's refusal retry covers it.
        @in_flight.reject! { |e| e.sent_at < cutoff }
      end

      def next_wakeup
        oldest = @in_flight.first
        oldest ? [oldest.sent_at + @expiry - now, 0.01].max : nil
      end

      def now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end
