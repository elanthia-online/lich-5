# frozen_string_literal: true

require_relative '../authentication/legacy_entry_file'

module Lich
  module Common
    module GUI
      # Handles state management for the Lich GUI login system
      # Applies theme settings; entry.dat loading and saving is delegated to
      # Lich::Common::Authentication::LegacyEntryFile
      module State
        # Loads saved entry data from file
        #
        # @see Lich::Common::Authentication::LegacyEntryFile.load_saved_entries
        def self.load_saved_entries(data_dir, autosort_state)
          Authentication::LegacyEntryFile.load_saved_entries(data_dir, autosort_state)
        end

        # Saves entry data to file
        #
        # @see Lich::Common::Authentication::LegacyEntryFile.save_entries
        def self.save_entries(data_dir, entry_data)
          Authentication::LegacyEntryFile.save_entries(data_dir, entry_data)
        end

        # Applies theme settings to GTK
        # Sets the GTK dark theme preference based on the provided state
        #
        # @param theme_state [Boolean] Whether dark theme is enabled
        # @return [void]
        def self.apply_theme_settings(theme_state)
          Gtk::Settings.default.gtk_application_prefer_dark_theme = true if theme_state == true
        end
      end
    end
  end
end
