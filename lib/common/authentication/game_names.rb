# frozen_string_literal: true

require_relative 'login_helpers'

module Lich
  module Common
    module Authentication
      # Display names for the canonical game codes, shared by every launcher
      # front end. The GTK launcher's Lich::Common::GUI::GameSelection reuses
      # these constants for its combo boxes.
      module GameNames
        # User-friendly display names for canonical game codes.
        GAME_NAMES = {
          'GS3' => 'GemStone IV',
          'GST' => 'GemStone IV Prime Test',
          'GSF' => 'GemStone IV Shattered',
          'DR'  => 'DragonRealms',
          'DRX' => 'DragonRealms Platinum',
          'DRT' => 'DragonRealms Prime Test',
          'DRF' => 'DragonRealms Fallen'
        }.freeze

        # Game code to display name mapping, derived from the canonical validator.
        GAME_MAPPING = LoginHelpers::VALID_GAME_CODES.to_h do |game_code|
          [game_code, GAME_NAMES.fetch(game_code)]
        end.freeze

        # Display name to game code mapping (reverse of GAME_MAPPING)
        # Used for converting user-selected display names back to game codes
        REVERSE_GAME_MAPPING = GAME_MAPPING.invert.freeze

        # Gets the game name for a game code
        # Converts an internal game code to its user-friendly display name
        #
        # @param game_code [String] Game code
        # @return [String] Display name for the game
        def self.get_game_name(game_code)
          return 'Unknown' unless LoginHelpers.valid_game_code?(game_code)

          GAME_MAPPING.fetch(game_code)
        end
      end
    end
  end
end
