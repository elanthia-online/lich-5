# frozen_string_literal: true

require 'rbconfig'
require_relative '../common/front-end'

module Lich
  module Main
    # Builds the argv used when replacing a reconnecting Lich process.
    module ReconnectCommand
      # Selects the current Ruby executable, preferring rubyw.exe on Windows
      # when that companion executable is actually installed.
      #
      # @param platform_key [Symbol] canonical host classification
      # @param configured_ruby [String] current Ruby executable
      # @return [String]
      # @raise [ArgumentError] when configured_ruby is blank
      def self.ruby_executable(platform_key: Lich::Common::Frontend.platform_key, configured_ruby: RbConfig.ruby)
        raise ArgumentError, 'configured Ruby executable must not be empty' if configured_ruby.to_s.empty?
        platform_key = Lich::Common::Frontend.validate_platform_key!(platform_key)
        return configured_ruby unless platform_key == :windows

        windowed_ruby = configured_ruby.sub(/ruby(?:\.exe)?$/i, 'rubyw.exe')
        return configured_ruby if windowed_ruby == configured_ruby

        File.file?(windowed_ruby) ? windowed_ruby : configured_ruby
      rescue SystemCallError
        configured_ruby
      end

      # Builds reconnect argv without shell re-parsing or mutating caller input.
      #
      # @param argv [Array<String>] original process arguments
      # @param program [String] Lich entrypoint
      # @param ruby_executable [String] Ruby executable selected for replacement
      # @param reconnect_arg [String, nil] current reconnect-delay argument
      # @param reconnect_delay [Integer] current delay component
      # @param reconnect_step [Integer] incremental delay component
      # @return [Array<String>]
      # @raise [ArgumentError] for invalid inputs
      def self.build(argv:, program:, ruby_executable:, reconnect_arg:, reconnect_delay:, reconnect_step:)
        raise ArgumentError, 'argv must be an Array' unless argv.is_a?(Array)
        raise ArgumentError, 'program must not be empty' if program.to_s.empty?
        raise ArgumentError, 'Ruby executable must not be empty' if ruby_executable.to_s.empty?

        begin
          delay = Integer(reconnect_delay)
          step = Integer(reconnect_step)
        rescue ArgumentError, TypeError
          raise ArgumentError, 'reconnect delay values must be integers'
        end
        raise ArgumentError, 'reconnect delay values must not be negative' if delay.negative? || step.negative?

        args = [ruby_executable, program, *argv]
        args << '--reconnected' unless args.include?('--reconnected')
        if step.positive?
          args.delete(reconnect_arg) unless reconnect_arg.nil?
          args << "--reconnect-delay=#{delay + step}+#{step}"
        end
        args
      end
    end
  end
end
