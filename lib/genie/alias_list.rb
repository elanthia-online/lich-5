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
    # decided when it is added -- true for a row of aliases.cfg ({#load}) and for `#alias` from an
    # authored context ({AuthoredCommand.authored_definitions?}), false otherwise -- and read by
    # {ParseCommand#parse_alias}. Not written by {#save} (Remix's file format): a reload re-reads
    # every row as authored.
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
      # A malformed row (ParseArgs throws) ends the load there.
      # @param path [String, nil] nil = the remembered path
      # @return [Boolean] Remix's Load result
      def load(path = nil)
        @mutex.synchronize { @file = path if path }
        lines = file && ConfigFile.read_lines(file)
        return false if lines.nil?

        lines.each do |line|
          args = Text.parse_args(line)
          add(args[1], args[2], authored: true) if args.length == 3 # the user's own file
        end
        true
      rescue StandardError # Load is catch (Exception) -> false
        false
      end

      # Aliases.Save (Aliases.cs:90-129 R): `#alias {key} {value}` per entry, in list order. The
      # snapshot is taken inside @save_mutex, so an older snapshot never lands last.
      # @param path [String, nil] nil = the remembered path
      # @return [Boolean] false when there is no path or the write failed
      def save(path = nil)
        target = path || file
        return false if target.nil?

        @save_mutex.synchronize do
          ConfigFile.write_lines(target, entries.map { |key, value| "#alias {#{key}} {#{value}}" })
          true
        end
      rescue StandardError
        false
      end
    end
  end
end
