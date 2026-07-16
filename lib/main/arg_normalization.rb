# frozen_string_literal: true

require_relative 'detachable_client_target'

module Lich
  module Main
    # Normalizes user-facing CLI aliases into the existing lower-level argument
    # forms consumed elsewhere in startup.
    module ArgNormalization
      HEADLESS_PATTERN = /^--headless(?:=(.+))?$/i.freeze
      DETACHABLE_CLIENT_PREFIX = '--detachable-client='.freeze

      # Rewrites high-level aliases in-place on the provided argv array.
      #
      # Current rules:
      # - `--headless PORT` => `--without-frontend --detachable-client=PORT`
      # - `--headless auto` => `--without-frontend --detachable-client=0`
      # - `--headless HOST:PORT` => `--without-frontend --detachable-client=HOST:PORT`
      #   (HOST may be tailscale, lan, any, an IP address, or a hostname)
      #
      # Bare `--headless` is rejected because an unattached fully headless login
      # is not a supported public workflow.
      #
      # @param argv [Array<String>] mutable argument vector
      # @return [Array<String>] the normalized argv array
      # @raise [ArgumentError] when `--headless` is missing a port or conflicts
      #   with an explicit detachable-client flag
      def self.normalize!(argv)
        headless_indices = argv.each_index.select { |index| argv[index].match?(HEADLESS_PATTERN) }
        return argv if headless_indices.empty?
        raise ArgumentError, '--headless may only be specified once' if headless_indices.length > 1

        if argv.any? { |arg| arg.start_with?(DETACHABLE_CLIENT_PREFIX) }
          raise ArgumentError, '--headless cannot be combined with --detachable-client'
        end

        headless_index = headless_indices.first
        headless_arg = argv[headless_index]
        inline_match = HEADLESS_PATTERN.match(headless_arg)
        port_token = inline_match[1]

        if port_token.nil?
          next_arg = argv[headless_index + 1]
          if next_arg.nil? || next_arg.start_with?('--')
            raise ArgumentError, '--headless requires a port number or auto'
          end

          port_token = next_arg
          argv.delete_at(headless_index + 1)
        end

        argv[headless_index] = '--without-frontend'
        argv.insert(headless_index + 1, "#{DETACHABLE_CLIENT_PREFIX}#{normalize_headless_target(port_token)}")
        argv
      end

      # Resolves the target token accepted by `--headless` to the canonical
      # form consumed by `--detachable-client`.
      #
      # @param token [String] user-provided token after `--headless`
      # @return [String] canonical `PORT` or `HOST:PORT` (port `0` means
      #   OS-assigned auto)
      # @raise [ArgumentError] when the token is not a valid port, `auto`, or
      #   HOST:PORT form
      def self.normalize_headless_target(token)
        target = DetachableClientTarget.parse(token)
        return target.port.to_s if target.host.nil?

        host = target.host.include?(':') ? "[#{target.host}]" : target.host
        "#{host}:#{target.port}"
      rescue DetachableClientTarget::ParseError
        raise ArgumentError, '--headless requires a port number between 1 and 65535, auto, ' \
                             'or HOST:PORT (HOST may be tailscale, lan, any, an IP address, or a hostname)'
      end
    end
  end
end
