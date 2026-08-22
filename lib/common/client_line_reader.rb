# frozen_string_literal: true

require_relative 'wire_encoding'

module Lich
  module Common
    # Reads one raw line from a frontend-facing client (anything
    # responding to +#gets+ -- a SynchronizedSocket-wrapped $_CLIENT_, a
    # PipeIO, or a test double) and returns a valid, correctly-tagged
    # UTF-8 string -- what the user actually typed, regardless of which
    # raw byte encoding their frontend used to send it.
    #
    # Every $_CLIENT_.gets call site in lib/main/main.rb that reads
    # frontend input -- the login handshake's GSL, Frostbite, and
    # generic-fallback paths, and the main command loop -- goes through
    # this one method rather than calling #gets directly. That keeps the
    # "decode immediately after every read" contract in one place, and
    # lets it be exercised directly in a spec with a lightweight double
    # instead of needing main.rb's full boot sequence running to test it.
    #
    # The legacy Simu-derived clients (Wizard, StormFront/Wrayth, Avalon,
    # Simutronics' own Saga -- see Saga's encodeCp1252, which encodes a
    # genuine JS-string codepoint, never a raw byte) all send Windows-1252
    # on the wire, so that remains the default. But that's a property of
    # those specific clients, not of the wire protocol itself -- nothing
    # stops a different kind of attached frontend (a terminal-based one
    # like ProfanityFE, which just forwards whatever its terminal already
    # gave it, typically UTF-8 on a modern OS) from sending real UTF-8
    # instead. Blindly CP1252-decoding that turns it into mojibake before
    # it ever reaches Game._puts's own WireEncoding.encode -- garbage in,
    # faithfully-encoded garbage out.
    #
    # Distinguishing the two is unambiguous in practice, not a guess: a
    # Windows-1252 high byte (0x80-0x9F) can never open a valid multibyte
    # UTF-8 sequence, so genuine CP1252 input fails strict UTF-8
    # validation and falls through to the CP1252 path below essentially
    # every time. Only already-valid UTF-8 bytes are read as UTF-8.
    #
    # Returns nil (rather than raising) when the client has
    # disconnected, matching #gets's own EOF behavior -- callers can use
    # this directly as a while-loop condition exactly as they would
    # #gets itself: +while (line = ClientLineReader.read(client))+.
    module ClientLineReader
      def self.read(client)
        raw = client.gets
        return nil if raw.nil?

        as_utf8 = raw.dup.force_encoding(Encoding::UTF_8)
        return as_utf8 if as_utf8.valid_encoding?

        Lich::Common::WireEncoding.decode(raw)
      end
    end
  end
end
