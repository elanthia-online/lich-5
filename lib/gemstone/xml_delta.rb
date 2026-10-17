# frozen_string_literal: true

require File.join(LIB_DIR, 'common', 'xmlparser', 'game_delta.rb')

module Lich
  module Gemstone
    # GemStone's semantic deltas for the shared server-stream parser. See
    # Lich::Common::XMLParserDelta for the composition and the hook contracts.
    module XMLDelta
      extend Lich::Common::XMLParserDelta::Base

      # GemStone subtitles carry no brackets: " - Town Square, Central - 228"
      # when the game shows room numbers, " - Town Square, Central" when it does
      # not. The title is bracketed here ("[Town Square, Central]") and the
      # number is stripped from it; the number's presence also turns on
      # Lich.display_uid (a global, not parser state).
      def self.main_subtitle(subtitle, nav_uid_pending:) # rubocop:disable Lint/UnusedMethodArgument
        if Lich.display_uid == false && subtitle[3..-1] =~ / - \d+$/
          Lich.display_uid = true
        end
        { room_title: '[' + subtitle[3..-1].gsub(/ - \d+$/, '') + ']' }
      end

      # GemStone sends <crtrStatus> inside room objs, just before the
      # creature's link, and also on its own: combat updates (one per hit),
      # the main-text "You also see" listing, and just before a room players
      # component. Inside room objs the tag is stashed for the link, which
      # registers the creature and marks it in the room before applying the
      # flags. A standalone tag for a creature already in the current room
      # roster is applied at once; registration and room-marking stay on the
      # link path. Any other standalone tag (an id the current room has not
      # linked) is stashed, but nothing reads it: the stash is only consumed
      # inside room objs, and opening room objs, <nav> or a reset clears it
      # first.
      def self.apply_crtr_status(id, flags, in_room_objs: false)
        return false if in_room_objs

        creature = room_creature(id)
        return false unless creature

        creature.sync_crtr_status(flags)
        :applied
      end

      # The GemStone creature a standalone <crtrStatus> may update: one already
      # registered and in the current room roster. Ids only enter the roster
      # from a room-objs link, so a recycled or never-linked id is never
      # touched.
      #
      # @param id [String] the tag's exist id
      # @return [Lich::Gemstone::CreatureInstance, nil]
      def self.room_creature(id)
        return nil unless defined?(Lich::Gemstone::CreatureInstance)
        return nil unless Lich::Gemstone::CreatureInstance.current_room_ids.include?(id.to_i)

        Lich::Gemstone::CreatureInstance[id]
      end
      private_class_method :room_creature

      Lich::Common::XMLParserDelta.register(/^GS/, self)
    end
  end
end
