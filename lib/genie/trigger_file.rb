# frozen_string_literal: true

module Lich
  module Genie
    # Genie's `triggers.cfg`: one `#trigger {pattern} {action} [{class}]` row per trigger.
    # Port of Globals.Triggers Load/LoadRow/Save (Globals.cs:1077-1182 R).
    #
    #   * load: ParseArgs every line; more than 2 args adds pattern [1], action [2] and
    #     the trimmed class [3] (LoadRow, Globals.cs:1112-1125 R). The pattern is used
    #     as written: LoadRow calls TriggerList.Add directly, NOT Globals.AddTrigger, so
    #     no `$var` substitution happens on load. Like variables.cfg, a row that makes
    #     ParseArgs throw aborts the rest of the file (Globals.cs:1100-1108 R).
    #   * save: rows in SortedList order of the trigger KEY. Remix's key is the pattern
    #     with its `e/`/`eval ` prefix and `/`...`/`/`/i` wrapper stripped
    #     (Triggers.Add, Globals.cs:1001-1023 R); Save rebuilds `e/key/` for an eval
    #     trigger and `/key/i` for an ignore-case one, and appends ` {class}` only when
    #     the class is non-empty (Globals.cs:1144-1161 R).
    module TriggerFile
      Row = Struct.new(:pattern, :commands, :klass)
      Key = Struct.new(:key, :ignore_case, :eval)

      module_function

      # @param path [String, nil]
      # @return [Array(Array<Row>, Boolean)] rows in file order, and Remix's Load
      #   return value (false when absent, unreadable, or aborted by a malformed row)
      def read(path)
        rows = []
        lines = ConfigFile.read_lines(path)
        return [rows, false] if lines.nil?

        lines.each do |line|
          args = Text.parse_args(line)
          next unless args.length > 2

          rows << Row.new(args[1], args[2], args.length > 3 ? args[3].strip : '')
        end
        [rows, true]
      rescue StandardError
        # Load is catch (Exception) -> false (Globals.cs:1105-1109 R): a malformed row
        # or an unreadable file keeps the rows read so far and never raises.
        [rows, false]
      end

      # Triggers.Add's pattern normalization (Globals.cs:1001-1023 R).
      # @param pattern [String]
      # @return [Key]
      def normalize(pattern)
        key = pattern.to_s
        eval_trigger = false
        if key.start_with?('e/')
          key = key[2..]
          eval_trigger = true
        elsif key.byteslice(0, 5).b.casecmp?('eval ') # ASCII-only ToLower match; never raises on bad bytes
          key = key[5..]
          eval_trigger = true
        elsif key.start_with?('/')
          key = key[1..]
        end
        ignore_case = false
        if key.end_with?('/i')
          ignore_case = true
          key = key[0...-2]
        elsif key.end_with?('/')
          key = key[0...-1]
        end
        Key.new(key, ignore_case, eval_trigger)
      end

      # The row Triggers.Save writes for one trigger (Globals.cs:1146-1160 R).
      # @return [String]
      def row(pattern, commands, klass)
        norm = normalize(pattern)
        shown = if norm.eval then "e/#{norm.key}/"
                elsif norm.ignore_case then "/#{norm.key}/i"
                else norm.key
                end
        line = "#trigger {#{shown}} {#{commands}}"
        klass.to_s.empty? ? line : "#{line} {#{klass}}"
      end

      # @param triggers [Array<Hash>] entries with 'pattern', 'commands', 'class'
      # @return [Array<String>] the rows in Remix's order. {Triggers} keys its registry
      #   by the normalized key, so its list never has collisions; for any other input
      #   a later entry with the same key overwrites an earlier one
      def rows(triggers)
        by_key = {}
        triggers.each { |t| by_key[normalize(t['pattern']).key] = t }
        Collation.sort(by_key.keys).map do |key|
          t = by_key[key]
          row(t['pattern'], t['commands'], t['class'])
        end
      end

      # @param path [String]
      # @param triggers [Array<Hash>]
      # @return [void]
      # @raise [StandardError] when the file cannot be written (callers swallow it)
      def save(path, triggers)
        ConfigFile.write_lines(path, rows(triggers))
      end
    end
  end
end
