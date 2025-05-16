# frozen_string_literal: true

require_relative 'update/error'
require_relative 'update/config'
require_relative 'update/version'
require_relative 'update/logger'
require_relative 'update/file_manager'
require_relative 'update/github'
require_relative 'update/tag_support'
require_relative 'update/validator'
require_relative 'update/release_manager'
require_relative 'update/installer'
require_relative 'update/cleaner'
require_relative 'update/cli'

require_relative 'update/updater'

module Lich
  # Main Updater module for Lich5
  module Util
    module Update
      class << self
        # Run the updater with command line arguments
        # @return [void]
        def run
          # Initialize components
          logger = Logger.new
          file_manager = FileManager.new(logger)
          github = GitHub.new(logger)
          tag_support = TagSupport.new(logger)
          validator = Validator.new(logger)
          release_manager = ReleaseManager.new(logger, github, tag_support, validator)
          installer = Installer.new(logger, file_manager, github)
          cleaner = Cleaner.new(logger)
          cli = CLI.new(logger)

          # Set current version
          installer.current_version = LICH_VERSION if defined?(LICH_VERSION)

          # Parse command line arguments
          options = cli.parse(ARGV)

          # If options is nil, there was an error parsing arguments
          return if options.nil?

          # Process the requested action
          process_action(options, logger, release_manager, installer, cleaner, file_manager, cli)
        end

        private

        # Process the requested action
        # @param options [Hash] the parsed command line options
        # @param logger [Logger] the logger to use
        # @param release_manager [ReleaseManager] the release manager to use
        # @param installer [Installer] the installer to use
        # @param cleaner [Cleaner] the cleaner to use
        # @param file_manager [FileManager] the file manager to use
        # @param cli [CLI] the CLI to use
        # @return [void]
        def process_action(options, _logger, release_manager, installer, cleaner, file_manager, cli)
          case options[:action]
          when 'help'
            cli.display_help
          when 'announce'
            release_manager.announce_update(installer.current_version, options[:tag])
          when 'update'
            if options[:file_type] && options[:file]
              # Update a specific file
              installer.update_file(options[:file_type], options[:file], get_directory_for_file_type(options[:file_type]), options[:tag])
            else
              # Update the entire installation
              installer.install(
                options[:tag],
                defined?(LICH_DIR) ? LICH_DIR : Dir.pwd,
                defined?(BACKUP_DIR) ? BACKUP_DIR : File.join(Dir.pwd, 'backup'),
                defined?(SCRIPT_DIR) ? SCRIPT_DIR : File.join(Dir.pwd, 'scripts'),
                defined?(LIB_DIR) ? LIB_DIR : File.join(Dir.pwd, 'lib'),
                defined?(DATA_DIR) ? DATA_DIR : File.join(Dir.pwd, 'data'),
                defined?(TEMP_DIR) ? TEMP_DIR : File.join(Dir.pwd, 'temp'),
                confirm: options[:confirm],
                create_snapshot: true
              )
            end
          when 'snapshot'
            file_manager.create_snapshot(
              defined?(LICH_DIR) ? LICH_DIR : Dir.pwd,
              defined?(BACKUP_DIR) ? BACKUP_DIR : File.join(Dir.pwd, 'backup'),
              defined?(SCRIPT_DIR) ? SCRIPT_DIR : File.join(Dir.pwd, 'scripts'),
              defined?(LIB_DIR) ? LIB_DIR : File.join(Dir.pwd, 'lib'),
              Lich::Updater::Config::CORE_SCRIPTS
            )
          when 'cleanup'
            cleaner.cleanup_all(
              defined?(LIB_DIR) ? LIB_DIR : File.join(Dir.pwd, 'lib'),
              defined?(TEMP_DIR) ? TEMP_DIR : File.join(Dir.pwd, 'temp'),
              defined?(BACKUP_DIR) ? BACKUP_DIR : File.join(Dir.pwd, 'backup')
            )
          else
            # Default to help if no action specified
            cli.display_help
          end
        end

        # Get the directory for a file type
        # @param file_type [String] the file type
        # @return [String] the directory
        def get_directory_for_file_type(file_type)
          case file_type
          when 'script'
            defined?(SCRIPT_DIR) ? SCRIPT_DIR : File.join(Dir.pwd, 'scripts')
          when 'lib', 'library'
            defined?(LIB_DIR) ? LIB_DIR : File.join(Dir.pwd, 'lib')
          when 'data'
            defined?(DATA_DIR) ? DATA_DIR : File.join(Dir.pwd, 'data')
          else
            Dir.pwd
          end
        end
      end
    end
  end
end

# Run the updater if this file is executed directly
Lich::Updater.run if __FILE__ == $PROGRAM_NAME
