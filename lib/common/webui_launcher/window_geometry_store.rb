# frozen_string_literal: true

require 'yaml'
require 'tempfile'

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
        # Windows refuses a rename over a file another process or store is replacing at
        # that moment (EACCES). The replacement is retried briefly; a save that still
        # cannot land is skipped and logged, since the next window change saves again.
        RENAME_ATTEMPTS = 3
        RENAME_RETRY_DELAY = 0.02

        # Scopes launcher geometry to the installation's data directory.
        # @param data_dir [String] installation-owned storage directory
        def initialize(data_dir:)
          @data_dir = data_dir
        end

        # Tries WebUI geometry, then legacy launcher geometry, then defaults.
        # @return [Hash] validated dimensions and optional position
        def load
          read_geometry(File.join(@data_dir, FILE_NAME)) ||
            read_geometry(File.join(@data_dir, LEGACY_FILE_NAME)) || DEFAULT.dup
        end

        # Replaces the private YAML file atomically: a uniquely named temporary
        # file (created 0600) in the same directory is renamed over it, so a reader
        # never sees a truncated file. This is atomic replacement, not fsync durability.
        # A rename the operating system keeps refusing is retried a bounded number of
        # times, then logged and reported as a failed save.
        # @return [Hash, false] normalized saved geometry, or false on validation/write failure
        def save(geometry)
          validated = validate(geometry)
          return false unless validated

          temporary = Tempfile.create([File.basename(FILE_NAME, '.yml'), '.tmp'], @data_dir)
          begin
            temporary.write(YAML.dump(validated))
            temporary.close
            renamed = replace_file(temporary.path, File.join(@data_dir, FILE_NAME))
          ensure
            temporary.close unless temporary.closed?
            File.unlink(temporary.path) if !renamed && File.exist?(temporary.path)
          end
          renamed ? validated : false
        rescue StandardError => error
          Lich.log("warning: Could not save WebUI window geometry: #{error.message}") if Lich.respond_to?(:log)
          false
        end

        # Normalizes integer dimensions and optional position within launcher limits.
        # Accepts symbol or string keys for in-memory and YAML input.
        # @return [Hash, nil] normalized geometry, or nil if invalid
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

        # Renames the temporary file over the target, retrying a refused rename a bounded
        # number of times with a short, growing pause (backoff, not synchronization).
        # @return [Boolean] whether the target was replaced
        def replace_file(source, target)
          attempts = 0
          begin
            attempts += 1
            File.rename(source, target)
            true
          rescue SystemCallError => error
            if attempts < RENAME_ATTEMPTS
              sleep(RENAME_RETRY_DELAY * attempts)
              retry
            end
            Lich.log("warning: WebUI launcher window geometry not saved (#{error.class})") if Lich.respond_to?(:log)
            false
          end
        end

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
