# frozen_string_literal: true

require 'yaml'

module Lich
  module Common
    class WebUILauncher
      # Persists validated outer-window geometry for the Chrome/Edge app shell.
      # A valid GTK launcher geometry is used once as a migration fallback.
      class WindowGeometryStore
        # File the WebUI launcher's own geometry is kept in, under the data directory.
        FILE_NAME = 'webui_launcher_geometry.yml'
        # The GTK launcher's settings file, read only when {FILE_NAME} is absent.
        LEGACY_FILE_NAME = 'login_gui_settings.yml'
        # Geometry used when neither file yields a valid one.
        DEFAULT = { width: 840, height: 680, position: nil }.freeze
        MIN_WIDTH = 480
        MIN_HEIGHT = 360
        MAX_DIMENSION = 16_384
        POSITION_RANGE = (-65_536..65_536)

        # @param data_dir [String] directory the geometry files live in
        # @return [WindowGeometryStore]
        def initialize(data_dir:)
          @data_dir = data_dir
        end

        # Reads the saved geometry, falling back to the GTK file and then to {DEFAULT}.
        #
        # @return [Hash{Symbol => Object}] :width, :height and :position (an [x, y] pair or nil)
        def load
          read_geometry(File.join(@data_dir, FILE_NAME)) ||
            read_geometry(File.join(@data_dir, LEGACY_FILE_NAME)) || DEFAULT.dup
        end

        # Validates the geometry and writes it to {FILE_NAME} with owner-only permissions.
        #
        # @param geometry [Hash, Object] candidate geometry, symbol or string keyed; see {#validate}
        # @return [Hash{Symbol => Object}, false] the validated geometry that was written, or false when
        #   the geometry is invalid or the write fails (the failure is logged)
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

        # Normalises a geometry to symbol keys and integer values, refusing anything out of bounds.
        #
        # Width and height must be Integers within {MIN_WIDTH}/{MIN_HEIGHT} and {MAX_DIMENSION};
        # a position must be nil or a two-Integer array within {POSITION_RANGE}.
        #
        # @param geometry [Hash, Object] candidate geometry, symbol or string keyed
        # @return [Hash{Symbol => Object}, nil] :width, :height and :position, or nil when invalid
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
