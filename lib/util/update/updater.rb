# frozen_string_literal: true

require_relative 'error'
require_relative 'config'
require_relative 'version'
require_relative 'logger'
require_relative 'file_manager'
require_relative 'github'
require_relative 'tag_support'
require_relative 'validator'
require_relative 'release_manager'
require_relative 'installer'
require_relative 'cleaner'
require_relative 'cli'

module Lich
  module Util
    module Update
      # Main module that ties all components together
      module Main
        class << self
          # Detect if running in Lich environment
          # @return [Boolean] true if running in Lich environment, false otherwise
          def in_lich_environment?
            # Check if running within Lich by looking for Lich-specific globals
            # $_CLIENT_ is a Lich-specific global variable
            (defined?($_CLIENT_) && !$_CLIENT_.nil?) || (defined?($_DETACHABLE_CLIENT_) && !$_DETACHABLE_CLIENT_.nil?)
          end

          # Initialize all components
          # @param stdout [IO] the output stream
          # @param force_environment [Symbol, nil] force a specific environment (:lich or :cli)
          # @return [Hash] the initialized components
          def initialize_components(stdout = nil, force_environment = nil)
            # Use $_CLIENT_ as default if available, otherwise fall back to STDOUT
            output = stdout || $_CLIENT_ || STDOUT

            # Determine environment based on context or forced value
            lich_environment = if force_environment
                                 force_environment == :lich
                               else
                                 in_lich_environment?
                               end

            logger = Logger.new(output)
            file_manager = FileManager.new(logger)
            github = GitHub.new(logger)
            tag_support = TagSupport.new(logger)
            validator = Validator.new(logger)
            release_manager = ReleaseManager.new(logger, github, tag_support, validator)
            installer = Installer.new(logger, file_manager, github)
            cleaner = Cleaner.new(logger)
            cli = CLI.new(logger, lich_environment: lich_environment)

            {
              logger: logger,
              file_manager: file_manager,
              github: github,
              tag_support: tag_support,
              validator: validator,
              release_manager: release_manager,
              installer: installer,
              cleaner: cleaner,
              cli: cli
            }
          end
        end
      end
    end
  end
end
