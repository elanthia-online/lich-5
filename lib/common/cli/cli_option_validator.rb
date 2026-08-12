# frozen_string_literal: true

module Lich
  module Common
    module CLI
      # Extracts and validates optional flag values (e.g. --frontend wizard) from ARGV.
      # Exits the process with a usage message when a flag is present but malformed:
      # missing its value, followed by another flag instead of a value, or holding a
      # value outside an explicit allow-list.
      module CliOptionValidator
        # @param flag [String] flag name including leading dashes, e.g. '--frontend'
        # @param usage [String] usage line printed alongside any error message
        # @param valid_values [Array<String>, nil] allowed values; nil skips content validation
        # @return [String, nil] the flag's value, or nil if the flag was not supplied
        def self.extract_flag_value(flag, usage:, valid_values: nil)
          return nil unless ARGV.include?(flag)

          value = ARGV[ARGV.index(flag) + 1]

          if value.nil? || value.start_with?('-')
            $stdout.puts "error: #{flag} requires a value"
            $stdout.puts usage
            exit 1
          end

          if valid_values && !valid_values.include?(value)
            $stdout.puts "error: Invalid value for #{flag}: #{value}"
            $stdout.puts "Valid values: #{valid_values.join(', ')}"
            $stdout.puts usage
            exit 1
          end

          value
        end

        # Validates a required positional argument (e.g. the ACCOUNT in
        # `--refresh-characters ACCOUNT`). Exits the process with a usage message when
        # the argument is absent, or when it looks like an option rather than a value -
        # `--add-character DOUG --game-code DR` otherwise reads "--game-code" as the
        # character name and goes on to persist it.
        #
        # @param value [String, nil] the positional argument as read from ARGV
        # @param name [String] argument name used in the error message, e.g. 'CHAR_NAME'
        # @param usage [String] usage line printed alongside any error message
        # @return [String] the validated value
        def self.require_positional(value, name:, usage:)
          if value.nil?
            $stdout.puts 'error: Missing required arguments'
            $stdout.puts usage
            exit 1
          end

          if value.start_with?('-')
            $stdout.puts "error: Expected #{name}, got option '#{value}'"
            $stdout.puts usage
            exit 1
          end

          value
        end
      end
    end
  end
end
