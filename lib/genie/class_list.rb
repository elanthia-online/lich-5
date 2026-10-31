# frozen_string_literal: true

module Lich
  module Genie
    # Port of Remix Lists/Classes.cs (R): the global class list `#class` edits -- one name ->
    # on/off entry per class, kept in SortedList order ({Collation}). It gates the global
    # #triggers and the gags/substitutes (and, in a front end, the highlights) only through
    # {#each_state}: Command_EventClassChange re-applies EVERY entry, in list order, to every
    # list on each class event (FormMain.cs:7483-7519 R), so a trigger added while its class is
    # off fires until the next class event switches it off again, and `default` stands for the
    # class-less ("") entries. The script-local action classes are a different store
    # ({ActionList}).
    #
    # Faithful details:
    #   * keys are case-sensitive as given (`#class Foo on` and `#class foo on` are two entries);
    #     only the `+name`/`-name` forms lower-case (Command.cs:1256-1270 R);
    #   * {#add}'s value test is true/on/1 -> on, false/off/0 -> off, ANYTHING ELSE -> off
    #     (Classes.cs:87-121 R: `yes` switches a class off);
    #   * {#activate_all} switches every entry on, {#inactivate_all} every entry but `default`
    #     off (Classes.cs:11-58 R); {#clear} leaves `default` = True (Classes.cs:80-85 R), as
    #     does every {#load} (Classes.cs:144-146 R).
    #
    # Thread-safe: one mutex; {#each_state} yields a snapshot outside it. @save_mutex orders
    # whole saves (snapshot + write), like Triggers#save and GlobalStore#save.
    class ClassList
      def initialize
        @entries = {} # key => Boolean
        @mutex = Mutex.new
        @save_mutex = Mutex.new
      end

      # Classes.Add(sKey, sValue) (Classes.cs:87-121 R).
      # @param key [String]
      # @param value [String]
      # @return [void]
      def add(key, value)
        on = %w[true on 1].include?(Text.net_downcase(value.to_s))
        @mutex.synchronize { @entries[key.to_s] = on }
      end

      # Classes.ActivateAll (Classes.cs:11-32 R).
      # @return [void]
      def activate_all
        @mutex.synchronize { @entries.each_key { |key| @entries[key] = true } }
      end

      # Classes.InActivateAll (Classes.cs:34-58 R): `default` keeps its state.
      # @return [void]
      def inactivate_all
        @mutex.synchronize { @entries.each_key { |key| @entries[key] = false unless key == 'default' } }
      end

      # Classes.Clear (Classes.cs:80-85 R).
      # @return [void]
      def clear
        @mutex.synchronize do
          @entries.clear
          @entries['default'] = true
        end
      end

      # Classes.Remove (Classes.cs:123-134 R). Remix's `#unclass` never calls it (it removes an
      # ALIAS, Command.cs:1356-1364 R), so no command reaches it.
      # @param key [String]
      # @return [Boolean] whether there was such an entry
      def remove(key)
        @mutex.synchronize { !@entries.delete(key.to_s).nil? }
      end

      # @param key [String]
      # @return [Boolean, nil] the entry's state, nil when there is none
      def [](key)
        @mutex.synchronize { @entries[key.to_s] }
      end

      # The entries in SortedList order, each [key, state] -- what Command_EventClassChange walks
      # and ListClasses prints (Command.cs:3508-3546 R).
      # @return [Array<Array(String, Boolean)>]
      def entries
        snapshot = @mutex.synchronize { @entries.dup }
        Collation.sort(snapshot.keys).map { |key| [key, snapshot[key]] }
      end

      # Command_EventClassChange's walk (FormMain.cs:7483-7519 R): each entry in list order as the
      # class name the lists compare with -- `default` is "" (the class-less entries) -- and its
      # state.
      # @yieldparam name [String]
      # @yieldparam state [Boolean]
      # @return [void]
      def each_state
        entries.each { |key, state| yield(key == 'default' ? '' : key, state) }
      end

      # Classes.Load (Classes.cs:138-189 R): `default` = True first, then every `#class {key}
      # {value}` row (exactly three ParseArgs tokens; the value lower-cased) merged in. A missing
      # file loads nothing; a malformed row (ParseArgs throws) ends the load there.
      # @param path [String, nil]
      # @return [Boolean] Remix's Load result
      def load(path)
        add('default', 'True')
        lines = path && ConfigFile.read_lines(path)
        return false if lines.nil?

        lines.each do |line|
          args = Text.parse_args(line)
          add(args[1], Text.net_downcase(args[2])) if args.length == 3
        end
        true
      rescue StandardError # Load is catch (Exception) -> false (Classes.cs:169-174 R)
        false
      end

      # Classes.Save (Classes.cs:191-229 R): `#class {key} {True|False}` per entry, in list order.
      # The snapshot is taken inside @save_mutex, so two concurrent saves write in order and an
      # older snapshot never lands last.
      # @param path [String, nil]
      # @return [Boolean] false when there is no path or the write failed
      def save(path)
        return false if path.nil?

        @save_mutex.synchronize do
          ConfigFile.write_lines(path, entries.map { |key, state| "#class {#{key}} {#{state ? 'True' : 'False'}}" })
          true
        end
      rescue StandardError
        false
      end
    end
  end
end
