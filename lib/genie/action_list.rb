# frozen_string_literal: true

module Lich
  module Genie
    # A script's action registry: port of Remix Script.ClassActionList (Script.cs:328-485 R).
    #
    #   * Keyed by the NORMALIZED trigger (`e/`/`eval ` prefix, a leading `/` and a
    #     trailing `/i` or `/` stripped, exactly like Triggers.Add; TriggerFile.normalize).
    #     Registering a key again REPLACES that action (`base[sTrigger] = new Action`,
    #     Script.cs:427-434 R), so an `action` row inside a loop never duplicates.
    #   * Iterated in SortedList order: the default comparer, i.e. the current culture's
    #     string compare (ICU root on Remix, {Collation}; measured on genieflow with the flow
    #     case t93). TriggerParse fires EVERY matching action in that order.
    #   * The class comes from the ACTION text, not from the `action` row: a body starting
    #     `(name)` has its class cut off (lower-cased, trimmed) and the rest trimmed
    #     (Script.cs:410-426 R). The class list remembers each class's FIRST state only: Add
    #     registers an unknown class as on, SetClass registers an unknown class with the given
    #     state, and neither ever updates a known class (Script.cs:417-424, 469-484 R) -- so a
    #     class first seen through `action (c) off` keeps creating INACTIVE actions after
    #     `action (c) on`, and one first seen through an action keeps creating active ones
    #     after `action (c) off`. SetClass flips IsActive on every current action of
    #     the class regardless. Clear keeps the class list (it is not part of the SortedList).
    class ActionList
      # One registered action (ClassActionList.Action, Script.cs:330-366 R).
      # @!attribute key [String] the normalized trigger (the SortedList key)
      # @!attribute action [String] the body, class prefix removed
      # @!attribute regex [Regexp, nil] nil for an eval action
      # @!attribute klass [String] "" when the action has no class
      # @!attribute active [Boolean] IsActive (mutable: SetClass flips it in place)
      # @!attribute sort_key [Array] Collation.key(key), computed once per key (uber.cmd
      #   re-registers its actions inside combat subs)
      # @!attribute authored [Boolean] the body is the user's own text (command provenance, {AuthoredCommand}):
      #   its `action` row was a .cmd row, not an action body's
      Entry = Struct.new(:key, :action, :regex, :eval, :klass, :active, :instant, :file_id, :file_row, :sort_key, :authored)

      def initialize
        @entries = {}
        @classes = {}
        @sorted = nil
      end

      # ClassActionList.Add (Script.cs:369-437 R).
      # @param trigger [String] the trigger text (already variable-expanded by the caller)
      # @param action [String] the action body, possibly starting with `(class)`
      # @param instant [Boolean]
      # @param authored [Boolean] see {Entry}
      # @return [Boolean] false when the pattern is not a valid (.NET) regex
      def add(trigger, action, file_id: 0, file_row: 0, instant: false, authored: false)
        norm = TriggerFile.normalize(trigger)
        regex = nil
        unless norm.eval
          begin
            regex = NetRegex.compile(norm.key, ignore_case: norm.ignore_case)
          rescue StandardError
            return false
          end
        end
        klass, body, active = split_class(action.to_s)
        old = @entries[norm.key]
        entry = Entry.new(norm.key, body, regex, norm.eval, klass, active, instant, file_id, file_row,
                          old ? old.sort_key : Collation.key(norm.key), authored ? true : false)
        @entries[norm.key] = entry
        replace_sorted(old, entry)
        true
      end

      # ClassActionList.Remove (Script.cs:439-467 R): normalize like Add, delete the key.
      # @param text [String]
      # @return [void]
      def remove(text)
        key = TriggerFile.normalize(text).key
        @sorted = nil if @entries.delete(key)
      end

      # SortedList.Clear: every action goes, the class list stays.
      # @return [void]
      def clear
        @entries.clear
        @sorted = nil
      end

      # ClassActionList.SetClass (Script.cs:469-484 R).
      # @param name [String]
      # @param status [Boolean]
      # @return [void]
      def set_class(name, status)
        name = Text.net_trim(name.to_s.downcase)
        @classes[name] = status unless @classes.key?(name)
        @entries.each_value { |entry| entry.active = status if entry.klass == name }
      end

      # @return [Array<Entry>] the actions in SortedList order (a snapshot: callers may
      #   register or remove actions while walking it)
      def to_a
        @sorted ||= @entries.values.sort_by(&:sort_key).freeze
      end

      # @return [Array<Entry>] the eval actions of {#to_a}, in the same order (cached per
      #   snapshot: every local variable set asks for them, Script.TriggerVariableChanged)
      def eval_entries
        sorted = to_a
        @eval_entries = [sorted, sorted.select(&:eval).freeze] unless @eval_entries&.first.equal?(sorted)
        @eval_entries.last
      end

      # @param entry [Entry]
      # @return [Boolean] true while +entry+ is the action registered under its key
      def current?(entry)
        @entries[entry.key].equal?(entry)
      end

      # @return [Integer]
      def size
        @entries.size
      end

      # @param key [String] a normalized trigger
      # @return [Entry, nil]
      def [](key)
        @entries[key]
      end

      # @param name [String] a lower-cased class name
      # @return [Boolean, nil] the class's remembered (first) state, nil if never seen
      def class_state(name)
        @classes[name]
      end

      private

      # Keep the sorted snapshot valid across an add: a new key needs a re-sort; a replaced
      # key keeps its place, so the new Entry is swapped into a COPY (a caller may be walking
      # the old snapshot).
      def replace_sorted(old, entry)
        return if @sorted.nil?
        return @sorted = nil if old.nil?

        index = @sorted.index { |e| e.equal?(old) }
        return @sorted = nil if index.nil?

        copy = @sorted.dup
        copy[index] = entry
        @sorted = copy.freeze
      end

      # The class prefix of an action body and the action's initial IsActive.
      # @return [Array(String, String, Boolean)] class, body, active
      def split_class(action)
        return ['', action, true] unless action.start_with?('(')

        close = action.index(')')
        return ['', action, true] if close.nil?

        klass = Text.net_trim(action[1...close].downcase)
        body = Text.net_trim(action[(close + 1)..])
        @classes[klass] = true unless @classes.key?(klass)
        [klass, body, @classes[klass] != false]
      end
    end
  end
end
