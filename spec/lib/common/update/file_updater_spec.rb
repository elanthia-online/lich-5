# frozen_string_literal: true

require_relative 'update_spec_helper'

RSpec.describe Lich::Util::Update::FileUpdater do
  let(:tmpdir) { Dir.mktmpdir('fu-test') }
  let(:client) { instance_double(Lich::Util::Update::GitHubClient) }
  let(:resolver) { instance_double(Lich::Util::Update::ChannelResolver) }
  let(:updater) { described_class.new(client, resolver) }

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
end
