# frozen_string_literal: true

module Lich
  module Main
    # Builds the human-facing notices Lich prints to $stdout for detachable
    # client listener lifecycle events: when the listener starts accepting
    # connections and when an attached client drops.
    #
    # These notices share a controlling terminal with an exec'd frontend (for
    # example ProfanityFE launched by a wrapper script), so they only become
    # visible once that frontend releases the screen. Keeping the wording in one
    # pure formatter ensures the connect and disconnect paths stay symmetric and
    # can be unit tested without opening sockets.
    #
    # @since 5.18.0
    module DetachableClientNotice
      PREFIX = '--- Lich: detachable client'

      # Formats a "host:port" endpoint, bracketing IPv6 literals so the port is
      # unambiguous (for example +[::1]:8000+). A host that is already bracketed
      # is left as-is.
      #
      # @param host [String, nil] bind host or address
      # @param port [Integer, String] listener port
      # @return [String] "host:port" with IPv6 literals bracketed
      def self.address(host, port)
        formatted_host = host.to_s
        formatted_host = "[#{formatted_host}]" if formatted_host.include?(':') && !formatted_host.start_with?('[')
        "#{formatted_host}:#{port}"
      end

      # Notice emitted when the detachable listener is ready for connections.
      #
      # @param host [String, nil] bind host or address
      # @param port [Integer, String] listener port
      # @return [String]
      def self.listening(host:, port:)
        "#{PREFIX} listening on #{address(host, port)}"
      end

      # Notice emitted when an attached client disconnects. Includes the session
      # name so an operator can tell which character's frontend dropped, the
      # endpoint it was attached to, and how many clients remain attached.
      #
      # @param name [String, nil] character/session name the client was attached
      #   to; when blank the name is omitted
      # @param host [String, nil] bind host or address
      # @param port [Integer, String] listener port
      # @param attached [Integer] detachable clients still attached after the drop
      # @return [String]
      def self.disconnected(name:, host:, port:, attached:)
        subject = name.to_s.empty? ? PREFIX : "#{PREFIX} #{name}"
        "#{subject} disconnected from #{address(host, port)} (#{attached} attached)"
      end
    end
  end
end
