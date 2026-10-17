# frozen_string_literal: true

module Lich
  module Common
    # Game-specific deltas for the shared server-stream parser (XMLParser),
    # composed the way lib/common/map is: the common behavior and the hook
    # interface live here, and each game supplies only what genuinely differs in
    # its own file (lib/gemstone/xml_delta.rb, lib/dragonrealms/xml_delta.rb),
    # which GameLoader requires alongside that game's map delta.
    #
    # XMLParser asks {.for} for the current game's delta at the point of use
    # instead of being extended once. XMLData exists before the game is known,
    # survives XMLParser#reset, and specs drive bare parsers with a stubbed
    # XMLData.game; resolving per call keeps all of those working.
    #
    # Hooks cover game *semantics* only. Differences that are really about the
    # stream dialect (Saga identity vs legacy Wrayth handshake) branch on
    # XMLData.stream_feature? instead.
    module XMLParserDelta
      # ||= so that re-running this file (";hmr xmlparser" load()s it, since
      # the path matches) keeps the deltas the game files already registered;
      # those files are not reloaded with it, so a plain = would leave every
      # game on Default until restart.
      @registry ||= []

      # Registers a game's delta module.
      #
      # @param pattern [Regexp] matched against XMLData.game (e.g. /^DR/)
      # @param delta [Module] a module extended with {Base}
      # @return [void]
      def self.register(pattern, delta)
        @registry.reject! { |pat, _| pat == pattern }
        @registry << [pattern, delta]
      end

      # @param game [String, nil] XMLData.game
      # @return [Module] the registered delta for +game+, or {Default}
      def self.for(game)
        @registry.each { |pattern, delta| return delta if game.to_s =~ pattern }
        Default
      end

      # The hook interface, with the behavior for a game that is not (yet)
      # known. Game deltas extend this and override only the hooks that differ.
      module Base
        # Parses the main window's streamWindow subtitle. Returns the parser
        # state to update; omitted keys are left as they are. XMLParser applies
        # only the keys listed under @return, so a new key needs a matching
        # line at the call site. A hook may also update global (non-parser)
        # state (GemStone's turns on Lich.display_uid), so call it once per
        # subtitle and never speculatively.
        #
        # @param subtitle [String] the subtitle attribute, e.g. GemStone
        #   " - Town Square, Central - 228", DragonRealms " - [Town Square] (1234)"
        # @param nav_uid_pending [Boolean] a <nav rm> already supplied this
        #   arrival's UID
        # @return [Hash] any of :room_title, :room_id, :show_room_id,
        #   :nav_uid_pending
        def main_subtitle(subtitle, nav_uid_pending:) # rubocop:disable Lint/UnusedMethodArgument
          { room_title: String.new }
        end
      end

      # Delta for an unknown or unregistered game.
      module Default
        extend Base
      end
    end
  end
end
