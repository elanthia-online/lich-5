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
        # effort): a +.old+ left by an older version (unless it holds exactly
        # +content+), and a +.tmp+ left by an older version or a staging file
        # of this name, once either is older than STALE_STAGING_AGE. If the
        # file system kept an existing name that differs from +path+'s only in
        # case, the file is renamed to +path+'s exact name.
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
          remove_leftovers(path, content)
        end

        # Best-effort removal, after a successful write of +path+, of files
        # left beside it by an interrupted writer. Never raises: the write it
        # follows already succeeded.
        #
        # * +path.old+ (older versions of safe_write and the legacy updater)
        #   is removed whatever its age (its mtime is the original file's, so
        #   age says nothing about it) unless it holds exactly +content+.
        #   Such a +.old+ is an older-version writer's rollback copy of the
        #   file this call just wrote: that writer moved +path+ aside after
        #   this call's rename and restores +.old+ if its own write fails, so
        #   removing it then would leave no file at +path+. A leftover from an
        #   interrupted older update holds the version before it, which
        #   differs, so it is still removed. +.old+ is looked up once: if it
        #   is absent, nothing is deleted, even if such a writer moves +path+
        #   there a moment later. One race remains: when a differing leftover
        #   is present and such a writer moves +path+ over it between the
        #   compare and the delete, its rollback copy is removed. There is no
        #   atomic compare-and-delete to close that gap.
        # * +path.tmp+ (older versions) is removed only once it is older than
        #   STALE_STAGING_AGE. A recent one may belong to an older-version
        #   writer in another session that is about to rename it over +path+;
        #   removing it then, after its writer moved +path+ to +.old+, would
        #   leave no file at +path+.
        # * +path.<pid>.<thread>.tmp+ staging files (a writer of this version
        #   that was hard-killed) are removed once older than
        #   STALE_STAGING_AGE.
        # * An entry whose name differs from +path+'s only in case and that is
        #   the same file (a case-insensitive file system) is renamed to
        #   +path+'s exact name; see fix_name_case.
        #
        # @param path [String] target file path
        # @param content [String] the content just written to +path+
        # @return [void]
        def self.remove_leftovers(path, content)
          cutoff = Time.now - STALE_STAGING_AGE
          old = "#{path}.old"
          delete_quietly(old) if File.file?(old) && !rollback_copy?(old, content)
          delete_quietly("#{path}.tmp", older_than: cutoff)

          dir = File.dirname(path)
          base = File.basename(path)
          staging = /\A#{Regexp.escape(base)}\.\d+\.\d+\.tmp\z/
          Dir.each_child(dir) do |name|
            if staging.match?(name)
              delete_quietly(File.join(dir, name), older_than: cutoff)
            elsif name != base && name.casecmp?(base)
              fix_name_case(File.join(dir, name), path)
            end
          end
        rescue StandardError
          nil
        end
        private_class_method :remove_leftovers

        # On a case-insensitive file system, renaming the staging file over an
        # existing file keeps the existing entry's name: writing buff.lic over
        # a local Buff.lic leaves Buff.lic. The sync compares by exact name,
        # so it would then download buff.lic again on every run. When
        # +existing+ is the same file as +path+, it is renamed to +path+'s
        # exact name. That is a case-only rename of one file, so the script
        # never goes missing. On a case-sensitive file system the two names
        # are different files and nothing is renamed. Never raises.
        #
        # @param existing [String] directory entry whose name case-matches +path+
        # @param path [String] target file path, with the wanted name
        # @return [void]
        def self.fix_name_case(existing, path)
          File.rename(existing, path) if File.identical?(existing, path)
        rescue StandardError
          nil
        end
        private_class_method :fix_name_case

        # Whether the existing regular file +file+ may be an older-version
        # writer's rollback copy of +content+: it holds exactly those bytes.
        # The size is compared first so a differing file is not read. If the
        # file cannot be read (or has gone), it is kept (true): a leftover is
        # cheaper than a lost file. The caller checks that +file+ exists, so
        # existence is not looked up a second time here.
        #
        # @param file [String] path to compare
        # @param content [String] the content just written
        # @return [Boolean]
        def self.rollback_copy?(file, content)
          File.size(file) == content.bytesize && File.binread(file) == content.b
        rescue StandardError
          true
        end
        private_class_method :rollback_copy?

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
