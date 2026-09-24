# frozen_string_literal: true

require 'yaml'

module Lich
  module Common
    class WebUILauncher
      # Persists validated outer-window geometry for the Chrome/Edge app shell.
      # A valid GTK launcher geometry is used once as a migration fallback.
      class WindowGeometryStore
        FILE_NAME = 'webui_launcher_geometry.yml'
        LEGACY_FILE_NAME = 'login_gui_settings.yml'
        DEFAULT = { width: 840, height: 680, position: nil }.freeze
        MIN_WIDTH = 480
        MIN_HEIGHT = 360
        MAX_DIMENSION = 16_384
        POSITION_RANGE = (-65_536..65_536)

        def initialize(data_dir:)
          @data_dir = data_dir
        end

        def load
          read_geometry(File.join(@data_dir, FILE_NAME)) ||
            read_geometry(File.join(@data_dir, LEGACY_FILE_NAME)) || DEFAULT.dup
        end

        def save(geometry)
          validated = validate(geometry)
          return false unless validated

          File.open(File.join(@data_dir, FILE_NAME), File::WRONLY | File::CREAT | File::TRUNC, 0o600) do |file|
            file.write(YAML.dump(validated))
          end
          validated
        rescue StandardError => error
          Lich.log("warning: Could not save WebUI window geometry: #{error.message}") if Lich.respond_to?(:log)
          false
        end

        def validate(geometry)
          return unless geometry.is_a?(Hash)

          width = integer(geometry[:width] || geometry['width'])
          height = integer(geometry[:height] || geometry['height'])
          position = geometry[:position] || geometry['position']
          return unless width&.between?(MIN_WIDTH, MAX_DIMENSION)
          return unless height&.between?(MIN_HEIGHT, MAX_DIMENSION)
          return { width: width, height: height, position: nil } if position.nil?
          return unless position.is_a?(Array) && position.length == 2

          x = integer(position[0])
          y = integer(position[1])
          return unless x && y && POSITION_RANGE.cover?(x) && POSITION_RANGE.cover?(y)

          { width: width, height: height, position: [x, y] }
        end

        private

        def read_geometry(path)
          return unless File.file?(path)

          validate(YAML.safe_load(File.read(path), permitted_classes: [Symbol], symbolize_names: true))
        rescue StandardError => error
          Lich.log("warning: Could not load WebUI window geometry: #{error.message}") if Lich.respond_to?(:log)
          nil
        end

        def integer(value)
          value if value.is_a?(Integer)
        end
      end
    end
  end
end
