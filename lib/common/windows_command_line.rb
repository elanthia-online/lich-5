# frozen_string_literal: true

require 'strscan'

module Lich
  module Common
    # Splits executable command templates using Windows CRT quoting rules.
    # This is not a cmd.exe interpreter: shell operators require an explicit
    # wrapper command. Configured additional arguments never pass through it.
    module WindowsCommandLine
      # @param command [String] executable and fixed argument template
      # @return [Array<String>] executable followed by literal arguments
      # @raise [ArgumentError] for empty commands, unmatched quotes or shell syntax
      def self.split(command)
        raise ArgumentError, 'Control characters are not allowed in frontend commands.' if command.to_s.match?(/[\r\n\x00]/)

        scanner = StringScanner.new(command.to_s)
        arguments = []
        until scanner.eos?
          scanner.skip(/[ \t]+/)
          break if scanner.eos?

          arguments << read_argument(scanner, executable: arguments.empty?)
        end
        raise ArgumentError, 'A frontend command must name an executable.' if arguments.empty? || arguments.first.empty?

        arguments
      end

      # @param scanner [StringScanner] current argument cursor
      # @param executable [Boolean] first argument uses path quoting, not escape rules
      # @return [String] one unquoted argument
      # @raise [ArgumentError] for ambiguous shell syntax or an unclosed quote
      # @api private
      def self.read_argument(scanner, executable:)
        value = +''
        quoted = false
        until scanner.eos? || (!quoted && scanner.check(/[ \t]/))
          if !executable && (slashes = scanner.scan(/\\+(?=")/))
            value << ('\\' * (slashes.length / 2))
            if slashes.length.odd?
              value << scanner.getch
              next
            end
          elsif (text = scanner.scan(/[^\\" \t&|<>]+/))
            value << text
            next
          end
          character = scanner.getch
          if character == '"'
            if quoted && !executable && scanner.peek(1) == '"'
              value << scanner.getch
            else
              quoted = !quoted
            end
          elsif !quoted && character.match?(/[&|<>]/)
            raise ArgumentError, 'Use a wrapper executable for Windows shell commands with additional arguments.'
          else
            value << character
          end
        end
        raise ArgumentError, 'Unclosed quote in Windows frontend command.' if quoted

        value
      end
      private_class_method :read_argument
    end
  end
end
