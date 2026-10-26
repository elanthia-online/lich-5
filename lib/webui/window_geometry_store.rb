# frozen_string_literal: true

require 'json'
require 'digest'
require 'fileutils'

module Lich
  module WebUI
    # Geometry only, separate from script settings. Each character/script/page
    # gets its own file, so closing one window cannot overwrite another's size.
    # Explicit script geometry wins; this supplies persistence to native forms
    # that never had their own window settings. No form draft is stored here.
    class WindowGeometryStore
      # Scopes geometry filenames to caller-supplied game/character context.
      # @param directory [String] storage directory
      # @param context [#call] callback supplying the current persistence context
      def initialize(directory:, context:)
        @directory, @context = directory, context
        @mutex = Mutex.new
      end

      # Reads valid saved content dimensions and position for a named script page.
      # @return [Hash, nil] geometry, or nil if missing, unreadable, or invalid
      def read(page)
        path = path_for(page)
        return unless path && File.file?(path)

        value = JSON.parse(File.read(path), symbolize_names: true)
        valid?(value) ? value : nil
      rescue JSON::ParserError, SystemCallError
        nil
      end

      # Replaces changed, valid geometry through a same-directory temporary file.
      # Unnamed owners are not persisted. This is atomic replacement, not fsync durability.
      # @return [void]
      def save(page)
        value = page.window_geometry
        path = path_for(page)
        return unless path && valid?(value)

        @mutex.synchronize do
          return if read(page) == value

          FileUtils.mkdir_p(@directory)
          temporary = "#{path}.#{Process.pid}.tmp"
          File.write(temporary, JSON.generate(value))
          File.rename(temporary, path)
        end
      end

      private

      # Hashes context, script name, and page ID into an installation-local filename.
      # @return [String, nil] persistence path, or nil for an unnamed owner
      def path_for(page)
        name = page.owner.respond_to?(:name) ? page.owner.name : nil
        return if name.to_s.empty?

        key = JSON.generate([@context.call, name, page.id])
        File.join(@directory, "#{Digest::SHA256.hexdigest(key)}.json")
      end

      # Checks integer dimensions and desktop coordinates against transport bounds.
      # @return [Boolean]
      def valid?(value)
        value.is_a?(Hash) && %i[width height].all? { |key| value[key].is_a?(Integer) && value[key].between?(1, 65_536) } &&
          value[:position].is_a?(Array) && value[:position].size == 2 &&
          value[:position].all? { |coordinate| coordinate.is_a?(Integer) && coordinate.between?(-65_536, 65_536) }
      end
    end
  end
end
