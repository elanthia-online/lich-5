# frozen_string_literal: true

require 'optparse'
require_relative 'error'
require_relative 'config'

module Lich
  module Util
    module Update
      # CLI interface for Lich Update
      class CLI
        # Initialize a new CLI
        # @param logger [Logger] the logger to use
        def initialize(logger)
          @logger = logger
          @options = Config::DEFAULT_OPTIONS.dup
        end

        # Parse command line arguments
        # @param args [Array<String>] the command line arguments
        # @return [Hash] the parsed options
        def parse(args)
          opt_parser = create_option_parser

          begin
            opt_parser.parse!(args)
            @options
          rescue OptionParser::InvalidOption, OptionParser::MissingArgument => e
            @logger.error("Error parsing arguments: #{e.message}")
            @logger.info(opt_parser.help)
            nil
          end
        end

        # Display help information
        # @return [void]
        def display_help
          @logger.info(create_option_parser.help)
        end

        # Get help text as a string
        # @return [String] the help text
        def help_text
          create_option_parser.help
        end

        private

        # Create the option parser
        # @return [OptionParser] the option parser
        def create_option_parser
          OptionParser.new do |opts|
            opts.banner = "Usage: ruby update.rb [options]"

            opts.separator ""
            opts.separator "Specific options:"

            # Tag options
            opts.on("--latest", "Update to the latest stable release") do
              @options[:tag] = 'latest'
            end

            opts.on("--beta", "Update to the latest beta release") do
              @options[:tag] = 'beta'
            end

            opts.on("--dev", "Update to the latest development release") do
              @options[:tag] = 'dev'
            end

            opts.on("--alpha", "Update to the latest alpha release") do
              @options[:tag] = 'alpha'
            end

            opts.on("--version=VERSION", "Update to a specific version (e.g., 5.11.0)") do |version|
              @options[:tag] = version
            end

            # File update options
            opts.on("--script=FILE", "Update a specific script file") do |file|
              @options[:file_type] = 'script'
              @options[:file] = file
            end

            opts.on("--lib=FILE", "--library=FILE", "Update a specific library file") do |file|
              @options[:file_type] = 'lib'
              @options[:file] = file
            end

            opts.on("--data=FILE", "Update a specific data file") do |file|
              @options[:file_type] = 'data'
              @options[:file] = file
            end

            # Confirmation options
            opts.on("--no-confirm", "Skip confirmation prompts") do
              @options[:confirm] = false
            end

            # Action options
            opts.on("--announce", "-a", "Announce available updates") do
              @options[:action] = 'announce'
            end

            opts.on("--update", "-u", "Update to the specified tag") do
              @options[:action] = 'update'
            end

            opts.on("--snapshot", "-s", "Create a snapshot of the current installation") do
              @options[:action] = 'snapshot'
            end

            opts.on("--revert", "-r", "Revert to previous snapshot") do
              @options[:action] = 'revert'
            end

            opts.on("--cleanup", "Clean up old installations") do
              @options[:action] = 'cleanup'
            end

            # Other options
            opts.on("--verbose", "Enable verbose output") do
              @options[:verbose] = true
            end

            opts.on("--help", "-h", "Display this help message") do
              @options[:action] = 'help'
            end

            opts.separator ""
            opts.separator "Examples:"
            opts.separator "  ruby update.rb --latest                  # Update to the latest stable release"
            opts.separator "  ruby update.rb --beta --no-confirm       # Update to the latest beta release w/o confirming"
            opts.separator "  ruby update.rb --version=5.11.0          # Update to version 5.11.0"
            opts.separator "  ruby update.rb --script=dependency.lic   # Update the dependency.lic script"
            opts.separator "  ruby update.rb --announce                # Check for available updates"
            opts.separator "  ruby update.rb --snapshot                # Create a snapshot of the current installation"
            opts.separator "  ruby update.rb --cleanup                 # Clean up old installations"
            opts.separator "  ruby update.rb --revert                  # Revert to previous snapshot"
          end
        end
      end
    end
  end
end
