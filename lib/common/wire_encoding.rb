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
    # Deliberately does not touch how Ox parses the decoded text (Ox's
    # convert_special: false / ASCII-8BIT attribute-value tagging in
    # lib/common/xmlparser.rb is unrelated machinery with its own history --
    # see the comments there -- and is out of scope for this fix).
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

      # Decodes raw wire bytes into a valid, correctly-tagged UTF-8 string.
      #
      # Any encoding tag already on +bytes+ is ignored -- only the
      # underlying bytes matter, which makes this safe to call on a string
      # straight off TCPSocket#gets regardless of the process's
      # Encoding.default_external.
      #
      # @param bytes [String] raw bytes as received from the socket
      # @return [String] a valid UTF-8 string
      def self.decode(bytes)
        raw = bytes.b
        codepoints = raw.each_byte.map do |b|
          (b >= 0x80 && b <= 0x9F) ? CP1252_REMAP[b - 0x80] : b
        end
        codepoints.pack('U*')
      end

      # Encodes a Ruby string (typically UTF-8, e.g. from a GTK entry) into
      # raw Windows-1252 bytes ready to write to the socket.
      #
      # @param text [String] any Ruby string
      # @return [String] ASCII-8BIT bytes
      def self.encode(text)
        bytes = text.codepoints.map do |cp|
          next cp if cp <= 0x7F || (cp >= 0xA0 && cp <= 0xFF)

          CP1252_UNMAP[cp] || FALLBACK_BYTE
        end
        bytes.pack('C*')
      end
    end
  end
end
