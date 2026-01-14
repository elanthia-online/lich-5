# frozen_string_literal: true

module Lich
  module Common
    module GUI
      # Manages persistence of login GUI window settings (size, position)
      #
      # Handles loading and saving window geometry to a YAML file,
      # with support for multi-monitor setups and Darwin menu bar offset.
      #
      # @example Loading settings
      #   settings = WindowSettings.load(DATA_DIR)
      #   # => { width: 800, height: 600, position: [100, 100] }
      #
      # @example Saving settings
      #   WindowSettings.save(DATA_DIR, width: 800, height: 600, position: [100, 100])
      module WindowSettings
        SETTINGS_FILE = 'login_gui_settings.yml'
        MIN_DIMENSION = 100
        DARWIN_SPACER = 28

        class << self
          # Loads window settings from YAML file
          #
          # @param data_dir [String] Directory containing settings file
          # @return [Hash] Settings hash with :width, :height, :position keys (may be empty)
          def load(data_dir)
            settings_file = File.join(data_dir, SETTINGS_FILE)
            return {} unless File.exist?(settings_file)

            settings = YAML.load_file(settings_file)
            validate_settings(settings) ? settings : {}
          rescue StandardError => e
            Lich.log "warning: Could not load window settings: #{e.message}"
            {}
          end

          # Saves window settings to YAML file
          #
          # @param data_dir [String] Directory to save settings file
          # @param width [Integer] Window width
          # @param height [Integer] Window height
          # @param position [Array<Integer>] Window position [x, y]
          # @return [Boolean] True if save succeeded
          def save(data_dir, width:, height:, position:)
            return false unless valid_dimensions?(width, height) && valid_position?(position)

            settings_file = File.join(data_dir, SETTINGS_FILE)
            settings = {
              width: width,
              height: height,
              position: position
            }

            File.open(settings_file, 'w') { |f| f.write(YAML.dump(settings)) }
            true
          rescue StandardError => e
            Lich.log "warning: Could not save window settings: #{e.message}"
            false
          end

          # Applies saved settings to a window with monitor bounds checking
          #
          # @param window [Gtk::Window] Window to configure
          # @param settings [Hash] Settings hash from load()
          # @return [void]
          def apply_to_window(window, settings)
            return if settings.empty?

            width = [settings[:width], MIN_DIMENSION].max
            height = [settings[:height], MIN_DIMENSION].max
            position = settings[:position]

            window.resize(width, height)

            return unless valid_position?(position)

            constrained_position = constrain_to_monitor(position, width, height)
            spacer = darwin? ? DARWIN_SPACER : 0
            window.move(constrained_position[0], constrained_position[1] + spacer)
          end

          # Captures current window geometry
          #
          # @param window [Gtk::Window] Window to capture geometry from
          # @return [Hash] Hash with :width, :height, :position keys
          def capture_geometry(window)
            {
              width: window.allocation.width,
              height: window.allocation.height,
              position: window.position
            }
          end

          private

          # Validates loaded settings structure
          #
          # @param settings [Hash, nil] Settings to validate
          # @return [Boolean] True if settings are valid
          def validate_settings(settings)
            return false unless settings.is_a?(Hash)

            valid_dimensions?(settings[:width], settings[:height]) &&
              valid_position?(settings[:position])
          end

          # Validates dimension values
          #
          # @param width [Object] Width value to validate
          # @param height [Object] Height value to validate
          # @return [Boolean] True if both are integers > MIN_DIMENSION
          def valid_dimensions?(width, height)
            width.is_a?(Integer) && width > MIN_DIMENSION &&
              height.is_a?(Integer) && height > MIN_DIMENSION
          end

          # Validates position value
          #
          # @param position [Object] Position to validate
          # @return [Boolean] True if position is [Integer, Integer] with positive values
          def valid_position?(position)
            position.is_a?(Array) &&
              position.length == 2 &&
              position[0].is_a?(Integer) && position[0] >= 0 &&
              position[1].is_a?(Integer) && position[1] >= 0
          end

          # Constrains window position to stay within monitor bounds
          #
          # @param position [Array<Integer>] Desired position [x, y]
          # @param width [Integer] Window width
          # @param height [Integer] Window height
          # @return [Array<Integer>] Constrained position [x, y]
          def constrain_to_monitor(position, width, height)
            display = Gdk::Display.default
            geometry = display.default_screen.get_monitor_geometry(
              display.default_screen.get_monitor_at_point(position[0], position[1])
            )

            monitor_x = geometry.x || 0
            monitor_y = geometry.y || 0
            monitor_width = geometry.width || 0
            monitor_height = geometry.height || 0

            constrained_x = [[monitor_x, position[0]].max, monitor_x + monitor_width - width].min
            constrained_y = [[monitor_y, position[1]].max, monitor_y + monitor_height - height].min

            [constrained_x, constrained_y]
          end

          # Checks if running on Darwin (macOS)
          #
          # @return [Boolean] True if platform is Darwin
          def darwin?
            RUBY_PLATFORM =~ /darwin/i
          end
        end
      end
    end
  end
end
