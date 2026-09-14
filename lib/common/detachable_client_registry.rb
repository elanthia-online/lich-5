# frozen_string_literal: true

module Lich
  module Common
    # Thread-safe registry for clients sharing one detachable listener.
    class DetachableClientRegistry
      def initialize
        @clients = []
        @mutex = Mutex.new
      end

      def register(client)
        @mutex.synchronize do
          was_empty = @clients.empty?
          @clients << client unless @clients.include?(client)
          was_empty && !@clients.empty?
        end
      end

      # Returns whether the client was removed and whether the registry is now
      # empty. The pair lets lifecycle reporting happen outside the mutex.
      def unregister(client)
        @mutex.synchronize do
          removed = !@clients.delete(client).nil?
          [removed, @clients.empty?]
        end
      end

      def snapshot
        @mutex.synchronize { @clients.dup }
      end

      def primary
        @mutex.synchronize { @clients.first }
      end

      def primary?(client)
        @mutex.synchronize { @clients.first.equal?(client) }
      end

      def count
        @mutex.synchronize { @clients.length }
      end

      def empty?
        @mutex.synchronize { @clients.empty? }
      end

      def remove_all
        @mutex.synchronize do
          clients = @clients.dup
          @clients.clear
          clients
        end
      end
    end
  end
end
