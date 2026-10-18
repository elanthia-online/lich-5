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
        # A staging file is only left behind when its writer was hard-killed
        # (SIGKILL, power loss). One older than this is treated as such a
        # leftover and removed after the next successful write of the same
        # file. The age is large so that a writer stalled on a slow or hung
        # drive keeps its staging file; if one is removed anyway, that
        # writer's rename fails and the live file is left untouched.
        STALE_STAGING_AGE = 24 * 60 * 60

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
        # neither the script resolver nor any sync SHA glob (+*.lic+,
        # +*.yaml+, +*.xml+) ever matches it.
        #
        # The temporary file is removed however safe_write exits: an
        # exception, a Thread#kill, or the process exiting while the
        # background login sync is mid-write. Only a hard kill (SIGKILL,
        # power loss) can leave one; see STALE_STAGING_AGE.
        #
        # After a successful write, leftovers beside +path+ are removed (best
        # effort): a +.old+ left by an older version, and a +.tmp+ left by an
        # older version or a staging file of this name, once either is older
        # than STALE_STAGING_AGE.
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
          ensure
            # After a successful rename the staging file no longer exists.
            begin
              File.delete(tmp) if File.exist?(tmp)
            rescue StandardError
              nil # the write error, if any, is the one worth reporting
            end
          end
          remove_leftovers(path)
        end

        # Best-effort removal, after a successful write of +path+, of files
        # left beside it by an interrupted writer. Never raises: the write it
        # follows already succeeded.
        #
        # * +path.old+ (older versions of safe_write and the legacy updater)
        #   is removed whatever its age. Its mtime is the original file's, so
        #   age says nothing about it, and an older-version writer that is
        #   still running renames its +.tmp+ into place without needing it.
        # * +path.tmp+ (older versions) is removed only once it is older than
        #   STALE_STAGING_AGE. A recent one may belong to an older-version
        #   writer in another session that is about to rename it over +path+;
        #   removing it then, after its writer moved +path+ to +.old+, would
        #   leave no file at +path+.
        # * +path.<pid>.<thread>.tmp+ staging files (a writer of this version
        #   that was hard-killed) are removed once older than
        #   STALE_STAGING_AGE.
        #
        # @param path [String] target file path
        # @return [void]
        def self.remove_leftovers(path)
          cutoff = Time.now - STALE_STAGING_AGE
          delete_quietly("#{path}.old")
          delete_quietly("#{path}.tmp", older_than: cutoff)

          dir = File.dirname(path)
          staging = /\A#{Regexp.escape(File.basename(path))}\.\d+\.\d+\.tmp\z/
          Dir.each_child(dir) do |name|
            next unless staging.match?(name)

            delete_quietly(File.join(dir, name), older_than: cutoff)
          end
        rescue StandardError
          nil
        end
        private_class_method :remove_leftovers

        # Deletes +file+ if it is a regular file (and, when +older_than+ is
        # given, last modified before that time), ignoring any error.
        #
        # @param file [String] path to delete
        # @param older_than [Time, nil] only delete a file modified before this
        # @return [void]
        def self.delete_quietly(file, older_than: nil)
          return unless File.file?(file)
          return if older_than && File.mtime(file) >= older_than

          File.delete(file)
        rescue StandardError
          nil
        end
        private_class_method :delete_quietly

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
