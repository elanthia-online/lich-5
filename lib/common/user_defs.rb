# frozen_string_literal: true

module Lich
  module Common
    # Shared machinery for merging player-supplied definitions onto core Lich's
    # frozen defaults: lenient per-entry validation with player-facing
    # diagnostics, timeout-bounded regex compilation, guarded matching, and a
    # memo with +reset!+.
    #
    # Extend it onto a module that owns one family of user definitions. The
    # extending module supplies the reading (where entries come from) and any
    # shape checks specific to its domain; everything below is domain-neutral.
    # Extracted from {Lich::DragonRealms::CustomSubstitutions} so the GemStone
    # combat definition supplements can share it without duplicating the
    # validation, timeout and reporting rules.
    #
    # Contract for every player entry:
    # - Invalid entries are dropped individually. One bad entry never disables
    #   the rest of its list.
    # - Every rejection is reported through {Lich::Messaging} with the exact
    #   key, index, offending value, reason, and consequence.
    # - Regexes compile with {REGEX_TIMEOUT_SECONDS} so a pathological pattern
    #   raises {Regexp::TimeoutError} instead of hanging Lich.
    #
    # @example
    #   module MyDefs
    #     extend Lich::Common::UserDefs
    #     MESSAGE_PREFIX = '[MyDefs]'
    #
    #     def self.patterns
    #       memoize(:patterns) do
    #         validate_entries(raw_list, :patterns) { |entry, i| validate_regex(entry, :patterns, i) }
    #       end
    #     end
    #   end
    module UserDefs
      # Per-regex evaluation budget (seconds) applied to every user-supplied
      # pattern. See {#timeout_bounded} and {#apply_regexes}.
      REGEX_TIMEOUT_SECONDS = 1.0

      # Sets up the per-module state: a lock guarding the caches (any number of
      # concurrently running scripts may call the extending module on shared
      # game text), the memo, and the once-only timeout report set.
      def self.extended(base)
        base.instance_variable_set(:@lock, Mutex.new)
        base.instance_variable_set(:@cache, {})
        base.instance_variable_set(:@reported_timeouts, [])
      end

      # Clears the memoized results and the per-pattern timeout-report dedup set
      # so the next lookup re-reads and re-validates. Call this whenever the
      # underlying source is reloaded.
      #
      # @return [void]
      def reset!
        @lock.synchronize do
          @cache = {}
          @reported_timeouts = []
        end
      end

      # Folds +patterns+ over +text+ as successive +String#sub(pattern, '')+
      # deletions, guarding each against {Regexp::TimeoutError}. A pattern that
      # times out is skipped for this input and reported once (deduplicated by
      # pattern source), never hanging the caller.
      #
      # @param text [String] the text to strip
      # @param patterns [Array<Regexp>] validated, timeout-bounded patterns
      # @return [String] +text+ with every applicable pattern removed
      def apply_regexes(text, patterns)
        patterns.reduce(text) do |current, pattern|
          current.sub(pattern, '')
        rescue Regexp::TimeoutError
          report_timeout(pattern)
          current
        end
      end

      private

      # Prefix on every player-facing message so the source is unambiguous.
      # The extending module may define +MESSAGE_PREFIX+; otherwise its own
      # short name is used.
      #
      # @return [String]
      def message_prefix
        return self::MESSAGE_PREFIX if const_defined?(:MESSAGE_PREFIX, false)

        "[#{name.to_s.split('::').last}]"
      end

      # Returns the memoized value for +key+, computing it with the block on
      # first use. Double-checked: no lock on the warm path (the common case on
      # hot parse paths), lock only to populate a missing key. Presence, not
      # truthiness, decides whether the key is cached, so a value of +false+ or
      # +nil+ is memoized like any other.
      #
      # @param key [Object] memo key
      # @return [Object] the cached or freshly computed value
      def memoize(key)
        return @cache[key] if @cache.key?(key)

        @lock.synchronize do
          return @cache[key] if @cache.key?(key)

          @cache[key] = yield
        end
      end

      # Validates each entry of +raw+ with the block, keeping the non-nil
      # results. Reports and returns an empty list when +raw+ is not a list.
      #
      # @param raw [Object] the player's value for +key+
      # @param key [Symbol, String] the key, for messages
      # @yieldparam entry [Object] one raw entry
      # @yieldparam index [Integer] its position, for messages
      # @yieldreturn [Object, nil] the validated entry, or nil if rejected
      # @return [Array] the valid entries (possibly empty)
      def validate_entries(raw, key)
        return [] if raw.nil?

        unless raw.is_a?(Array)
          report("#{key} ignored -- expected a list, got #{raw.class}. No custom entries were loaded.")
          return []
        end

        valid = raw.each_with_index.filter_map { |entry, index| yield(entry, index) }
        report_debug("loaded #{valid.size} custom #{key} #{valid.size == 1 ? 'entry' : 'entries'}") unless valid.empty?
        valid
      end

      # Validates a +[from, to]+ literal substitution pair.
      #
      # @return [Array(String, String), nil] the pair, or nil if rejected
      def validate_pair(entry, key, index)
        unless entry.is_a?(Array) && entry.size == 2
          report("#{key}[#{index}] skipped -- expected a [from, to] pair, got #{entry.inspect}. This entry will not be applied.")
          return nil
        end

        from, to = entry
        unless from.is_a?(String) && to.is_a?(String)
          report("#{key}[#{index}] skipped -- both 'from' and 'to' must be strings, got #{entry.inspect}. This entry will not be applied.")
          return nil
        end

        if from.empty?
          report("#{key}[#{index}] skipped -- 'from' must not be empty (it would match everything). This entry will not be applied.")
          return nil
        end

        if from == to
          report("#{key}[#{index}] skipped -- 'from' and 'to' are identical (#{from.inspect}), so it would do nothing. This entry will not be applied.")
          return nil
        end

        warn_non_ascii(from, key, index)
        warn_non_ascii(to, key, index)
        [from, to]
      end

      # Validates a bare non-empty string.
      #
      # @return [String, nil] the string, or nil if rejected
      def validate_name(entry, key, index)
        unless entry.is_a?(String) && !entry.empty?
          report("#{key}[#{index}] skipped -- expected a non-empty string, got #{entry.inspect}. This entry will not be applied.")
          return nil
        end

        warn_non_ascii(entry, key, index)
        entry
      end

      # Validates a regular-expression entry, accepting either a String
      # (compiled with {REGEX_TIMEOUT_SECONDS}) or a pre-compiled Regexp (from
      # a YAML +!ruby/regexp+ tag), which is re-wrapped to enforce the timeout.
      #
      # @return [Regexp, nil] a timeout-bounded pattern, or nil if rejected
      def validate_regex(entry, key, index)
        if entry.is_a?(Regexp)
          warn_non_ascii(entry.source, key, index)
          return timeout_bounded(entry.source, entry.options, key, index)
        end

        unless entry.is_a?(String) && !entry.empty?
          report("#{key}[#{index}] skipped -- expected a regular expression string, got #{entry.inspect}. This entry will not be applied.")
          return nil
        end

        warn_non_ascii(entry, key, index)
        timeout_bounded(entry, 0, key, index)
      end

      # Compiles +source+ into a timeout-bounded Regexp, reporting and
      # returning nil on a compile error.
      #
      # @param source [String] regex source
      # @param options [Integer] regex option flags to preserve
      # @return [Regexp, nil]
      def timeout_bounded(source, options, key, index)
        Regexp.new(source, options, timeout: REGEX_TIMEOUT_SECONDS)
      rescue RegexpError => e
        report("#{key}[#{index}] skipped -- invalid regular expression #{source.inspect}: #{e.message}. This pattern will not be applied.")
        nil
      end

      # Warns (but does not reject) when a value contains non-ASCII bytes,
      # since game text is ASCII and non-ASCII usually signals a typo (e.g. a
      # smart quote pasted from a browser).
      #
      # @param value [String] the string to check
      # @return [void]
      def warn_non_ascii(value, key, index)
        return if value.ascii_only?

        report("#{key}[#{index}] warning -- contains non-ASCII characters (#{value.inspect}); game text is ASCII, so this may be a typo. It will still be applied.")
      end

      # Emits a player-facing warning, guarded so it is safe before
      # {Lich::Messaging} exists.
      #
      # @param text [String] message body (the prefix is added)
      # @return [void]
      def report(text)
        return unless defined?(Lich::Messaging) && Lich::Messaging.respond_to?(:msg)

        Lich::Messaging.msg('warn', "#{message_prefix} #{text}")
      end

      # Emits a low-noise informational line, routed at debug level so it only
      # shows when the player has debug messaging enabled.
      #
      # @param text [String] message body (the prefix is added)
      # @return [void]
      def report_debug(text)
        return unless defined?(Lich::Messaging) && Lich::Messaging.respond_to?(:msg)

        Lich::Messaging.msg('debug', "#{message_prefix} #{text}")
      end

      # Reports a runtime regex timeout once per offending pattern.
      #
      # @param pattern [Regexp] the pattern that timed out
      # @return [void]
      def report_timeout(pattern)
        # Guard only the dedup set; do the messaging I/O outside the lock.
        first_time = @lock.synchronize do
          next false if @reported_timeouts.include?(pattern.source)

          @reported_timeouts << pattern.source
          true
        end
        return unless first_time

        report("a custom regular expression #{pattern.source.inspect} took too long (over #{REGEX_TIMEOUT_SECONDS}s) and was skipped for this text. Consider simplifying it.")
      end
    end
  end
end
