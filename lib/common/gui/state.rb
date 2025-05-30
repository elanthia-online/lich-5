# frozen_string_literal: true

module Lich
  module Common
    module GUI
      # Handles state management for the Lich GUI login system
      module State
        # Loads saved entry data from file
        #
        # @param data_dir [String] Directory containing entry data
        # @param autosort_state [Boolean] Whether to use auto-sorting
        # @return [Array] Array of saved login entries
        def self.load_saved_entries(data_dir, autosort_state)
          if File.exist?(File.join(data_dir, "entry.dat"))
            File.open(File.join(data_dir, "entry.dat"), 'r') { |file|
              begin
                if autosort_state
                  # Sort in list by instance name, account name, and then character name
                  Marshal.load(file.read.unpack('m').first).sort do |a, b|
                    [a[:game_name], a[:user_id], a[:char_name]] <=> [b[:game_name], b[:user_id], b[:char_name]]
                  end
                else
                  # Sort in list by account name, and then character name (old Lich 4)
                  Marshal.load(file.read.unpack('m').first).sort do |a, b|
                    [a[:user_id].downcase, a[:char_name]] <=> [b[:user_id].downcase, b[:char_name]]
                  end
                end
              rescue
                Array.new
              end
            }
          else
            Array.new
          end
        end

        # Saves entry data to file
        #
        # @param data_dir [String] Directory to save entry data
        # @param entry_data [Array] Array of entry data to save
        # @return [Boolean] True if save was successful
        def self.save_entries(data_dir, entry_data)
          File.open(File.join(data_dir, "entry.dat"), 'w') { |file|
            file.write([Marshal.dump(entry_data)].pack('m'))
          }
          true
        rescue
          false
        end

        # Applies theme settings to GTK
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
