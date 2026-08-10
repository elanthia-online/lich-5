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
      end
    end
  end
end
