# frozen_string_literal: true

require_relative 'wire_encoding'

module Lich
  module Common
    # Reads one raw line from a frontend-facing client (anything
    # responding to +#gets+ -- a SynchronizedSocket-wrapped $_CLIENT_, a
    # PipeIO, or a test double) and decodes it from the GS4/DR wire
    # format (Windows-1252) to a valid, correctly-tagged UTF-8 string.
    #
    # Every $_CLIENT_.gets call site in lib/main/main.rb that reads
    # frontend input -- the login handshake's GSL, Frostbite, and
    # generic-fallback paths, and the main command loop -- goes through
    # this one method rather than calling #gets and
    # WireEncoding.decode separately. That keeps the "decode
    # immediately after every read" contract in one place, and lets it
    # be exercised directly in a spec with a lightweight double instead
    # of needing main.rb's full boot sequence running to test it.
    #
    # Returns nil (rather than raising) when the client has
    # disconnected, matching #gets's own EOF behavior -- callers can use
    # this directly as a while-loop condition exactly as they would
    # #gets itself: +while (line = ClientLineReader.read(client))+.
    module ClientLineReader
      def self.read(client)
        Lich::Common::WireEncoding.decode(client.gets)
      end
    end
  end
end
