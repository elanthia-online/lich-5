# frozen_string_literal: true

=begin
  Snapshot and rollback functionality for Lich core files.

  Creates timestamped backups of lib/, lich.rbw, and core scripts before
  updates. Supports rollback to most recent snapshot.

  Both directions are built so that a failure (disk full, a locked or
  unreadable file) leaves the installation as it was, apart from the one case
  named below, and a snapshot killed part way is never visible to #revert:

  - #snapshot copies into a staging directory that #revert cannot see, and
    renames it to its final L5-snapshot-<DATE-TIME> name only after every
    copy has succeeded.
  - #revert checks that the newest snapshot is complete before it touches
    anything, refuses (naming the directory) when it is not, and copies the
    snapshot next to the live files before swapping them in with renames
    that are undone if any step fails. If even the undo fails, lib/, the
    core scripts and lich.rbw can be left part old, part restored; the
    working directories are then kept and named so the previous files can
    be recovered by hand. Where the filesystem supports locking, only one
    #revert runs at a time on an installation: a second one started
    meanwhile changes nothing.

  A revert killed during the swap cannot undo it. It can leave lib/, the core
  scripts or lich.rbw missing, so that Lich will not start and cannot run the
  revert again. The snapshot itself is untouched: copying its lib/, the core
  scripts in its scripts/ and its lich.rbw back by hand, or running the
  revert from another session of this installation that is still running,
  restores it.
=end

require 'tmpdir'

module Lich
  module Util
    module Update
      class SnapshotManager
        CORE_SCRIPTS = %w[
          alias.lic autostart.lic dependency.lic ewaggle.lic foreach.lic
          go2.lic infomon.lic jinx.lic lnet.lic log.lic logxml.lic
          map.lic repository.lic vars.lic version.lic
        ].freeze

        # Prefix of a published, restorable snapshot. #revert only ever
        # considers directories matching "#{SNAPSHOT_PREFIX}*".
        SNAPSHOT_PREFIX = 'L5-snapshot-'

        # Prefix of a snapshot still being copied. Deliberately does not
        # start with SNAPSHOT_PREFIX, so a snapshot that is interrupted part
        # way through is never picked by #revert.
        STAGING_PREFIX = 'L5-staging-'

        # Prefix of the hidden working directories #revert creates beside the
        # live lib/, scripts/ and lich.rbw while it restores them.
        REVERT_TEMP_PREFIX = '.lich5-revert-'

        # Lock file in BACKUP_DIR that #revert holds for its whole run, so two
        # reverts on one installation never swap files at the same time.
        REVERT_LOCK_NAME = '.lich5-revert.lock'

        # How many same-second name collisions #snapshot tolerates before
        # giving up on publishing.
        MAX_PUBLISH_ATTEMPTS = 100

        # Creates a fresh timestamped directory under BACKUP_DIR for a
        # data-only backup (e.g. effect-list.xml with no preceding full
        # update). Deliberately uses a different prefix than SNAPSHOT_PREFIX
        # so #revert's "L5-snapshot-*" glob can never mistake a directory
        # containing only backed-up data files -- no lib/, lich.rbw, or
        # scripts/ -- for a real, restorable ecosystem snapshot.
        #
        # Update.update_core_data_and_scripts is a public entry point with no
        # guard of its own against concurrent callers (e.g. multiboxed Lich
        # processes autostarting within the same second after an update), so
        # this uses Dir.mktmpdir rather than a bare mkdir_p on a
        # second-resolution timestamp -- two calls in the same second must
        # not resolve to the same directory and silently clobber each other's
        # backup.
        #
        # @return [String] path to the newly created directory
        def new_data_backup_dir
          Dir.mktmpdir("L5-databackup-#{Time.now.strftime('%Y-%m-%d-%H-%M-%S')}-", BACKUP_DIR)
        end

        # Creates timestamped snapshot of lib/, lich.rbw, and core scripts.
        #
        # The copies go into a staging directory under BACKUP_DIR whose name
        # #revert ignores. Only once every copy has succeeded is it renamed
        # to L5-snapshot-<DATE-TIME>. If a copy fails, the staging directory
        # is removed and the error is re-raised, so the caller's update
        # aborts before changing anything. A process killed mid-copy leaves
        # only an L5-staging-* directory, which #revert never restores from.
        #
        # @return [String] path to the published snapshot directory
        # @raise [SystemCallError] if any copy fails; no snapshot is published
        def snapshot
          respond
          respond 'Creating a snapshot of current Lich core files ONLY.'
          respond
          respond 'You may also wish to copy your entire Lich5 folder to'
          respond 'another location for additional safety, after any'
          respond 'additional requested updates are completed.'

          FileUtils.mkdir_p(BACKUP_DIR)
          staging_dir = Dir.mktmpdir(STAGING_PREFIX, BACKUP_DIR)
          begin
            # Dir.mktmpdir creates 0700; a published snapshot keeps the
            # permissions a plain mkdir would have given it.
            File.chmod(0o777 & ~File.umask, staging_dir)
            copy_core_files(staging_dir)
            snapshot_subdir = publish_snapshot(staging_dir)
          rescue StandardError => e
            FileUtils.rm_rf(staging_dir)
            respond
            respond "Snapshot failed (#{e.class}: #{e.message})."
            respond 'No snapshot was saved and nothing was changed.'
            raise
          end

          respond
          respond 'Current Lich ecosystem files (only) backed up to:'
          respond "    #{snapshot_subdir}"

          snapshot_subdir
        end

        # Restores most recent snapshot from BACKUP_DIR.
        #
        # Refuses, without changing anything, when the newest L5-snapshot-*
        # directory is incomplete (no lib/version.rb declaring LICH_VERSION,
        # no lich.rbw, or no scripts/). It names every incomplete directory
        # newer than the next complete snapshot, and that snapshot if there
        # is one, but never falls back to it on its own: an older snapshot
        # may be several versions back.
        #
        # Holds an exclusive lock for the whole run. If another revert on the
        # same installation holds it, says so and changes nothing.
        #
        # @return [void]
        def revert
          respond
          respond 'Reverting Lich5 to previously installed version.'

          with_revert_lock { revert_newest_snapshot }
        end

        private

        # Runs the block while holding an exclusive, non-blocking flock on
        # BACKUP_DIR/REVERT_LOCK_NAME. Two reverts that swap files in the
        # same lib/ at once rename each other's entries and can lose files,
        # so a revert that finds the lock taken returns without yielding.
        # The lock is released when the file is closed, including when the
        # holder is killed, so it can never go stale. If the lock file cannot
        # be created or the filesystem does not support flock (some network
        # shares), the block runs unlocked rather than blocking every revert.
        #
        # @return [void]
        def with_revert_lock
          lock = begin
            FileUtils.mkdir_p(BACKUP_DIR)
            File.open(File.join(BACKUP_DIR, REVERT_LOCK_NAME), File::RDWR | File::CREAT, 0o644)
          rescue SystemCallError => e
            respond "Could not create the revert lock file (#{e.class}: #{e.message}); continuing without it."
            return yield
          end

          begin
            locked = begin
              lock.flock(File::LOCK_EX | File::LOCK_NB)
            rescue NotImplementedError, SystemCallError => e
              respond "Could not lock #{lock.path} (#{e.class}: #{e.message}); continuing without the lock."
              :unsupported
            end
            unless locked
              respond
              respond 'Another revert is already running on this installation. Nothing was changed.'
              return
            end

            yield
          ensure
            lock.close
          end
        end

        # The body of #revert, run while holding the revert lock.
        #
        # @return [void]
        def revert_newest_snapshot
          candidates = snapshot_dirs
          restore_snapshot = candidates.first
          if restore_snapshot.nil?
            respond "No prior Lich5 version found. Seek assistance."
            return
          end

          unless snapshot_problems(restore_snapshot).empty?
            refuse_incomplete(candidates)
            return
          end

          targetversion = snapshot_version(restore_snapshot)
          respond "Restoring Lich5 version #{targetversion} from:"
          respond "    #{restore_snapshot}"

          restore_from(restore_snapshot)

          Lich::Util::Update.clear_branch_tracking

          respond
          respond "Lich5 has been reverted to Lich5 version #{targetversion}"
          respond "You should exit the game, then log back in.  This will start the game"
          respond "with your previous version of Lich.  Enjoy!"
        end

        # @return [String] file name of the running Lich launcher (lich.rbw)
        def lich_file_name
          File.basename($PROGRAM_NAME)
        end

        # Copies lich.rbw, the contents of LIB_DIR, and the core scripts that
        # exist into +dest+. LIB_DIR's contents always land in dest/lib, even
        # when LIB_DIR is not named "lib" (--lib-dir), because that is where
        # #revert reads them from. Working directories a failed #revert kept
        # in LIB_DIR are not part of the install and are left out. A child of
        # LIB_DIR that is a symlink is copied as a link, not followed, so a
        # dangling link cannot abort the snapshot and a linked directory is
        # not copied as a full tree.
        #
        # @param dest [String] directory to fill
        # @return [void]
        def copy_core_files(dest)
          FileUtils.cp(File.join(LICH_DIR, lich_file_name), File.join(dest, lich_file_name))

          dest_lib = File.join(dest, 'lib')
          FileUtils.mkdir_p(dest_lib)
          Dir.children(LIB_DIR).each do |name|
            FileUtils.cp_r(File.join(LIB_DIR, name), dest_lib, dereference_root: false) unless revert_temp_name?(name)
          end

          FileUtils.mkdir_p(File.join(dest, 'scripts'))
          CORE_SCRIPTS.each do |file|
            source = File.join(SCRIPT_DIR, file)
            FileUtils.cp(source, File.join(dest, 'scripts', file)) if File.exist?(source)
          end
        end

        # Renames a fully copied staging directory to its final snapshot
        # name. If another snapshot already took this second's name, a
        # zero-padded counter is appended, which still sorts after the bare
        # name so #revert picks the newer one. Windows reports a rename onto
        # an existing directory as EACCES, so that counts as a collision too
        # when the target now exists; any other EACCES is re-raised.
        #
        # @param staging_dir [String] completed staging directory
        # @return [String] path of the published snapshot
        def publish_snapshot(staging_dir)
          base = File.join(BACKUP_DIR, "#{SNAPSHOT_PREFIX}#{Time.now.strftime('%Y-%m-%d-%H-%M-%S')}")
          MAX_PUBLISH_ATTEMPTS.times do |attempt|
            target = attempt.zero? ? base : format('%s-%02d', base, attempt)
            next if File.exist?(target)

            begin
              File.rename(staging_dir, target)
              return target
            rescue Errno::EEXIST, Errno::ENOTEMPTY, Errno::EACCES => e
              raise if e.is_a?(Errno::EACCES) && !File.exist?(target)

              next # another process published the same name in between
            end
          end
          raise Errno::EEXIST, "#{base} (and #{MAX_PUBLISH_ATTEMPTS - 1} numbered variants)"
        end

        # @return [Array<String>] snapshot directories, newest first
        def snapshot_dirs
          Dir.glob(File.join(BACKUP_DIR, "#{SNAPSHOT_PREFIX}*")).select { |path| File.directory?(path) }.sort.reverse
        end

        # Lists what a snapshot directory lacks for #revert to restore it.
        #
        # @param dir [String] snapshot directory
        # @return [Array<String>] human-readable problems; empty if complete
        def snapshot_problems(dir)
          problems = []
          if !File.file?(File.join(dir, 'lib', 'version.rb'))
            problems << 'lib/version.rb is missing'
            legacy = legacy_lib_dir_name(dir)
            problems << legacy_rename_hint(dir, legacy) if legacy
          elsif snapshot_version(dir).nil?
            problems << 'lib/version.rb does not declare LICH_VERSION'
          end
          problems << "#{lich_file_name} is missing" unless File.file?(File.join(dir, lich_file_name))
          problems << 'scripts/ is missing' unless File.directory?(File.join(dir, 'scripts'))
          problems
        end

        # Older Lich versions copied LIB_DIR into a snapshot under its own
        # name, so with --lib-dir pointing at a directory not named "lib" the
        # files landed in <snapshot>/<name>/ and lib/ stayed empty. Only a
        # snapshot that renaming would make complete counts: lib/ must be
        # absent or empty, and lich.rbw and scripts/ must be present (older
        # versions copied them before and after LIB_DIR, so a missing one
        # means that snapshot was interrupted, possibly mid-copy).
        #
        # @param dir [String] snapshot directory
        # @return [String, nil] that directory name if +dir+ has this layout
        def legacy_lib_dir_name(dir)
          name = File.basename(LIB_DIR)
          return nil if name == 'lib'
          return nil unless File.file?(File.join(dir, name, 'version.rb'))
          return nil unless File.file?(File.join(dir, lich_file_name)) && File.directory?(File.join(dir, 'scripts'))

          lib = File.join(dir, 'lib')
          if File.symlink?(lib) || File.exist?(lib)
            return nil unless File.directory?(lib) && !File.symlink?(lib) && Dir.empty?(lib)
          end
          name
        end

        # Tells the user how to turn a legacy --lib-dir snapshot (see
        # #legacy_lib_dir_name) into one #revert accepts. The empty lib/ that
        # older versions created has to go first: renaming onto it fails or
        # nests the directory inside it, depending on the tool.
        #
        # @param dir [String] snapshot directory
        # @param legacy [String] name returned by #legacy_lib_dir_name
        # @return [String] the hint
        def legacy_rename_hint(dir, legacy)
          steps = if File.directory?(File.join(dir, 'lib'))
                    "delete the empty lib/ in it, then rename #{legacy}/ to lib/"
                  else
                    "rename #{legacy}/ to lib/"
                  end
          "an older Lich saved this --lib-dir snapshot's files in #{legacy}/; to use it, #{steps}"
        end

        # @param dir [String] snapshot directory
        # @return [String, nil] LICH_VERSION declared by dir/lib/version.rb
        def snapshot_version(dir)
          content = File.binread(File.join(dir, 'lib', 'version.rb'))
          content =~ /LICH_VERSION\s*=\s*['"]([^'"]+)['"]/ ? $1 : nil
        rescue SystemCallError
          nil
        end

        # Explains why #revert will not restore the newest snapshot and what
        # to do next. Every incomplete snapshot newer than the next complete
        # one is listed, because the revert keeps refusing until all of them
        # are out of the way (older Lich versions left one per failed
        # snapshot attempt).
        #
        # @param candidates [Array<String>] all snapshots, newest first; the
        #   first is incomplete
        # @return [void]
        def refuse_incomplete(candidates)
          incomplete = []
          fallback = nil
          candidates.each do |path|
            problems = snapshot_problems(path)
            if problems.empty?
              fallback = path
              break
            end
            incomplete << [path, problems]
          end

          respond
          if incomplete.size == 1
            respond 'The newest snapshot is incomplete, so nothing was changed:'
          else
            respond "The #{incomplete.size} newest snapshots are incomplete, so nothing was changed:"
          end
          incomplete.each do |path, problems|
            respond "    #{path}"
            problems.each { |problem| respond "  - #{problem}" }
          end
          interrupted = incomplete.count { |path, _| legacy_lib_dir_name(path).nil? }
          if interrupted == incomplete.size && interrupted == 1
            respond 'It was most likely left by a snapshot that was interrupted.'
          elsif interrupted == incomplete.size
            respond 'They were most likely left by snapshots that were interrupted.'
          elsif interrupted.positive?
            respond 'The ones without a rename hint were most likely left by snapshots that were interrupted.'
          end

          if fallback
            respond
            respond "The next complete snapshot is Lich5 version #{snapshot_version(fallback)}:"
            respond "    #{fallback}"
            if incomplete.size == 1
              respond 'To revert to it, move or delete the incomplete directory above,'
            else
              respond "To revert to it, move or delete all #{incomplete.size} incomplete directories above,"
            end
            respond 'then run the revert again.'
          else
            respond 'No complete snapshot was found. Seek assistance.'
          end
        end

        # Replaces the live lib/ contents, the snapshot's scripts and
        # lich.rbw with the copies in +snapshot_dir+.
        #
        # Phase 1 copies everything from the snapshot into hidden working
        # directories next to the targets; a failure there removes them and
        # leaves the install untouched. Phase 2 swaps the copies in with
        # renames only, recording each one, and undoes them in reverse if any
        # rename fails. Core scripts that the snapshot does not contain are
        # left in place rather than deleted, and so are working directories
        # an earlier failed revert kept in LIB_DIR for recovery.
        #
        # @param snapshot_dir [String] a snapshot that passed #snapshot_problems
        # @return [void]
        # @raise [SystemCallError] if the restore fails; the install is left
        #   as it was (or, if even the undo fails, the working directories are
        #   kept and named so the files can be recovered by hand)
        def restore_from(snapshot_dir)
          temp_dirs = []
          begin
            new_lib = revert_temp_dir(LIB_DIR, 'new', temp_dirs)
            FileUtils.cp_r(File.join(snapshot_dir, 'lib', '.'), new_lib)
            new_scripts = revert_temp_dir(SCRIPT_DIR, 'new', temp_dirs)
            FileUtils.cp_r(File.join(snapshot_dir, 'scripts', '.'), new_scripts)
            new_lich_dir = revert_temp_dir(LICH_DIR, 'new', temp_dirs)
            new_lich = File.join(new_lich_dir, lich_file_name)
            live_lich = File.join(LICH_DIR, lich_file_name)
            FileUtils.cp(File.join(snapshot_dir, lich_file_name), new_lich)
            File.chmod(File.stat(live_lich).mode, new_lich) if File.exist?(live_lich)

            old_lib = revert_temp_dir(LIB_DIR, 'old', temp_dirs)
            old_scripts = revert_temp_dir(SCRIPT_DIR, 'old', temp_dirs)
            old_lich_dir = revert_temp_dir(LICH_DIR, 'old', temp_dirs)
          rescue StandardError => e
            remove_revert_temp_dirs(temp_dirs)
            respond
            respond "Revert failed while copying the snapshot (#{e.class}: #{e.message})."
            respond 'Nothing was changed.'
            raise
          end

          journal = []
          begin
            # This run's working directories, and any a previous failed
            # revert kept for recovery by hand, stay where they are.
            Dir.children(LIB_DIR).each do |name|
              move_entry(File.join(LIB_DIR, name), File.join(old_lib, name), journal) unless revert_temp_name?(name)
            end
            Dir.children(new_lib).each do |name|
              move_entry(File.join(new_lib, name), File.join(LIB_DIR, name), journal) unless revert_temp_name?(name)
            end

            Dir.children(new_scripts).each do |name|
              live = File.join(SCRIPT_DIR, name)
              move_entry(live, File.join(old_scripts, name), journal) if File.exist?(live) || File.symlink?(live)
              move_entry(File.join(new_scripts, name), live, journal)
            end

            move_entry(live_lich, File.join(old_lich_dir, lich_file_name), journal) if File.exist?(live_lich)
            move_entry(new_lich, live_lich, journal)
          rescue StandardError => e
            undone = undo_moves(journal)
            respond
            respond "Revert failed while swapping files in (#{e.class}: #{e.message})."
            if undone
              remove_revert_temp_dirs(temp_dirs)
              respond 'Every change was undone; your installation is as it was.'
            else
              respond 'Some changes could not be undone. Your previous files are kept in:'
              temp_dirs.each { |dir| respond "    #{dir}" }
              respond 'Seek assistance.'
            end
            raise
          end

          remove_revert_temp_dirs(temp_dirs)
        end

        # Creates a hidden working directory for #restore_from inside
        # +parent+ (so renames out of it stay on one filesystem) and records
        # it in +temp_dirs+.
        #
        # @return [String] the new directory
        def revert_temp_dir(parent, role, temp_dirs)
          dir = Dir.mktmpdir("#{REVERT_TEMP_PREFIX}#{role}-", parent)
          temp_dirs << dir
          dir
        end

        # @param name [String] a directory entry name
        # @return [Boolean] true if +name+ is a #restore_from working directory
        def revert_temp_name?(name)
          name.start_with?(REVERT_TEMP_PREFIX)
        end

        # Renames +from+ to +to+ and records the move so it can be undone.
        def move_entry(from, to, journal)
          File.rename(from, to)
          journal << [from, to]
        end

        # Reverses recorded moves, newest first.
        #
        # @return [Boolean] true if every move was undone
        def undo_moves(journal)
          journal.reverse.map do |from, to|
            File.rename(to, from)
            true
          rescue SystemCallError
            false
          end.all?
        end

        # Removes #restore_from's working directories. Failing to remove one
        # (e.g. a Windows file lock) does not fail an otherwise finished
        # revert; it is reported instead.
        def remove_revert_temp_dirs(temp_dirs)
          temp_dirs.each do |dir|
            FileUtils.rm_rf(dir)
            respond "Could not remove the temporary directory #{dir}; it is safe to delete." if File.exist?(dir)
          end
        end
      end
    end
  end
end
