# frozen_string_literal: true

# mock_database_adapter.rb - In-memory test doubles for the Settings module
#
# Deliberately NOT auto-required via spec_helper. The Settings specs under
# spec/lib/common/settings/ intentionally skip spec_helper and require this
# file directly to test database and path-navigation logic in strict isolation
# from the broader game-object mock environment.
#
# Contains three test doubles:
#   MockDatabaseAdapter - in-memory Settings storage (no SQLite)
#   MockScript          - minimal Script.current stub for Settings path resolution
#   MockXMLData         - minimal XMLData stub for game/character name resolution

require 'ostruct'
require_relative 'support/lich_sqlite'

module Lich
  module Common
    # Mock database adapter that simulates database operations using in-memory storage
    class MockDatabaseAdapter
      # One clock for every instance, so that data_version only ever grows,
      # even across the fresh adapter each example creates: the real
      # adapter's values grow across reopened connections too, and Settings
      # keeps versions recorded with rows that may still be cached from an
      # earlier example.
      @version_clock = 0
      @version_clock_mutex = Mutex.new

      def self.next_version
        @version_clock_mutex.synchronize { @version_clock += 1 }
      end

      def initialize
        @storage = {}
        @version = self.class.next_version
        @data_version_unknown = false
      end

      # Set to true to play a database whose data_version can't be read right
      # now (DatabaseAdapter#data_version returns nil while another process
      # holds the lock).
      attr_accessor :data_version_unknown

      # Like DatabaseAdapter#data_version: changes on every save, as the real
      # one changes on every commit by any connection, this process's included.
      def data_version
        @data_version_unknown ? nil : @version
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
        @version = self.class.next_version
        true
      end

      # Read-modify-write of one row, mirroring DatabaseAdapter#update_settings:
      # the block gets the stored row and returns the row to store, or nil to
      # store nothing. Returns the block's own row object (not a copy), as the
      # real adapter does, so a caller that forgets to copy a value is caught.
      # on_stored is called with the stored row, as the real adapter does.
      def update_settings(script_name, scope = ":", on_stored: nil)
        updated = yield get_settings(script_name, scope)
        return nil unless updated.is_a?(Hash)

        save_settings(script_name, updated, scope)
        on_stored&.call(updated)
        updated
      end

      # Clear all stored settings
      # This is useful for resetting the state between tests
      def clear
        @storage = {}
        @version = self.class.next_version
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
          # Return nil for name when current_name is explicitly nil
          # This allows testing InstanceSettings without Script context
          OpenStruct.new(name: current_name)
        end

        def reset!
          @current_name = nil
        end
      end

      # Set a default for tests that don't set it explicitly
      self.current_name = 'test_script'
    end

    # Minimal XMLData stub for settings tests - just game and name, with sensible defaults.
    module MockXMLData
      class << self
        attr_writer :game, :name

        def game
          @game || "GSIV"
        end

        def name
          @name || "TestCharacter"
        end

        # NOTE: spec_helper's global before hook resets the real XMLData module,
        # not this stub (which is injected via stub_const only in settings specs).
        # Settings specs manage their own state in per-example before blocks, so
        # this method exists for explicit call-sites, not automatic reset.
        def reset!
          @game = nil
          @name = nil
        end
      end
    end
  end
end
