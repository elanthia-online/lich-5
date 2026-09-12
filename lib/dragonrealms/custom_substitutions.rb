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

        private

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
