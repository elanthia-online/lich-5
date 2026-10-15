# frozen_string_literal: true

require File.join(LIB_DIR, 'common', 'xmlparser', 'game_delta.rb')

module Lich
  module Gemstone
    # GemStone's semantic deltas for the shared server-stream parser. See
    # Lich::Common::XMLParserDelta for the composition and the hook contracts.
    module XMLDelta
      extend Lich::Common::XMLParserDelta::Base

      # GemStone subtitles read " - [Town Square] - 1234" when the game shows
      # room numbers; the number is stripped from the title, and its presence
      # turns on Lich.display_uid.
      def self.main_subtitle(subtitle, nav_uid_pending:) # rubocop:disable Lint/UnusedMethodArgument
        if Lich.display_uid == false && subtitle[3..-1] =~ / - \d+$/
          Lich.display_uid = true
        end
        { room_title: '[' + subtitle[3..-1].gsub(/ - \d+$/, '') + ']' }
      end

      Lich::Common::XMLParserDelta.register(/^GS/, self)
    end
  end
end
