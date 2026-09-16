# frozen_string_literal: true

module Lich
  module Gemstone
    # Builds the one-time state push a newly attached detachable-client
    # frontend receives, so it starts with the vitals, status, hands, injuries,
    # and exits it missed before attaching.
    #
    # GemStone-owned: the DragonRealms feed differs substantially, so it has its
    # own Lich::DragonRealms::DetachableClientInit. Shared code that overlaps
    # (indicators, spell, hands, compass) is duplicated on purpose so each game
    # can change its push without affecting the other. Waiting for the login
    # feed and sending the result stay in detachable_client_send_init
    # (global_defs.rb).
    module DetachableClientInit
      # Every indicator the game sends. One not yet sent is reported as not
      # visible rather than as an empty attribute.
      INDICATORS = %w[IconBLEEDING IconPOISONED IconDISEASED IconSTANDING IconKNEELING IconSITTING IconPRONE
                      IconSTUNNED IconHIDDEN IconINVISIBLE IconDEAD IconWEBBED IconJOINED].freeze

      INJURY_AREAS = %w[back leftHand rightHand head rightArm abdomen leftEye leftArm chest rightLeg neck leftLeg nsys rightEye].freeze

      SHORT_DIRS = {
        'north' => 'n', 'northeast' => 'ne', 'east' => 'e', 'southeast' => 'se',
        'south' => 's', 'southwest' => 'sw', 'west' => 'w', 'northwest' => 'nw',
        'up' => 'up', 'down' => 'down', 'out' => 'out'
      }.freeze

      # Whether enough of the login feed has been parsed to build the push. In
      # the GemStone login feed the first <prompt> follows everything the push
      # describes (vitals, stance, mind, encumbrance, indicators, spell, hands,
      # and room exits), whereas IconJOINED and <endSetup/> arrive before some
      # of it. XMLData.prompt starts empty and holds the prompt text once one
      # has been parsed.
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
          "<progressBar id='pbarStance' value='#{XMLData.stance_value}'/>",
          "<progressBar id='mindState' value='#{XMLData.mind_value}' text='#{encode(XMLData.mind_text)}'/>",
          "<progressBar id='encumlevel' value='#{XMLData.encumbrance_value}' text='#{encode(XMLData.encumbrance_text)}'/>",
          injuries,
          compass,
        ].join
      end

      # GemStone reports current/max in text. The game does whole-integer math
      # with truncation, clamps the bar percent to 0..100, and still reports the
      # raw current value (which can be negative) in text. Integer division
      # matches it for the clamped range; a zero max (for example a character
      # with no mana, or a feed not yet parsed) reports 0 rather than dividing
      # by zero.
      def self.vitals
        %w[mana health spirit stamina].map do |id|
          current = XMLData.public_send(id)
          max = XMLData.public_send("max_#{id}")
          "<progressBar id='#{id}' value='#{percent(current, max)}' text='#{id} #{current}/#{max}'/>"
        end.join
      end

      def self.percent(current, max)
        return 0 if max.to_i <= 0

        ((current.to_i * 100) / max.to_i).clamp(0, 100)
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

      def self.injuries
        INJURY_AREAS.map do |area|
          wound = Wounds.public_send(area)
          scar = Scars.public_send(area)
          if wound > 0
            "<image id=\"#{area}\" name=\"Injury#{wound}\"/>"
          elsif scar > 0
            "<image id=\"#{area}\" name=\"Scar#{scar}\"/>"
          end
        end.join
      end

      def self.compass
        dirs = XMLData.room_exits.filter_map { |direction| "<dir value='#{SHORT_DIRS[direction]}'/>" if SHORT_DIRS.key?(direction) }
        "<compass>#{dirs.join}</compass>"
      end

      def self.encode(value)
        Lich::Common::XmlEntities.encode(value)
      end

      private_class_method :vitals, :percent, :hands, :indicators, :injuries, :compass, :encode
    end
  end
end
