# frozen_string_literal: true

require 'json'

module Lich
  module Genie
    # Which saved #triggers and aliases were NOT the user's own text ({AuthoredCommand}): a side
    # file next to the list file (`triggers.cfg.untrusted`, `aliases.cfg.untrusted`), so a
    # definition built from a capture stays game text across `#trigger save` / `#alias save` and the
    # next load. triggers.cfg and aliases.cfg keep Remix's format byte for byte (Globals.cs:1127-1182,
    # Aliases.cs:90-129 R); Remix has no such file and never reads one.
    #
    # The side file lists the identity of each saved definition that is not authored, as the load
    # will read it back from the list file: [pattern, body, class] for a trigger (TriggerFile.read),
    # [key, value] for an alias (AliasList#load). A row of the list file whose identity is listed
    # loads not authored; any other row loads authored -- a hand-edited row is the user's own.
    #
    #   * no side file: every row is authored (nothing that was not authored was ever saved);
    #   * a side file that cannot be read or does not parse: every row of that load is not authored
    #     (fail closed), and the caller prints one notice;
    #   * {.save} writes the side file atomically before the list file. The side file written first
    #     also covers what the list file on disk still holds, so a list-file write that fails leaves
    #     nothing trusted that was not; once the list file is written, the side file is rewritten
    #     with exactly the saved definitions (removed when there are none). A side file that cannot
    #     be written first fails the save: the list file is not written.
    #
    # Format: UTF-8, CRLF lines ({ConfigFile.write_lines}): {HEADER}, one JSON array of strings per
    # identity (sorted), then `end <count>`.
    module DefinitionTrust
      SUFFIX = '.untrusted'
      HEADER = 'lich-genie-untrusted 1'
      FOOTER = /\Aend (\d+)\z/.freeze
      # How many times {.read_with} reads a list file whose side file changes meanwhile.
      READ_ATTEMPTS = 3

      # A side file that could not be written or removed; the message names it.
      class Error < StandardError; end

      # What a load reads: the listed identities, or a side file that could not be read.
      Untrusted = Struct.new(:identities, :corrupt) do
        # @param identity [Array<String>]
        # @return [Boolean] whether a row with +identity+ loads authored
        def authored?(identity)
          !corrupt && !identities.include?(identity)
        end
      end

      ABSENT = Untrusted.new(Set.new.freeze, false).freeze
      CORRUPT = Untrusted.new(Set.new.freeze, true).freeze

      module_function

      # @param list_path [String]
      # @return [String] the side file of +list_path+
      def path(list_path)
        "#{list_path}#{SUFFIX}"
      end

      # @param list_path [String, nil]
      # @param arity [Integer] strings per identity (3: trigger, 2: alias)
      # @return [Untrusted] {ABSENT} when there is no side file, {CORRUPT} when it cannot be used
      def read(list_path, arity)
        return ABSENT if list_path.nil?

        file = path(list_path)
        return ABSENT unless File.exist?(file) || File.symlink?(file) # a dangling link is present, and unreadable

        identities = parse(ConfigFile.read_lines(file), arity)
        identities ? Untrusted.new(identities.freeze, false).freeze : CORRUPT
      rescue StandardError
        CORRUPT
      end

      # Read a list file (the block) together with its side file: the side file is read before and
      # after the block, and a pair that differs (a save -- maybe another Lich's on the same config
      # dir -- landed in between) is read again. The side file a save writes first lists what both
      # the old and the new list file need, so an unchanged side file fits whichever list file the
      # block saw. Still changing after READ_ATTEMPTS: {CORRUPT}.
      # @param list_path [String, nil]
      # @param arity [Integer]
      # @yieldreturn [Object] the list file's content
      # @return [Array(Object, Untrusted)]
      def read_with(list_path, arity)
        READ_ATTEMPTS.times do
          before = read(list_path, arity)
          content = yield
          return [content, before] if read(list_path, arity) == before
        end
        [yield, CORRUPT]
      end

      # The lines a list-file row reads back as (decoded and split where the load splits it):
      # a value holding a line break reads back as more than one row.
      # @param line [String] one row as the save writes it
      # @return [Array<String>]
      def read_back(line)
        ConfigFile.split_lines(ConfigFile.decode(ConfigFile.utf8(line)))
      end

      # The notice for a side file that could not be used ({.read} gave {CORRUPT}).
      # @param list_path [String]
      # @return [String]
      def corrupt_notice(list_path)
        "#{File.basename(path(list_path))} is unreadable: no definition loaded from " \
          "#{File.basename(list_path)} may run a Lich command"
      end

      # Save a list file with its side file (see the module comment). The block writes the list
      # file and returns what the save returns; it is not run when the first side-file write fails.
      # @param list_path [String]
      # @param identities [Enumerable<Array<String>>] the saved definitions that are not authored
      # @param arity [Integer]
      # @param on_disk [#call] callable => the identities of every row the list file now on disk
      #   holds (only asked when its side file cannot be read)
      # @param notice [#call, nil] callable(text): told when the side file cannot be brought down to
      #   +identities+ after the list file is written (it then still lists more: fails closed)
      # @return [Object] the block's value
      # @raise [Error] the side file could not be written first (the list file was not written)
      def save(list_path, identities, arity:, on_disk:, notice: nil)
        identities = identities.to_set
        previous = read(list_path, arity)
        guard = identities | (previous.corrupt ? on_disk.call.to_set : previous.identities)
        begin
          write(list_path, guard) unless guard.empty?
        rescue Error => e
          raise Error, "#{e.message}: #{File.basename(list_path)} not saved"
        end
        result = yield
        begin
          update(list_path, identities) unless guard == identities && !guard.empty?
        rescue Error => e
          notice&.call(e.message)
        end
        result
      end

      # Write +identities+ to the side file of +list_path+ atomically, or remove it when empty.
      # @raise [Error]
      def update(list_path, identities)
        identities.empty? ? remove(list_path) : write(list_path, identities)
      end

      def write(list_path, identities)
        rows = identities.map { |identity| JSON.generate(identity) }.sort
        ConfigFile.write_lines(path(list_path), [HEADER, *rows, "end #{rows.length}"])
      rescue StandardError => e
        raise Error, "#{File.basename(path(list_path))} could not be written (#{e.message})"
      end

      def remove(list_path)
        file = path(list_path)
        File.delete(file) if File.exist?(file) || File.symlink?(file)
      rescue StandardError => e
        raise Error, "#{File.basename(file)} could not be removed (#{e.message})"
      end

      # @return [Set<Array<String>>, nil] nil when +lines+ are not a side file of this +arity+
      def parse(lines, arity)
        return nil unless lines && lines.length >= 2 && lines.first == HEADER

        count = FOOTER.match(lines.last)
        return nil unless count && count[1].to_i == lines.length - 2

        lines[1...-1].each_with_object(Set.new) do |line, set|
          identity = JSON.parse(line)
          return nil unless identity.is_a?(Array) && identity.length == arity && identity.all?(String)

          set << identity
        end
      rescue JSON::ParserError
        nil
      end
    end
  end
end
