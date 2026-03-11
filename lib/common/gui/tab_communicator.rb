# frozen_string_literal: true

module Lich
  module Common
    module GUI
      # Provides cross-tab communication for data synchronization
      # Enables tabs to notify each other of data changes for real-time updates
      class TabCommunicator
        # Initializes a new TabCommunicator instance
        #
        # @return [TabCommunicator] New instance
        def initialize
          @data_change_callbacks = []
        end

        # Registers a callback for data change notifications
        # Allows tabs to register for notifications when data changes occur
        #
        # @param callback [Proc] Callback to execute when data changes
        # @return [void]
        def register_data_change_callback(callback)
          @data_change_callbacks << callback if callback.respond_to?(:call)
        end

        # Notifies all registered callbacks of a data change
        # Triggers all registered callbacks when data changes occur
        #
        # @param change_type [Symbol] Type of change that occurred (:favorite, :character, :account)
        # @param data [Hash] Additional data about the change
        # @return [void]
        def notify_data_changed(change_type = :general, data = {})
          @data_change_callbacks.each do |callback|
            begin
              callback.call(change_type, data)
            rescue StandardError => e
              Lich.log "error: Error in data change callback: #{e.message}"
            end
          end
        end

        # Removes a callback from the notification list
        # Allows tabs to unregister from data change notifications
        #
        # @param callback [Proc] Callback to remove
        # @return [void]
        def unregister_data_change_callback(callback)
          @data_change_callbacks.delete(callback)
        end

        # Clears all registered callbacks
        # Removes all registered callbacks, typically used during cleanup
        #
        # @return [void]
        def clear_callbacks
          @data_change_callbacks.clear
        end
      end
    end
  end
end
