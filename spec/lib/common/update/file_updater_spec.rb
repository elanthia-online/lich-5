# frozen_string_literal: true

require_relative 'update_spec_helper'

RSpec.describe Lich::Util::Update::FileUpdater do
  let(:tmpdir) { Dir.mktmpdir('fu-test') }
  let(:client) { instance_double(Lich::Util::Update::GitHubClient) }
  let(:resolver) { instance_double(Lich::Util::Update::ChannelResolver) }
  let(:snapshot_manager) { instance_double(Lich::Util::Update::SnapshotManager) }
  let(:updater) { described_class.new(client, resolver, snapshot_manager) }

  before do
    stub_const('SCRIPT_DIR', tmpdir)
    allow(Lich::Util::Update::StatusReporter).to receive(:respond_mono)
  end

  after { FileUtils.remove_entry(tmpdir) }

  describe '#update_file_from_repo finds data files via subdir pattern' do
    it 'resolves effect-list.xml through the gs-scripts pattern' do
      tree = {
        'tree' => [
          { 'path' => 'scripts/effect-list.xml', 'type' => 'blob', 'sha' => 'abc123' },
          { 'path' => 'scripts/gameobj-data.xml', 'type' => 'blob', 'sha' => 'def456' },
        ]
      }
      allow(client).to receive(:fetch_github_json).and_return(tree)
      allow(client).to receive(:http_get).and_return('<xml>effect data</xml>')
      allow(Lich::Util::Update::FileWriter).to receive(:safe_write)

      updater.update_file_from_repo('data', 'gs-scripts', 'effect-list.xml')

      expect(client).to have_received(:http_get).with(
        'https://raw.githubusercontent.com/elanthia-online/scripts/master/scripts/effect-list.xml',
        auth: false
      )
    end
  end

  describe '#update_file_from_repo when file is not in repo tree' do
    it 'reports not found without attempting download' do
      tree = {
        'tree' => [
          { 'path' => 'scripts/other-file.xml', 'type' => 'blob', 'sha' => 'xxx' },
        ]
      }
      allow(client).to receive(:fetch_github_json).and_return(tree)

      updater.update_file_from_repo('data', 'gs-scripts', 'nonexistent.xml')

      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with(
        /nonexistent\.xml not found/
      )
    end
  end

  describe '#update_file_from_repo when GitHub tree API fails' do
    it 'bails early with an error message and does not attempt download' do
      allow(client).to receive(:fetch_github_json).and_return(nil)

      updater.update_file_from_repo('data', 'gs-scripts', 'effect-list.xml')

      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with(
        /Failed to fetch repository tree/
      )
    end
  end

  describe '#update_file_from_repo skips download when local SHA matches remote' do
    it 'reports already up to date' do
      content = '<xml>current content</xml>'
      local_path = File.join(DATA_DIR, 'gameobj-data.xml')
      FileUtils.mkdir_p(DATA_DIR)
      File.binwrite(local_path, content)
      sha = git_blob_sha(content)

      tree = {
        'tree' => [
          { 'path' => 'scripts/gameobj-data.xml', 'type' => 'blob', 'sha' => sha },
        ]
      }
      allow(client).to receive(:fetch_github_json).and_return(tree)

      updater.update_file_from_repo('data', 'gs-scripts', 'gameobj-data.xml')

      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with(
        /already up to date/
      )
    end
  end

  describe '#update_file_from_repo with unsupported type' do
    it 'rejects library type with repo syntax' do
      expect { updater.update_file_from_repo('library', 'scripts', 'foo.rb') }.not_to raise_error
    end
  end

  describe '#update_file_from_repo with unknown repo key' do
    it 'reports unknown repository' do
      expect { updater.update_file_from_repo('script', 'fake-repo', 'foo.lic') }.not_to raise_error
    end
  end

  describe '#update_core_data_and_scripts' do
    let(:effect_list_path) { File.join(DATA_DIR, 'effect-list.xml') }

    before do
      XMLData.game = 'GS'
      FileUtils.mkdir_p(DATA_DIR)
      File.write(effect_list_path, '<xml>old effect data</xml>')
      allow(updater).to receive(:update_file)
      allow(Lich).to receive(:core_updated_with_lich_version=)
    end

    after do
      XMLData.game = 'DR'
      File.delete(effect_list_path) if File.exist?(effect_list_path)
    end

    context 'given an explicit snapshot_dir from an active full update' do
      it "backs the prior effect-list.xml up under that snapshot's data directory" do
        snapshot_dir = Dir.mktmpdir('snap-test')

        updater.update_core_data_and_scripts('5.16.0', snapshot_dir)

        expect(File.read(File.join(snapshot_dir, 'data', 'effect-list.xml'))).to eq('<xml>old effect data</xml>')
        FileUtils.remove_entry(snapshot_dir)
      end
    end

    context 'given no snapshot_dir (a standalone call, e.g. login autostart)' do
      it 'asks SnapshotManager for a data-only backup directory rather than a real snapshot directory' do
        data_backup_dir = Dir.mktmpdir('databackup-test')
        allow(snapshot_manager).to receive(:new_data_backup_dir).and_return(data_backup_dir)

        updater.update_core_data_and_scripts('5.16.0')

        expect(snapshot_manager).to have_received(:new_data_backup_dir)
        expect(File.read(File.join(data_backup_dir, 'data', 'effect-list.xml'))).to eq('<xml>old effect data</xml>')
        FileUtils.remove_entry(data_backup_dir)
      end
    end

    context 'called twice with no snapshot_dir within the same second (e.g. two multiboxed logins)' do
      it 'never resolves both standalone calls to the same data-only backup directory' do
        # update_core_data_and_scripts is a public entry point with no guard
        # of its own against concurrent callers -- the @@autostarted check
        # lives in games.rb, not here. Use a real SnapshotManager (rather
        # than the instance_double above) so this exercises the actual
        # directory-naming collision risk instead of a stubbed return value.
        real_snapshot_manager = Lich::Util::Update::SnapshotManager.new
        concurrent_updater = described_class.new(client, resolver, real_snapshot_manager)
        allow(concurrent_updater).to receive(:update_file)

        before_dirs = Dir.glob(File.join(BACKUP_DIR, 'L5-databackup-*'))
        concurrent_updater.update_core_data_and_scripts('5.16.0')
        concurrent_updater.update_core_data_and_scripts('5.16.0')
        created_dirs = Dir.glob(File.join(BACKUP_DIR, 'L5-databackup-*')).sort - before_dirs

        expect(created_dirs.length).to eq(2)
        expect(created_dirs[0]).not_to eq(created_dirs[1])

        created_dirs.each { |dir| FileUtils.remove_entry(dir) }
      end
    end
  end
end
