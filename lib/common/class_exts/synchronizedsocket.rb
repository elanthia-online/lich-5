# Carve out from lich.rbw
# extension to SynchronizedSocket class 2024-06-13

module Lich
  module Common
    class SynchronizedSocket
      FATAL_WRITE_ERRORS = [
        Errno::ECONNRESET,
        Errno::EPIPE,
        Errno::ECONNABORTED,
        IOError,
      ].freeze

      def initialize(o)
        @delegate = o
        @mutex = Mutex.new
        @alive = true
      end

      def alive?
        @alive && !@delegate.closed?
      end

      def puts(*args, &block)
        return nil unless @alive

        @mutex.synchronize {
          @delegate.puts(*args, &block)
        }
      rescue *FATAL_WRITE_ERRORS => e
        handle_write_failure(e)
        nil
      end

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

      def write(*args, &block)
        return nil unless @alive

        @mutex.synchronize {
          @delegate.write(*args, &block)
        }
      rescue *FATAL_WRITE_ERRORS => e
        handle_write_failure(e)
        nil
      end

      def method_missing(method, *args, &block)
        @delegate.__send__ method, *args, &block
      end

      def respond_to_missing?(method, include_private = false)
        @delegate.respond_to?(method, include_private) || super
      end

      private

      def handle_write_failure(error)
        @alive = false
        Lich.log "error: client socket write failed: #{error.class} - #{error.message}"
      end
    end
  end
end
