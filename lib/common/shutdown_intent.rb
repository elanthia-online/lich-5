# frozen_string_literal: true

module Lich
  module Common
    # Detects explicit frontend shutdown commands.
    module ShutdownIntent
      USER_EXIT_COMMAND = /\A\s*(?:<c>)?\s*(?:exit|quit)\s*\z/i

      def self.user_exit_command?(client_string)
        return false if client_string.nil?

        USER_EXIT_COMMAND.match?(client_string.to_s)
      end
    end
  end
end
