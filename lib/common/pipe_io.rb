# frozen_string_literal: true

module Lich
  module Common
    # Duplex IO adapter that lets stdin/stdout stand in for a front-end client
    # socket in --pipe mode. Reads come from +input+ ($stdin), writes go to
    # +output+ ($stdout).
    #
    # Designed to be wrapped in a SynchronizedSocket, exactly like the real
    # client TCPSocket. The rest of the codebase then talks to $_CLIENT_ the
    # same way it always does (#gets / #write / #puts / #alive? / #close).
    #
    # Liveness is defined as "have not yet hit EOF on the input stream":
    # once #gets returns nil (the upstream pipe closed), #closed? returns true,
    # so SynchronizedSocket#alive? (@alive && !delegate.closed?) flips to false
    # and the normal disconnect/shutdown path runs.
    class PipeIO
      def initialize(input: $stdin, output: $stdout)
        @input  = input
        @output = output
        @output.sync = true # pipes must flush downstream output immediately
        @eof = false
      end

      # Client read loop calls this via SynchronizedSocket#method_missing.
      # Returns nil at EOF, which both ends the read loop and marks us closed.
      def gets(*args)
        line = @input.gets(*args)
        @eof = true if line.nil?
        line
      end

      def write(*args, &block)
        @output.write(*args, &block)
      end

      def puts(*args, &block)
        @output.puts(*args, &block)
      end

      # Consulted (through SynchronizedSocket#alive?) by the server read loop's
      # retry guard and the client thread. True once the input stream is spent.
      def closed?
        @eof
      end

      def close
        @eof = true
        @output.flush rescue nil
        # Intentionally do not close the $stdin/$stdout file descriptors.
      end

      def sync=(value)
        @output.sync = value
      end

      def sync
        @output.sync
      end
    end
  end
end
