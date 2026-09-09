# frozen_string_literal: true

require 'shellwords'
require_relative 'frontend'
require_relative 'frontend_locator'
require_relative 'windows_command_line'

module Lich
  module Common
    # Converts catalog launcher metadata into either a launch-file command
    # template or a shell-free environment/argv process plan.
    module FrontendLauncher
      SpawnPlan = Struct.new(:environment, :argv, keyword_init: true) do
        def initialize(environment:, argv:)
          super(environment: environment.freeze, argv: argv.freeze)
          freeze
        end
      end

      class Error < StandardError; end
      class UnsupportedError < Error; end
      class UnavailableError < Error; end

      PROCESS_LOCAL_LAUNCH_FIELDS = %w[FRONTEND CUSTOMLAUNCHARGV].freeze
      CONNECTION_PLACEHOLDER_PATTERN = /(%host%|%port%|%key%)/.freeze

      class << self
        # Returns whether a frontend has enough machine-local configuration to
        # launch. Custom adapters are backed by their persisted command; native
        # adapters continue to use executable discovery.
        #
        # @param frontend_id [String, Symbol] registered frontend identifier
        # @param locator [FrontendLocator] injectable discovery API
        # @param frontend [Frontend] injectable frontend catalog API
        # @param refresh [Boolean] bypass cached native discovery when true
        # @return [Boolean]
        def launchable?(frontend_id, locator: FrontendLocator, frontend: Frontend, refresh: false)
          definition = frontend.definition_for(frontend_id)
          if definition.dig(:metadata, :launcher_adapter) == :custom
            return !definition.dig(:metadata, :launch_command).to_s.strip.empty?
          end

          locator.launchable?(definition[:id], refresh: refresh)
        rescue ArgumentError
          false
        end

        # Builds the platform command template for a registered frontend.
        #
        # @param frontend_id [String, Symbol] registered frontend identifier
        # @param platform_key [Symbol] canonical host classification
        # @param locator [FrontendLocator] injectable discovery API
        # @param simu_launcher [#call] injectable legacy launcher lookup
        # @return [String, Array<String>] legacy template or shell-free Windows argv
        # @raise [ArgumentError] for an unknown frontend identifier
        # @raise [UnsupportedError] when the adapter has no platform command
        # @raise [UnavailableError] when a required executable/launcher is absent
        def command(
          frontend_id,
          platform_key: Frontend.platform_key,
          locator: FrontendLocator,
          simu_launcher: -> { Lich.get_simu_launcher }
        )
          definition = Frontend.definition_for(frontend_id)

          base_command = case definition.dig(:metadata, :launcher_adapter)
                         when :environment
                           raise UnsupportedError, "#{definition[:id]} requires a structured spawn plan"
                         when :avalon
                           avalon_command(definition, platform_key, locator)
                         when :simutronics
                           simu_launcher.call || raise(UnavailableError, 'Simutronics launcher was not found')
                         when :custom
                           definition.dig(:metadata, :launch_command)
                         else
                           raise UnsupportedError, "no launcher adapter for #{definition[:id]}"
                         end

          if base_command.to_s.strip.empty?
            raise UnavailableError, "#{Frontend.display_name(definition[:id])} has no launch command"
          end

          with_additional_arguments(base_command, definition, platform_key: platform_key)
        end

        # Appends user-configured arguments to a command-template launcher.
        # Arguments are escaped independently while Lich's connection
        # placeholders remain available for the launch handoff to replace.
        #
        # @param base_command [String, Array<String>] command template or literal argv
        # @param frontend [String, Symbol, Hash] frontend id or definition
        # @param platform_key [Symbol] host command-line convention
        # @return [String, Array<String>] command template or shell-free argv
        def with_additional_arguments(base_command, frontend, platform_key: Frontend.platform_key)
          definition = frontend.is_a?(Hash) ? frontend : Frontend.definition_for(frontend)
          arguments = Array(definition.dig(:metadata, :additional_arguments))
          return [*base_command, *arguments] if base_command.is_a?(Array)
          return base_command if arguments.empty?
          return [*WindowsCommandLine.split(base_command), *arguments] if platform_key == :windows

          escaped_arguments = arguments.map { |argument| escape_argument(argument) }
          argument_separator = definition.dig(:metadata, :launcher_adapter) == :avalon ? ' --args ' : ' '
          "#{base_command}#{argument_separator}#{escaped_arguments.join(' ')}"
        end

        # Removes Lich-only control fields before launch data is serialized for
        # a native frontend. The selected frontend identity remains available
        # to the current Lich process but is not part of Simutronics' .sal
        # contract.
        #
        # @param launch_data [Array<String>]
        # @return [Array<String>] detached native launch-data copy
        def native_session_data(launch_data)
          Array(launch_data).reject do |line|
            key = line.to_s.split('=', 2).first.to_s.upcase
            PROCESS_LOCAL_LAUNCH_FIELDS.include?(key)
          end
        end

        # Resolves every connection placeholder after Lich opens the local
        # listener used by a configured frontend.
        #
        # @param command [String, Array<String>]
        # @param host [String]
        # @param port [String, Integer]
        # @param key [String]
        # @return [String, Array<String>]
        def render_connection(command, host:, port:, key:)
          if command.is_a?(Array)
            return command.map { |argument| render_connection(argument, host: host, port: port, key: key) }
          end

          {
            '%host%' => host,
            '%port%' => port,
            '%key%'  => key
          }.reduce(command.to_s) do |rendered, (placeholder, value)|
            rendered.gsub(placeholder, value.to_s)
          end
        end

        # Builds a shell-free process environment and argv for an environment
        # launcher adapter. Catalog launch_plans are keyed by platform and
        # contain :command, :arguments, and :environment. A command may be a
        # literal executable or :resolved_executable for locator discovery;
        # %host%, %port%, and %key% tokens are replaced in environment values.
        # Connection secrets remain out of process arguments.
        #
        # @param frontend_id [String, Symbol] registered frontend identifier
        # @param host [String] local proxy host
        # @param port [Integer, String] local proxy port
        # @param key [String] authenticated game connection key
        # @param platform_key [Symbol] canonical host classification
        # @param locator [FrontendLocator] injectable discovery API
        # @param refresh [Boolean] refresh executable discovery before resolving
        # @return [SpawnPlan]
        # @raise [ArgumentError] for blank connection values
        # @raise [UnsupportedError] when no plan exists on the platform
        def spawn_plan(
          frontend_id,
          host:,
          port:,
          key:,
          platform_key: Frontend.platform_key,
          locator: FrontendLocator,
          refresh: true
        )
          definition = Frontend.definition_for(frontend_id)
          unless definition.dig(:metadata, :launcher_adapter) == :environment
            raise UnsupportedError, "no environment launcher for #{definition[:id]}"
          end

          replacements = { '%host%' => host, '%port%' => port, '%key%' => key }
          replacements.each do |token, value|
            raise ArgumentError, "#{token.delete('%')} must not be empty" if value.to_s.empty?
          end

          platform_key = Frontend.validate_platform_key!(platform_key)
          plan = definition.dig(:metadata, :launch_plans, platform_key)
          unless plan
            raise UnsupportedError, "no #{platform_key} launcher for #{definition[:id]}"
          end

          environment = plan.fetch(:environment).transform_values do |value|
            replacements.reduce(value.to_s) { |resolved, (token, replacement)| resolved.gsub(token, replacement.to_s) }
          end
          command, arguments = resolve_plan_launch(
            plan,
            definition,
            platform_key,
            locator,
            refresh: refresh
          )
          SpawnPlan.new(
            environment: environment,
            argv: [command, *arguments]
          )
        end

        # Builds a shell-free Saga launch plan that asks Saga to authenticate
        # the named character and start its own Via-Lich session. Unlike
        # +spawn_plan+, this contract does not create a Lich proxy listener or
        # pass a game key; Saga owns authentication and Lich process startup.
        #
        # @param account [String] Saga account with a saved password
        # @param character [String] character to launch
        # @param game_code [String] Saga instance code (for example, GS3 or DR)
        # @param platform_key [Symbol] canonical host classification
        # @param locator [FrontendLocator] injectable discovery API
        # @param refresh [Boolean] refresh executable discovery before resolving
        # @return [SpawnPlan]
        # @raise [ArgumentError] for blank launch identifiers
        # @raise [UnsupportedError] when no Saga plan exists on the platform
        # @raise [UnavailableError] when Saga is not installed
        def saga_managed_login_plan(
          account:,
          character:,
          game_code:,
          platform_key: Frontend.platform_key,
          locator: FrontendLocator,
          refresh: true
        )
          identifiers = {
            account: account,
            character: character,
            game_code: game_code
          }
          identifiers.each do |name, value|
            raise ArgumentError, "#{name} must not be empty" if value.to_s.strip.empty?
          end

          definition = Frontend.definition_for('saga')
          unless definition.dig(:metadata, :launcher_adapter) == :environment
            raise UnsupportedError, 'no environment launcher for saga'
          end

          platform_key = Frontend.validate_platform_key!(platform_key)
          plan = definition.dig(:metadata, :launch_plans, platform_key)
          raise UnsupportedError, "no #{platform_key} launcher for saga" unless plan

          command, arguments = resolve_plan_launch(
            plan,
            definition,
            platform_key,
            locator,
            refresh: refresh
          )
          SpawnPlan.new(
            environment: {
              # Saga 0.8.5 implements this currently undocumented startup contract.
              'SAGA_AUTO_LOGIN'         => "#{character.to_s.strip}@#{game_code.to_s.strip.upcase}",
              'SAGA_AUTO_LOGIN_ACCOUNT' => account.to_s.strip,
              'SAGA_AUTO_LOGIN_MODE'    => 'lich'
            },
            argv: [command, *arguments]
          )
        end

        private

        # Returns configured additional arguments as strings.
        #
        # @param definition [Hash] immutable frontend definition
        # @return [Array<String>] configured additional arguments
        # @api private
        def additional_arguments(definition)
          Array(definition.dig(:metadata, :additional_arguments)).map(&:to_s)
        end

        # Combines catalog plan arguments with configured additional arguments.
        #
        # @param command [String] resolved launcher command
        # @param plan [Hash] platform launch plan
        # @param definition [Hash] immutable frontend definition
        # @return [Array<String>] complete process argument list
        # @api private
        def plan_arguments(command, plan, definition)
          configured = additional_arguments(definition)
          return plan.fetch(:arguments) if configured.empty?

          separator = command == '/usr/bin/open' ? ['--args'] : []
          [*plan.fetch(:arguments), *separator, *configured]
        end

        # Resolves a structured launch plan to its command and arguments.
        # A configured macOS executable replaces Saga's bundle-id fallback;
        # application-bundle binaries still launch through `open` so normal
        # macOS application semantics are retained.
        #
        # @param plan [Hash] platform launch plan
        # @param definition [Hash] immutable frontend definition
        # @param platform_key [Symbol] canonical host classification
        # @param locator [FrontendLocator] injectable discovery API
        # @param refresh [Boolean] bypass cached discovery when true
        # @return [Array(String, Array<String>)] command and argument list
        # @api private
        def resolve_plan_launch(plan, definition, platform_key, locator, refresh:)
          override = macos_configured_launch(definition, platform_key, locator, refresh: refresh)
          return override if override

          command = resolve_plan_command(plan.fetch(:command), definition, locator, refresh: refresh)
          [command, plan_arguments(command, plan, definition)]
        end

        # Returns a macOS launch pair for a valid configured executable.
        # Invalid or removed overrides deliberately fall back to discovery and
        # the catalog's bundle-id launch plan.
        #
        # @param definition [Hash] immutable frontend definition
        # @param platform_key [Symbol] canonical host classification
        # @param locator [FrontendLocator] injectable discovery API
        # @param refresh [Boolean] bypass cached discovery when true
        # @return [Array(String, Array<String>), nil]
        # @api private
        def macos_configured_launch(definition, platform_key, locator, refresh:)
          return nil unless platform_key == :darwin
          return nil if definition.dig(:metadata, :configured_executable).to_s.strip.empty?

          resolution = locator.resolve(definition[:id], refresh: refresh)
          return nil unless resolution&.source == :configured

          executable = resolution.executable_path
          bundle = executable[%r{\A(.+\.app)/Contents/MacOS/[^/]+\z}, 1]
          command = bundle ? '/usr/bin/open' : executable
          arguments = bundle ? ['-n', '-a', bundle] : []
          configured = additional_arguments(definition)
          arguments.concat(['--args', *configured]) if bundle && !configured.empty?
          arguments.concat(configured) unless bundle
          [command, arguments]
        end

        # Shell-escapes an argument while preserving connection placeholders.
        #
        # @param argument [String] argument template
        # @return [String] escaped argument template
        # @api private
        def escape_argument(argument)
          return "''" if argument.empty?

          argument.to_s.split(CONNECTION_PLACEHOLDER_PATTERN).filter_map do |segment|
            next if segment.empty?
            next segment if segment.match?(CONNECTION_PLACEHOLDER_PATTERN)

            # Shellwords conservatively escapes '=' even though it is inert
            # inside an argument. Keep --option=value readable while escaping
            # whitespace and shell syntax.
            Shellwords.escape(segment).gsub('\\=', '=')
          end.join
        end

        def resolve_plan_command(command, definition, locator, refresh:)
          return command unless command == :resolved_executable

          resolution = locator.resolve(definition[:id], refresh: refresh)
          unless resolution
            raise UnavailableError, "#{Frontend.display_name(definition[:id])} was not found"
          end

          resolution.executable_path
        end

        def avalon_command(definition, platform_key, locator)
          platform_key = Frontend.validate_platform_key!(platform_key)
          unless platform_key == :darwin
            raise UnsupportedError, "no #{platform_key} launcher for #{definition[:id]}"
          end

          resolution = locator.resolve(definition[:id], refresh: true)
          raise UnavailableError, 'Avalon was not found' unless resolution

          bundle = resolution.executable_path[%r{\A(.+\.app)/Contents/MacOS/[^/]+\z}, 1]
          raise UnavailableError, 'Avalon executable is not inside an application bundle' unless bundle

          "/usr/bin/open -n -a #{Shellwords.escape(bundle)} \"%1\""
        end
      end
    end
  end
end
