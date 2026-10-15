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

      Lich::Common::XMLParserDelta.register(/^GS/, self)
    end
  end
end
