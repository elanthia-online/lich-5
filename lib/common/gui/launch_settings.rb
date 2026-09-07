# frozen_string_literal: true

require 'socket'
require_relative '../frontend'

module Lich
  module Common
    module GUI
      # Interprets saved GUI launch preferences independently of frontend
      # protocol identity. CLI callers retain their explicit command-line flags.
      module LaunchSettings
        DEFAULT_PORT = 8000

        # Validates launch preferences without changing the entry or opening a
        # network connection. Old entries retain client-launch behavior, except
        # external-only protocols such as Profanity.
        # @param entry [Hash] symbol-keyed saved entry
        # @return [Hash] normalized mode and optional local listener port
        def self.resolve(entry)
          definition = Frontend.definition_for(entry.fetch(:frontend))
          external_only = definition.dig(:metadata, :external_client_only) && entry[:custom_launch].to_s.strip.empty?
          mode = entry[:launch_mode] || (external_only ? 'external' : 'client')
          raise ArgumentError, 'Choose Launch client or Headless / external client.' unless %w[client external].include?(mode)

          if mode == 'client'
            raise ArgumentError, 'This frontend requires Headless / external client mode.' if external_only

            return { mode: mode, port: nil }
          end
          unless definition[:capabilities].include?(:xml)
            raise ArgumentError, 'Headless external clients require an XML-capable frontend, such as Profanity.'
          end

          value = entry[:listen_port] || DEFAULT_PORT
          raise ArgumentError, 'The local port must be an integer from 1 to 65535.' unless value.to_s.match?(/\A\d+\z/)

          port = value.to_i
          raise ArgumentError, 'The local port must be an integer from 1 to 65535.' unless (1..65_535).cover?(port)

          { mode: mode, port: port }
        end

        # @param entry [Hash] saved entry
        # @return [Boolean] whether an external client will attach
        def self.external?(entry)
          return false unless entry.is_a?(Hash) && entry[:frontend]
          return entry[:launch_mode] == 'external' if entry[:launch_mode]
          return false unless entry[:custom_launch].to_s.strip.empty?

          Frontend.definition_for(entry[:frontend]).dig(:metadata, :external_client_only) == true
        rescue ArgumentError
          false
        end

        # @param entry [Hash] saved entry
        # @return [Array<String>] flags for the existing detachable CLI path
        def self.flags(entry)
          settings = resolve(entry)
          return [] unless settings[:mode] == 'external'

          ['--without-frontend', "--detachable-client=127.0.0.1:#{settings[:port]}"]
        end

        # Applies GUI-selected headless settings after authentication when the
        # launcher itself becomes the session (including unsaved manual logins).
        # @param entry [Hash] selected entry
        # @param argv [Array<String>] runtime argument list
        # @param options [Hash] already-parsed runtime options
        # @return [void]
        def self.apply_to_runtime!(entry, argv:, options:)
          settings = resolve(entry)
          return unless settings[:mode] == 'external'

          argv.reject! { |arg| arg.start_with?('--frontend=', '--detachable-client=') || arg == '--without-frontend' }
          argv.concat(flags(entry))
          argv << "--frontend=#{Frontend.canonical_name(entry[:frontend])}"
          options[:detachable_client_host] = '127.0.0.1'
          options[:detachable_client_port] = settings[:port]
        end

        # Checks for an already-occupied local port before GUI authentication.
        # The runtime listener still performs the authoritative bind, since a
        # different process can acquire the port after this check completes.
        # @param entry [Hash] saved entry
        # @return [void]
        def self.preflight!(entry)
          settings = resolve(entry)
          return unless settings[:mode] == 'external'

          socket = TCPServer.new('127.0.0.1', settings[:port])
          nil
        rescue SystemCallError
          raise ArgumentError, "Local port #{settings[:port]} is unavailable. Choose another port or stop the session using it."
        ensure
          socket&.close
        end
      end
    end
  end
end
