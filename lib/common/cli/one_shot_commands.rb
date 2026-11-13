# frozen_string_literal: true

module Lich
  module Common
    module CLI
      # Command-line commands that print a result and exit instead of starting
      # a session: the account and data commands CLIOrchestration dispatches,
      # and the session queries ActiveSessionsQuery answers.
      #
      # Has no dependencies, so the gem-recovery code can load it before any
      # gem is available. Recovery uses it to avoid relaunching these commands
      # after a gem repair: the relaunch discards their output, and their
      # arguments can carry passwords.
      module OneShotCommands
        # Flag => CLIOrchestration handler method. CLIOrchestration.execute
        # dispatches from this table, so the recovery check and the dispatcher
        # cannot drift apart.
        HANDLERS = {
          '--change-account-password' => :handle_change_account_password,
          '-cap'                      => :handle_change_account_password,
          '--add-account'             => :handle_add_account,
          '-aa'                       => :handle_add_account,
          '--refresh-characters'      => :handle_refresh_characters,
          '-rc'                       => :handle_refresh_characters,
          '--add-character'           => :handle_add_character,
          '-ac'                       => :handle_add_character,
          '--change-master-password'  => :handle_change_master_password,
          '-cmp'                      => :handle_change_master_password,
          '--recover-master-password' => :handle_recover_master_password,
          '-rmp'                      => :handle_recover_master_password,
          '--convert-entries'         => :handle_convert_entries,
          '--change-encryption-mode'  => :handle_change_encryption_mode,
          '-cem'                      => :handle_change_encryption_mode,
          '--web-login-test'          => :handle_web_login_test
        }.freeze

        # Session queries answered by ActiveSessionsQuery before dispatch.
        SESSION_QUERY = /\A--(?:active-sessions|session-info(?:=.*)?)\z/m.freeze

        # @param argv [Array<String>] the command line
        # @return [Boolean] true when +argv+ runs a one-shot command
        def self.present?(argv)
          argv.any? { |arg| HANDLERS.key?(arg) || SESSION_QUERY.match?(arg) }
        end
      end
    end
  end
end
