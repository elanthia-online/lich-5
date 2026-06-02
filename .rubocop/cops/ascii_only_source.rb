# frozen_string_literal: true

module RuboCop
  module Cop
    module Custom
      # Checks source files for non-ASCII characters and escape sequences that
      # produce non-ASCII output at runtime.
      class AsciiOnlySource < Base
        extend AutoCorrector
        include RangeHelp

        MSG = 'Use only ASCII characters and ASCII-producing escapes in source files.'

        UNICODE_BRACE_ESCAPE = /\\u\{[0-9a-fA-F\s]+\}/
        UNICODE_SHORT_ESCAPE = /\\u[0-9a-fA-F]{4}/
        HEX_ESCAPE = /\\x[0-9a-fA-F]{2}/

        REPLACEMENTS = {
          "\u2713" => 'ok',
          "\u2717" => 'x',
          "\u2605" => '*',
          "\u2606" => '-',
          "\u26A0" => 'warning',
          "\uFE0F" => '',
          "\u00A0" => ' ',
          "\u00AD" => '',
          "\u00A9" => '(c)',
          "\u00AE" => '(r)',
          "\u200B" => '',
          "\u2013" => '-',
          "\u2014" => '-',
          "\u2022" => '*',
          "\u2026" => '...',
          "\u2122" => 'TM',
          "\u2190" => '<-',
          "\u2192" => '->',
          "\u2500" => '-',
          "\u00D7" => 'x',
          "\uFEFF" => ''
        }.freeze

        ESCAPE_REPLACEMENTS = {
          '\u2713' => 'ok',
          '\u2717' => 'x',
          '\u2605' => '*',
          '\u2606' => '-',
          '\u26A0' => 'warning',
          '\uFE0F' => ''
        }.freeze

        UTF8_ESCAPE_REPLACEMENTS = {
          '\xC2\xA0' => ' ',
          '\xC2\xA9' => '(c)',
          '\xC2\xAD' => '',
          '\xC2\xAE' => '(r)',
          '\xC3\x97' => 'x',
          '\xE2\x80\x8B' => '',
          '\xE2\x80\x93' => '-',
          '\xE2\x80\x94' => '-',
          '\xE2\x80\x98' => nil,
          '\xE2\x80\x99' => nil,
          '\xE2\x80\x9C' => nil,
          '\xE2\x80\x9D' => nil,
          '\xE2\x80\xA2' => '*',
          '\xE2\x80\xA6' => '...',
          '\xE2\x84\xA2' => 'TM',
          '\xE2\x86\x90' => '<-',
          '\xE2\x86\x92' => '->',
          '\xE2\x94\x80' => '-',
          '\xEF\xBB\xBF' => ''
        }.freeze

        ##
        # Iterates over each line of the processed source and inspects it for ASCII-related offenses.
        #
        # Calls `inspect_line` with the line content and its 1-based line number for every line in `processed_source`.
        def on_new_investigation
          processed_source.lines.each_with_index do |line, index|
            inspect_line(line, index + 1)
          end
        end

        private

        ##
        # Inspects a source line for non-ASCII characters and active escape sequences and registers offenses.
        #
        # Performs three checks on the given line:
        # - Reports contiguous raw non-ASCII character runs.
        # - Skips further checks for lines that are comments (line.lstrip starts with `#`).
        # - Detects UTF-8 byte-escape sequences, `\uXXXX`, `\u{...}`, and `\xNN` escapes that would produce non-ASCII output,
        #   avoiding duplicate reports for multi-byte escape sequences by tracking ignored ranges.
        #
        # @param [String] line - The source line to inspect.
        # @param [Integer] line_number - The 1-based line number in the source buffer.
        def inspect_line(line, line_number)
          add_raw_non_ascii_offenses(line, line_number)
          return if line.lstrip.start_with?('#')

          ignored_ranges = add_utf8_escape_sequence_offenses(line, line_number)
          add_escape_offenses(line, line_number, UNICODE_SHORT_ESCAPE) { |token| unicode_short_non_ascii?(token) }
          add_escape_offenses(line, line_number, UNICODE_BRACE_ESCAPE) { |token| unicode_brace_non_ascii?(token) }
          add_escape_offenses(line, line_number, HEX_ESCAPE, ignored_ranges) { |token| hex_non_ascii?(token) }
        end

        ##
        # Adds offences for each contiguous run of non-ASCII characters found in `line`.
        # For each run, registers an offense covering that range on `line_number` and
        # supplies an auto-correction when a full ASCII replacement for the run exists.
        # @param [String] line - The source line to inspect.
        # @param [Integer] line_number - The 1-based line number in the source buffer.
        def add_raw_non_ascii_offenses(line, line_number)
          scan_ranges(line) { |char| !char.ascii_only? }.each do |start_column, length|
            token = line.chars.slice(start_column, length).join
            add_ascii_offense(line_number, start_column, length, correction_for_raw(token))
          end
        end

        ##
        # Register offenses for UTF-8 byte-escape sequences found in a source line.
        # Scans the given line for multi-byte UTF-8 escape sequences (keys from
        # `UTF8_ESCAPE_REPLACEMENTS`), adds an offense for each active match, and
        # records the character-column ranges for those matches so they can be
        # ignored by subsequent scans.
        # @param [String] line - The source line to inspect.
        # @param [Integer] line_number - The 1-based line number in the source buffer.
        # @return [Array<Range>] An array of ranges (start_column...end_column) covering each matched escape sequence that was recorded to be ignored.
        def add_utf8_escape_sequence_offenses(line, line_number)
          ignored_ranges = []

          UTF8_ESCAPE_REPLACEMENTS.each_key do |sequence|
            pattern = /#{Regexp.escape(sequence)}/i
            line.to_enum(:scan, pattern).each do
              token = Regexp.last_match(0)
              start_column = Regexp.last_match.begin(0)
              next unless active_escape?(line, start_column)

              ignored_ranges << (start_column...(start_column + token.length))
              add_ascii_offense(
                line_number,
                start_column,
                token.length,
                correction_for_utf8_escape(token)
              )
            end
          end

          ignored_ranges
        end

        ##
        # Scan a source line for escape sequences matching `pattern` and register an offense
        # for each matched token that is not covered by `ignored_ranges`, is an active escape,
        # and for which the provided block returns a truthy value.
        # @param [String] line - The source line to inspect.
        # @param [Integer] line_number - The 1-based line number in the source buffer.
        # @param [Regexp] pattern - Regular expression used to locate escape tokens in the line.
        # @param [Array<Range>] ignored_ranges - Ranges of columns to ignore when reporting (optional).
        # @yield [String] token - Called for each matched token; return truthy to report an offense for that token.
        def add_escape_offenses(line, line_number, pattern, ignored_ranges = [])
          line.to_enum(:scan, pattern).each do
            token = Regexp.last_match(0)
            start_column = Regexp.last_match.begin(0)
            next if range_covered?(start_column, ignored_ranges)
            next unless active_escape?(line, start_column)
            next unless yield(token)

            add_ascii_offense(
              line_number,
              start_column,
              token.length,
              correction_for_escape(token)
            )
          end
        end

        ##
        # Registers an offense covering a specific source range and, if a replacement is provided,
        # instructs the corrector to replace that range with the replacement.
        # @param [Integer] line_number - The line number in the source buffer containing the offense.
        # @param [Integer] column - The column index where the offense starts within the line.
        # @param [Integer] length - The number of characters covered by the offense.
        # @param [String, nil] correction - The replacement text to apply; if `nil`, no automatic correction is applied.
        def add_ascii_offense(line_number, column, length, correction)
          range = source_range(processed_source.buffer, line_number, column, length)

          add_offense(range, message: MSG) do |corrector|
            corrector.replace(range, correction) unless correction.nil?
          end
        end

        ##
        # Finds contiguous runs of characters in a line for which the given block returns true.
        # @param [String] line - The string to scan (columns are zero-based).
        # @yield [char] Called for each character; return truthy to include that character in the current run.
        # @return [Array<Array<Integer>>] An array of [start_column, length] pairs describing each contiguous run.
        def scan_ranges(line)
          ranges = []
          current_start = nil
          current_length = 0

          line.each_char.with_index do |char, column|
            if yield(char)
              current_start ||= column
              current_length += 1
            elsif current_start
              ranges << [current_start, current_length]
              current_start = nil
              current_length = 0
            end
          end

          ranges << [current_start, current_length] if current_start
          ranges
        end

        ##
        # Determines whether a `\uXXXX`-style escape token represents a non-ASCII codepoint.
        # @param [String] token - The escape sequence in the form `'\uXXXX'` (hex digits).
        # @return [Boolean] `true` if the hex value in the escape is greater than 0x7F, `false` otherwise.
        def unicode_short_non_ascii?(token)
          token.delete_prefix('\u').to_i(16) > 0x7F
        end

        ##
        # Determines whether a `\u{...}`-style Unicode escape token contains any codepoint greater than 0x7F.
        # @param [String] token - The Unicode brace escape token (for example `'\u{2713, 20AC}'`) containing comma- or space-separated hex codepoints.
        # @return [Boolean] `true` if any parsed codepoint value is greater than 0x7F, `false` otherwise.
        def unicode_brace_non_ascii?(token)
          token.delete_prefix('\u{').delete_suffix('}').split.any? do |codepoint|
            codepoint.to_i(16) > 0x7F
          end
        end

        ##
        # Determines whether a `\xNN` hexadecimal escape represents a non-ASCII byte.
        # @param [String] token - The escape token starting with `\x` followed by two hex digits.
        # @return [Boolean] `true` if the hex value is greater than 0x7F, `false` otherwise.
        def hex_non_ascii?(token)
          token.delete_prefix('\x').to_i(16) > 0x7F
        end

        ##
        # Determines whether an escape sequence at the given column is active by checking
        # the parity of consecutive backslashes immediately preceding it.
        # @param [String] line - The line of source text.
        # @param [Integer] start_column - The index in `line` where the escape sequence begins (0-based).
        # @return [Boolean] `true` if the number of consecutive backslashes immediately before `start_column` is odd, `false` otherwise.
        def active_escape?(line, start_column)
          backslashes = 0
          column = start_column

          while column >= 0 && line[column] == '\\'
            backslashes += 1
            column -= 1
          end

          backslashes.odd?
        end

        ##
        # Checks whether any range in `ranges` includes the given column index.
        # @param [Integer] column - The column index to test.
        # @param [Array<Range>] ranges - An array of Range objects to check against.
        # @return [Boolean] `true` if any range covers `column`, `false` otherwise.
        def range_covered?(column, ranges)
          ranges.any? { |range| range.cover?(column) }
        end

        ##
        # Compute an ASCII replacement for a string of non-ASCII characters.
        # @param [String] token - A sequence of characters to map to ASCII equivalents.
        # @return [String, nil] The concatenated ASCII replacements for all characters in `token`, or `nil` if any character has no mapping.
        def correction_for_raw(token)
          corrections = token.each_char.map { |char| REPLACEMENTS[char] }
          return nil if corrections.any?(&:nil?)

          corrections.join
        end

        ##
        # Provide an ASCII replacement for a Unicode or hex escape token when a known mapping exists or when a brace-style `\u{...}` escape can be converted.
        # @param [String] token - The escape sequence token (e.g. `'\u2713'`, `'\u{2014}'`, `'\xC2\xA0'`).
        # @return [String, nil] The ASCII replacement for the token if available, `nil` otherwise.
        def correction_for_escape(token)
          return ESCAPE_REPLACEMENTS[token] if ESCAPE_REPLACEMENTS.key?(token)

          correction_for_brace_escape(token) if token.start_with?('\u{')
        end

        ##
        # Map a UTF-8 byte-escape sequence token to its ASCII replacement.
        # @param [String] token - The escape token (e.g. a sequence containing `\xNN` bytes).
        # @return [String, nil] The ASCII replacement string for the normalized byte-escape sequence, or `nil` if no replacement is defined.
        def correction_for_utf8_escape(token)
          UTF8_ESCAPE_REPLACEMENTS[normalized_hex_sequence(token)]
        end

        ##
        # Normalize a token containing hex byte values into a canonical concatenation of uppercase `\xNN` escapes.
        # @param [String] token - String containing hexadecimal byte pairs (may include mixed case and non-escape characters); each pair of hex digits will be treated as a byte.
        # @return [String] A string of joined byte escapes like `\xC2\xA0` where each byte is uppercased and formatted as `\xNN`.
        def normalized_hex_sequence(token)
          token.scan(/[0-9a-fA-F]{2}/).map { |byte| "\\x#{byte.upcase}" }.join
        end

        ##
        # Produces an ASCII replacement for a `\u{...}` Unicode brace escape.
        # @param [String] token - The brace escape token (e.g. '\u{2713}').
        # @return [String, nil] The ASCII replacement for the escape's characters, or `nil` if any codepoint is invalid or no full ASCII mapping is available.
        def correction_for_brace_escape(token)
          chars = token.delete_prefix('\u{').delete_suffix('}').split.map do |codepoint|
            codepoint.to_i(16).chr(Encoding::UTF_8)
          end

          correction_for_raw(chars.join)
        rescue RangeError
          nil
        end
      end
    end
  end
end
