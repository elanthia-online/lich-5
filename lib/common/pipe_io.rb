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
      #
      # Contract: returns raw bytes exactly as read from +input+ ($stdin by
      # default), tagged with whatever Encoding.default_external happens to
      # be -- the same as a real TCPSocket#gets. This is NOT decoded text;
      # every $_CLIENT_.gets call site in lib/main/main.rb reads through
      # Lich::Common::ClientLineReader.read, never #gets directly, which
      # decodes it before anything treats it as Unicode. --pipe mode's wire
      # contract is Windows-1252 by default, the same as a real socket-based
      # frontend -- $stdin is not given any special encoding treatment
      # here, deliberately. A --pipe launcher that wants to send already-
      # UTF-8 text must identify as a frontend registered with the
      # :utf8_input capability (see Lich::Common::Frontend.utf8_input?) via
      # --frontend=, not rely on this class doing any detection itself.
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
