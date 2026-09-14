# frozen_string_literal: true

module Lich
  module Main
    # Parses the value of +--detachable-client=VALUE+ (and the +--headless+
    # alias) into a bind host token and a port, without touching the network.
    # Keyword hosts (tailscale/lan/any) are resolved to concrete addresses
    # later by Lich::Common::BindHostResolver.
    #
    # Accepted forms: +PORT+, +auto+, +HOST:PORT+, +HOST:auto+, +[IPV6]:PORT+
    #
    # @since 5.18.0
    module DetachableClientTarget
      # Raised when the flag value does not match any accepted form.
      ParseError = Class.new(ArgumentError)

      # +host+ is nil when only a port was given (the bind host then comes
      # from --bind-address or the loopback default); +port+ 0 means the OS
      # assigns one.
      Target = Struct.new(:host, :port, keyword_init: true)

      USAGE = '--detachable-client requires PORT, auto, or HOST:PORT ' \
              '(HOST may be tailscale, lan, any, an IP address, or a hostname)'

      # Parses a flag value into a Target.
      #
      # @param value [String] text after the = in --detachable-client=VALUE
      # @return [Target]
      # @raise [ParseError] when the value matches no accepted form
      def self.parse(value)
        token = value.to_s.strip
        raise ParseError, USAGE if token.empty?
        return Target.new(host: nil, port: 0) if token.casecmp('auto').zero?
        return Target.new(host: nil, port: parse_port(token)) if token.match?(/\A\d+\z/)

        host, port_token = split_host_port(token)
        port = port_token.casecmp('auto').zero? ? 0 : parse_port(port_token)
        Target.new(host: host, port: port)
      end

      def self.split_host_port(token)
        if (bracketed = token.match(/\A\[([^\]]+)\]:([^:]+)\z/))
          bracketed.captures
        elsif (plain = token.match(/\A([^:]+):([^:]+)\z/))
          plain.captures
        else
          raise ParseError, USAGE
        end
      end

      def self.parse_port(port_token)
        port = begin
          Integer(port_token, 10)
        rescue ArgumentError, TypeError
          raise ParseError, USAGE
        end
        unless port.between?(0, 65_535)
          raise ParseError, 'detachable client port must be between 0 and 65535 (0 or auto lets the OS choose)'
        end
        port
      end
    end
  end
end
