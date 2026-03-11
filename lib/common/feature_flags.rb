# frozen_string_literal: true

module Lich
  module Common
    # Centralized feature flag access.
    #
    # Flags are stored in `lich_settings` using keys in the form
    # `feature_flag:<flag_name>`. Missing keys fall back to defaults.
    module FeatureFlags
      DEFAULTS = {
        cli_hello_world_demo: false
      }.freeze

      SETTINGS_PREFIX = 'feature_flag:'

      # Returns whether the given feature flag is enabled.
      #
      # @param name [String, Symbol] feature flag name
      # @return [Boolean]
      def self.enabled?(name)
        flag_name = validate_flag_name!(normalize_name(name))

        begin
          stored = read_flag(flag_name)
          return DEFAULTS.fetch(flag_name.to_sym, false) if stored.nil?

          truthy?(stored)
        rescue StandardError => e
          Lich.log("warning: FeatureFlags read failed for #{flag_name}: #{e.class}: #{e.message}") if Lich.respond_to?(:log)
          DEFAULTS.fetch(flag_name.to_sym, false)
        end
      end

      # Sets a feature flag value in persistent settings.
      #
      # @param name [String, Symbol] feature flag name
      # @param value [Object] value to persist
      # @return [Boolean] true when persisted successfully, false when write fails
      def self.set(name, value)
        flag_name = validate_flag_name!(normalize_name(name))

        begin
          write_flag(flag_name, value)
        rescue StandardError => e
          Lich.log("warning: FeatureFlags write failed for #{flag_name}: #{e.class}: #{e.message}") if Lich.respond_to?(:log)
          false
        end
      end

      def self.normalize_name(name)
        name.to_s.strip.downcase
      end
      private_class_method :normalize_name

      def self.validate_flag_name!(flag_name)
        raise ArgumentError, 'feature flag name must be non-empty' if flag_name.empty?

        flag_name
      end
      private_class_method :validate_flag_name!

      def self.truthy?(value)
        value.to_s.match?(/\A(?:1|true|on|yes)\z/i)
      end
      private_class_method :truthy?

      def self.read_flag(flag_name)
        db = fetch_db
        return nil unless db

        db.get_first_value('SELECT value FROM lich_settings WHERE name = ?;', "#{SETTINGS_PREFIX}#{flag_name}")
      end
      private_class_method :read_flag

      def self.write_flag(flag_name, value)
        db = fetch_db
        return false unless db

        db.execute('INSERT OR REPLACE INTO lich_settings(name, value) VALUES(?, ?);',
                   ["#{SETTINGS_PREFIX}#{flag_name}", value.to_s])
        true
      end
      private_class_method :write_flag

      def self.fetch_db
        return nil unless Lich.respond_to?(:db)

        Lich.db
      end
      private_class_method :fetch_db
    end
  end
end
