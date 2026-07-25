# frozen_string_literal: true

module Lich
  module Common
    # Serializes command processing across primary and detachable frontends.
    module ClientInputDispatcher
      @mutex = Mutex.new

      def self.dispatch(client_string)
        @mutex.synchronize { yield client_string }
      end
    end
  end
end
