# frozen_string_literal: true

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
      #
      # Bare `--headless` is rejected because an unattached fully headless login
      # is not a supported public workflow.
      #
      # @param argv [Array<String>] mutable argument vector
      # @return [Array<String>] the normalized argv array
      # @raise [ArgumentError] when `--headless` is missing a port or conflicts
      #   with an explicit detachable-client flag
      def self.normalize!(argv)
        headless_index = argv.index { |arg| arg.match?(HEADLESS_PATTERN) }
        return argv if headless_index.nil?

        if argv.any? { |arg| arg.start_with?(DETACHABLE_CLIENT_PREFIX) }
          raise ArgumentError, '--headless cannot be combined with --detachable-client'
        end

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
        argv.insert(headless_index + 1, "#{DETACHABLE_CLIENT_PREFIX}#{normalize_headless_port(port_token)}")
        argv
      end

      # Resolves the detachable port token accepted by `--headless`.
      #
      # @param token [String] user-provided token after `--headless`
      # @return [Integer] detachable listener port, or `0` for OS-assigned auto
      # @raise [ArgumentError] when the token is not a valid port or `auto`
      def self.normalize_headless_port(token)
        return 0 if token.to_s.casecmp('auto').zero?

        port = Integer(token, 10)
        return port if port.positive? && port <= 65_535

        raise ArgumentError, '--headless requires a port number between 1 and 65535, or auto'
      rescue ArgumentError
        raise ArgumentError, '--headless requires a port number between 1 and 65535, or auto'
      end
    end
  end
end
