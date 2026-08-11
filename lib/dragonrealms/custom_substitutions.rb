# frozen_string_literal: true

module Lich
  module DragonRealms
    # Merges a player's own substitution/normalization entries (from their
    # character settings) on top of core Lich's built-in defaults, so a player
    # can teach Lich about their own problematic scrolls, creatures, boxes, etc.
    # without waiting for a Lich release.
    #
    # Core Lich keeps the authoritative default lists as frozen constants; those
    # are passed in as +defaults+ and are also the fallback when no dr-scripts /
    # no user additions are present. Only the user's *additions* are read from
    # settings and validated here -- defaults are trusted.
    #
    # Every user entry is validated *before* it is merged. Invalid entries are
    # dropped individually (lenient per-entry: one bad entry never disables the
    # rest) and each rejection is reported to the player through
    # {Lich::Messaging} with the exact key, index, offending value, reason, and
    # consequence, so they understand precisely what happened and why.
    #
    # Results are memoized per settings key (built once, on first use) so hot
    # parse paths do not repeatedly call +get_settings+ or recompile regexes.
    # Call {reset!} to rebuild after a settings reload.
    #
    # @example Merge user scroll rewrites on top of the built-in defaults
    #   pre = Lich::DragonRealms::CustomSubstitutions.resolve(
    #     :custom_scroll_substitutions,
    #     Lich::DragonRealms::DRC::DEFAULT_SCROLL_SUBSTITUTIONS_PRE,
    #     type: :pairs
    #   )
    #   pre.reduce(entry) { |text, (from, to)| text.sub(from, to) }
    #
    # @see DRC.scroll_list_to_adj_and_noun
    module CustomSubstitutions
      # Prefix on every player-facing message so the source is unambiguous.
      MESSAGE_PREFIX = '[CustomSubstitutions]'

      # Per-regex evaluation budget (seconds) applied to every user-supplied
      # pattern, so a pathological (catastrophic-backtracking) pattern raises
      # {Regexp::TimeoutError} instead of hanging Lich. See {apply_regexes}.
      REGEX_TIMEOUT_SECONDS = 1.0

      # Supported validation shapes, dispatched on by {resolve} and
      # {validate_entry}:
      # - +:pairs+   -- +[from, to]+ literal String substitution pairs
      # - +:names+   -- bare canonical-name Strings
      # - +:regexes+ -- regular-expression Strings (or pre-compiled Regexps)
      SUPPORTED_TYPES = %i[pairs names regexes].freeze

      # Guards the shared caches below. {resolve}/{apply_regexes} are public
      # utility methods any number of concurrently-running scripts (each on its
      # own Thread) can call on shared game text, so the memo must not be
      # populated by two threads at once. Mirrors the +@@mutex+ idiom used by
      # {GameObj} and {DRExpMonitor}.
      @lock = Mutex.new
      # Memoized merged lists, keyed by settings key. See {resolve}.
      @cache = {}
      # Regex sources already reported as timing out, so each is reported at
      # most once. See {apply_regexes}.
      @reported_timeouts = []

      class << self
        # Returns +defaults+ merged with the validated user additions found at
        # +key+ in the player's settings, deduplicated and memoized.
        #
        # @param key [Symbol, String] the settings key holding user additions
        #   (e.g. +:custom_scroll_substitutions+)
        # @param defaults [Array] the trusted built-in default list (frozen
        #   constant); used as-is and returned unchanged when there are no valid
        #   additions
        # @param type [Symbol] one of {SUPPORTED_TYPES}; selects the validator
        # @return [Array] defaults followed by the valid, deduplicated additions
        # @raise [ArgumentError] if +type+ is not in {SUPPORTED_TYPES}
        # @example
        #   resolve(:custom_creature_normalizations, DEFAULTS, type: :names)
        # @see #reset!
        def resolve(key, defaults, type:)
          raise ArgumentError, "unsupported type #{type.inspect}" unless SUPPORTED_TYPES.include?(type)

          # Double-checked: no lock on the warm path (the common case on hot
          # parse paths), lock only to populate a missing key.
          @cache[key] || @lock.synchronize { @cache[key] ||= (Array(defaults) + validated_additions(key, type)).uniq }
        end

        # Clears the memoized merged lists (and the per-pattern timeout-report
        # dedup set) so the next {resolve}/{apply_regexes} call re-reads settings
        # and re-validates. Call this whenever settings are reloaded.
        #
        # @return [void]
        # @see #resolve
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
        #   (typically from {resolve} with +type: :regexes+)
        # @return [String] +text+ with every applicable pattern removed
        # @example
        #   apply_regexes('a gaudy scroll bedizened with gems', patterns)
        # @see DRC.remove_flavor_text
        def apply_regexes(text, patterns)
          patterns.reduce(text) do |current, pattern|
            current.sub(pattern, '')
          rescue Regexp::TimeoutError
            report_timeout(pattern)
            current
          end
        end

        private

        # Reads, validates, and returns the user additions at +key+.
        #
        # @param key [Symbol, String] settings key
        # @param type [Symbol] validator shape
        # @return [Array] valid additions (possibly empty)
        def validated_additions(key, type)
          raw = user_setting(key)
          return [] if raw.nil?

          unless raw.is_a?(Array)
            report("#{key} ignored -- expected a list, got #{raw.class}. No custom entries were loaded.")
            return []
          end

          valid = raw.each_with_index.filter_map { |entry, index| validate_entry(entry, type, key, index) }
          report_debug("loaded #{valid.size} custom #{key} #{valid.size == 1 ? 'entry' : 'entries'}") unless valid.empty?
          valid
        end

        # Reads a single settings key from +get_settings+, tolerating any
        # environment where settings are unavailable (no dr-scripts, early boot,
        # or a raising accessor) by returning +nil+.
        #
        # @param key [Symbol, String] settings key
        # @return [Object, nil] the raw settings value, or nil when unavailable
        def user_setting(key)
          return nil unless defined?(get_settings)

          settings = get_settings
          return nil if settings.nil?

          settings[key]
        rescue StandardError
          nil
        end

        # Dispatches a single entry to the validator for +type+.
        #
        # @return [Object, nil] the validated (possibly transformed) entry, or
        #   nil if it was rejected and reported
        def validate_entry(entry, type, key, index)
          case type
          when :pairs   then validate_pair(entry, key, index)
          when :names   then validate_name(entry, key, index)
          when :regexes then validate_regex(entry, key, index)
          end
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

        # Validates a bare canonical-name string.
        #
        # @return [String, nil] the name, or nil if rejected
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

          Lich::Messaging.msg('warn', "#{MESSAGE_PREFIX} #{text}")
        end

        # Emits a low-noise informational line, routed at debug level so it only
        # shows when the player has debug messaging enabled.
        #
        # @param text [String] message body (the prefix is added)
        # @return [void]
        def report_debug(text)
          return unless defined?(Lich::Messaging) && Lich::Messaging.respond_to?(:msg)

          Lich::Messaging.msg('debug', "#{MESSAGE_PREFIX} #{text}")
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
end
