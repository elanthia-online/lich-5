# frozen_string_literal: true

module Lich
  module Util
    module Update
      # Logger for Lich Update
      class Logger
        # Initialize a new Logger
        # @param output [IO] the output stream (defaults to $_CLIENT_)
        def initialize(output = nil)
          @output = output || $_CLIENT_ || $_DETACHABLE_CLIENT_ || STDOUT
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
          # Use monsterbold if available, otherwise just output the message
          if defined?(monsterbold_start) && defined?(monsterbold_end)
            write(monsterbold_start + message + monsterbold_end)
          else
            write(message)
          end
        end

        # Log a blank line
        def blank_line
          write('')
        end

        private

        # Write a message to the output stream
        # @param message [String] the message to write
        def write(message)
          # Use _respond if available, otherwise just write to the output stream
          if defined?(_respond)
            _respond(message)
          else
            @output.puts(message)
          end
        end
      end
    end
  end
end
