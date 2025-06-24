# Mock Database Adapter for Settings Module Testing

# This file implements an in-memory database adapter for testing the Settings module
# without requiring an actual SQLite database.

module Lich
  module Common
    # Mock database adapter that simulates database operations using in-memory storage
    class MockDatabaseAdapter
      def initialize
        @storage = {}
      end

      # Get settings for a specific script and scope
      # @param script_name [String] The name of the script
      # @param scope [String] The scope of the settings (default: ":")
      # @return [Hash] The settings hash for the specified script and scope
      def get_settings(script_name, scope = ":")
        key = "#{script_name}:#{scope}"
        # Return a deep copy to prevent unintended modifications
        deep_copy(@storage[key] || {})
      end

      # Save settings for a specific script and scope
      # @param script_name [String] The name of the script
      # @param settings [Hash] The settings hash to save
      # @param scope [String] The scope of the settings (default: ":")
      def save_settings(script_name, settings, scope = ":")
        key = "#{script_name}:#{scope}"
        # Store a deep copy to prevent unintended modifications
        @storage[key] = deep_copy(settings)
      end

      # Clear all stored settings
      # This is useful for resetting the state between tests
      def clear
        @storage = {}
      end

      # Get a copy of the entire storage hash
      # This is useful for inspecting the state during tests
      # @return [Hash] A deep copy of the storage hash
      def dump
        deep_copy(@storage)
      end

      private

      # Create a deep copy of an object
      # @param obj [Object] The object to copy
      # @return [Object] A deep copy of the object
      def deep_copy(obj)
        case obj
        when Hash
          obj.transform_values { |v| deep_copy(v) }
        when Array
          obj.map { |v| deep_copy(v) }
        else
          obj
        end
      end
    end

    # Mock script module for testing
    module MockScript
      class << self
        attr_accessor :current_name

        def current
          OpenStruct.new(name: current_name || "test_script")
        end
      end
    end

    # Mock XMLData module for testing
    module MockXMLData
      class << self
        attr_accessor :game, :name

        # def game
        @game || "GSIV"
        # end

        # def name
        @name || "TestCharacter"
        # end
      end
    end
  end
end
