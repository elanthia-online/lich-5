# frozen_string_literal: true

module Lich
  module Genie
    # The keys of Remix's name list (Lists/Names.cs R; `#name`, `#unname`, names.cfg). The colours
    # and the highlighting are the front end's (the `name` / `unname` hooks); the engine keeps the
    # keys for one Remix behaviour scripts can see: every add and every load ends in RebuildIndex
    # (Names.cs:91-112 R), which compiles `\b(<key>|<key>...)\b` over the sorted keys -- a key that
    # makes that an invalid .NET regex throws there, on that `#name` and on every later one while
    # the key stays listed, ending the ParseCommand (genieflow: "Invalid pattern
    # '\b(bad[|x)\b' ... Unterminated [] set." for `#name red x` after `#name red {bad[}`). Remove
    # and Clear do not rebuild.
    #
    # Thread-safe: one mutex; the validation runs on a snapshot outside it.
    class NameList
      def initialize
        @keys = {}
        @mutex = Mutex.new
      end

      # @return [Array<String>] the keys in RebuildIndex's order
      def keys
        Collation.sort(@mutex.synchronize { @keys.keys })
      end

      # Names.Add of each key (an empty one adds nothing, Names.cs:41-46 R), then RebuildIndex.
      # @param keys [Array<String>]
      # @return [void]
      # @raise [Error] when the index is not a valid regex (the keys stay added)
      def add(keys)
        @mutex.synchronize { keys.each { |key| @keys[key.to_s] = true unless key.to_s.empty? } }
        rebuild_index
      end

      # Names.Remove of each key (Names.cs:80-90 R).
      # @param keys [Array<String>]
      # @return [void]
      def remove(keys)
        @mutex.synchronize { keys.each { |key| @keys.delete(key.to_s) } }
      end

      # @return [void]
      def clear
        @mutex.synchronize { @keys.clear }
      end

      # Names.Load (Names.cs:114-148 R): each row with exactly three ParseArgs tokens adds its third
      # (`#name {colour} {key}`), merged in; then RebuildIndex. No file: false, nothing rebuilt.
      # @param path [String, nil]
      # @return [Boolean]
      # @raise [Error] when the index is not a valid regex (see {#add})
      def load(path)
        lines = path && ConfigFile.read_lines(path)
        return false if lines.nil?

        lines.each do |line|
          args = Text.parse_args(line)
          add_key(args[2].to_s) if args.length == 3
        end
        rebuild_index
        true
      end

      # RebuildIndex's regex: `\b(` + the sorted keys joined by `|` + `)\b`, "" with no key.
      # @return [String]
      def index_pattern
        joined = keys.join('|')
        joined.empty? ? '' : "\\b(#{joined})\\b"
      end

      private

      def add_key(key)
        @mutex.synchronize { @keys[key] = true unless key.empty? }
      end

      def rebuild_index
        pattern = index_pattern
        NetRegex.compile(pattern)
        nil
      rescue RegexpError => e
        raise Error, "Invalid pattern '#{pattern}'. #{e.message}"
      end
    end
  end
end
