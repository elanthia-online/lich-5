# frozen_string_literal: true

require 'ostruct'

module Lich
  module Util
    # Generic CLI argument parser for any command-line parsing task
    # Separates concerns: parsing, validation, execution
    #
    # @example
    #   opts = Lich::Util::Opts.parse(ARGV, {
    #     gui: { type: :boolean, default: true },
    #     account: { type: :string },
    #     password: { type: :string }
    #   })
    #   # => OpenStruct with frozen attributes
    #
    # @example Nested values
    #   opts = Lich::Util::Opts.parse(['--host=localhost:4000'], {
    #     host: { type: :string, parser: ->(v) { h,p = v.split(':'); {host: h, port: p.to_i} } }
    #   })
    class Opts
      # Parse ARGV into an immutable OpenStruct
      #
      # @param argv [Array<String>] Argument list (usually ARGV)
      # @param schema [Hash] Option definitions with metadata
      # @option schema [Symbol] :type Type coercion (:string, :boolean, :integer, :array)
      # @option schema [Object] :default Default value if not provided
      # @option schema [Proc] :parser Custom parser function
      #
      # @return [OpenStruct] Frozen options with all specified keys
      def self.parse(argv, schema = {})
        options = {}

        # Set defaults
        schema.each do |key, config|
          options[key] = config[:default] if config.key?(:default)
        end

        # Parse ARGV
        i = 0
        while i < argv.length
          arg = argv[i]

          # Try each schema key to find a match
          matched = false
          schema.each do |key, config|
            option_name = "--#{key.to_s.gsub(/_/, '-')}"
            short_option = config[:short] ? "-#{config[:short]}" : nil

            if arg == option_name || (short_option && arg == short_option)
              matched = true
              options[key] = parse_value(argv, i, config)
              # Skip next arg if this option consumed it (not boolean or custom parser with = form)
              i += 1 if config[:type] != :boolean && !config[:parser]
              break
            elsif arg =~ /^#{option_name}=(.+)$/
              matched = true
              value = Regexp.last_match(1)
              options[key] = parse_value_with_content(value, config)
              break
            end
          end

          i += 1
        end

        # Return frozen OpenStruct
        OpenStruct.new(options).freeze
      end

      # Parse individual option values with type coercion

      def self.parse_value(argv, index, config)
        case config[:type]
        when :boolean
          true
        when :string
          argv[index + 1]
        when :integer
          argv[index + 1]&.to_i
        when :array
          # Collect following args until next --flag
          values = []
          j = index + 1
          while j < argv.length && !argv[j].start_with?('-')
            values << argv[j]
            j += 1
          end
          values
        else
          config[:parser] ? config[:parser].call(argv[index + 1]) : argv[index + 1]
        end
      end

      def self.parse_value_with_content(value, config)
        # If custom parser provided, use it first
        return config[:parser].call(value) if config[:parser]

        case config[:type]
        when :boolean
          value.match?(/^(true|on|yes|1)$/i)
        when :string
          value
        when :integer
          value.to_i
        else
          value
        end
      end
    end
  end
end
