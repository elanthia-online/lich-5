# frozen_string_literal: true

require 'rbconfig'
require_relative 'front-end'

module Lich
  module Common
    # Selects the Ruby executable used to start another Lich process.
    module RubyExecutable
      # Prefer the installed windowless Ruby companion on Windows.
      #
      # @param platform_key [Symbol] canonical host classification
      # @param configured_ruby [String] configured Ruby executable
      # @return [String] executable to use for the child process
      # @raise [ArgumentError] when configured_ruby is blank
      def self.resolve(platform_key: Frontend.platform_key, configured_ruby: RbConfig.ruby)
        raise ArgumentError, 'configured Ruby executable must not be empty' if configured_ruby.to_s.empty?

        platform_key = Frontend.validate_platform_key!(platform_key)
        return configured_ruby unless platform_key == :windows

        windowed_ruby = configured_ruby.sub(/ruby(?:\.exe)?$/i, 'rubyw.exe')
        return configured_ruby if windowed_ruby == configured_ruby

        File.file?(windowed_ruby) ? windowed_ruby : configured_ruby
      rescue SystemCallError
        configured_ruby
      end
    end
  end
end
