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
      # Upper bound, in seconds, on one readiness wait in #gets. Each wait
      # re-resolves the input's OS handle, so this also bounds how long the
      # reader can watch a handle that a spawn has replaced (see #gets).
      READ_WAIT_SECONDS = 1.0

      def initialize(input: $stdin, output: $stdout)
        @input  = input
        @output = output
        @output.sync = true # pipes must flush downstream output immediately
        @eof = false
      end

      # Client read loop calls this via SynchronizedSocket#method_missing.
      # Returns nil at EOF, which both ends the read loop and marks us closed.
      #
      # Waits for the input to be readable before reading, so an idle reader
      # never has a native read pending. On Windows a synchronous ReadFile
      # pending on stdin blocks CreateProcessW, which Ruby runs with the GVL
      # held, so every Process.spawn / system / Open3 call froze the whole
      # process until the front end sent its next line.
      #
      # The wait is bounded. On Windows IO.select resolves the fd to its OS
      # handle once, on entry, and a spawn that redirects stdin (Open3, or
      # spawn with in:) swaps fd 0's handle while the reader is parked. An
      # unbounded select keeps polling the old handle and never wakes, not
      # even for EOF; each bounded pass picks up the current one.
      #
      # A line already in Ruby's read buffer is returned without waiting
      # (IO.select reports buffered data as readable). A partial line still
      # blocks in the read until its newline arrives.
      #
      # @param args [Array] passed through to the input's #gets
      # @return [String, nil] the next line, or nil at EOF
      def gets(*args)
        nil until IO.select([@input], nil, nil, READ_WAIT_SECONDS)
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
