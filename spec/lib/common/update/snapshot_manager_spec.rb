# frozen_string_literal: true

require_relative 'update_spec_helper'

RSpec.describe Lich::Util::Update::SnapshotManager do
  let(:manager) { described_class.new }

  describe '#new_snapshot_dir vs #new_data_backup_dir' do
    it 'uses a prefix for data-only backups that #revert\'s snapshot glob cannot match' do
      # Regression guard: #revert restores from
      # Dir.glob(File.join(BACKUP_DIR, "L5-snapshot-*")).sort.reverse.first,
      # with no check that the directory actually contains a full snapshot
      # (lib/, lich.rbw, scripts/). A data-only backup directory sharing that
      # prefix would be indistinguishable from a real snapshot and, if newest,
      # would have #revert wipe LIB_DIR and then fail to restore it.
      snapshot_dir = manager.new_snapshot_dir
      data_backup_dir = manager.new_data_backup_dir

      restorable = Dir.glob(File.join(BACKUP_DIR, "L5-snapshot-*"))

      expect(restorable).to include(snapshot_dir)
      expect(restorable).not_to include(data_backup_dir)

      FileUtils.remove_entry(snapshot_dir)
      FileUtils.remove_entry(data_backup_dir)
    end
  end

  describe '#new_data_backup_dir' do
    it 'never returns the same directory for two calls in the same second' do
      # Regression guard: a bare mkdir_p on a second-resolution timestamp
      # would let two calls within the same wall-clock second (e.g. two
      # multiboxed Lich processes autostarting after an update) collide on
      # the same directory and silently clobber each other's backup.
      first_dir = manager.new_data_backup_dir
      second_dir = manager.new_data_backup_dir

      expect(first_dir).not_to eq(second_dir)

      FileUtils.remove_entry(first_dir)
      FileUtils.remove_entry(second_dir)
    end
  end
end
