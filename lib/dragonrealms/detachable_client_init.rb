# frozen_string_literal: true

module Lich
  module DragonRealms
    # Builds the one-time state push a newly attached detachable-client
    # frontend receives, so it starts with the vitals, status, hands, and exits
    # it missed before attaching.
    #
    # DragonRealms-owned: the GemStone feed differs substantially, so it has its
    # own Lich::Gemstone::DetachableClientInit. Shared code that overlaps
    # (indicators, spell, hands, compass) is duplicated on purpose so each game
    # can change its push without affecting the other. Waiting for the login
    # feed and sending the result stay in detachable_client_send_init
    # (global_defs.rb).
    #
    # Not sent, because the DragonRealms feed has no equivalent: stance, mind,
    # and encumbrance bars (experience arrives as its own stream). Injuries are
    # not sent yet: the DragonRealms injury image names for an injured body part
    # have not been confirmed from a captured feed.
    module DetachableClientInit
      # Every indicator the game sends. One not yet sent is reported as not
      # visible rather than as an empty attribute.
      INDICATORS = %w[IconBLEEDING IconPOISONED IconDISEASED IconSTANDING IconKNEELING IconSITTING IconPRONE
                      IconSTUNNED IconHIDDEN IconINVISIBLE IconDEAD IconWEBBED IconJOINED].freeze

      # [progressBar id, text label]. The game labels stamina as "fatigue".
      VITALS = [%w[health health], %w[mana mana], %w[stamina fatigue], %w[spirit spirit], %w[concentration concentration]].freeze

      SHORT_DIRS = {
        'north' => 'n', 'northeast' => 'ne', 'east' => 'e', 'southeast' => 'se',
        'south' => 's', 'southwest' => 'sw', 'west' => 'w', 'northwest' => 'nw',
        'up' => 'up', 'down' => 'down', 'out' => 'out'
      }.freeze

      # Whether enough of the login feed has been parsed to build the push. In
      # the DragonRealms login feed the first <prompt> follows everything the
      # push describes (vitals, indicators, spell, hands, and room exits),
      # whereas IconJOINED and <endSetup/> arrive before some of it.
      # XMLData.prompt starts empty and holds the prompt text once one has been
      # parsed.
      #
      # @return [Boolean]
      def self.ready?
        !XMLData.prompt.empty?
      end

      # @return [String] the XML to send to the frontend
      def self.init_string
        [
          vitals,
          "<spell>#{encode(XMLData.prepared_spell)}</spell>",
          hands,
          indicators,
          compass,
        ].join
      end

      # DragonRealms reports vitals as a bare percent ("health 100%"), which the
      # parser stores in the current field with a nil max. value and text carry
      # the same percent, as the game itself sends them; value is clamped to
      # 0..100 while text keeps the raw number.
      def self.vitals
        VITALS.map do |id, label|
          percent = XMLData.public_send(id).to_i
          "<progressBar id='#{id}' value='#{percent.clamp(0, 100)}' text='#{label} #{percent}%'/>"
        end.join
      end

      # A hand is nil until the game has sent it, so fall back to the game's own
      # "Empty" rather than raising and losing the whole push.
      def self.hands
        "<right>#{encode(GameObj.right_hand&.name || 'Empty')}</right>" \
          "<left>#{encode(GameObj.left_hand&.name || 'Empty')}</left>"
      end

      def self.indicators
        INDICATORS.map do |indicator|
          "<indicator id='#{indicator}' visible='#{XMLData.indicator.fetch(indicator, 'n')}'/>"
        end.join
      end

      def self.compass
        dirs = XMLData.room_exits.filter_map { |direction| "<dir value='#{SHORT_DIRS[direction]}'/>" if SHORT_DIRS.key?(direction) }
        "<compass>#{dirs.join}</compass>"
      end

      def self.encode(value)
        Lich::Common::XmlEntities.encode(value)
      end

      private_class_method :vitals, :hands, :indicators, :compass, :encode
    end
  end
end
