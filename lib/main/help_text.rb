# frozen_string_literal: true

module Lich
  module Main
    # Renders user-facing CLI help text by topic.
    module HelpText
      HELP_TOPICS = %w[login accounts automation paths advanced].freeze

      # Returns formatted help text for the requested topic.
      #
      # @param topic [String, nil] optional topic name
      # @return [String] rendered help output
      def self.render(topic = nil)
        normalized_topic = normalize_topic(topic)

        case normalized_topic
        when 'login' then login_help
        when 'accounts' then accounts_help
        when 'automation' then automation_help
        when 'paths' then paths_help
        when 'advanced' then advanced_help
        else
          default_help
        end
      end

      # Resolves the topic token following `--help`, if any.
      #
      # @param argv [Array<String>] command line arguments
      # @param help_arg [String] the matched help flag
      # @return [String, nil] requested topic name
      def self.topic_from_argv(argv, help_arg)
        return help_arg.split('=', 2).last if help_arg.start_with?('--help=')

        help_index = argv.index(help_arg)
        return nil if help_index.nil?

        topic = argv[help_index + 1]
        return nil if topic.nil? || topic.start_with?('--')

        topic
      end

      # Normalizes user-facing aliases for help topic names.
      #
      # @param topic [String, nil]
      # @return [String, nil]
      def self.normalize_topic(topic)
        case topic.to_s.downcase
        when '', 'overview' then nil
        when 'account', 'accounts' then 'accounts'
        when 'automation', 'automations', 'sessions', 'diagnostics' then 'automation'
        when 'login' then 'login'
        when 'path', 'paths' then 'paths'
        when 'advanced', 'compat', 'compatibility' then 'advanced'
        else
          nil
        end
      end

      def self.default_help
        <<~TEXT
          Lich 5
          Usage:
            lich [command] [options]

          Most common:
            lich --login CHARACTER
            lich --login CHARACTER --headless PORT
            lich --login CHARACTER --headless auto
            lich --add-account ACCOUNT PASSWORD

          Help topics:
            lich --help login
            lich --help accounts
            lich --help automation
            lich --help paths
            lich --help advanced

          General:
            --help                  Show help
            --version               Show version
        TEXT
      end

      def self.login_help
        <<~TEXT
          Lich Help: login

          Usage:
            lich --login CHARACTER [options]

          Login options:
            --login CHARACTER       Login using a saved entry
            --headless PORT         Run without a frontend and expose a detachable client on PORT
            --headless auto         Run without a frontend and let the OS assign a detachable port
            --start-scripts=LIST    Start scripts after login (comma-separated)
            --save                  Save successful CLI login details to entry.yaml
            --reconnect             Reconnect automatically if the session drops
            --reconnect-delay=SPEC  Delay before reconnecting

          Game selection:
            --gemstone, --gs
            --dragonrealms, --dr
            --shattered
            --fallen
            --platinum
            --test

          Frontend selection:
            --wizard
            --stormfront
            --avalon
            --frostbite
            --genie

          Advanced launch:
            --custom-launch=NAME
            --detachable-client=PORT
            --dark-mode=true|false
            --game=HOST:PORT

          Examples:
            lich --login Mychar
            lich --login Mychar --gemstone --shattered
            lich --login Mychar --frostbite
            lich --login Mychar --headless 8001
            lich --login Mychar --headless auto
            lich --login Mychar --start-scripts=repository,go2
        TEXT
      end

      def self.accounts_help
        <<~TEXT
          Lich Help: accounts

          Usage:
            lich [account command] [options]

          Commands:
            --add-account ACCOUNT PASSWORD
            --change-account-password ACCOUNT NEWPASSWORD
            --change-master-password OLDPASSWORD [NEWPASSWORD]
            --recover-master-password [NEWPASSWORD]
            --convert-entries MODE
            --change-encryption-mode MODE [--master-password PASSWORD]

          Modes:
            plaintext
            standard
            enhanced

          Examples:
            lich --add-account MYACCOUNT MYPASSWORD --frontend stormfront
            lich --change-account-password MYACCOUNT NEWPASSWORD
            lich --convert-entries enhanced
            lich --change-encryption-mode enhanced --master-password SECRET
        TEXT
      end

      def self.automation_help
        <<~TEXT
          Lich Help: automation

          Usage:
            lich [automation command]

          Commands:
            --active-sessions       List live sessions
            --session-info NAME     Show live session details for NAME

          Examples:
            lich --active-sessions
            lich --session-info Mychar
        TEXT
      end

      def self.paths_help
        <<~TEXT
          Lich Help: paths

          Usage:
            lich [options]

          Path options:
            --home=PATH
            --script-dir=PATH
            --data-dir=PATH
            --temp-dir=PATH
            --hosts-dir=PATH
            --hosts-file=PATH

          Examples:
            lich --script-dir=/my/scripts
            lich --data-dir=/my/data --temp-dir=/tmp/lich
        TEXT
      end

      def self.advanced_help
        <<~TEXT
          Lich Help: advanced

          Compatibility / advanced options:
            --gui
            --no-gui
            --without-frontend
            --detachable-client=PORT
            --frontend=NAME
            --frontend-command=CMD
            --game=HOST:PORT

          Notes:
            Prefer --headless PORT or --headless auto for new headless launches.
            Compatibility flags remain supported but are intentionally omitted from the default help screen.
        TEXT
      end
    end
  end
end
