# frozen_string_literal: true

module Lich
  module Common
    # Thread-safe socket wrapper with write-side resilience.
    #
    # Wraps a delegate socket (typically +TCPSocket+) with a mutex to
    # serialize writes and an internal liveness flag that transitions
    # irreversibly to dead on any fatal write error.
    #
    # When a fatal write error occurs the wrapper:
    # 1. Sets +@alive+ to +false+
    # 2. Closes the delegate socket (unblocking any blocked readers)
    # 3. Logs the error via +Lich.log+
    #
    # Subsequent writes short-circuit without touching the delegate.
    # Reads still delegate via +method_missing+ so lifecycle threads
    # can detect the closed socket through normal +IOError+ propagation.
    class SynchronizedSocket
      # Errors that indicate a permanently broken write path.
      FATAL_WRITE_ERRORS = [
        Errno::ECONNRESET,
        Errno::EPIPE,
        Errno::ECONNABORTED,
        Errno::ENOTCONN,
        IOError,
      ].freeze

      # @param delegate [#puts, #write, #gets, #close] the underlying socket
      def initialize(delegate)
        @delegate = delegate
        @mutex = Mutex.new
        @alive = true
      end

      # Whether the socket is usable for I/O.
      #
      # Returns +false+ once a fatal write error has occurred or the
      # delegate has been closed by any means. This transition is
      # one-way -- a dead socket cannot be revived.
      #
      # @return [Boolean]
      def alive?
        @alive && !@delegate.closed?
      end

      # Thread-safe write with newline, resilient to fatal errors.
      #
      # @param args [Array] arguments forwarded to the delegate
      # @return [nil] when the socket is dead or a fatal error occurs
      def puts(*args, &block)
        return nil unless @alive

        @mutex.synchronize {
          @delegate.puts(*args, &block)
        }
      rescue *FATAL_WRITE_ERRORS => e
        handle_write_failure(e)
        nil
      end

      # Conditional thread-safe write, resilient to fatal errors.
      #
      # Acquires the mutex, evaluates the block, and writes only if
      # the block returns truthy. Used by +respond+ / +_respond+ to
      # avoid interrupting an XML stream mid-element.
      #
      # @param args [Array] arguments forwarded to the delegate
      # @yield evaluated inside the mutex to decide whether to write
      # @return [Boolean] +true+ if written, +false+ otherwise
      def puts_if(*args)
        return false unless @alive

        @mutex.synchronize {
          if yield
            @delegate.puts(*args)
            return true
          else
            return false
          end
        }
      rescue *FATAL_WRITE_ERRORS => e
        handle_write_failure(e)
        false
      end

      # Thread-safe raw write, resilient to fatal errors.
      #
      # @param args [Array] arguments forwarded to the delegate
      # @return [Integer, nil] bytes written, or +nil+ on fatal error
      def write(*args, &block)
        return nil unless @alive

        @mutex.synchronize {
          @delegate.write(*args, &block)
        }
      rescue *FATAL_WRITE_ERRORS => e
        handle_write_failure(e)
        nil
      end

      # Delegates all non-write methods to the underlying socket.
      #
      # Read-side errors propagate normally so that connection
      # lifecycle threads can detect disconnects.
      def method_missing(method, *args, &block)
        @delegate.__send__(method, *args, &block)
      end

      # @return [Boolean] whether the delegate responds to +method+
      def respond_to_missing?(method, include_private = false)
        @delegate.respond_to?(method, include_private) || super
      end

      private

      # Marks the socket permanently dead, closes the delegate, and
      # logs the error.
      #
      # Closing the delegate is the key architectural decision: it
      # unblocks any thread stuck in a blocking read (+gets+), which
      # lets the detachable client thread's reconnection loop restart
      # the TCP listener. Without this, a dead-but-open socket leaves
      # readers blocked indefinitely (the zombie state from issue #594).
      #
      # @api private
      # @param error [Exception] the fatal write error that triggered death
      # @return [void]
      def handle_write_failure(error)
        @alive = false
        @delegate.close rescue nil
        Lich.log "error: client socket write failed: #{error.class} - #{error.message}"
      end
    end
  end
end
