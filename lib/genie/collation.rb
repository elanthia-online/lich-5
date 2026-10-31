# frozen_string_literal: true

module Lich
  module Genie
    # Key order of Genie's config writers. Remix keeps variables and triggers in a
    # `System.Collections.SortedList` built with the default comparer
    # (Lists/SortedList.cs:7, Globals.cs:56-58 R), which is the current culture's string
    # compare. Remix targets net10.0-windows (Genie4.csproj:3), so that compare is ICU's
    # root collation: `variables.cfg`/`triggers.cfg` come out in that order.
    #
    # This is a small UCA-style three-level key, exact for ASCII and measured against
    # the real Remix writer (genieflow `#var save`, 2026-10-19):
    #   * primary: whitespace < punctuation/symbols (ICU order below) < digits < letters,
    #     letters case-blind (`.alt` < `0` < `Abbey` < `acdc`);
    #   * secondary: accents (`E` < `e`-acute);
    #   * tertiary: lowercase before uppercase at the first difference (`ab` < `aB` < `Ab`).
    # Non-ASCII is approximated: NFD base letter + combining-mark secondary, a few
    # expansions (sharp s = "ss", ae/oe ligatures, o-stroke); any other non-ASCII
    # character sorts after `z` by code point.
    module Collation
      # ICU root order of the ASCII whitespace/punctuation/symbol characters
      # (non-ignorable), as measured on the Remix writer for every printable one.
      SYMBOLS = ["\t", "\n", "\v", "\f", "\r", ' ',
                 '_', '-', ',', ';', ':', '!', '?', '.', "'", '"', '(', ')', '[', ']', '{', '}',
                 '@', '*', '/', '\\', '&', '#', '%', '`', '^', '+', '<', '=', '>', '|', '~', '$'].freeze

      COMMON = 5 # secondary weight of a plain character
      LOWER = 0
      VARIANT = 1 # sharp s / ligatures: after the plain spelling ("ss" < sharp s < "st")
      UPPER = 2
      VARIANT_UPPER = 3

      PRIMARY = {}.tap do |table|
        SYMBOLS.each_with_index { |ch, i| table[ch] = i + 1 }
        ('0'..'9').each_with_index { |ch, i| table[ch] = 100 + i }
        ('a'..'z').each_with_index { |ch, i| table[ch] = 200 + i }
      end.freeze

      # Secondary order of the common combining marks (DUCET: acute, grave, breve,
      # circumflex, caron, ring, diaeresis, double acute, tilde, dot above); others by
      # code point after these.
      MARKS = [0x0301, 0x0300, 0x0306, 0x0302, 0x030C, 0x030A, 0x0308, 0x030B, 0x0303, 0x0307]
              .each_with_index.to_h { |cp, i| [cp, COMMON + 1 + i] }.freeze
      STROKE = COMMON + 40 # o-stroke: a secondary variant of o (o < o-stroke < p)

      # Expansions: code point => [[base letter, tertiary], ...] or a stroke marker.
      EXPANSIONS = {
        0x00DF => [['s', VARIANT], ['s', VARIANT]],             # sharp s
        0x00E6 => [['a', VARIANT], ['e', VARIANT]],             # ae
        0x00C6 => [['a', VARIANT_UPPER], ['e', VARIANT_UPPER]], # AE
        0x0153 => [['o', VARIANT], ['e', VARIANT]],             # oe
        0x0152 => [['o', VARIANT_UPPER], ['e', VARIANT_UPPER]], # OE
        0x00F8 => [['o', LOWER, STROKE]],                       # o-stroke
        0x00D8 => [['o', UPPER, STROKE]]                        # O-stroke
      }.freeze

      module_function

      # @param text [String]
      # @return [Array] comparable key: [primaries, secondaries, tertiaries, text]
      def key(text)
        primaries = []
        secondaries = []
        tertiaries = []
        elements(text.to_s).each do |primary, secondary, tertiary|
          primaries << primary unless primary.zero?
          secondaries << secondary
          tertiaries << tertiary
        end
        [primaries, secondaries, tertiaries, text.to_s]
      end

      # @param list [Enumerable<String>]
      # @return [Array<String>] in Remix SortedList order
      def sort(list)
        list.sort_by { |item| key(item) }
      end

      REPLACEMENT = [0xFFFD].pack('U').freeze

      # A UTF-8-tagged string with invalid bytes would make String#downcase raise and
      # abort a whole save; Remix strings never hold invalid bytes (StreamReader decodes
      # them to U+FFFD), so collate them as U+FFFD, as ConfigFile.utf8 writes them.
      def elements(text)
        text = text.scrub(REPLACEMENT) if text.encoding == Encoding::UTF_8 && !text.valid_encoding?
        text.unicode_normalize(:nfd).each_char.flat_map { |ch| char_elements(ch) }
      rescue ArgumentError, Encoding::CompatibilityError
        text.each_char.flat_map { |ch| char_elements(ch) }
      end

      def char_elements(char)
        down = char.downcase
        tertiary = char == down ? LOWER : UPPER
        return [[PRIMARY[down], COMMON, tertiary]] if PRIMARY.key?(down)

        code = char.ord
        return [] if code < 0x20 || code == 0x7F # ignorable controls
        return expansion(code) if EXPANSIONS.key?(code)
        return [[0, MARKS.fetch(code, COMMON + 20 + (code - 0x0300)), LOWER]] if code.between?(0x0300, 0x036F)

        [[10_000 + down.ord, COMMON, tertiary]]
      end

      def expansion(code)
        EXPANSIONS[code].map do |letter, tertiary, secondary|
          [PRIMARY[letter], secondary || COMMON, tertiary]
        end
      end
    end
  end
end
