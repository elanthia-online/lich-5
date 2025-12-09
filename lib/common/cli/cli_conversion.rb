# frozen_string_literal: true

require_relative '../gui/yaml_state'

module Lich
  module Common
    module CLI
      # Handles entry.dat to entry.yaml conversion for CLI
      # Provides detection mechanism and orchestration for conversion process
      module CLIConversion
        # Checks if conversion is needed
        # Returns true when entry.dat exists but entry.yaml doesn't exist
        #
        # @param data_dir [String] Directory containing entry data
        # @return [Boolean] True if conversion is needed
        def self.conversion_needed?(data_dir)
          dat_file = File.join(data_dir, 'entry.dat')
          yaml_file = Lich::Common::GUI::YamlState.yaml_file_path(data_dir)

          File.exist?(dat_file) && !File.exist?(yaml_file)
        end

        # Performs conversion from entry.dat to entry.yaml
        # Delegates to YamlState.migrate_from_legacy for actual conversion
        # For enhanced mode, user will be prompted to create a master password interactively
        #
        # @param data_dir [String] Directory containing entry data
        # @param encryption_mode [Symbol] Encryption mode (:plaintext, :standard, :enhanced)
        # @return [Boolean] True if conversion was successful
        def self.convert(data_dir, encryption_mode)
          # Normalize encryption_mode to symbol if string is passed
          mode = encryption_mode.to_sym

          # Validate preconditions
          dat_file = File.join(data_dir, 'entry.dat')
          yaml_file = Lich::Common::GUI::YamlState.yaml_file_path(data_dir)

          unless File.exist?(dat_file)
            Lich.log "error: entry.dat not found at #{dat_file}"
            return false
          end

          if File.exist?(yaml_file)
            Lich.log "error: entry.yaml already exists at #{yaml_file}"
            return false
          end

          # Delegate to YamlState for the actual conversion
          # For enhanced mode, migrate_from_legacy will prompt user to create master password
          result = Lich::Common::GUI::YamlState.migrate_from_legacy(data_dir, encryption_mode: mode)

          unless result
            Lich.log "error: YamlState.migrate_from_legacy returned false"
          end

          result
        rescue StandardError => e
          Lich.log "error: Conversion failed: #{e.class}: #{e.message}"
          Lich.log "error: Backtrace: #{e.backtrace.join("\n  ")}"
          false
        end

        # Prints helpful conversion message showing user how to run conversion
        # Called when conversion is detected and user tries to login without converting
        def self.print_conversion_help_message
          lich_script = File.join(LICH_DIR, 'lich.rbw')

          $stdout.puts "\n" + '=' * 80
          $stdout.puts "Saved entries conversion required"
          $stdout.puts '=' * 80
          $stdout.puts "\nYour login entries need to be converted to the new format."
          $stdout.puts "\nRun one of these commands:\n\n"

          $stdout.puts "For no encryption (least secure):"
          $stdout.puts "  ruby #{lich_script} --convert-entries plaintext\n\n"

          $stdout.puts "For account-based encryption (standard):"
          $stdout.puts "  ruby #{lich_script} --convert-entries standard\n\n"

          $stdout.puts "For master-password encryption (recommended):"
          $stdout.puts "  ruby #{lich_script} --convert-entries enhanced\n\n"

          $stdout.puts '=' * 80 + "\n"
        end
      end
    end
  end
end
