# frozen_string_literal: true

require_relative 'script_list_feed'

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
    # The same line also asks for feeds (FEEDS): extra lines Lich sends the
    # client, such as the running-script list (ScriptListFeed). Feeds never
    # change the stream, and each category is resolved on its own: a line
    # replaces a client's rewrite set only when it names a rewrite, and its
    # feed set only when it names a feed, so asking for a feed never changes
    # the rewrites. A line that names nothing Lich knows (a bare
    # SET_FRONTEND_CAPS) replaces both with the empty set. The launch flag
    # follows the same rule.
    #
    # Only these three rewrites follow the client. Everything else Lich does
    # to the stream for a front end (Wizard's GSL codes, the origin sentinel,
    # mono, the room-number display, the Genie and Frostbite subtitle edits)
    # still follows the session's +$frontend+. A Wizard/Avalon (GSL) session
    # ignores declarations: its GSL conversion keeps state across lines, so
    # every client there gets the session's set.
    module ClientCapabilities
      # The rewrites a client can declare, in canonical order.
      DECLARABLE = %i[room_element game_links double_bold].freeze

      # The feeds a client can ask for, in canonical order.
      FEEDS = %i[script_list].freeze

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
      @launch_feeds = nil

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
        # The rewrites named replace the client's earlier rewrite set, and the
        # feeds named replace its earlier feed set; a category the line does
        # not name is left as it was, so a client can turn on a feed without
        # restating its rewrites. Names Lich does not know are ignored, so a
        # newer client can declare capabilities an older Lich lacks; a
        # declaration with no known name (or none at all) declares the empty
        # set for both, the full legacy rewrite and no feeds.
        #
        # @param client [#declared_capabilities=, #declared_feeds=, nil] the
        #   client connection
        # @param line [String, nil] one line read from that client
        # @return [Boolean] true when the line was a declaration, which the
        #   caller must then not forward to the game
        def declare(client, line)
          match = line.is_a?(String) && DECLARATION.match(line)
          return false unless match

          capabilities, feeds, unknown = parse_all(match[:names])
          nothing_known = capabilities.empty? && feeds.empty?
          if (nothing_known || !capabilities.empty?) && client.respond_to?(:declared_capabilities=)
            client.declared_capabilities = capabilities
          end
          client.declared_feeds = feeds if (nothing_known || !feeds.empty?) && client.respond_to?(:declared_feeds=)
          log("info: client declared capabilities [#{(capabilities + feeds).join(' ')}]" \
              "#{" (ignored unknown: #{unknown.join(' ')})" unless unknown.empty?}")
          ScriptListFeed.client_ready(client) if defined?(ScriptListFeed)
          true
        end

        # Splits a list of capability names into the known set and the rest.
        #
        # @param names [String, nil] names separated by spaces, tabs or commas
        # @return [Array(Array<Symbol>, Array<String>)] the frozen known set in
        #   DECLARABLE order, and the unknown names as given
        def parse(names)
          capabilities, _feeds, unknown = parse_all(names)
          [capabilities, unknown]
        end

        # Splits a list of names into rewrites, feeds and the rest.
        #
        # @param names [String, nil] names separated by spaces, tabs or commas
        # @return [Array(Array<Symbol>, Array<Symbol>, Array<String>)] the
        #   frozen rewrite set in DECLARABLE order, the frozen feed set in
        #   FEEDS order, and the unknown names as given
        def parse_all(names)
          tokens = names.to_s.split(SEPARATOR).reject(&:empty?)
          wanted = tokens.map { |token| token.downcase.to_sym }
          unknown = tokens.reject { |token| (DECLARABLE + FEEDS).include?(token.downcase.to_sym) }
          [DECLARABLE.select { |capability| wanted.include?(capability) }.freeze,
           FEEDS.select { |feed| wanted.include?(feed) }.freeze,
           unknown]
        end

        # Applies a --frontend-caps= list: like a declaration, it sets the
        # session's rewrite set only when it names a rewrite (or names nothing
        # known), and its feed set only when it names a feed.
        #
        # @param names [String, nil]
        # @return [Array<String>] the unknown names, for the caller to report
        def apply_launch_list(names)
          capabilities, feeds, unknown = parse_all(names)
          nothing_known = capabilities.empty? && feeds.empty?
          self.launch_capabilities = capabilities if nothing_known || !capabilities.empty?
          self.launch_feeds = feeds if nothing_known || !feeds.empty?
          unknown
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

        # The session's feeds from --frontend-caps=, or nil when it named none.
        # @return [Array<Symbol>, nil]
        attr_reader :launch_feeds

        # Sets (or, with nil, clears) the session's --frontend-caps= feeds.
        #
        # @param feeds [Array<Symbol>, nil]
        def launch_feeds=(feeds)
          @launch_feeds = feeds.nil? ? nil : FEEDS.select { |feed| feeds.include?(feed) }.freeze
        end

        # The feeds a client gets when it has not asked for any: the launch
        # flag's, else the catalog's for the session's front end (no built-in
        # front end has one).
        #
        # @param frontend [String, nil] the session's front end
        # @return [Array<Symbol>] frozen, in FEEDS order
        def session_feeds(frontend = $frontend)
          launch_feeds || FEEDS.select { |feed| Frontend.has_capability?(frontend, feed) }.freeze
        end

        # The feeds a client gets: the ones it asked for, else the session's.
        # Unlike the rewrites, a GSL session honours a client's feeds: they
        # add lines of their own and touch no conversion state.
        #
        # @param client [Object, nil]
        # @return [Array<Symbol>]
        def feeds_for(client)
          (client.declared_feeds if client.respond_to?(:declared_feeds)) || session_feeds
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
