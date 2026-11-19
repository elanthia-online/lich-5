# frozen_string_literal: true

module Lich
  module Genie
    # Genie's `variables.cfg`: one `#var {key} {value}` row per saved variable.
    # Port of Globals.Variables Load/LoadRow/Save (Globals.cs:724-818 R).
    #
    #   * load: every line goes through ParseArgs ({Text.parse_args}); a line with
    #     exactly 3 args adds [1] => [2], anything else is skipped (LoadRow,
    #     Globals.cs:765-774 R). ParseArgs throws on some malformed rows (a lone `'` or
    #     `"` key); Load catches that OUTSIDE the read loop and returns false
    #     (Globals.cs:753-761 R), so every row after the bad one is lost and the rows
    #     before it stay loaded. Verified on the real Remix code (genieflow --vars).
    #   * save: rows in SortedList key order ({Collation}), `#var {key} {value}` with
    #     no escaping (Globals.cs:794-803 R), written through {ConfigFile}.
    #
    # Files written by this engine's old write-through store (LF line ends, insertion
    # order) load unchanged: ReadLine accepts LF and the order never mattered on load.
    module VariableFile
      module_function

      # @param path [String, nil]
      # @return [Hash{String=>String}] key => value in file order (empty if absent)
      def load(path)
        read(path).first
      end

      # @param path [String, nil]
      # @return [Array(Hash{String=>String}, Boolean)] the rows, and Remix's Load
      #   return value (false when the file is absent or unreadable, or a row aborted
      #   the load)
      def read(path)
        entries = {}
        lines = ConfigFile.read_lines(path)
        return [entries, false] if lines.nil?

        lines.each do |line|
          args = Text.parse_args(line)
          entries[args[1]] = args[2] if args.length == 3
        end
        [entries, true]
      rescue StandardError
        # Load wraps the whole read in catch (Exception) -> false (Globals.cs:757-762 R):
        # a malformed row (Genie::Error from ParseArgs) and an unreadable file (EACCES,
        # a Windows lock, an I/O error) both keep the rows read so far and never raise.
        [entries, false]
      end

      # @param entries [Hash{String=>String}]
      # @return [Array<String>] the rows Remix's Save writes, in its order
      def rows(entries)
        Collation.sort(entries.keys).map { |key| "#var {#{key}} {#{entries[key]}}" }
      end

      # @param entries [Hash{String=>String}]
      # @return [String] the exact file content (CRLF rows, sorted)
      def dump(entries)
        rows(entries).map { |row| "#{row}#{ConfigFile::NEWLINE}" }.join
      end

      # @param path [String]
      # @param entries [Hash{String=>String}]
      # @return [void]
      # @raise [StandardError] when the file cannot be written (callers swallow it)
      def save(path, entries)
        ConfigFile.write_lines(path, rows(entries))
      end
    end
  end
end
