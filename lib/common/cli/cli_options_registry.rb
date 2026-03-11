# frozen_string_literal: true

module Lich
  module Common
    module CLI
      # Declarative registry for Lich startup CLI options
      # Centralizes option metadata: type, dependencies, exclusivity, deprecation, handlers
      #
      # @example
      #   CliOptionsRegistry.option :gui,
      #     type: :boolean,
      #     default: true,
      #     deprecated: false
      #
      #   CliOptionsRegistry.option :change_account_password,
      #     type: :string,
      #     mutually_exclusive: [:gui],
      #     handler: -> (opts) { execute_and_exit }
      class CliOptionsRegistry
        @options = {}
        @handlers = {}

        class << self
          # Register an option with metadata
          #
          # @param name [Symbol] Option name (becomes --option-name flag)
          # @param type [Symbol] Type (:boolean, :string, :integer, :array)
          # @param default [Object] Default value
          # @param deprecated [Boolean] If true, logs deprecation warning
          # @param deprecation_message [String] Custom deprecation message
          # @param mutually_exclusive [Array<Symbol>] Options that can't be combined
          # @param handler [Proc] Handler to execute (for CLI commands that exit)
          def option(name, type: :string, default: nil, deprecated: false,
                     deprecation_message: nil, mutually_exclusive: [], handler: nil)
            @options[name] = {
              type: type,
              default: default,
              deprecated: deprecated,
              deprecation_message: deprecation_message,
              mutually_exclusive: Array(mutually_exclusive)
            }
            @handlers[name] = handler if handler
          end

          # Get option definition
          #
          # @param name [Symbol] Option name
          # @return [Hash] Option metadata
          def get_option(name)
            @options[name]
          end

          # Get all registered options
          #
          # @return [Hash] All option definitions
          def all_options
            @options.dup
          end

          # Get handler for option (if any)
          #
          # @param name [Symbol] Option name
          # @return [Proc, nil] Handler function or nil
          def get_handler(name)
            @handlers[name]
          end

          # Validate option combinations
          #
          # @param parsed_opts [OpenStruct] Parsed options
          # @return [Array<String>] List of validation errors (empty if valid)
          def validate(parsed_opts)
            errors = []

            # Check mutually exclusive options
            @options.each do |option_name, config|
              next unless parsed_opts.respond_to?(option_name) && parsed_opts.public_send(option_name)
              next if config[:mutually_exclusive].empty?

              config[:mutually_exclusive].each do |exclusive_option|
                if parsed_opts.respond_to?(exclusive_option) && parsed_opts.public_send(exclusive_option)
                  errors << "Options --#{option_name} and --#{exclusive_option} are mutually exclusive"
                end
              end
            end

            # Check for deprecation warnings
            @options.each do |option_name, config|
              next unless config[:deprecated]
              next unless parsed_opts.respond_to?(option_name) && parsed_opts.public_send(option_name)

              message = config[:deprecation_message] || "Option --#{option_name} is deprecated and will be removed in a future version"
              Lich.log "warning: #{message}"
            end

            errors
          end

          # Get schema for Opts.parse
          #
          # @return [Hash] Schema formatted for Lich::Util::Opts.parse
          def to_opts_schema
            schema = {}
            @options.each do |name, config|
              schema[name] = {
                type: config[:type],
                default: config[:default]
              }
            end
            schema
          end
        end
      end
    end
  end
end
