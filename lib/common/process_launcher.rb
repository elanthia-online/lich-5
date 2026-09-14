# frozen_string_literal: true

module Lich
  module Common
    # Spawns a process from an explicit environment and argv without allowing a
    # one-element argv to fall back to Ruby's shell-interpreted command form.
    module ProcessLauncher
      class << self
        # Launches one process and returns its PID.
        #
        # Inputs are passed directly to Process.spawn after validation. A
        # one-element argv uses Ruby's [executable, argv0] form so executable
        # paths containing spaces or shell metacharacters remain atomic.
        #
        # @param environment [Hash] child-process environment overrides
        # @param argv [Array<String>] executable followed by zero or more arguments
        # @param spawner [#call] injectable Process.spawn-compatible callable
        # @return [Integer] child process ID
        # @raise [ArgumentError] when environment or argv is invalid
        # @raise [SystemCallError] when the operating system cannot spawn the process
        def call(environment, argv, spawner: Process.method(:spawn))
          raise ArgumentError, 'environment must be a Hash' unless environment.is_a?(Hash)
          unless argv.is_a?(Array) && !argv.empty? && argv.all?(String) && !argv.first.empty?
            raise ArgumentError, 'argv must contain a non-empty String executable followed by String arguments'
          end

          executable, *arguments = argv
          if arguments.empty?
            spawner.call(environment, [executable, File.basename(executable)])
          else
            spawner.call(environment, executable, *arguments)
          end
        end
      end
    end
  end
end
