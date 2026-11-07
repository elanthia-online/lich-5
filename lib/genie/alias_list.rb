# frozen_string_literal: true

module Lich
  module Genie
    # Port of Remix Lists/Aliases.cs (R): the global alias list. Command.ParseCommand expands a
    # piece whose first word is a key on EVERY ParseCommand -- a script's `put`/`send`, a released
    # queue item, a #trigger body, a ParseAllArgs argument (Command.cs:235-241 R) -- so it is
    # engine state, not only a front end's: `#alias {nexus} {recall nexus list}` makes a script's
    # `put nexus` send "recall nexus list" ({ParseCommand#parse_alias}).
    #
    # A SortedList ({Collation} order) keyed as given; the lookup is exact (Remix's SortedList
    # compares with the culture comparer, which tells keys apart by case too). Loaded from
    # aliases.cfg at engine start (FormMain.cs:2323 R), written only by `#alias save` / `#save
    # aliases|all`. Thread-safe (one mutex).
    #
    # Each alias also carries whether its value is the user's own text ({AuthoredCommand}):
    # decided when it is added -- true for a row of aliases.cfg that aliases.cfg.untrusted does
    # not list ({#load}) and for `#alias` from an authored context
    # ({AuthoredCommand.authored_definitions?}), false otherwise -- and read by
    # {ParseCommand#parse_alias}. aliases.cfg keeps Remix's format; {#save} lists the aliases that
    # are not authored in the side file ({DefinitionTrust}).
    class AliasList
      def initialize
        @entries = {}
        @authored = {} # key => true for an authored value (absent = not authored)
        @file = nil # m_FileName (Aliases.cs:38 R): the last path given to {#load}
        @mutex = Mutex.new
        @save_mutex = Mutex.new # orders whole saves, like Triggers#save
      end

      # @return [String, nil] where `#alias load|save` read and write (the last loaded path)
      attr_reader :file

      # Aliases.Add (Aliases.cs:10-23 R): a new key or a replaced value (and provenance).
      # @param authored [Boolean] the value is the user's own text
      # @return [void]
      def add(key, value, authored: false)
        @mutex.synchronize do
          @entries[key.to_s] = value.to_s
          authored ? @authored[key.to_s] = true : @authored.delete(key.to_s)
        end
      end

      # Aliases.Remove (Aliases.cs:25-37 R).
      # @return [Boolean] whether there was such a key
      def remove(key)
        @mutex.synchronize do
          @authored.delete(key.to_s)
          !@entries.delete(key.to_s).nil?
        end
      end

      # @return [void]
      def clear
        @mutex.synchronize do
          @entries.clear
          @authored.clear
        end
      end

      # @param key [String]
      # @return [Boolean] whether +key+'s value was added as the user's own text
      def authored?(key)
        @mutex.synchronize { @authored.key?(key.to_s) }
      end

      # @param key [String]
      # @return [Boolean]
      def key?(key)
        @mutex.synchronize { @entries.key?(key.to_s) }
      end

      # @param key [String]
      # @return [String, nil]
      def [](key)
        @mutex.synchronize { @entries[key.to_s] }
      end

      # @return [Array<Array(String, String)>] [key, alias] in SortedList order (ListAliases,
      #   Command.cs:3468-3506 R; Save)
      def entries
        snapshot = @mutex.synchronize { @entries.dup }
        Collation.sort(snapshot.keys).map { |key| [key, snapshot[key]] }
      end

      # Aliases.Load (Aliases.cs:40-88 R): every row with exactly three ParseArgs tokens is
      # merged in (`#alias {key} {value}`); the path is remembered even when the file is absent.
      # A malformed row (ParseArgs throws) ends the load there. A row is authored unless
      # aliases.cfg.untrusted lists it; every row is not authored when that file cannot be read,
      # and +notice+ is told once ({DefinitionTrust}).
      # @param path [String, nil] nil = the remembered path
      # @param notice [#call, nil] callable(text): one engine line
      # @return [Boolean] Remix's Load result
      def load(path = nil, notice: nil)
        @mutex.synchronize { @file = path if path }
        source = file
        lines, untrusted = DefinitionTrust.read_with(source, 2) { source && ConfigFile.read_lines(source) }
        return false if lines.nil?

        noticed = false
        lines.each do |line|
          row = self.class.parse_row(line)
          next unless row

          if untrusted.corrupt && !noticed
            noticed = true
            notice&.call(DefinitionTrust.corrupt_notice(source))
          end
          add(*row, authored: untrusted.authored?(row))
        end
        true
      rescue StandardError # Load is catch (Exception) -> false
        false
      end

      # Aliases.Save (Aliases.cs:90-129 R): `#alias {key} {value}` per entry, in list order. The
      # snapshot is taken inside @save_mutex, so an older snapshot never lands last. The aliases
      # that are not authored are listed in aliases.cfg.untrusted, written before aliases.cfg
      # ({DefinitionTrust.save}); when that write fails, +notice+ is told and aliases.cfg is not
      # written.
      # @param path [String, nil] nil = the remembered path
      # @param notice [#call, nil] callable(text): one engine line for a side-file failure
      # @return [Boolean] false when there is no path or the write failed
      def save(path = nil, notice: nil)
        target = path || file
        return false if target.nil?

        @save_mutex.synchronize do
          snapshot = @mutex.synchronize { [@entries.dup, @authored.dup] }
          rows = Collation.sort(snapshot[0].keys).map { |key| [key, snapshot[0][key]] }
          untrusted = rows.reject { |key, _| snapshot[1].key?(key) }.flat_map { |key, value| self.class.identities(key, value) }
          DefinitionTrust.save(target, untrusted, arity: 2, on_disk: -> { identities_on_disk(target) }, notice: notice) do
            ConfigFile.write_lines(target, rows.map { |key, value| self.class.row(key, value) })
            true
          end
        end
      rescue DefinitionTrust::Error => e
        notice&.call(e.message)
        false
      rescue StandardError
        false
      end

      # The row Aliases.Save writes (Aliases.cs:110-111 R).
      # @return [String]
      def self.row(key, value)
        "#alias {#{key}} {#{value}}"
      end

      # One aliases.cfg line as {#load} reads it: [key, value] when ParseArgs gives exactly three
      # tokens, else nil.
      # @param line [String]
      # @return [Array(String, String), nil]
      # @raise [Error] a line ParseArgs throws on (it ends the load)
      def self.parse_row(line)
        args = Text.parse_args(line)
        args.length == 3 ? [args[1], args[2]] : nil
      end

      # An alias's identity as {#load} reads it back from the row {.row} writes ({DefinitionTrust}).
      # @return [Array<Array(String, String)>]
      def self.identities(key, value)
        DefinitionTrust.read_back(row(key, value)).filter_map do |line|
          parse_row(line)
        rescue StandardError # a piece ParseArgs throws on ends the load there: nothing to list
          nil
        end
      end

      private

      # Every row of the aliases.cfg now at +path+, as {#load} would read it (up to a malformed row).
      def identities_on_disk(path)
        rows = []
        (ConfigFile.read_lines(path) || []).each do |line|
          row = self.class.parse_row(line)
          rows << row if row
        end
        rows
      rescue StandardError
        rows
      end
    end
  end
end
