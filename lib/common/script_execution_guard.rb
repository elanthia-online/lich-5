# frozen_string_literal: true

module Lich
  module Common
    # Optional cooperative execution policy for one script. This is not a
    # sandbox: the caller owns installing checkpoints and the guarded send.
    class ScriptExecutionGuard
      class Interrupted < StandardError
        attr_reader :reason

        # Build an interruption without retaining a rejected command payload.
        # @param reason [Symbol] cancellation identifier supplied by the guard
        # @return [Interrupted] the interruption
        def initialize(reason)
          @reason = reason
          super("Script execution interrupted: #{reason}")
        end
      end

      # Create a policy whose first denial remains latched until disposal.
      # @param callback [Proc] observation-only policy accepting a command or nil
      # @param allow_script_starts [Boolean] whether guarded workers may launch scripts
      # @return [ScriptExecutionGuard] the uninstalled policy guard
      # @raise [ArgumentError] if callback is not a Proc
      def initialize(callback, allow_script_starts: true)
        raise ArgumentError, 'execution guard requires a Proc' unless callback.is_a?(Proc)
        unless allow_script_starts.equal?(true) || allow_script_starts.equal?(false)
          raise ArgumentError, 'allow_script_starts must be true or false'
        end

        @callback = callback
        @allow_script_starts = allow_script_starts
        @mutex = Mutex.new
        @reason = nil
        @callbacks = {}
      end

      # A nil command is a cooperative checkpoint; a String is an impending
      # send. Only literal true permits continuation. Callbacks may inspect
      # Script.current (which checks again), but may not send recursively.
      # @param command [String, nil] exact wire command, or nil for a checkpoint
      # @return [true] when the policy permits continuation
      # @raise [Interrupted] on cancellation, invalid input, callback failure,
      #   recursive command dispatch, or a result other than literal true
      def checkpoint!(command: nil)
        unless command.nil? || command.is_a?(String)
          cancel!(:invalid_command)
          check_cancelled!
        end

        thread = Thread.current
        entered = @mutex.synchronize do
          interrupt! if @reason
          if @callbacks.key?(thread)
            if command.nil?
              false
            else
              @reason = :reentrant_command
              interrupt!
            end
          else
            @callbacks[thread] = true
            true
          end
        end
        return true unless entered

        accepted = false
        begin
          accepted = @callback.call(command&.dup&.freeze)
        rescue Exception # rubocop:disable Lint/RescueException
          # Callback failures must latch, including script-defined exceptions;
          # never expose their message, backtrace, cause, or command payload.
          cancel!(:callback_error)
        ensure
          @mutex.synchronize { @callbacks.delete(thread) }
          cancel!(command.nil? ? :checkpoint_rejected : :command_rejected) unless accepted.equal?(true)
        end
        check_cancelled!
        true
      end

      # The first cancellation wins across all threads using this guard.
      # Reasons are short identifiers, never raw commands or exception text.
      # @param reason [String, Symbol] identifier; unsupported values normalize
      #   to :cancelled without retaining their contents
      # @return [self] this guard with cancellation latched
      def cancel!(reason = :cancelled)
        label = reason.to_s if reason.is_a?(String) || reason.is_a?(Symbol)
        normalized = label && label.match?(/\A[a-z][a-z0-9_]{0,63}\z/) ? label.to_sym : :cancelled
        @mutex.synchronize { @reason ||= normalized }
        self
      end

      # Permanently close this guard using the standard lifecycle reason.
      # @return [self] this guard with :closed latched unless already cancelled
      def close!
        cancel!(:closed)
      end

      # Reject an explicitly prohibited native script start before startup
      # admission. The denial also cancels future sends and cleanup attempts.
      # Ordinary guards leave script startup behavior unchanged.
      # @return [true] when this guard does not restrict script starts
      # @raise [Interrupted] if script starts are prohibited
      def check_script_start!
        return true if @allow_script_starts

        cancel!(:script_start_rejected)
        check_cancelled!
      end

      # Check whether continuation has been permanently denied for this guard.
      # @return [Boolean] whether any cancellation reason is latched
      def cancelled?
        @mutex.synchronize { !@reason.nil? }
      end

      # Identify callback reentry without treating it as a new policy check.
      # @return [Boolean] true only while this thread is evaluating the policy
      def checking?
        @mutex.synchronize { @callbacks.key?(Thread.current) }
      end

      private

      # Raise a sanitized interruption for an already-latched cancellation.
      # @return [nil] when no cancellation has occurred
      # @raise [Interrupted] when cancelled
      # @api private
      def check_cancelled!
        @mutex.synchronize { interrupt! if @reason }
      end

      # Raise the cancellation identifier without a retained exception cause.
      # @return [void]
      # @raise [Interrupted] always
      # @api private
      def interrupt!
        raise Interrupted.new(@reason), cause: nil
      end
    end
  end
end
