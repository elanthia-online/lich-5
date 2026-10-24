# frozen_string_literal: true

module Lich
  module Genie
    # Process-wide registry of Genie `#trigger`s. Unlike front-end effects, a trigger
    # RUNS COMMANDS when a game line matches, so it is automation and lives in Lich
    # (clean-room port of Genie Globals.Triggers + FormMain.ParseTriggers).
    #
    # Faithful behaviors:
    #   * a trigger is created active (the Trigger ctor, Globals.cs:944-966 R), whatever its
    #     class's state; each class event re-applies the whole {ClassList} through
    #     {#toggle_class} (Command_EventClassChange, FormMain.cs:7483-7519 R), which compares
    #     the class names lower-cased, "" being the class-less triggers (`default`).
    #   * fired in SortedList order of the KEY ({Collation}; Globals.cs:939 R) with each
    #     trigger's IsActive read when the loop reaches it, so an earlier trigger's `#class`
    #     switches a later one on or off for the SAME line (ParseTriggers, FormMain.cs:4435-4457
    #     R). On a match the capture groups (1..n) go to the action.
    #   * keyed like Triggers.Add (Globals.cs:1002-1045 R): the KEY is the pattern with
    #     its `e/`/`eval `/leading-`/` prefix and `/i`/`/` suffix stripped
    #     ({TriggerFile.normalize}). Re-adding a key replaces the trigger (last writer
    #     wins: `foo`, `/foo/i`, `foo` leaves `foo`), and `#untrigger` normalizes the
    #     same way (Remove, Globals.cs:1047-1075 R). `/re/i` compiles case-insensitive
    #     (Trigger ctor, Globals.cs:951-966 R; MyRegexOptions = Multiline, which is
    #     Ruby's default `^`/`$`).
    #   * a non-eval key that does not compile is rejected: {#add} adds nothing and
    #     returns false (the ValidateRegExp gate, Globals.cs:1029-1032 R). The router
    #     echoes `Invalid regexp in trigger:` for it (Command.cs:1418-1421 R); a
    #     triggers.cfg row with one is silently skipped (LoadRow ignores the result).
    #     "Compiles" is {NetRegex}: .NET-only rejections (`a++`, `\Qx`, ...) and the
    #     .NET-only constructs (`[\w-']`, capturing and variable-length lookbehind, inline
    #     `(?i)` scoping) follow Remix; a .NET-valid pattern NetRegex cannot match
    #     ({NetRegex::Unsupported}) is stored, never fires, and the router warns once; the
    #     constructs NetRegex does not cover stay a known divergence (open-items.md Q3).
    #   * an eval trigger (`e/expr/`, `eval expr`) never fires on a game line; a variable
    #     change wakes it ({#eval_candidates}, VariableDispatch; FormMain.cs:4936-4963 R).
    #   * memory-only until `#trigger save` / `#save triggers|all` ({#save}); the
    #     process-wide registry reads `triggers.cfg` once at engine start ({#load}),
    #     like FormMain.cs:2339 R.
    #
    # The registry only decides WHAT fires; a caller-supplied executor runs the action
    # (see {#apply}). Matching is done under a lock, then actions are yielded OUTSIDE
    # the lock so an action that touches the registry (e.g. `#class`) can't deadlock.
    class Triggers
      # +timeouts+: consecutive timed-out matches; +disabled+: shut off after TIMEOUT_LIMIT of them
      # +authored+: the body is the user's own text, so its `,`/`;` rows may be Lich commands ({AuthoredCommand}); decided at {#add}
      Trigger = Struct.new(:pattern, :regex, :commands, :klass, :active, :timeouts, :disabled, :authored)

      # Whether the registry accepts +pattern+: an eval pattern always, any other only
      # when its normalized key compiles ({NetRegex}; Globals.cs:1029-1032 R).
      # @param pattern [String]
      # @return [Boolean]
      def self.valid_pattern?(pattern)
        norm = TriggerFile.normalize(pattern)
        norm.eval || !compile(norm).nil?
      end

      # The {NetRegex::Unsupported} +pattern+ compiles to (registered, never fires, so the
      # router warns once), nil for any other pattern.
      # @param pattern [String]
      # @return [NetRegex::Unsupported, nil]
      def self.unsupported(pattern)
        norm = TriggerFile.normalize(pattern)
        compiled = norm.eval ? nil : compile(norm)
        compiled.is_a?(NetRegex::Unsupported) ? compiled : nil
      end

      # @param norm [TriggerFile::Key]
      # @return [Regexp, NetRegex::Emulated, NetRegex::Unsupported, nil] nil when the key is
      #   not a valid regex
      #
      # A plain Regexp gets a match timeout (MATCH_TIMEOUT_SECONDS): Onigmo backtracks
      # catastrophically on some patterns .NET runs fast, and a #trigger is
      # matched against every game line on the trigger worker -- one such pattern must not stall
      # the engine's game-line dispatch. A timed-out match counts as no match, and TIMEOUT_LIMIT
      # of them in a row shut the trigger off until it is added again ({#apply}). Not
      # applied to NetRegex's lookbehind emulation (NetRegex::Emulated: its internal regexes).
      def self.compile(norm)
        compiled = NetRegex.compile(norm.key, ignore_case: norm.ignore_case)
        compiled.is_a?(Regexp) ? Regexp.new(compiled, timeout: MATCH_TIMEOUT_SECONDS) : compiled
      rescue StandardError # catch-all like ValidateRegExp (Utility.cs:113-126 R)
        nil
      end

      # Regexp#timeout of a #trigger pattern (seconds).
      MATCH_TIMEOUT_SECONDS = 1.0
      # Consecutive timed-out matches after which a #trigger stops being matched (decided
      # divergence, open-items.md K1: Remix would hang its trigger consumer on such a pattern; ours would
      # spend MATCH_TIMEOUT_SECONDS of the trigger worker on every game line, delaying every later
      # line, #trigger and script behind it). A match that completes resets the count.
      TIMEOUT_LIMIT = 3

      def initialize
        @triggers = {}
        @sorted = nil # the keys in SortedList order, rebuilt after a change
        @mutex = Mutex.new
        @save_mutex = Mutex.new
      end

      # @return [#call, nil] callable(pattern) told ONCE about a #trigger shut off after
      #   TIMEOUT_LIMIT consecutive timed-out matches (the glue prints one warning line); called
      #   outside the lock
      attr_accessor :on_disabled

      # Triggers.Add (Globals.cs:1002-1045 R). An empty pattern is a valid key that
      # matches every line, as in Remix. The raw pattern is kept for display and save.
      # @param authored [Boolean] the body is the user's own text: true for a triggers.cfg
      #   row that triggers.cfg.untrusted does not list ({#load}) and a `#trigger` from an
      #   authored context; its `,`/`;` rows may then be Lich commands when it fires
      #   ({TriggerRunner#fire}). Kept across a save and load by {DefinitionTrust}.
      # @return [Boolean] false (nothing added) when a non-eval pattern is not a regex
      def add(pattern, commands, klass: '', authored: false)
        norm = TriggerFile.normalize(pattern)
        regex = norm.eval ? nil : self.class.compile(norm)
        return false if regex.nil? && !norm.eval

        trigger = Trigger.new(pattern.to_s, regex, commands.to_s, klass.to_s, true, 0, false, authored ? true : false)
        @mutex.synchronize do
          @sorted = nil unless @triggers.key?(norm.key)
          @triggers[norm.key] = trigger
        end
        true
      end

      # Triggers.Remove: normalizes like {#add} (Globals.cs:1047-1075 R).
      # @return [void]
      def remove(pattern)
        key = TriggerFile.normalize(pattern).key
        @mutex.synchronize { @sorted = nil if @triggers.delete(key) }
      end

      # @return [void]
      def clear
        @mutex.synchronize do
          @triggers.clear
          @sorted = nil
        end
      end

      # Triggers.ToggleClass (Globals.cs:973-1000 R): every trigger whose class equals +name+
      # lower-cased (Text.net_downcase, Remix ToLower) takes +state+; "" is the class-less
      # triggers (Command_EventClassChange passes "" for `default`).
      # @param name [String]
      # @param state [Boolean]
      # @return [void]
      def toggle_class(name, state)
        key = Text.net_downcase(name.to_s)
        on = state ? true : false
        @mutex.synchronize do
          @triggers.each_value { |t| t.active = on if Text.net_downcase(t.klass) == key }
        end
      end

      # The registry in SortedList order of the key: [key, pattern, commands, class, active] each
      # (ListTriggers prints key=action, Command.cs:3428-3466 R).
      # @return [Array<Array>]
      def entries
        @mutex.synchronize { sorted_triggers.map { |key, t| [key, t.pattern, t.commands, t.klass, t.active] } }
      end

      # @return [Array<Hash>] one entry per trigger, for display/inspection
      def list
        @mutex.synchronize do
          @triggers.values.map do |t|
            { 'pattern' => t.pattern, 'class' => t.klass, 'active' => t.active, 'commands' => t.commands }
          end
        end
      end

      # @param pattern [String] normalized like {#add}
      # @return [Boolean, nil] whether that trigger's body is authored; nil: no such trigger
      def authored?(pattern)
        key = TriggerFile.normalize(pattern).key
        @mutex.synchronize { @triggers[key]&.authored }
      end

      # @return [Integer] number of registered triggers
      def count
        @mutex.synchronize { @triggers.length }
      end

      # Add every row of a `triggers.cfg` to the registry WITHOUT clearing it first
      # (TriggerList.Load, Globals.cs:1077-1110 R; `#trigger load` merges, Command.cs:
      # 1380-1384 R, while `#load triggers` clears first, Command.cs:684-690 R). A row is
      # authored unless triggers.cfg.untrusted lists it; every row is not authored when that
      # file cannot be read, and +notice+ is told once ({DefinitionTrust}).
      # @param path [String, nil]
      # @param notice [#call, nil] callable(text): one engine line
      # @return [Boolean] Remix's Load result (false: absent, or a malformed row
      #   aborted the rest of the file)
      def load(path, notice: nil)
        (rows, ok), untrusted = DefinitionTrust.read_with(path, 3) { TriggerFile.read(path) }
        notice&.call(DefinitionTrust.corrupt_notice(path)) if untrusted.corrupt && !rows.empty?
        rows.each { |row| add(row.pattern, row.commands, klass: row.klass, authored: untrusted.authored?(row.to_a)) }
        ok
      end

      # Write every trigger, active or not, to +path+ (TriggerList.Save,
      # Globals.cs:1127-1182 R). The snapshot is taken under the lock; the file is
      # written outside it, so a contended write never blocks the trigger worker's
      # matching. @save_mutex orders whole saves, as GlobalStore#save does: Remix holds
      # the reader lock across the write, so no Add can land between a save's snapshot
      # and its file and two saves write the same rows; here the later save takes its
      # snapshot after the earlier one has written, so an older snapshot never lands last.
      # The triggers that are not authored are listed in triggers.cfg.untrusted, written before
      # triggers.cfg ({DefinitionTrust.save}); when that write fails, +notice+ is told and
      # triggers.cfg is not written.
      # @param path [String]
      # @param notice [#call, nil] callable(text): one engine line for a side-file failure
      # @return [Boolean] false when the file could not be written (Save swallows it)
      def save(path, notice: nil)
        return false if path.nil?

        @save_mutex.synchronize do
          snapshot = @mutex.synchronize { @triggers.values.map { |t| [t.pattern, t.commands, t.klass, t.authored] } }
          untrusted = snapshot.reject(&:last).flat_map { |pattern, commands, klass| TriggerFile.identities(pattern, commands, klass) }
          on_disk = -> { TriggerFile.read(path).first.map(&:to_a) }
          DefinitionTrust.save(path, untrusted, arity: 3, on_disk: on_disk, notice: notice) do
            TriggerFile.save(path, snapshot.map { |pattern, commands, klass| { 'pattern' => pattern, 'commands' => commands, 'class' => klass } })
            true
          end
        end
      rescue DefinitionTrust::Error => e
        notice&.call(e.message)
        false
      rescue StandardError # Save is catch (Exception) -> false (Globals.cs:1177-1181 R)
        false
      end

      # ParseTriggers' loop (FormMain.cs:4431-4457 R): every trigger in SortedList order of its
      # key, IsActive read as the loop reaches it -- after the actions of the earlier matches
      # ran -- and on a match yields [commands, captures, authored] (captures = groups 1..n as
      # strings; authored = whether its body is the user's own text) before going on. The order is taken under
      # the lock, the matching and the actions run outside it, so an action that touches the
      # registry (`#class`, `#trigger`) is safe; a trigger it adds fires from the next line on
      # (Remix: the add fails under the reader lock; a tracked divergence, open-items.md Q8).
      # @param line [String]
      # @yield [commands, captures, authored]
      # @return [void]
      def apply(line)
        return unless line.is_a?(String)

        @mutex.synchronize { sorted_triggers.map(&:last) }.each do |t|
          next unless t.active && t.regex && !t.disabled

          md = match(t, line)
          yield(t.commands, md.captures.map(&:to_s), t.authored) if md
        end
      end

      # The eval triggers a change of +name+ wakes (FormMain.cs:4940-4946 R): every active
      # eval trigger whose KEY (the normalized pattern, Globals.cs:1002-1023 R) contains
      # +name+ -- a substring test, so `$tb` also wakes a `$tbx = 1` key. Snapshot taken under
      # the lock, in SortedList order.
      # @param name [String] the variable name as raised ("$health", "lastcommand", ...)
      # @return [Array<Array(String, String, Boolean)>] [key, commands, authored] triples
      def eval_candidates(name)
        @mutex.synchronize do
          sorted_triggers.filter_map do |key, t|
            [key, t.commands, t.authored] if t.active && t.regex.nil? && key.include?(name)
          end
        end
      end

      # Diagnostic: every trigger whose regex matches +line+, with its class and
      # active state -- so a trace can tell "the pattern did not match" apart from
      # "it matched but its class is off" (the usual reason a trigger looks dead).
      # Does NOT run any actions.
      # @param line [String]
      # @return [Array<Hash>]
      def diagnose(line)
        return [] unless line.is_a?(String)

        @mutex.synchronize do
          @triggers.values.filter_map do |t|
            next if t.disabled || !t.regex&.match?(line)

            { 'pattern' => t.pattern, 'class' => t.klass, 'active' => t.active }
          rescue Regexp::TimeoutError
            nil
          end
        end
      end

      private

      # [key, trigger] pairs in SortedList order (under the lock); the key order is cached until
      # the next add of a new key, remove or clear.
      def sorted_triggers
        @sorted ||= Collation.sort(@triggers.keys)
        @sorted.map { |key| [key, @triggers[key]] }
      end

      # One match of +trigger+ outside the lock; a timed-out match is no match and counts toward
      # the shut-off ({TIMEOUT_LIMIT}).
      def match(trigger, line)
        md = trigger.regex.match(line)
        @mutex.synchronize { trigger.timeouts = 0 }
        md
      rescue Regexp::TimeoutError # no match (MATCH_TIMEOUT_SECONDS, {.compile})
        on_disabled&.call(trigger.pattern) if @mutex.synchronize { timed_out(trigger) }
        nil
      end

      # One more consecutive timed-out match of +trigger+ (under the lock).
      # @return [Boolean] whether this one shut it off (TIMEOUT_LIMIT reached)
      def timed_out(trigger)
        trigger.timeouts += 1
        return false if trigger.timeouts < TIMEOUT_LIMIT

        trigger.disabled = true
      end
    end
  end
end
