# frozen_string_literal: true

require_relative '../common/user_defs'

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
    # The validation, timeout, reporting and memo rules live in
    # {Lich::Common::UserDefs}; this module supplies the settings-backed
    # reading and the per-type dispatch. Every user entry is validated *before*
    # it is merged. Invalid entries are dropped individually (lenient per-entry:
    # one bad entry never disables the rest) and each rejection is reported to
    # the player through {Lich::Messaging} with the exact key, index, offending
    # value, reason, and consequence.
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
    # @see Lich::Common::UserDefs
    module CustomSubstitutions
      extend Lich::Common::UserDefs

      # Prefix on every player-facing message so the source is unambiguous.
      MESSAGE_PREFIX = '[CustomSubstitutions]'

      # Per-regex evaluation budget (seconds) applied to every user-supplied
      # pattern. Kept here for callers that reference it; the value is owned by
      # {Lich::Common::UserDefs::REGEX_TIMEOUT_SECONDS}.
      REGEX_TIMEOUT_SECONDS = Lich::Common::UserDefs::REGEX_TIMEOUT_SECONDS

      # Supported validation shapes, dispatched on by {resolve} and
      # {validate_entry}:
      # - +:pairs+   -- +[from, to]+ literal String substitution pairs
      # - +:names+   -- bare canonical-name Strings
      # - +:regexes+ -- regular-expression Strings (or pre-compiled Regexps)
      SUPPORTED_TYPES = %i[pairs names regexes].freeze

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

          memoize(key) { (Array(defaults) + validated_additions(key, type)).uniq }
        end

        # Returns the validated user entries listed under one section of a
        # settings key whose value is a map of section name => list, memoized
        # per section. Only the player's entries are returned: the callers'
        # built-in lists are kept apart from them on purpose (see
        # {Lich::DragonRealms::DRCI.item_bput}).
        #
        # The map is read and checked once: a value that is not a map is
        # reported and treated as empty, and each section name not in
        # +sections+ is reported once (a misspelt verb would otherwise be
        # silently ignored). Section names may be Strings or Symbols.
        #
        # @param key [Symbol, String] the settings key holding the map
        #   (e.g. +:custom_item_success_patterns+)
        # @param section [Symbol, String] the section to return (e.g. +:remove+)
        # @param type [Symbol] one of {SUPPORTED_TYPES}; selects the validator
        # @param sections [Array<String>] every section name the caller reads
        # @return [Array] the valid, deduplicated entries for +section+
        #   (possibly empty)
        # @raise [ArgumentError] if +type+ is not in {SUPPORTED_TYPES} or
        #   +section+ is not in +sections+
        # @example
        #   resolve_section(:custom_item_success_patterns, 'remove', type: :regexes, sections: %w[remove wear])
        # @see #reset!
        def resolve_section(key, section, type:, sections:)
          raise ArgumentError, "unsupported type #{type.inspect}" unless SUPPORTED_TYPES.include?(type)

          name = section.to_s
          raise ArgumentError, "unknown section #{name.inspect} for #{key}" unless sections.include?(name)

          # Read before memoize: memoize holds a non-reentrant lock while it
          # computes, so it must not be nested.
          table = section_table(key, sections)
          memoize([key, name]) do
            label = "#{key}[#{name}]"
            validate_entries(table[name], label) { |entry, index| validate_entry(entry, type, label, index) }.uniq
          end
        end

        # Reports that a player's pattern under +key+ / +section+ ran past
        # {REGEX_TIMEOUT_SECONDS} while matching game text, for callers that
        # match outside {apply_regexes} and so catch the
        # +Regexp::TimeoutError+ themselves.
        #
        # @param key [Symbol, String] the settings key
        # @param section [Symbol, String] the section whose pattern timed out
        # @param consequence [String] what the caller did instead, for the player
        # @return [void]
        def report_section_timeout(key, section, consequence)
          report("#{key}[#{section}] -- a custom regular expression took too long (over #{REGEX_TIMEOUT_SECONDS}s) on game text. " \
                 "#{consequence} Consider simplifying it.")
        end

        private

        # The player's map at +key+ with String section names, memoized. A
        # value that is not a map, and each unknown section name, is reported
        # here, once per session.
        #
        # @param key [Symbol, String] settings key
        # @param sections [Array<String>] the section names the caller reads
        # @return [Hash{String => Object}] section name => raw list
        def section_table(key, sections)
          memoize([key, :table]) do
            raw = user_setting(key)
            if raw.nil?
              {}
            elsif !raw.is_a?(Hash)
              report("#{key} ignored -- expected a map of verb => list of patterns, got #{raw.class}. No custom entries were loaded.")
              {}
            else
              table = raw.to_h { |name, list| [name.to_s, list] }
              (table.keys - sections).each do |name|
                report("#{key}[#{name}] ignored -- #{name.inspect} is not a supported verb (supported: #{sections.join(', ')}). These entries will not be applied.")
              end
              table
            end
          end
        end

        # Reads, validates, and returns the user additions at +key+.
        #
        # @param key [Symbol, String] settings key
        # @param type [Symbol] validator shape
        # @return [Array] valid additions (possibly empty)
        def validated_additions(key, type)
          validate_entries(user_setting(key), key) { |entry, index| validate_entry(entry, type, key, index) }
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
      end
    end
  end
end
