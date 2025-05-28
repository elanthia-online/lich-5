# frozen_string_literal: true

require 'fileutils'
require 'timeout'
require 'zlib'

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
        def get_user_confirmation(logger)
          # Use $_CLIENT_ as primary input stream if available, otherwise fall back to $stdin
          sync_thread = $_CLIENT_ || $_DETACHABLE_CLIENT_ || $stdin
          line = nil
          begin
            Timeout.timeout(10) do
              line = sync_thread.gets
              break if line.is_a?(String) && line.strip =~ /^(?:<c>)?(?:y(?:es)?|no?)?$/i
            end
            # Return true only if the user entered 'y' or 'Y', false for any other input
            return false if line.nil?
            return !!(line.strip.downcase =~ /^(?:<c>)?y(?:es)?$/i)
          rescue Timeout::Error
            logger.info("DEBUG: Ten (10) seconds have elapsed.  Means 'no' in this context.") if $DEBUG
            return false
          end
        end

        # Update core data and scripts - Backward compatibility method
        # @param script_dir [String, nil] the script directory (defaults to Config::DIRECTORIES[:script] if nil)
        # @param data_dir [String, nil] the data directory (defaults to Config::DIRECTORIES[:data] if nil)
        # @param game_type [String] the game type (gs or dr)
        # @return [Boolean] true if the update was successful
        def update_core_data_and_scripts(script_dir = nil, data_dir = nil, game_type = 'gs', version = LICH_VERSION)
          # Use config values if parameters are nil
          script_dir ||= Config::DIRECTORIES[:script]
          data_dir ||= Config::DIRECTORIES[:data]

          # Initialize components
          components = Main.initialize_components
          installer = components[:installer]

          # Call the instance method
          installer.update_core_data_and_scripts(script_dir, data_dir, game_type)
          # Update Lich.db with the version of Lich
          Lich.core_updated_with_lich_version = version
        end

        private

        # Parse the parameter into options
        # @param parameter [String, Symbol, Hash, Array, nil] the update parameter
        # @param cli [CLI] The CLI instance for parsing command-line style parameters
        # @param logger [Logger] The logger instance for error reporting
        # @return [Hash] the parsed options
        def parse_parameter(parameter, cli, logger)
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
          logger = components[:logger]
          release_manager = components[:release_manager]
          installer = components[:installer]
          cleaner = components[:cleaner]
          file_manager = components[:file_manager]
          cli = components[:cli]

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
            if options[:prompt_beta] && options[:tag] == 'beta' ||
               options[:prompt_alpha] && options[:tag] == 'alpha' ||
               options[:prompt_dev] && options[:tag] == 'dev'
              # do not shorten development to 'dev' in prompts
              logger.info("You are about to join the #{options[:tag]} program for Lich5.") unless options[:tag] == 'dev'
              logger.info("You are about to join the development program for Lich5.") if options[:tag] == 'dev'
              # Prompt for beta
              logger.info("#{options[:tag].capitalize} versions may contain experimental features and bugs.") if options[:tag] == 'beta'
              # Prompt for alpha
              logger.info("#{options[:tag].capitalize} versions have a higher risk of changes and instability.") if options[:tag] == 'alpha'
              logger.info("Features may change significantly between releases.") if options[:tag] == 'alpha'
              # Prompt for development
              logger.info("#{options[:tag].capitalize} versions are unstable and may break at any time.") if options[:tag] == 'dev'
              logger.info("Features may be incomplete or change without notice.") if options[:tag] == 'dev'
              logger.info("Do you want to proceed? (y/n)")

              # Get user confirmation
              if !get_user_confirmation(logger)
                result[:success] = false
                # do not shorten development to 'dev' in results / info
                result[:message] = "#{options[:tag].capitalize} update cancelled by user" unless options[:tag] == 'dev'
                result[:message] = "Development update cancelled by user" if options[:tag] == 'dev'
                # Display cancellation message to user
                logger.info("Update cancelled: #{options[:tag].capitalize} update will not proceed.") unless options[:tag] == 'dev'
                logger.info("Update cancelled: Development update will not proceed.") if options[:tag] == 'dev'
                return result
              end
            end

            # First check if an update is available before creating a snapshot
            update_available, update_message = installer.check_update_available(options[:tag])

            if !update_available
              result[:success] = false
              result[:message] = update_message || "No updates available for tag: #{options[:tag]}"
              logger.info(result[:message])
              return result
            end

            # Only create a snapshot if an update is available
            logger.info("Update available. Creating snapshot before proceeding...")
            snapshot_path = file_manager.create_snapshot(
              Config::DIRECTORIES[:lich],
              Config::DIRECTORIES[:backup],
              Config::DIRECTORIES[:script],
              Config::DIRECTORIES[:lib],
              Config::DIRECTORIES[:data],
              Config::CORE_SCRIPTS,
              Config::USER_DATA_FILES || []
            )

            # Perform the update
            success, message = installer.update(options[:tag])
            result[:success] = success
            result[:message] = message
            result[:data][:snapshot_path] = snapshot_path if snapshot_path
          when 'update_file'
            # Check if file update is available before proceeding
            file_update_available, file_update_message = installer.check_file_update_available(
              options[:file_type],
              options[:file],
              options[:tag]
            )

            if !file_update_available
              result[:success] = false
              result[:message] = file_update_message || "No updates available for file: #{options[:file]}"
              logger.info(result[:message])
              return result
            end

            # Perform the file update
            success = installer.update_file(
              options[:file_type],
              options[:file],
              options[:tag]
            )
            result[:success] = success
            result[:message] = success ?
              "File #{options[:file]} updated successfully" :
              "Failed to update file #{options[:file]}"
          when 'revert'
            # Revert to previous snapshot
            success, message = installer.revert
            result[:success] = success
            result[:message] = message
          when 'snapshot'
            # Create a snapshot
            snapshot_path = file_manager.create_snapshot(
              Config::DIRECTORIES[:lich],
              Config::DIRECTORIES[:backup],
              Config::DIRECTORIES[:script],
              Config::DIRECTORIES[:lib],
              Config::DIRECTORIES[:data],
              Config::CORE_SCRIPTS,
              Config::USER_DATA_FILES || []
            )
            result[:success] = !snapshot_path.nil?
            result[:message] = snapshot_path ?
              "Snapshot created at #{snapshot_path}" :
              "Failed to create snapshot"
            result[:data][:snapshot_path] = snapshot_path if snapshot_path
          when 'cleanup'
            # Clean up old installations
            success, message = cleaner.cleanup
            result[:success] = success
            result[:message] = message
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

# CLI entrypoint - only execute when run directly as a script
if $PROGRAM_NAME == __FILE__
  # Detect if running in Lich environment using Main.in_lich_environment? if available
  in_lich_environment = if defined?(Lich::Util::Update::Main.in_lich_environment?)
                          Lich::Util::Update::Main.in_lich_environment?
                        else
                          # Fallback detection if method not available
                          defined?($_CLIENT_) && !$_CLIENT_.nil?
                        end

  # If not in Lich environment, process as CLI
  if !in_lich_environment
    # Pass ARGV to the request method
    result = Lich::Util::Update.request(ARGV)

    # Set exit code based on success
    exit(result[:success] ? 0 : 1)
  else
    # If in Lich environment but run directly, show help
    Lich::Util::Update.request('help')
  end
end
