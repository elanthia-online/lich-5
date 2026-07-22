# frozen_string_literal: true

require 'shellwords'
require_relative 'front-end'
require_relative 'frontend_locator'

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

      class << self
        # Builds the platform command template for a registered frontend.
        #
        # @param frontend_id [String, Symbol] registered frontend identifier
        # @param platform [String] Ruby platform identifier
        # @param locator [FrontendLocator] injectable discovery API
        # @param simu_launcher [#call] injectable legacy launcher lookup
        # @return [String]
        # @raise [ArgumentError] for an unknown frontend identifier
        # @raise [UnsupportedError] when the adapter has no platform command
        # @raise [UnavailableError] when a required executable/launcher is absent
        def command(
          frontend_id,
          platform: RUBY_PLATFORM,
          locator: FrontendLocator,
          simu_launcher: -> { Lich.get_simu_launcher }
        )
          definition = Frontend.definition_for(frontend_id)

          case definition.dig(:metadata, :launcher_adapter)
          when :environment
            raise UnsupportedError, "#{definition[:id]} requires a structured spawn plan"
          when :avalon
            avalon_command(definition, platform, locator)
          when :simutronics
            simu_launcher.call || raise(UnavailableError, 'Simutronics launcher was not found')
          else
            raise UnsupportedError, "no launcher adapter for #{definition[:id]}"
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
        # @param platform [String] Ruby platform identifier
        # @param locator [FrontendLocator] injectable discovery API
        # @param refresh [Boolean] refresh executable discovery before resolving
        # @return [SpawnPlan]
        # @raise [ArgumentError] for blank connection values
        # @raise [UnsupportedError] when no plan exists on the platform
        def spawn_plan(frontend_id, host:, port:, key:, platform: RUBY_PLATFORM, locator: FrontendLocator, refresh: true)
          definition = Frontend.definition_for(frontend_id)
          unless definition.dig(:metadata, :launcher_adapter) == :environment
            raise UnsupportedError, "no environment launcher for #{definition[:id]}"
          end

          replacements = { '%host%' => host, '%port%' => port, '%key%' => key }
          replacements.each do |token, value|
            raise ArgumentError, "#{token.delete('%')} must not be empty" if value.to_s.empty?
          end

          platform_key = Frontend.platform_key(platform)
          plan = definition.dig(:metadata, :launch_plans, platform_key)
          unless plan
            raise UnsupportedError, "no #{platform_key} launcher for #{definition[:id]}"
          end

          environment = plan.fetch(:environment).transform_values do |value|
            replacements.reduce(value.to_s) { |resolved, (token, replacement)| resolved.gsub(token, replacement.to_s) }
          end
          command = resolve_plan_command(plan.fetch(:command), definition, locator, refresh: refresh)
          SpawnPlan.new(
            environment: environment,
            argv: [command, *plan.fetch(:arguments)]
          )
        end

        private

        def resolve_plan_command(command, definition, locator, refresh:)
          return command unless command == :resolved_executable

          resolution = locator.resolve(definition[:id], refresh: refresh)
          unless resolution
            raise UnavailableError, "#{Frontend.display_name(definition[:id])} was not found"
          end

          resolution.executable_path
        end

        def avalon_command(definition, platform, locator)
          platform_key = Frontend.platform_key(platform)
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
