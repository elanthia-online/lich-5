# frozen_string_literal: true

module Lich
  module Common
    module CLI
      # Command-line commands that print a result and exit instead of starting
      # a session: the account and data commands CLIOrchestration dispatches,
      # and the session queries ActiveSessionsQuery answers.
      #
      # Has no dependencies, so GemCheck can load it before any gem is
      # available. GemCheck uses it to avoid relaunching these commands after a
      # gem repair: the relaunch discards their output, and their arguments can
      # carry passwords.
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

        # Inline form of the session-info query: --session-info=NAME.
        SESSION_INFO_PREFIX = '--session-info='

        # The one rule for "this command line asks a session query".
        # ActiveSessionsQuery.query_requested? calls it, so the query that
        # runs and the recovery check cannot drift apart. A bare trailing
        # --session-info (no name) is not a query: Lich starts a session.
        #
        # @param argv [Array<String>] the command line
        # @return [Boolean] true when +argv+ asks a session query
        def self.session_query?(argv)
          return true if argv.include?('--active-sessions')
          return true if argv.any? { |arg| arg.start_with?(SESSION_INFO_PREFIX) }

          idx = argv.index('--session-info')
          !idx.nil? && !argv[idx + 1].nil?
        end

        # @param argv [Array<String>] the command line
        # @return [Boolean] true when +argv+ runs a one-shot command
        def self.present?(argv)
          argv.any? { |arg| HANDLERS.key?(arg) } || session_query?(argv)
        end
      end
    end
  end
end
