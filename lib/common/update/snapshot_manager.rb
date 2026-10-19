# frozen_string_literal: true

=begin
  Snapshot and rollback functionality for Lich core files.

  Creates timestamped backups of lib/, lich.rbw, and core scripts before
  updates. Supports rollback to most recent snapshot. #snapshot, #revert
  and #restore_from describe how each leaves the installation as it was when
  it fails.

  A revert whose thread is killed (Lich shutting down) undoes the swap like
  a failed one. A revert whose process is killed during the swap cannot
  undo it. It can leave lib/, the core scripts or lich.rbw missing, so that
  Lich will not start and cannot run the revert again. The snapshot itself is untouched: copying its lib/, the core
  scripts in its scripts/ and its lich.rbw back by hand, or running the
  revert from another session of this installation that is still running,
  restores it. On Windows each rename of the swap that Windows refuses
  keeps this window open for up to about 3 seconds while it is retried;
  Lich says so while it waits.
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

        # Lock file in BACKUP_DIR. #revert holds it exclusively for its whole
        # run and #snapshot holds it shared while it copies, so two reverts
        # never swap files at the same time and a snapshot never copies a
        # lib/ that a revert has half swapped. Snapshots do not exclude each
        # other.
        REVERT_LOCK_NAME = '.lich5-revert.lock'

        # Empty file #snapshot writes into the staging directory once every
        # copy has succeeded, just before publishing it. A snapshot without
        # it was taken by an older Lich, which copied straight into
        # L5-snapshot-<DATE-TIME> and could leave it cut short (see
        # #legacy_cut_off).
        STAGED_MARKER_NAME = '.lich5-staged'

        # Raised by #snapshot when a revert on the same installation is
        # running, so the update that asked for the snapshot stops before
        # changing anything.
        class RevertRunningError < StandardError; end

        # How many same-second name collisions #snapshot tolerates before
        # giving up on publishing.
        MAX_PUBLISH_ATTEMPTS = 100

        # Seconds to wait before each retry of a rename Windows refused with
        # a transient error (see #rename_with_retry); about 3s in all.
        RENAME_RETRY_DELAYS = [0.1, 0.2, 0.4, 0.8, 1.6].freeze

        # Errors Windows reports when a rename is refused because another
        # process has the entry, or a file inside it, open.
        TRANSIENT_RENAME_ERRORS = [Errno::EACCES, Errno::EPERM, Errno::EBUSY].freeze

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
        # #revert ignores. Only once every copy has succeeded is
        # STAGED_MARKER_NAME written into it and it renamed to
        # L5-snapshot-<DATE-TIME>. If a copy fails, the staging directory
        # is removed and the error is re-raised, so the caller's update
        # aborts before changing anything. The staging directory is also
        # removed when the thread is killed (Lich kills the client thread
        # running ;lich5-update when it shuts down), since that clean-up is
        # in an ensure. A process killed mid-copy leaves only an
        # L5-staging-* directory, which #revert never restores from.
        #
        # Holds the revert lock shared while copying and publishing. If a
        # revert on the same installation holds it, says so and raises
        # without copying anything, as copying a lib/ in the middle of a
        # revert's swap could publish a mix of two versions that looks
        # complete. Other snapshots do not block it.
        #
        # @return [String] path to the published snapshot directory
        # @raise [SystemCallError] if any copy fails; no snapshot is published
        # @raise [RevertRunningError] if a revert is running; nothing is copied
        def snapshot
          respond
          respond 'Creating a snapshot of current Lich core files ONLY.'
          respond
          respond 'You may also wish to copy your entire Lich5 folder to'
          respond 'another location for additional safety, after any'
          respond 'additional requested updates are completed.'

          FileUtils.mkdir_p(BACKUP_DIR)
          snapshot_subdir = nil
          locked = with_revert_lock(File::LOCK_SH) do
            # Interrupts are deferred except while copying and publishing, so
            # a kill can never land between creating the staging directory
            # and the ensure that removes it.
            Thread.handle_interrupt(Object => :never) do
              staging_dir = Dir.mktmpdir(STAGING_PREFIX, BACKUP_DIR)
              begin
                Thread.handle_interrupt(Object => :immediate) do
                  # Dir.mktmpdir creates 0700; a published snapshot keeps the
                  # permissions a plain mkdir would have given it.
                  File.chmod(0o777 & ~File.umask, staging_dir)
                  copy_core_files(staging_dir)
                  File.write(File.join(staging_dir, STAGED_MARKER_NAME), '')
                  snapshot_subdir = publish_snapshot(staging_dir)
                end
              rescue StandardError => e
                respond
                respond "Snapshot failed (#{e.class}: #{e.message})."
                respond 'No snapshot was saved and nothing was changed.'
                raise
              ensure
                # Once published, staging_dir no longer exists, so this only
                # ever removes this call's own unpublished copy.
                FileUtils.rm_rf(staging_dir) unless snapshot_subdir
              end
            end
            true
          end
          unless locked
            respond
            respond 'A revert is running on this installation, so no snapshot was saved and nothing was changed.'
            respond 'Run the update again once the revert has finished.'
            raise RevertRunningError, 'a revert is running on this installation'
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
        # no lich.rbw, no scripts/, or, in one an older Lich took, core
        # scripts that may have been cut off part way). It names every incomplete directory
        # newer than the next complete snapshot, and that snapshot if there
        # is one, but never falls back to it on its own: an older snapshot
        # may be several versions back.
        #
        # Holds the revert lock exclusively for the whole run. If another
        # revert, or a snapshot, on the same installation holds it, says so
        # and changes nothing.
        #
        # @return [void]
        def revert
          respond
          respond 'Reverting Lich5 to previously installed version.'

          ran = with_revert_lock(File::LOCK_EX) do
            revert_newest_snapshot
            true
          end
          return if ran

          respond
          respond 'Another revert or a snapshot is running on this installation. Nothing was changed.'
        end

        private

        # Runs the block while holding a non-blocking flock of +mode+
        # (File::LOCK_EX for #revert, File::LOCK_SH for #snapshot) on
        # BACKUP_DIR/REVERT_LOCK_NAME. Two reverts that swap files in the
        # same lib/ at once rename each other's entries and can lose files,
        # and a snapshot copying lib/ during a swap copies a mix of both
        # versions, so when the lock is taken this returns false without
        # yielding. The lock is released when the file is closed, including
        # when the holder is killed, so it can never go stale. If the lock
        # file cannot be created or the filesystem does not support flock
        # (some network shares), the block runs unlocked rather than blocking
        # every revert and update.
        #
        # @param mode [Integer] File::LOCK_EX or File::LOCK_SH
        # @return [Object, false] the block's value, or false if the lock is
        #   held by someone else
        def with_revert_lock(mode)
          lock = begin
            FileUtils.mkdir_p(BACKUP_DIR)
            File.open(File.join(BACKUP_DIR, REVERT_LOCK_NAME), File::RDWR | File::CREAT, 0o644)
          rescue SystemCallError => e
            respond "Could not create the revert lock file (#{e.class}: #{e.message}); continuing without it."
            return yield
          end

          begin
            locked = begin
              lock.flock(mode | File::LOCK_NB)
            rescue NotImplementedError, SystemCallError => e
              respond "Could not lock #{lock.path} (#{e.class}: #{e.message}); continuing without the lock."
              :unsupported
            end
            return false unless locked

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

          kept = core_scripts_not_in(restore_snapshot)
          restore_from(restore_snapshot)

          Lich::Util::Update.clear_branch_tracking

          respond
          respond "Lich5 has been reverted to Lich5 version #{targetversion}"
          unless kept.empty?
            respond 'These core scripts are not in the snapshot and were kept at the current version:'
            respond "    #{kept.join(' ')}"
          end
          respond "You should exit the game, then log back in.  This will start the game"
          respond "with your previous version of Lich.  Enjoy!"
        end

        # Core scripts installed now that +snapshot_dir+ has no copy of.
        # #restore_from leaves them as they are. A snapshot lacks one when
        # the script was not installed when it was taken (a core script
        # added since, or one installed later). An older Lich interrupted
        # while copying the core scripts also left some out, but #revert
        # refuses such a snapshot (see #legacy_cut_off).
        #
        # @param snapshot_dir [String] snapshot directory
        # @return [Array<String>] file names, in CORE_SCRIPTS order
        def core_scripts_not_in(snapshot_dir)
          CORE_SCRIPTS.select do |file|
            entry?(File.join(SCRIPT_DIR, file)) && !entry?(File.join(snapshot_dir, 'scripts', file))
          end
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
        # when the target now exists; any other EACCES is re-raised once
        # #rename_with_retry has given up on it.
        #
        # @param staging_dir [String] completed staging directory
        # @return [String] path of the published snapshot
        def publish_snapshot(staging_dir)
          base = File.join(BACKUP_DIR, "#{SNAPSHOT_PREFIX}#{Time.now.strftime('%Y-%m-%d-%H-%M-%S')}")
          MAX_PUBLISH_ATTEMPTS.times do |attempt|
            target = attempt.zero? ? base : format('%s-%02d', base, attempt)
            next if File.exist?(target)

            begin
              rename_with_retry(staging_dir, target)
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
          problems = interruption_problems(dir)
          cut_off = legacy_cut_off(dir)
          return problems unless cut_off

          problems << cut_off_problem(*cut_off)
          problems << cut_off_hint if problems.size == 1
          problems
        end

        # Every problem #snapshot_problems lists except a missing tail of
        # core scripts (see #legacy_cut_off), which may also mean those
        # scripts were simply not installed when the snapshot was taken.
        #
        # @param dir [String] snapshot directory
        # @return [Array<String>] human-readable problems; empty if none
        def interruption_problems(dir)
          problems = []
          if !File.file?(File.join(dir, 'lib', 'version.rb'))
            problems << 'lib/version.rb is missing'
            legacy = legacy_lib_dir_name(dir)
            problems << legacy_rename_hint(dir, legacy) if legacy
          elsif snapshot_version(dir).nil?
            problems << 'lib/version.rb does not declare LICH_VERSION'
          end
          problems << "#{lich_file_name} is missing" unless File.file?(File.join(dir, lich_file_name))
          if File.directory?(File.join(dir, 'scripts'))
            problems.concat(legacy_empty_scripts(dir).map { |file| "scripts/#{file} is empty" })
          else
            problems << 'scripts/ is missing'
          end
          problems
        end

        # True when the only thing keeping #revert from restoring +dir+ is a
        # missing tail of core scripts, which #snapshot_problems words as
        # either an interruption or scripts not installed back then.
        #
        # @param dir [String] snapshot directory
        # @return [Boolean]
        def only_missing_tail?(dir)
          interruption_problems(dir).empty? && !legacy_cut_off(dir).nil?
        end

        # Older Lich versions copied straight into L5-snapshot-<DATE-TIME>,
        # the core scripts last and one at a time in CORE_SCRIPTS order, so
        # one interrupted while copying them left only the first few in
        # scripts/, the last of them possibly cut short, and passes every
        # other check. A snapshot #snapshot published (it has
        # STAGED_MARKER_NAME) was copied in full before publishing, so it is
        # never checked this way.
        #
        # An empty copy is a sure sign (see #legacy_empty_scripts). Core
        # scripts installed now that come after every core script it has
        # are not: either their copy never started, or they were not
        # installed when it was taken, and nothing on disk tells the two
        # apart. #revert refuses it either way, since the last script it has
        # may be cut short. One missing from between two it has was simply
        # not installed then, and is kept by #restore_from.
        #
        # Cannot tell a copy cut short part way through its bytes when it is
        # the last core script installed (version.lic, normally).
        #
        # @param dir [String] snapshot directory
        # @return [Array(String, Array<String>), nil] the last core script it
        #   has (nil if none) and the installed ones after it, or nil if no
        #   installed core script comes after every one it has
        def legacy_cut_off(dir)
          return nil if File.exist?(File.join(dir, STAGED_MARKER_NAME))
          return nil unless File.directory?(File.join(dir, 'scripts'))

          last = CORE_SCRIPTS.reverse.find { |file| entry?(File.join(dir, 'scripts', file)) }
          after = last ? CORE_SCRIPTS.drop(CORE_SCRIPTS.index(last) + 1) : CORE_SCRIPTS
          never_copied = after.select { |file| entry?(File.join(SCRIPT_DIR, file)) }
          never_copied.empty? ? nil : [last, never_copied]
        end

        # Core scripts an older Lich left empty in +dir+ (see
        # #legacy_cut_off): copying them was interrupted before any byte
        # was written.
        #
        # @param dir [String] snapshot directory
        # @return [Array<String>] file names, in CORE_SCRIPTS order
        def legacy_empty_scripts(dir)
          return [] if File.exist?(File.join(dir, STAGED_MARKER_NAME))
          return [] unless File.directory?(File.join(dir, 'scripts'))

          CORE_SCRIPTS.select do |file|
            path = File.join(dir, 'scripts', file)
            entry?(path) && File.zero?(path)
          end
        end

        # @param last [String, nil] last core script the snapshot has
        # @param never_copied [Array<String>] installed core scripts after it
        # @return [String] the problem, naming both possible causes
        def cut_off_problem(last, never_copied)
          names = never_copied.join(' ')
          not_installed = 'or they were not installed when it was taken'
          if last
            "scripts/ ends at #{last} and has none of the installed core scripts after it (#{names}): " \
              "either copying them stopped early and #{last} may be cut short, #{not_installed}"
          else
            "scripts/ has none of the installed core scripts (#{names}): " \
              "either copying them stopped early, #{not_installed}"
          end
        end

        # Tells the user how to use a snapshot whose only problem is a
        # missing tail of core scripts, if they know those were not
        # installed then. A copy of the live script restores it as it is,
        # which is what #restore_from does for a core script a snapshot
        # lacks.
        #
        # @return [String] the hint
        def cut_off_hint
          'if the scripts named above were not installed when it was taken, it is complete; ' \
            "to use it, copy them from #{SCRIPT_DIR} into its scripts/ (a revert would leave them as they are anyway)"
        end

        # @param path [String]
        # @return [Boolean] true if +path+ exists or is a (possibly dangling) symlink
        def entry?(path)
          File.exist?(path) || File.symlink?(path)
        end

        # Older Lich versions copied LIB_DIR into a snapshot under its own
        # name, so with --lib-dir pointing at a directory not named "lib" the
        # files landed in <snapshot>/<name>/ and lib/ stayed empty. Only a
        # snapshot that renaming would make complete counts: lib/ must be
        # absent or empty, and lich.rbw and scripts/ must be present (older
        # versions copied them before and after LIB_DIR, so a missing one
        # means that snapshot was interrupted, possibly mid-copy), and so
        # must every core script it would restore (see #legacy_cut_off;
        # older versions copied those last).
        #
        # @param dir [String] snapshot directory
        # @return [String, nil] that directory name if +dir+ has this layout
        def legacy_lib_dir_name(dir)
          name = File.basename(LIB_DIR)
          return nil if name == 'lib'
          return nil unless File.file?(File.join(dir, name, 'version.rb'))
          return nil unless File.file?(File.join(dir, lich_file_name)) && File.directory?(File.join(dir, 'scripts'))
          return nil unless legacy_empty_scripts(dir).empty? && legacy_cut_off(dir).nil?

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
          # A snapshot with a hint is not blamed on an interruption: it may
          # only need renaming, or only lack scripts not installed back then.
          interrupted = incomplete.count { |path, _| legacy_lib_dir_name(path).nil? && !only_missing_tail?(path) }
          if interrupted == incomplete.size && interrupted == 1
            respond 'It was most likely left by a snapshot that was interrupted.'
          elsif interrupted == incomplete.size
            respond 'They were most likely left by snapshots that were interrupted.'
          elsif interrupted.positive?
            respond 'The ones without a hint were most likely left by snapshots that were interrupted.'
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
        # directories next to the targets (for a symlinked lich.rbw, next to
        # the file it points to; see #launcher_path); a failure there
        # removes them and leaves the install untouched. Phase 2 swaps the
        # copies in with renames only, recording each one, and undoes them
        # in reverse if any rename fails. Every entry of LIB_DIR, hidden ones
        # included, is replaced, so lib/ ends up exactly the snapshot's lib/.
        # Core scripts that the snapshot does not contain are left in place
        # rather than deleted, and so are working directories an earlier
        # failed revert kept in LIB_DIR for recovery.
        #
        # The same clean-up runs when the thread is killed (Lich kills the
        # client thread running ;lich5-update when it shuts down) or gets
        # any other async exception: Thread#kill skips rescue clauses but
        # runs ensure blocks, so the clean-up lives in an ensure. Each rename
        # and its journal entry, and the whole clean-up, run with interrupts
        # deferred, so the journal never misses a rename and a second
        # interruption (Ruby re-signals threads still running at exit)
        # cannot stop an undo half way. Only killing the process can.
        #
        # @param snapshot_dir [String] a snapshot that passed #snapshot_problems
        # @return [void]
        # @raise [SystemCallError] if the restore fails; the install is left
        #   as it was (or, if even the undo fails, the working directories are
        #   kept and named so the files can be recovered by hand; the live
        #   lib/, core scripts and lich.rbw may then be part old, part restored)
        def restore_from(snapshot_dir)
          temp_dirs = []
          journal = []
          stage = :copying
          failure = nil
          begin
            new_lib = revert_temp_dir(LIB_DIR, 'new', temp_dirs)
            FileUtils.cp_r(File.join(snapshot_dir, 'lib', '.'), new_lib)
            new_scripts = revert_temp_dir(SCRIPT_DIR, 'new', temp_dirs)
            FileUtils.cp_r(File.join(snapshot_dir, 'scripts', '.'), new_scripts)
            live_lich = launcher_path
            new_lich_dir = revert_temp_dir(File.dirname(live_lich), 'new', temp_dirs)
            new_lich = File.join(new_lich_dir, File.basename(live_lich))
            FileUtils.cp(File.join(snapshot_dir, lich_file_name), new_lich)
            File.chmod(File.stat(live_lich).mode, new_lich) if File.exist?(live_lich)

            old_lib = revert_temp_dir(LIB_DIR, 'old', temp_dirs)
            old_scripts = revert_temp_dir(SCRIPT_DIR, 'old', temp_dirs)
            old_lich_dir = revert_temp_dir(File.dirname(live_lich), 'old', temp_dirs)

            stage = :swapping
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

            move_entry(live_lich, File.join(old_lich_dir, File.basename(live_lich)), journal) if File.exist?(live_lich)
            move_entry(new_lich, live_lich, journal)
            stage = :done
          rescue StandardError => e
            failure = e
            raise
          ensure
            Thread.handle_interrupt(Object => :never) { finish_restore(stage, temp_dirs, journal, failure) }
          end
        end

        # Clean-up for #restore_from, whether it finished, failed or was
        # interrupted (+failure+ is nil then). Removes the working
        # directories, after undoing the swap if it did not finish, and
        # reports what happened unless it finished.
        #
        # @param stage [Symbol] :copying, :swapping or :done
        # @param temp_dirs [Array<String>] working directories created so far
        # @param journal [Array<Array(String, String)>] renames done so far
        # @param failure [StandardError, nil] the error that stopped it
        # @return [void]
        def finish_restore(stage, temp_dirs, journal, failure)
          case stage
          when :done
            remove_revert_temp_dirs(temp_dirs)
          when :copying
            remove_revert_temp_dirs(temp_dirs)
            respond
            if failure
              respond "Revert failed while copying the snapshot (#{failure.class}: #{failure.message})."
            else
              respond 'Revert was interrupted while copying the snapshot.'
            end
            respond 'Nothing was changed.'
          when :swapping
            undone = undo_moves(journal)
            remove_revert_temp_dirs(temp_dirs) if undone
            respond
            if failure
              respond "Revert failed while swapping files in (#{failure.class}: #{failure.message})."
            else
              respond 'Revert was interrupted while swapping files in.'
            end
            if undone
              respond 'Every change was undone; your installation is as it was.'
            else
              respond 'Some changes could not be undone. Your previous files are kept in:'
              temp_dirs.each { |dir| respond "    #{dir}" }
              respond 'Seek assistance.'
            end
          end
        end

        # The file #restore_from replaces with the snapshot's launcher. When
        # LICH_DIR/lich.rbw is a symlink, that is the file it points to, as
        # an update writes the new launcher through the link, so the revert
        # restores that file and keeps the link. A dangling link is replaced
        # itself, so that Lich has a launcher to start from.
        #
        # @return [String] path of the launcher file to replace
        def launcher_path
          live_lich = File.join(LICH_DIR, lich_file_name)
          return live_lich unless File.symlink?(live_lich) && File.exist?(live_lich)

          File.realpath(live_lich)
        end

        # Creates a hidden working directory for #restore_from inside
        # +parent+ (so renames out of it stay on one filesystem) and records
        # it in +temp_dirs+.
        #
        # @return [String] the new directory
        def revert_temp_dir(parent, role, temp_dirs)
          Thread.handle_interrupt(Object => :never) do
            dir = Dir.mktmpdir("#{REVERT_TEMP_PREFIX}#{role}-", parent)
            temp_dirs << dir
            dir
          end
        end

        # @param name [String] a directory entry name
        # @return [Boolean] true if +name+ is a #restore_from working directory
        def revert_temp_name?(name)
          name.start_with?(REVERT_TEMP_PREFIX)
        end

        # Renames +from+ to +to+ and records the move so it can be undone.
        # Interrupts are deferred until both are done, so a Thread#kill
        # cannot land between the rename and its journal entry.
        def move_entry(from, to, journal)
          Thread.handle_interrupt(Object => :never) do
            rename_with_retry(from, to)
            journal << [from, to]
          end
        end

        # File.rename, retried on Windows while the refusal looks transient.
        # Windows will not rename a file or directory while another process
        # (an antivirus or search indexer reading files just written) has it,
        # or a file inside it, open without delete sharing, and reports that
        # as EACCES, EPERM or EBUSY until the other process lets go. Each retry
        # waits the next of RENAME_RETRY_DELAYS. Nothing is retried on other
        # platforms, where these errors do not clear on their own, nor when
        # +to+ exists. For #publish_snapshot that is a name collision, which
        # it handles by trying the next name. In a revert, the swap only
        # renames onto free names (it moves each live entry out first), so
        # the target can exist only for an undo after an earlier undo
        # already failed; the run's working directories are kept by then,
        # and waiting would only leave the installation half moved for
        # longer. The first retry of each rename says so, because during a
        # revert swap the waits can leave lib/ or the launcher half moved,
        # and closing Lich then stops it starting.
        #
        # @raise [SystemCallError] the last error once the retries run out
        # @return [void]
        def rename_with_retry(from, to)
          attempt = 0
          begin
            File.rename(from, to)
          rescue *TRANSIENT_RENAME_ERRORS
            raise unless Gem.win_platform? && attempt < RENAME_RETRY_DELAYS.size && !File.exist?(to)

            if attempt.zero?
              respond "Windows is refusing to rename #{from} (another program, such as an antivirus, " \
                      "probably has it open); retrying for up to #{RENAME_RETRY_DELAYS.sum.round} seconds. " \
                      'Do not close Lich meanwhile.'
            end
            sleep(RENAME_RETRY_DELAYS[attempt])
            attempt += 1
            retry
          end
        end

        # Reverses recorded moves, newest first.
        #
        # @return [Boolean] true if every move was undone
        def undo_moves(journal)
          journal.reverse.map do |from, to|
            rename_with_retry(to, from)
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
