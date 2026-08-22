# frozen_string_literal: true

module Lich
  module Common
    # Transcodes the GS4/DR wire protocol at the socket boundary.
    #
    # The game stream is Windows-1252, not the process's default external
    # encoding (see Game.open / Game._puts in lib/games.rb, which call
    # .decode / .encode from this module rather than trusting whatever
    # Encoding.default_external happens to resolve to). Left unhandled, a
    # server line containing an actual Windows-1252 high byte (curly quotes,
    # em-dash, ellipsis, etc.) gets tagged with the wrong encoding by
    # TCPSocket#gets and raises ArgumentError the moment any regex or gsub
    # touches it (see lib/games.rb's XMLCleaner methods and strip_xml_simple
    # in lib/global_defs.rb, all of which operate on the raw line).
    #
    # CP1252_REMAP is verified byte-for-byte against Simutronics' own
    # official Saga Electron client not just against the
    # published Windows-1252 standard. That verification matters for one
    # specific reason: five byte positions (0x81, 0x8D, 0x8F, 0x90, 0x9D)
    # are officially undefined in Windows-1252. Ruby's built-in
    # Windows-1252 transcoder (String#encode('UTF-8')) raises
    # Encoding::UndefinedConversionError on those five bytes by default, or
    # silently substitutes U+FFFD with invalid: :replace -- neither of
    # which matches what the real client does. Saga passes them through as
    # their raw byte value (the same convention as the WHATWG Encoding
    # Standard's "best fit" mapping), so this module reproduces that exact
    # behavior instead of leaning on Ruby's stricter built-in table.
    #
    # This module trusts its callers to hand it real Unicode codepoints
    # (.encode) or raw wire bytes (.decode) -- it does not itself guard
    # against a string whose encoding tag lies about its content. Ox (run
    # with convert_special: false in lib/common/xmlparser.rb) hands its SAX
    # callbacks the already-UTF-8-decoded server line's bytes back re-tagged
    # ASCII-8BIT; XMLParser#retag_ox_utf8! corrects that tag before any of
    # those values reach .encode (e.g. the spell/right/left fake tags),
    # since .encode's codepoint-by-codepoint walk would otherwise treat each
    # raw UTF-8 byte of a real multibyte character as its own codepoint.
    module WireEncoding
      # index i => Unicode code point for wire byte (0x80 + i). Order and
      # values match the standard Windows-1252 code page and Saga's
      # CP1252_REMAP table exactly (verified 2026-08-20).
      CP1252_REMAP = [
        8364, 129, 8218, 402, 8222, 8230, 8224, 8225,
        710, 8240, 352, 8249, 338, 141, 381, 143,
        144, 8216, 8217, 8220, 8221, 8226, 8211, 8212,
        732, 8482, 353, 8250, 339, 157, 382, 376
      ].freeze

      # codepoint => wire byte, the inverse of CP1252_REMAP. Includes
      # self-mapped entries for the five officially-undefined positions
      # (e.g. U+0081 => 0x81), so encode(decode(byte)) round-trips for
      # every one of the 256 possible input bytes.
      CP1252_UNMAP = CP1252_REMAP.each_with_index.to_h { |codepoint, i| [codepoint, 128 + i] }.freeze

      # Byte written for an outgoing character with no Windows-1252
      # representation, matching Saga's fallback exactly rather than
      # raising and dropping the whole outgoing line.
      FALLBACK_BYTE = 63 # '?'

      # Wizard's legacy binary protocol markers (link/speech highlight
      # start/end, and per-color message markers) are single raw bytes in
      # the 0x80-0x9F range that are NOT Windows-1252 text -- they're
      # control codes the classic Wizard client interprets specially.
      # Previously these were spliced into strings as literal
      # ASCII-8BIT-tagged bytes (lib/main/main.rb's $link_highlight_start
      # etc., lib/messaging.rb's wizard_color), which breaks two ways once
      # real text is involved: combining an ASCII-8BIT string containing a
      # real high byte with a UTF-8 string containing real non-ASCII text
      # raises Encoding::CompatibilityError, and if that combination
      # happens not to raise (pure-ASCII surrounding text),
      # WireEncoding.encode has no way to tell "this 0x8A is a protocol
      # marker" from "this is Unicode code point U+008A" and mangles it
      # via the normal CP1252 path (falls through to FALLBACK_BYTE, since
      # U+008A isn't a real CP1252_UNMAP target).
      #
      # The fix: represent each marker as a Unicode Private Use Area code
      # point (guaranteed to never collide with real game text) instead
      # of a raw byte, so markers stay valid UTF-8 all the way through
      # Lich's normal text pipeline (no ASCII-8BIT/UTF-8 mixing, ever).
      # .encode translates a marker code point straight to its real wire
      # byte here, bypassing the general CP1252 path entirely -- callers
      # that need a marker should reference these constants (e.g.
      # WireEncoding::WIZARD_LINK_START) rather than a raw byte literal.
      WIZARD_LINK_START = "\u{E000}" # rubocop:disable Custom/AsciiOnlySource
      WIZARD_LINK_END = "\u{E001}" # rubocop:disable Custom/AsciiOnlySource
      WIZARD_SPEECH_START = "\u{E002}" # rubocop:disable Custom/AsciiOnlySource
      WIZARD_SPEECH_END = "\u{E003}" # rubocop:disable Custom/AsciiOnlySource

      # One code point per Lich::Messaging wizard_color name (the 15
      # per-color Wizard message markers, wire bytes 128-142), plus a
      # shared end/terminator marker (wire byte 0xA0, same terminator
      # byte the link/speech markers above use). Named by color rather
      # than by number so lib/messaging.rb reads the same way its
      # existing wizard_color hash does.
      WIZARD_COLOR_START = {
        'white' => "\u{E004}", 'black' => "\u{E005}", 'dark blue' => "\u{E006}", # rubocop:disable Custom/AsciiOnlySource
        'dark green' => "\u{E007}", 'dark teal' => "\u{E008}", 'dark red' => "\u{E009}", # rubocop:disable Custom/AsciiOnlySource
        'purple' => "\u{E00A}", 'gold' => "\u{E00B}", 'light grey' => "\u{E00C}", # rubocop:disable Custom/AsciiOnlySource
        'blue' => "\u{E00D}", 'bright green' => "\u{E00E}", 'teal' => "\u{E00F}", # rubocop:disable Custom/AsciiOnlySource
        'red' => "\u{E010}", 'pink' => "\u{E011}", 'yellow' => "\u{E012}" # rubocop:disable Custom/AsciiOnlySource
      }.freeze
      WIZARD_COLOR_END = "\u{E013}" # rubocop:disable Custom/AsciiOnlySource

      # code point => real wire byte, covering both marker families above.
      WIZARD_MARKER_BYTES = {
        0xE000 => 0x87, # link start
        0xE001 => 0xA0, # link end (shared terminator byte)
        0xE002 => 0x8A, # speech start
        0xE003 => 0xA0, # speech end (shared terminator byte)
        0xE004 => 128,  # white
        0xE005 => 129,  # black
        0xE006 => 130,  # dark blue
        0xE007 => 131,  # dark green
        0xE008 => 132,  # dark teal
        0xE009 => 133,  # dark red
        0xE00A => 134,  # purple
        0xE00B => 135,  # gold
        0xE00C => 136,  # light grey
        0xE00D => 137,  # blue
        0xE00E => 138,  # bright green
        0xE00F => 139,  # teal
        0xE010 => 140,  # red
        0xE011 => 141,  # pink
        0xE012 => 142,  # yellow
        0xE013 => 0xA0  # color end (shared terminator byte)
      }.freeze

      # Decodes raw wire bytes into a valid, correctly-tagged UTF-8 string.
      #
      # Any encoding tag already on +bytes+ is ignored -- only the
      # underlying bytes matter, which makes this safe to call on a string
      # straight off TCPSocket#gets regardless of the process's
      # Encoding.default_external.
      #
      # @param bytes [String, nil] raw bytes as received from the socket
      # @return [String, nil] a valid UTF-8 string, or nil if +bytes+ is nil
      #   (mirrors IO#gets, which this typically wraps immediately -- a
      #   disconnect mid-read is a legitimate nil, not an error to raise on)
      def self.decode(bytes)
        return nil if bytes.nil?

        raw = bytes.b
        codepoints = raw.each_byte.map do |b|
          (b >= 0x80 && b <= 0x9F) ? CP1252_REMAP[b - 0x80] : b
        end
        codepoints.pack('U*')
      end

      # Encodes a Ruby string (typically UTF-8, e.g. from a GTK entry) into
      # raw Windows-1252 bytes ready to write to the socket. Wizard marker
      # code points (see WIZARD_MARKER_BYTES) are translated to their real
      # protocol byte rather than treated as text.
      #
      # @param text [String, nil] any Ruby string
      # @return [String, nil] ASCII-8BIT bytes, or nil if +text+ is nil
      def self.encode(text)
        return nil if text.nil?

        bytes = text.codepoints.map do |cp|
          next WIZARD_MARKER_BYTES[cp] if WIZARD_MARKER_BYTES.key?(cp)
          next cp if cp <= 0x7F || (cp >= 0xA0 && cp <= 0xFF)

          CP1252_UNMAP[cp] || FALLBACK_BYTE
        end
        bytes.pack('C*')
      end
    end
  end
end
