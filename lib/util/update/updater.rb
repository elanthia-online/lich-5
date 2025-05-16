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
          # Initialize all components
          # @param stdout [IO] the output stream
          # @return [Hash] the initialized components
          def initialize_components(stdout = STDOUT)
            logger = Logger.new(stdout)
            file_manager = FileManager.new(logger)
            github = GitHub.new(logger)
            tag_support = TagSupport.new(logger)
            validator = Validator.new(logger)
            release_manager = ReleaseManager.new(logger, github, tag_support, validator)
            installer = Installer.new(logger, file_manager, github)
            cleaner = Cleaner.new(logger)
            cli = CLI.new(logger)

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
