# frozen_string_literal: true

require_relative '../authentication/login_helpers'

module Lich
  module Common
    module GUI
      # Provides game selection utilities for the Lich GUI login system
      # Implements accurate game selection with proper accessibility support
      module GameSelection
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
        GAME_MAPPING = Authentication::LoginHelpers::VALID_GAME_CODES.to_h do |game_code|
          [game_code, GAME_NAMES.fetch(game_code)]
        end.freeze

        # Display name to game code mapping (reverse of GAME_MAPPING)
        # Used for converting user-selected display names back to game codes
        REVERSE_GAME_MAPPING = GAME_MAPPING.invert.freeze

        # Game codes that may be written to a character's entry.yaml record.
        #
        # Deliberately narrower than Authentication::LoginHelpers::VALID_GAME_CODES,
        # which additionally accepts GS4 - a code the game stream reports at runtime
        # (instance='GS4') but that no game entry is stored under; persisting it would
        # yield a record whose game_name is 'Unknown'. Anything selectable in the GUI's
        # game combo, and only that, is storable here.
        PERSISTABLE_GAME_CODES = GAME_MAPPING.keys.freeze

        # Creates an accessible game selection combo box
        # Builds a dropdown with all available games and proper accessibility support
        #
        # @param current_selection [String, nil] Currently selected game code (optional)
        # @return [Gtk::ComboBoxText] Combo box with game options
        def self.create_game_selection_combo(current_selection = nil)
          combo = Gtk::ComboBoxText.new

          # Add all game options
          GAME_MAPPING.each do |_code, name|
            combo.append_text(name)
          end

          # Set default selection
          if Authentication::LoginHelpers.valid_game_code?(current_selection)
            # Set to the provided game code
            index = GAME_MAPPING.keys.index(current_selection)
            combo.active = index if index
          else
            # Default to GS Prime
            combo.active = GAME_MAPPING.keys.index('GS3') || 0
          end

          # Add accessibility properties
          Accessibility.make_combo_accessible(
            combo,
            "Game Selection",
            "Select the game for this character"
          )

          combo
        end

        # Gets the game code for the selected game in the combo box
        # Converts the user-selected display name back to the internal game code
        #
        # @param combo [Gtk::ComboBoxText] Game selection combo box
        # @return [String] Game code for the selected game
        def self.get_selected_game_code(combo)
          return nil unless combo

          selected_text = combo.active_text
          game_code = REVERSE_GAME_MAPPING[selected_text]
          Authentication::LoginHelpers.valid_game_code?(game_code) ? game_code : 'GS3'
        end

        # Gets the game name for a game code
        # Converts an internal game code to its user-friendly display name
        #
        # @param game_code [String] Game code
        # @return [String] Display name for the game
        def self.get_game_name(game_code)
          return 'Unknown' unless Authentication::LoginHelpers.valid_game_code?(game_code)

          GAME_MAPPING.fetch(game_code)
        end

        # Updates an existing combo box with the current game options
        # Refreshes the contents of an existing combo box with the latest game options
        #
        # @param combo [Gtk::ComboBoxText] Existing game selection combo box
        # @param current_selection [String, nil] Currently selected game code (optional)
        # @return [void]
        def self.update_game_selection_combo(combo, current_selection = nil)
          return unless combo

          # Clear existing options
          while combo.remove_text(0)
            # Keep removing until empty
          end

          # Add all game options
          GAME_MAPPING.each do |_code, name|
            combo.append_text(name)
          end

          # Set selection
          if Authentication::LoginHelpers.valid_game_code?(current_selection)
            # Set to the provided game code
            index = GAME_MAPPING.keys.index(current_selection)
            combo.active = index if index
          else
            # Default to GS Prime
            combo.active = GAME_MAPPING.keys.index('GS3') || 0
          end
        end
      end
    end
  end
end
