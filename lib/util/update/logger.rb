# frozen_string_literal: true

module Lich
  module Util
    module Update
      # Logger for Lich Update
      class Logger
        # Initialize a new Logger
        # @param output [IO] the output stream (defaults to STDOUT)
        def initialize(output = STDOUT)
          @output = output
        end

        # Log an informational message
        # @param message [String] the message to log
        def info(message)
          write(message)
        end

        # Log a warning message
        # @param message [String] the message to log
        def warn(message)
          write("WARNING: #{message}")
        end

        # Log an error message
        # @param message [String] the message to log
        def error(message)
          write("ERROR: #{message}")
        end

        # Log a success message
        # @param message [String] the message to log
        def success(message)
          write("SUCCESS: #{message}")
        end

        # Log a formatted message with bold styling
        # @param message [String] the message to log
        def bold(message)
          # In the original code, this would use Lich::Messaging.monsterbold
          # For now, we'll just return the message
          write(message)
        end

        # Log a blank line
        def blank_line
          write('')
        end

        private

        # Write a message to the output stream
        # @param message [String] the message to write
        def write(message)
          # In the original code, this would use _respond or Lich::Messaging.mono
          # For now, we'll just write to the output stream
          @output.puts(message)
        end
      end
    end
  end
end
