# frozen_string_literal: true

require 'socket'
require 'ipaddr'

module Lich
  module Common
    # Resolves keyword bind hosts (+tailscale+, +lan+, +any+) into concrete
    # local addresses so users never have to discover their own interface IPs.
    # Non-keyword hosts pass through unchanged, gaining only an advisory
    # warning when they look reachable from untrusted networks.
    #
    # The detachable-client port is an unauthenticated plaintext socket that
    # can drive the game session, so every resolution away from loopback
    # carries a warning for the caller to surface to the user.
    #
    # @example Resolve the machine's Tailscale address
    #   Lich::Common::BindHostResolver.resolve('tailscale').host #=> "100.101.102.103"
    #
    # @since 5.18.0
    module BindHostResolver
      # Raised when a keyword host cannot be resolved to a usable address.
      Error = Class.new(StandardError)

      # The outcome of resolving a bind host token: +host+ is a bindable
      # address or hostname; +warning+ is advisory text for the user, or nil
      # when the binding is loopback/tailnet/private-safe.
      Resolution = Struct.new(:host, :warning, keyword_init: true)

      # Tailscale assigns every node an address from the CGNAT range.
      TAILSCALE_RANGE = IPAddr.new('100.64.0.0/10').freeze

      # RFC1918 ranges in preference order for +lan+: household routers hand
      # out 192.168/16 and 10/8, while Docker bridges, WSL adapters, and VM
      # host-only interfaces typically squat on 172.16/12.
      PRIVATE_RANGES = [
        IPAddr.new('192.168.0.0/16').freeze,
        IPAddr.new('10.0.0.0/8').freeze,
        IPAddr.new('172.16.0.0/12').freeze
      ].freeze

      ANY_WARNING = 'binding 0.0.0.0 exposes the unauthenticated detachable client ' \
                    'port on every network this machine is connected to; anyone who ' \
                    'can reach it can control the session'

      # Resolves a bind host token to a concrete address.
      #
      # @param token [String] +tailscale+, +lan+, +any+ (case-insensitive), an
      #   IP address, or a hostname
      # @param address_list [Array<Addrinfo>] local addresses (injectable for tests)
      # @param route_probe [#call] returns the default-route source address or nil
      # @return [Resolution] the bindable host and an optional user-facing warning
      # @raise [Error] when a keyword host has no matching local address
      def self.resolve(token, address_list: Socket.ip_address_list, route_probe: method(:default_route_address))
        case token.to_s.downcase
        when 'tailscale'
          resolve_tailscale(address_list)
        when 'lan'
          resolve_lan(address_list, route_probe)
        when 'any'
          Resolution.new(host: '0.0.0.0', warning: ANY_WARNING)
        else
          Resolution.new(host: token, warning: warning_for_explicit(token))
        end
      end

      def self.resolve_tailscale(address_list)
        address = ipv4_addresses(address_list).find { |ip| TAILSCALE_RANGE.include?(ip) }
        unless address
          raise Error, "Tailscale doesn't appear to be running on this machine " \
                       '(no 100.64.0.0/10 address found); start Tailscale or use lan:PORT instead'
        end
        Resolution.new(host: address, warning: nil)
      end

      def self.resolve_lan(address_list, route_probe)
        candidates = ipv4_addresses(address_list).select { |ip| private_address?(ip) }
        probed = begin
          route_probe.call
        rescue StandardError
          nil
        end
        address = if probed && candidates.include?(probed)
                    probed
                  else
                    PRIVATE_RANGES.lazy.map { |range| candidates.find { |ip| range.include?(ip) } }.find(&:itself)
                  end
        raise Error, 'no private (LAN) IPv4 address found on this machine' unless address

        Resolution.new(
          host: address,
          warning: 'the detachable client port is unauthenticated; anyone on your network ' \
                   "can control this session via #{address}. Prefer tailscale:PORT if you use Tailscale"
        )
      end

      # Learns the source address the OS would pick for outbound traffic by
      # connect()ing a UDP socket to a public IP - no packet is actually sent.
      # This selects the interface holding the default route, which is the
      # address other LAN devices can reach, unlike a naive first-interface
      # scan that may land on a Docker bridge or VM adapter.
      def self.default_route_address
        UDPSocket.open do |socket|
          socket.connect('8.8.8.8', 53)
          socket.addr[3]
        end
      rescue StandardError
        nil
      end

      def self.warning_for_explicit(token)
        ip = IPAddr.new(token.to_s)
        if ip.ipv4?
          return ANY_WARNING if ip == IPAddr.new('0.0.0.0')
          return nil if ip.loopback? || ip.private? || TAILSCALE_RANGE.include?(ip)
        else
          return ANY_WARNING if ip == IPAddr.new('::')
          return nil if ip.loopback? || ip.private? || ip.link_local?
        end
        "#{token} is not a private address; the unauthenticated detachable client " \
          'port may be reachable from untrusted networks'
      rescue IPAddr::InvalidAddressError
        # A hostname - nothing to judge without resolving it here.
        nil
      end

      def self.ipv4_addresses(address_list)
        address_list.select(&:ipv4?).map(&:ip_address).uniq
      end

      def self.private_address?(address)
        IPAddr.new(address).private?
      rescue IPAddr::InvalidAddressError
        false
      end
    end
  end
end
