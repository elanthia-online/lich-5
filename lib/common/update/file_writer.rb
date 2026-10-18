# frozen_string_literal: true

=begin
  Atomic file writing utilities for the update system.

  Provides safe_write (write-temp-then-rename pattern) and SHA map building
  for detecting file changes.
=end

module Lich
  module Util
    module Update
      module FileWriter
        # Suffixes that older versions of safe_write (and the legacy
        # updater) left beside a file when they were interrupted.
        LEGACY_LEFTOVER_SUFFIXES = %w[.old .tmp].freeze

        # Atomically replaces the file at +path+ with +content+.
        #
        # The content is written to a temporary file in the same directory
        # and then renamed over +path+. The live file is never moved away,
        # so a reader (for example a script start resolving the name) sees
        # either the old content or the new content, never a missing file.
        # File.rename replaces an existing destination on POSIX (rename(2))
        # and on Windows (MoveFileExW with MOVEFILE_REPLACE_EXISTING).
        #
        # The temporary name carries the process and thread so two writers of
        # the same file (two sessions sharing a scripts directory, or a manual
        # sync during the login sync) never share one. It ends in +.tmp+, so
        # neither the script resolver nor the +*.lic+/+*.yaml+ SHA globs
        # ever match it.
        #
        # After a successful write, +.old+ and +.tmp+ files that older
        # versions left beside +path+ are removed (best effort).
        #
        # @param path [String] target file path
        # @param content [String] file content to write
        # @return [void]
        # @raise [StandardError] if the write or rename fails; +path+ is left
        #   untouched and the temporary file is removed
        def self.safe_write(path, content)
          tmp = "#{path}.#{Process.pid}.#{Thread.current.object_id}.tmp"
          begin
            File.binwrite(tmp, content)
            File.rename(tmp, path)
          rescue StandardError
            begin
              File.delete(tmp) if File.exist?(tmp)
            rescue StandardError
              nil # the write error is the one worth reporting
            end
            raise
          end
          remove_legacy_leftovers(path)
        end

        # Best-effort removal of +path.old+ / +path.tmp+ left by older
        # versions. Never raises: the write it follows already succeeded.
        #
        # @param path [String] target file path
        # @return [void]
        def self.remove_legacy_leftovers(path)
          LEGACY_LEFTOVER_SUFFIXES.each do |suffix|
            leftover = "#{path}#{suffix}"
            begin
              File.delete(leftover) if File.file?(leftover)
            rescue StandardError
              nil
            end
          end
        end
        private_class_method :remove_legacy_leftovers

        # Builds filename => git-SHA map for files in directory.
        #
        # @param dir [String] directory path
        # @param pattern [String] glob pattern (default: '*.lic')
        # @return [Hash<String, String>] filename => SHA1 hash
        def self.build_local_sha_map(dir, pattern = '*.lic')
          Dir[File.join(dir, pattern)].each_with_object({}) do |path, map|
            body = File.binread(path)
            map[File.basename(path)] = Digest::SHA1.hexdigest("blob #{body.size}\0#{body}")
          end
        end
      end
    end
  end
end
