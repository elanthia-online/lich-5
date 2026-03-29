# frozen_string_literal: true

=begin
  Snapshot and rollback functionality for Lich core files.

  Creates timestamped backups of lib/, lich.rbw, and core scripts before
  updates. Supports rollback to most recent snapshot.
=end

module Lich
  module Util
    module Update
      class SnapshotManager
        CORE_SCRIPTS = %w[
          alias.lic autostart.lic dependency.lic ewaggle.lic foreach.lic
          go2.lic infomon.lic jinx.lic lnet.lic log.lic logxml.lic
          map.lic repository.lic vars.lic version.lic
        ].freeze

        # Creates timestamped snapshot of lib/, lich.rbw, and core scripts.
        #
        # @return [void]
        def snapshot
          respond
          respond 'Creating a snapshot of current Lich core files ONLY.'
          respond
          respond 'You may also wish to copy your entire Lich5 folder to'
          respond 'another location for additional safety, after any'
          respond 'additional requested updates are completed.'

          snapshot_subdir = File.join(BACKUP_DIR, "L5-snapshot-#{Time.now.strftime('%Y-%m-%d-%H-%M-%S')}")
          FileUtils.mkdir_p(snapshot_subdir)

          FileUtils.cp(File.join(LICH_DIR, File.basename($PROGRAM_NAME)),
                       File.join(snapshot_subdir, File.basename($PROGRAM_NAME)))

          FileUtils.mkdir_p(File.join(snapshot_subdir, "lib"))
          FileUtils.cp_r(LIB_DIR, snapshot_subdir)

          FileUtils.mkdir_p(File.join(snapshot_subdir, "scripts"))
          CORE_SCRIPTS.each do |file|
            source = File.join(SCRIPT_DIR, file)
            FileUtils.cp(source, File.join(snapshot_subdir, "scripts", file)) if File.exist?(source)
          end

          respond
          respond 'Current Lich ecosystem files (only) backed up to:'
          respond "    #{snapshot_subdir}"
        end

        # Restores most recent snapshot from BACKUP_DIR.
        #
        # @return [void]
        def revert
          respond
          respond 'Reverting Lich5 to previously installed version.'

          revert_array = Dir.glob(File.join(BACKUP_DIR, "L5-snapshot-*")).sort.reverse
          restore_snapshot = revert_array.first
          if restore_snapshot.nil?
            respond "No prior Lich5 version found. Seek assistance."
          else
            FileUtils.rm_rf(Dir.glob(File.join(LIB_DIR, "*")))
            FileUtils.cp_r(File.join(restore_snapshot, "lib", "."), LIB_DIR)

            CORE_SCRIPTS.each do |file|
              File.delete(File.join(SCRIPT_DIR, file)) if File.exist?(File.join(SCRIPT_DIR, file))
            end
            FileUtils.cp_r(File.join(restore_snapshot, "scripts", "."), SCRIPT_DIR)

            lich_to_update = File.join(LICH_DIR, File.basename($PROGRAM_NAME))
            update_to_lich = File.join(restore_snapshot, File.basename($PROGRAM_NAME))
            File.open(update_to_lich, 'rb') { |r| File.open(lich_to_update, 'wb') { |w| w.write(r.read) } }

            targetversion = ''
            targetfile = File.read(File.join(LIB_DIR, "version.rb"))
            targetfile.each_line do |line|
              if line =~ /LICH_VERSION\s*=\s*['"]([^'"]+)['"]/
                targetversion = $1
              end
            end

            Lich::Util::Update.clear_branch_tracking

            respond
            respond "Lich5 has been reverted to Lich5 version #{targetversion}"
            respond "You should exit the game, then log back in.  This will start the game"
            respond "with your previous version of Lich.  Enjoy!"
          end
        end
      end
    end
  end
end
