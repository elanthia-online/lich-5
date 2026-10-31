# frozen_string_literal: true

require 'json'
require 'digest'
require 'fileutils'
require 'tempfile'

module Lich
  module WebUI
    # Geometry only, separate from script settings. Each character/script/page
    # gets its own file, so closing one window cannot overwrite another's size.
    # Explicit script geometry wins; this supplies persistence to native forms
    # that never had their own window settings. No form draft is stored here.
    class WindowGeometryStore
      # Windows refuses a rename over a file another process or store is replacing at
      # that moment (EACCES). The replacement is retried briefly; a save that still
      # cannot land is skipped and logged, since the next window change saves again.
      RENAME_ATTEMPTS = 3
      RENAME_RETRY_DELAY = 0.02

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
      # Each save creates its own uniquely named temporary file, so stores that
      # share a directory never write or rename one another's file.
      # Unnamed owners are not persisted. This is atomic replacement, not fsync durability.
      # A rename the operating system keeps refusing is logged and skipped, not raised.
      # @return [void]
      def save(page)
        value = page.window_geometry
        path = path_for(page)
        return unless path && valid?(value)

        @mutex.synchronize do
          return if read(page) == value

          FileUtils.mkdir_p(@directory)
          temporary = Tempfile.create([File.basename(path, '.json'), '.tmp'], @directory)
          begin
            temporary.write(JSON.generate(value))
            temporary.close
            renamed = replace_file(temporary.path, path)
          ensure
            temporary.close unless temporary.closed?
            File.unlink(temporary.path) if !renamed && File.exist?(temporary.path)
          end
        end
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
          Lich.log("warning: WebUI window geometry not saved (#{error.class})") if Lich.respond_to?(:log)
          false
        end
      end

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
