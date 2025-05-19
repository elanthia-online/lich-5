# frozen_string_literal: true

require 'zlib'
require 'fileutils'

# Load supporting files - ensure error.rb is loaded first to avoid superclass mismatch
require_relative 'update/error'
require_relative 'update/config'
require_relative 'update/version'
require_relative 'update/logger'
require_relative 'update/file_utils_helper'
require_relative 'update/file_manager'
require_relative 'update/github'
require_relative 'update/tag_support'
require_relative 'update/validator'
require_relative 'update/release_manager'
require_relative 'update/installer'
require_relative 'update/cleaner'
require_relative 'update/cli'
# Load updater.rb which contains the Main module
require_relative 'update/updater'

module Lich
  module Util
    module Update
      # Main entry point for the Lich Update utility
      # Provides a contract API for updating Lich and its components
      class << self
        # Request an update operation
        # @param parameter [String, Symbol, Hash, Array, nil] the update parameter
        #   - String: CLI-style command (e.g., "--update", "--announce", "help")
        #   - Symbol: Action identifier (e.g., :update, :announce, :help)
        #   - Hash: Structured options (e.g., {action: :update, tag: 'latest'})
        #   - Array: CLI args (e.g., ["--update", "--beta"])
        #   - nil: Display help information
        # @return [Hash] the result of the operation
        #   - :success [Boolean] whether the operation was successful
        #   - :action [String] the action that was performed
        #   - :message [String] a message describing the result
        #   - :data [Hash] additional data about the operation (optional)
        # @example Update to the latest version
        #   Lich::Util::Update.request(:update)
        # @example Check for available updates
        #   Lich::Util::Update.request(:announce)
        # @example Update to a specific version
        #   Lich::Util::Update.request({action: :update, tag: '5.11.0'})
        # @example Update a specific script
        #   Lich::Util::Update.request({action: :update_file, file_type: :script, file: 'dependency.lic'})
        def request(parameter = nil)
          puts "DEBUG: Parameter type: #{parameter.class}, value: #{parameter.inspect}" if $DEBUG

          # Initialize components using the Main module
          components = Main.initialize_components

          # Set current version if available
          if defined?(LICH_VERSION)
            components[:installer].current_version = LICH_VERSION
          else
            components[:installer].current_version = Config::CURRENT_VERSION
          end

          # Parse the parameter into options
          options = parse_parameter(parameter, components[:cli], components[:logger])

          # Process the request with the parsed options
          process_request(options, components)
        end

        # Get user input for confirmation
        # @param logger [Logger] The logger instance for displaying prompts
        # @return [Boolean] true if user confirms, false otherwise
        def get_user_confirmation(_logger)
          # Use $_CLIENT_ as primary input stream if available, otherwise fall back to $stdin
          input_stream = defined?($_CLIENT_) ? $_CLIENT_ : $stdin

          # Read a line from the input stream
          line = input_stream.gets

          # Return true only if the user entered 'y' or 'Y', false for any other input
          return false if line.nil?
          return line.strip.downcase == 'y'
        end

        private

        # Parse the parameter into options
        # @param parameter [String, Symbol, Hash, Array, nil] the update parameter
        # @param cli [CLI] The CLI instance for parsing command-line style parameters
        # @param logger [Logger] The logger instance for error reporting
        # @return [Hash] the parsed options
        def parse_parameter(parameter, cli, logger)
          puts "DEBUG: parse_parameter received: #{parameter.inspect}" if $DEBUG

          case parameter
          when String
            parse_string_parameter(parameter, cli, logger)
          when Symbol
            parse_symbol_parameter(parameter, logger)
          when Hash
            parse_hash_parameter(parameter)
          when Array
            # For array parameters, use the CLI parser
            if parameter.first == '--announce'
              return {
                action: 'announce',
                tag: 'latest',
                confirm: true,
                verbose: false
              }
            elsif parameter.first =~ /--script=(.*)/
              file = $1
              return {
                action: 'update_file',
                file_type: 'script',
                file: file,
                tag: 'latest',
                confirm: true,
                verbose: false
              }
            else
              parsed = cli.parse(parameter)
              parsed || Config::DEFAULT_OPTIONS.dup
            end
          when NilClass
            # Default to help if no parameter is provided
            Config::DEFAULT_OPTIONS.dup
          else
            logger.error("Unsupported parameter type: #{parameter.class}") if $DEBUG
            Config::DEFAULT_OPTIONS.dup
          end
        end

        # Parse a string parameter into options
        # @param parameter [String] the string parameter
        # @param cli [CLI] The CLI instance for parsing command-line style parameters
        # @param logger [Logger] The logger instance for error reporting
        # @return [Hash] the parsed options
        def parse_string_parameter(parameter, cli, logger)
          puts "DEBUG: parse_string_parameter received: #{parameter.inspect}" if $DEBUG

          options = Config::DEFAULT_OPTIONS.dup

          # First check for exact matches without prefixes
          case parameter.to_s.downcase
          when 'help'
            options[:action] = 'help'
            return options
          when 'announce'
            options[:action] = 'announce'
            return options
          when 'update'
            options[:action] = 'update'
            return options
          when 'revert'
            options[:action] = 'revert'
            return options
          when 'snapshot'
            options[:action] = 'snapshot'
            return options
          when 'cleanup'
            options[:action] = 'cleanup'
            return options
          when 'beta', 'test'
            options[:action] = 'update'
            options[:tag] = 'beta'
            options[:prompt_beta] = true
            return options
          when 'latest'
            options[:action] = 'update'
            options[:tag] = 'latest'
            return options
          when 'dev', 'development'
            options[:action] = 'update'
            options[:tag] = 'dev'
            options[:prompt_dev] = true
            return options
          when 'alpha'
            options[:action] = 'update'
            options[:tag] = 'alpha'
            options[:prompt_alpha] = true
            return options
          end

          # Handle CLI-style arguments with prefixes
          if parameter =~ /--alpha/
            # Special case for --alpha to ensure it's parsed correctly
            options[:action] = 'update'
            options[:tag] = 'alpha'
            options[:prompt_alpha] = true
            return options
          end

          # Handle other CLI-style arguments with prefixes
          case parameter
          when /--announce|-a/
            options[:action] = 'announce'
          when /--latest/
            options[:action] = 'update'
            options[:tag] = 'latest'
          when /--beta|--test/
            options[:action] = 'update'
            options[:tag] = 'beta'
            options[:prompt_beta] = true
          when /--dev|--development/
            options[:action] = 'update'
            options[:tag] = 'dev'
            options[:prompt_dev] = true
          when /--help|-h/
            options[:action] = 'help'
          when /--update|-u/
            options[:action] = 'update'
          when /--revert|-r/
            options[:action] = 'revert'
          when /--(?:(script|library|data))=(.*)/
            options[:action] = 'update_file'
            options[:file_type] = normalize_file_type($1)
            options[:file] = $2
          when /--snapshot|-s/
            options[:action] = 'snapshot'
          when /--cleanup/
            options[:action] = 'cleanup'
          when /--version=(.*)/
            options[:action] = 'update'
            options[:tag] = $1
          when /--no-confirm/
            options[:confirm] = false
          when /--verbose/
            options[:verbose] = true
          else
            # Try to parse as CLI arguments
            args = parameter.split(/\s+/)
            parsed_options = cli.parse(args)

            if parsed_options
              return parsed_options
            else
              logger.error("Command '#{parameter}' unknown, illegitimate and ignored.")
              options[:action] = 'help'
            end
          end

          options
        end

        # Parse a symbol parameter into options
        # @param parameter [Symbol] the symbol parameter
        # @param logger [Logger] The logger instance for error reporting
        # @return [Hash] the parsed options
        def parse_symbol_parameter(parameter, logger)
          puts "DEBUG: parse_symbol_parameter received: #{parameter.inspect}" if $DEBUG

          options = Config::DEFAULT_OPTIONS.dup

          # Convert symbol to string and check if it's a valid action
          param_str = parameter.to_s.downcase

          # Check for valid actions
          if ['help', 'announce', 'update', 'revert', 'snapshot', 'cleanup'].include?(param_str)
            options[:action] = param_str
            return options
          end

          # Check for special cases
          case param_str
          when 'beta', 'test'
            options[:action] = 'update'
            options[:tag] = 'beta'
            options[:prompt_beta] = true
          when 'latest'
            options[:action] = 'update'
            options[:tag] = 'latest'
          when 'dev', 'development'
            options[:action] = 'update'
            options[:tag] = 'dev'
            options[:prompt_dev] = true
          when 'alpha'
            options[:action] = 'update'
            options[:tag] = 'alpha'
            options[:prompt_alpha] = true
          else
            logger.error("Symbol '#{parameter}' not recognized.")
            options[:action] = 'help'
          end

          options
        end

        # Parse a hash parameter into options
        # @param parameter [Hash] the hash parameter
        # @return [Hash] the parsed options
        def parse_hash_parameter(parameter)
          puts "DEBUG: parse_hash_parameter received: #{parameter.inspect}" if $DEBUG

          options = Config::DEFAULT_OPTIONS.dup

          # Merge with default options, ensuring string keys are converted to symbols
          parameter.each do |key, value|
            options[key.to_sym] = value
          end

          # Convert action to string if it's a symbol
          options[:action] = options[:action].to_s if options[:action].is_a?(Symbol)

          # Set prompt flags based on tag
          case options[:tag]
          when 'beta'
            options[:prompt_beta] = true unless options.key?(:prompt_beta)
          when 'alpha'
            options[:prompt_alpha] = true unless options.key?(:prompt_alpha)
          when 'dev'
            options[:prompt_dev] = true unless options.key?(:prompt_dev)
          end

          options
        end

        # Normalize a file type
        # @param type [String, Symbol] The file type to normalize
        # @return [String] The normalized file type
        def normalize_file_type(type)
          case type.to_s.downcase
          when 'script'
            'script'
          when 'lib', 'library'
            'lib'
          when 'data'
            'data'
          else
            type.to_s
          end
        end

        # Process the request based on options
        # @param options [Hash] The options hash
        # @param components [Hash] The component instances
        # @return [Hash] Result of the operation
        def process_request(options, components)
          puts "DEBUG: process_request received options: #{options.inspect}" if $DEBUG

          logger = components[:logger]
          release_manager = components[:release_manager]
          installer = components[:installer]
          cleaner = components[:cleaner]
          file_manager = components[:file_manager]
          cli = components[:cli]
          components[:github]

          result = {
            success: true,
            action: options[:action],
            message: "",
            data: {}
          }

          case options[:action]
          when 'help'
            cli.display_help
            result[:message] = "Help information displayed"
          when 'announce'
            success = release_manager.announce_update(installer.current_version, options[:tag])
            result[:success] = success
            result[:message] = success ?
              "Update announcement displayed" :
              "No updates available or announcement failed"
          when 'update'
            # Handle prompts for different development streams if needed
            if options[:prompt_beta] && options[:tag] == 'beta'
              logger.info("You are about to join the beta program for Lich5.")
              logger.info("Beta versions may contain experimental features and bugs.")
              logger.info("Do you want to proceed? (y/n)")

              # Get user confirmation
              if !get_user_confirmation(logger)
                result[:success] = false
                result[:message] = "Beta update cancelled by user"
                # Display cancellation message to user
                logger.info("Update cancelled: Beta update will not proceed.")
                return result
              end
            elsif options[:prompt_alpha] && options[:tag] == 'alpha'
              logger.info("You are about to join the alpha program for Lich5.")
              logger.info("Alpha versions have a higher risk of changes and instability.")
              logger.info("Features may change significantly between releases.")
              logger.info("Do you want to proceed? (y/n)")

              # Get user confirmation
              if !get_user_confirmation(logger)
                result[:success] = false
                result[:message] = "Alpha update cancelled by user"
                # Display cancellation message to user
                logger.info("Update cancelled: Alpha update will not proceed.")
                return result
              end

              # No fallback for alpha - respect user's explicit choice
            elsif options[:prompt_dev] && options[:tag] == 'dev'
              logger.info("You are about to join the development program for Lich5.")
              logger.info("Development versions are unstable and may break at any time.")
              logger.info("Features may be incomplete or change without notice.")
              logger.info("Do you want to proceed? (y/n)")

              # Get user confirmation
              if !get_user_confirmation(logger)
                result[:success] = false
                result[:message] = "Development update cancelled by user"
                # Display cancellation message to user
                logger.info("Update cancelled: Development update will not proceed.")
                return result
              end

              # No fallback for dev - respect user's explicit choice
            end

            # Create a snapshot before updating
            snapshot_path = file_manager.create_snapshot(
              Config::DIRECTORIES[:lich],
              Config::DIRECTORIES[:backup],
              Config::DIRECTORIES[:script],
              Config::DIRECTORIES[:lib],
              Config::CORE_SCRIPTS
            )

            # Perform the update with all required arguments
            success = installer.install(
              options[:tag],
              Config::DIRECTORIES[:lich],
              Config::DIRECTORIES[:backup],
              Config::DIRECTORIES[:script],
              Config::DIRECTORIES[:lib],
              Config::DIRECTORIES[:data],
              Config::DIRECTORIES[:temp],
              { confirm: options[:confirm], create_snapshot: false } # We already created a snapshot
            )

            if success
              result[:success] = true
              result[:message] = "Update to #{options[:tag]} completed successfully"
              result[:data][:snapshot_path] = snapshot_path
            else
              result[:success] = false
              result[:message] = "Update to #{options[:tag]} failed"
              result[:data][:snapshot_path] = snapshot_path
            end
          when 'update_file'
            # Update a specific file
            file_type = options[:file_type]
            file = options[:file]

            success = installer.update_file(file_type, file, options[:tag])

            if success
              result[:success] = true
              result[:message] = "File #{file} updated successfully"
              result[:data][:file] = file
              result[:data][:file_type] = file_type
            else
              result[:success] = false
              result[:message] = "Failed to update file #{file}"
              result[:data][:file] = file
              result[:data][:file_type] = file_type
            end
          when 'revert'
            # Revert functionality is not implemented in the current version
            # This is a placeholder for future implementation
            result[:success] = false
            result[:message] = "Revert functionality is not implemented in this version"
          when 'snapshot'
            # Create a snapshot
            snapshot_path = file_manager.create_snapshot(
              Config::DIRECTORIES[:lich],
              Config::DIRECTORIES[:backup],
              Config::DIRECTORIES[:script],
              Config::DIRECTORIES[:lib],
              Config::CORE_SCRIPTS
            )

            if snapshot_path
              result[:success] = true
              result[:message] = "Snapshot created successfully"
              result[:data][:snapshot_path] = snapshot_path
            else
              result[:success] = false
              result[:message] = "Failed to create snapshot"
            end
          when 'cleanup'
            # Clean up temporary files
            success = cleaner.cleanup_all(
              Config::DIRECTORIES[:lib],
              Config::DIRECTORIES[:temp],
              Config::DIRECTORIES[:backup]
            )

            if success
              result[:success] = true
              result[:message] = "Cleanup completed successfully"
            else
              result[:success] = false
              result[:message] = "Cleanup failed"
            end
          else
            result[:success] = false
            result[:message] = "Unknown action: #{options[:action]}"
          end

          result
        end
      end
    end
  end
end
