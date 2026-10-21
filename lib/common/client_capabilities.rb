# frozen_string_literal: true

module Lich
  module Common
    # Which of DragonRealms' rich-stream rewrites each attached front end gets.
    #
    # Lich rewrites the Saga-identity stream for a front end that cannot take
    # it: the inline <room> block becomes the legacy roomName/roomDesc lines
    # and compass (unless the front end has :room_element), <a exist> links are
    # stripped (unless :game_links), and doubled bold is collapsed (unless
    # :double_bold). Several front ends can share one session (a detachable
    # listener takes many), so each client connection carries its own set of
    # those three capabilities, resolved highest priority first:
    #
    # 1. what the client declared with a +SET_FRONTEND_CAPS+ line
    #    (see docs/frontends/capability-declaration.md);
    # 2. the session's +--frontend-caps=+ launch flag;
    # 3. the frontend catalog's capabilities for +$frontend+ (what every
    #    client got before declarations existed).
    #
    # Only these three rewrites follow the client. Everything else Lich does
    # to the stream for a front end (Wizard's GSL codes, the origin sentinel,
    # mono, the room-number display, the Genie and Frostbite subtitle edits)
    # still follows the session's +$frontend+. A Wizard/Avalon (GSL) session
    # ignores declarations: its GSL conversion keeps state across lines, so
    # every client there gets the session's set.
    module ClientCapabilities
      # The capabilities a client can declare, in canonical order.
      DECLARABLE = %i[room_element game_links double_bold].freeze

      # The client-to-Lich control line. Lich consumes it and never sends it
      # to the game. The command is case-sensitive, like SET_FRONTEND_PID; the
      # names after it are not.
      DECLARATION = /\ASET_FRONTEND_CAPS(?:[ \t]+(?<names>[^\r\n]*?))?[ \t]*\r?\n?\z/
      private_constant :DECLARATION

      # Names in a declaration or the launch flag are separated by spaces,
      # tabs or commas.
      SEPARATOR = /[\s,]+/
      private_constant :SEPARATOR

      @launch_capabilities = nil

      class << self
        # Whether a line from a client is a capability declaration.
        #
        # @param line [String, nil] one line read from a client
        # @return [Boolean]
        def declaration?(line)
          line.is_a?(String) && DECLARATION.match?(line)
        end

        # Applies a capability declaration to the client that sent it.
        #
        # The declared set replaces any earlier declaration from that client.
        # Names Lich does not know are ignored, so a newer client can declare
        # capabilities an older Lich lacks; a declaration with no known name
        # (or none at all) declares the empty set, the full legacy rewrite.
        #
        # @param client [#declared_capabilities=, nil] the client connection
        # @param line [String, nil] one line read from that client
        # @return [Boolean] true when the line was a declaration, which the
        #   caller must then not forward to the game
        def declare(client, line)
          match = line.is_a?(String) && DECLARATION.match(line)
          return false unless match

          capabilities, unknown = parse(match[:names])
          client.declared_capabilities = capabilities if client.respond_to?(:declared_capabilities=)
          log("info: client declared capabilities [#{capabilities.join(' ')}]" \
              "#{" (ignored unknown: #{unknown.join(' ')})" unless unknown.empty?}")
          true
        end

        # Splits a list of capability names into the known set and the rest.
        #
        # @param names [String, nil] names separated by spaces, tabs or commas
        # @return [Array(Array<Symbol>, Array<String>)] the frozen known set in
        #   DECLARABLE order, and the unknown names as given
        def parse(names)
          tokens = names.to_s.split(SEPARATOR).reject(&:empty?)
          known, unknown = tokens.partition { |token| DECLARABLE.include?(token.downcase.to_sym) }
          wanted = known.map { |token| token.downcase.to_sym }
          [DECLARABLE.select { |capability| wanted.include?(capability) }.freeze, unknown]
        end

        # The session's set from --frontend-caps=, or nil when not given.
        # @return [Array<Symbol>, nil]
        attr_reader :launch_capabilities

        # Sets (or, with nil, clears) the session's --frontend-caps= set.
        #
        # @param capabilities [Array<Symbol>, nil]
        def launch_capabilities=(capabilities)
          @launch_capabilities = capabilities.nil? ? nil : DECLARABLE.select { |capability| capabilities.include?(capability) }.freeze
        end

        # The set a client gets when it has not declared one: the launch flag's,
        # else the catalog's for the session's front end.
        #
        # @param frontend [String, nil] the session's front end
        # @return [Array<Symbol>] frozen, in DECLARABLE order
        def session_default(frontend = $frontend)
          launch_capabilities || DECLARABLE.select { |capability| Frontend.has_capability?(frontend, capability) }.freeze
        end

        # Groups clients by the capability set each one gets, so a server line
        # is rewritten once per distinct set, not once per client.
        #
        # @param clients [Array] the clients about to receive one line
        # @return [Hash{Array<Symbol> => Array}] each set and its clients; with
        #   no clients, the session's set and an empty list, so the line still
        #   runs through the client pipeline (whose state it may update)
        def group(clients)
          session = session_default
          return { session => clients.dup } if clients.empty? || Frontend.supports_gsl?

          clients.group_by { |client| declared(client) || session }
        end

        private

        def declared(client)
          client.declared_capabilities if client.respond_to?(:declared_capabilities)
        end

        def log(message)
          Lich.log(message) if Lich.respond_to?(:log)
        end
      end
    end
  end
end
