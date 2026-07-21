# frozen_string_literal: true

require_relative '../common/bind_host_resolver'

module Lich
  module Main
    # Applies keyword resolution to the parsed +--bind-address+ value, giving
    # it the same host vocabulary as +--detachable-client+ / +--headless+:
    # +tailscale+, +lan+, +any+, an IP address, or a hostname.
    #
    # Resolution happens once at startup, so every listener Lich opens (the
    # frontend socket, the +--game+ proxy, and a detachable client that
    # inherits the bind address) binds the same concrete address — and a
    # keyword failure (say, Tailscale not running) is reported before any
    # socket work begins.
    #
    # @since 5.19.2
    module BindAddressOption
      # The outcome of applying the option: +host+ is the concrete address to
      # store back (nil when no --bind-address was given), +warning+ is
      # advisory text to surface once, +error+ is fatal text (unresolvable
      # keyword) — the caller decides how to exit.
      Result = Struct.new(:host, :warning, :error, keyword_init: true)

      # Resolves the raw --bind-address token.
      #
      # @param token [String, nil] the parsed flag value, or nil when absent
      # @param resolver [#resolve] injectable for tests
      # @return [Result]
      def self.apply(token, resolver: Lich::Common::BindHostResolver)
        return Result.new if token.nil?

        resolution = resolver.resolve(token)
        Result.new(host: resolution.host, warning: resolution.warning)
      rescue Lich::Common::BindHostResolver::Error => e
        Result.new(error: e.message)
      end
    end
  end
end
