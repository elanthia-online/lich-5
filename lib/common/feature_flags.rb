# frozen_string_literal: true

module Lich
  module Common
    # Provides persistent access to core feature flags.
    #
    # Feature flags are stored in the `lich_settings` table using keys with the
    # `feature_flag:` prefix. Missing keys fall back to values defined in
    # {DEFAULTS}, or `false` when no explicit default is registered.
    #
    # This module intentionally exposes a minimal surface area:
    # - {.enabled?} reads a flag with safe fallback behavior
    # - {.set} persists a flag value for future reads
    #
    # Keeping the API narrow makes it easier to adopt feature flags incrementally
    # without introducing a second configuration framework.
    #
    # == Caching
    #
    # Resolved flag values are cached in-memory with a TTL of
    # {CACHE_TTL_SECONDS}. Each Lich process maintains its own independent
    # cache, so a {.set} in one process is not visible to other processes
    # until their cached entries expire. Cross-process convergence is
    # bounded by the TTL.
    module FeatureFlags
      SETTINGS_PREFIX = 'feature_flag:'
      VALID_NAME_PATTERN = /\A[a-z0-9_]+\z/

      # Defines default values for known feature flags.
      #
      # Add new flags here as infrastructure is adopted by production code. The
      # persisted value in `lich_settings` always overrides the default.
      DEFAULTS = {}.freeze

      # Cached flag values are considered fresh for this many seconds.
      # Feature flags change infrequently; this avoids repeated DB reads
      # on every heartbeat cycle.
      #
      # @return [Integer]
      CACHE_TTL_SECONDS = 60

      @cache = {}
      @cache_mutex = Mutex.new

      # Returns whether a feature flag is enabled.
      #
      # @param name [String, Symbol] the feature flag name
      # @return [Boolean] the persisted flag value, the configured default, or
      #   `false` if the flag is unknown or the value cannot be read
      # @raise [ArgumentError] if the flag name is blank or contains unsupported
      #   characters
      def self.enabled?(name)
        flag_name = validate_flag_name!(normalize_name(name))
        cached = cache_read(flag_name)
        return cached unless cached.nil?

        begin
          return default_for(flag_name) unless fetch_db

          stored = read_flag(flag_name)
          resolved = stored.nil? ? default_for(flag_name) : truthy?(stored)
          cache_write(flag_name, resolved)
          resolved
        rescue StandardError => e
          log_failure('read', flag_name, e)
          default_for(flag_name)
        end
      end

      # Persists a feature flag value in `lich_settings`.
      #
      # Values are stored as strings to match the existing `lich_settings`
      # storage model. Callers should prefer booleans, but any value responding
      # to `#to_s` is accepted and later interpreted by {.enabled?}.
      #
      # @param name [String, Symbol] the feature flag name
      # @param value [Object] the value to persist
      # @return [Boolean] `true` when the write succeeds, otherwise `false`
      # @raise [ArgumentError] if the flag name is blank or contains unsupported
      #   characters
      def self.set(name, value)
        flag_name = validate_flag_name!(normalize_name(name))
        begin
          result = write_flag(flag_name, value)
          cache_write(flag_name, truthy?(value)) if result
          result
        rescue StandardError => e
          log_failure('write', flag_name, e)
          false
        end
      end

      # Clears all cached feature flag values, forcing the next read to
      # hit the database.
      #
      # @return [void]
      def self.clear_cache!
        @cache_mutex.synchronize { @cache.clear }
      end

      # Normalizes a feature flag identifier before validation.
      #
      # @param name [String, Symbol, nil]
      # @return [String]
      def self.normalize_name(name)
        name.to_s.strip.downcase
      end
      private_class_method :normalize_name

      # Validates that a normalized feature flag name is usable.
      #
      # @param flag_name [String]
      # @return [String] the validated flag name
      # @raise [ArgumentError] if the name is blank or contains characters
      #   outside the supported snake_case style
      def self.validate_flag_name!(flag_name)
        raise ArgumentError, 'feature flag name must be non-empty' if flag_name.empty?
        raise ArgumentError, "feature flag name must match #{VALID_NAME_PATTERN.inspect}" unless flag_name.match?(VALID_NAME_PATTERN)

        flag_name
      end
      private_class_method :validate_flag_name!

      # Interprets persisted flag values using common truthy variants.
      #
      # @param value [Object]
      # @return [Boolean]
      def self.truthy?(value)
        value.to_s.match?(/\A(?:1|true|on|yes)\z/i)
      end
      private_class_method :truthy?

      # Returns the default value for a validated feature flag name.
      #
      # @param flag_name [String]
      # @return [Boolean]
      def self.default_for(flag_name)
        DEFAULTS.fetch(flag_name.to_sym, false)
      end
      private_class_method :default_for

      # Reads a persisted feature flag value from `lich_settings`.
      #
      # @param flag_name [String]
      # @return [String, nil]
      def self.read_flag(flag_name)
        db = fetch_db
        return nil unless db

        db.get_first_value('SELECT value FROM lich_settings WHERE name = ?;', setting_key(flag_name))
      end
      private_class_method :read_flag

      # Writes a feature flag value to `lich_settings`.
      #
      # @param flag_name [String]
      # @param value [Object]
      # @return [Boolean]
      def self.write_flag(flag_name, value)
        db = fetch_db
        return false unless db

        db.execute(
          'INSERT OR REPLACE INTO lich_settings(name, value) VALUES(?, ?);',
          [setting_key(flag_name), value.to_s]
        )
        true
      end
      private_class_method :write_flag

      # Returns the fully qualified setting key for a validated flag name.
      #
      # @param flag_name [String]
      # @return [String]
      def self.setting_key(flag_name)
        "#{SETTINGS_PREFIX}#{flag_name}"
      end
      private_class_method :setting_key

      # Returns the configured database handle when available.
      #
      # @return [Object, nil]
      def self.fetch_db
        return nil unless Lich.respond_to?(:db)

        Lich.db
      end
      private_class_method :fetch_db

      # Returns the cached boolean value for a flag, or nil if the cache
      # entry is missing or expired.
      #
      # @param flag_name [String]
      # @return [Boolean, nil]
      def self.cache_read(flag_name)
        @cache_mutex.synchronize do
          entry = @cache[flag_name]
          return nil unless entry
          age = Time.now.to_f - entry[:at]
          return nil if age > CACHE_TTL_SECONDS || age.negative?
          entry[:value]
        end
      end
      private_class_method :cache_read

      # Stores a resolved flag value in the cache.
      #
      # @param flag_name [String]
      # @param value [Boolean]
      # @return [void]
      def self.cache_write(flag_name, value)
        @cache_mutex.synchronize do
          @cache[flag_name] = { value: value, at: Time.now.to_f }
        end
      end
      private_class_method :cache_write

      # Logs a read or write failure without raising a second error.
      #
      # @param operation [String] the failed operation, such as `read` or `write`
      # @param flag_name [String] the normalized feature flag name
      # @param error [StandardError] the original failure
      # @return [void]
      def self.log_failure(operation, flag_name, error)
        return unless defined?(Lich) && Lich.respond_to?(:log)

        Lich.log("warning: FeatureFlags #{operation} failed for #{flag_name}: #{error.class}: #{error.message}")
      end
      private_class_method :log_failure
    end
  end
end
