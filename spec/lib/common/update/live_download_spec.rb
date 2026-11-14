# frozen_string_literal: true

require_relative 'update_spec_helper'

# Downloads real GitHub tarballs and runs them through the real installers'
# download and extraction, stopping just before anything is installed:
# perform_update, the step that copies into the Lich install, is replaced by
# a probe of the extracted tree. Runs only with LICH_LIVE_UPDATE_DOWNLOAD=1,
# because it needs the network; the Windows job in windows_file_handoff.yaml
# sets it, so extraction is exercised on real Windows paths and file locking.
RSpec.describe 'lich5-update live download and extraction', if: ENV['LICH_LIVE_UPDATE_DOWNLOAD'] == '1' do
  let(:temp_dir) { Dir.mktmpdir('lich-live-update') }
  let(:snapshot_dir) { Dir.mktmpdir('lich-live-snapshot') }
  let(:snapshot_manager) { instance_double(Lich::Util::Update::SnapshotManager) }
  let(:release_installer) do
    Lich::Util::Update::ReleaseInstaller.new(instance_double(Lich::Util::Update::GitHubClient),
                                             instance_double(Lich::Util::Update::ChannelResolver), snapshot_manager)
  end
  let(:messages) { [] }
  let(:probed) { [] }

  before do
    stub_const('TEMP_DIR', temp_dir)
    allow(snapshot_manager).to receive(:snapshot).and_yield(snapshot_dir)
    allow(release_installer).to receive(:respond) { |message = ''| messages << message }
    allow(release_installer).to receive(:perform_update) do |source_dir, version, _snapshot|
      version_file = File.join(source_dir, 'lib', 'version.rb')
      probed << { version: version, version_rb: release_installer.extract_version_from_file(version_file),
                  valid: release_installer.validate_lich_structure(source_dir),
                  files: Dir.glob('**/*', base: source_dir).count { |path| File.file?(File.join(source_dir, path)) },
                  inside_temp: File.expand_path(source_dir).start_with?("#{File.expand_path(temp_dir)}/") }
      true
    end
  end

  after do
    FileUtils.remove_entry(temp_dir) if Dir.exist?(temp_dir)
    FileUtils.remove_entry(snapshot_dir) if Dir.exist?(snapshot_dir)
  end

  it 'downloads and extracts the v5.24.2 release asset through ReleaseInstaller, then cleans up' do
    allow(Lich::Util::Update).to receive(:clear_branch_tracking)
    release_installer.instance_variable_set(:@current, '5.0.0')
    release_installer.instance_variable_set(:@update_to, '5.24.2')
    release_installer.instance_variable_set(:@zipfile,
                                            "https://github.com/elanthia-online/lich-5/releases/download/v5.24.2/#{Lich::Util::Update::ASSET_TARBALL_NAME}")

    release_installer.send(:install_release)

    expect(probed.length).to eq(1), messages.join("\n")
    expect(probed.first).to include(version: '5.24.2', version_rb: '5.24.2', valid: true, inside_temp: true)
    expect(probed.first[:files]).to be > 900
    expect(messages.join("\n")).to include('updated to Lich5 version 5.24.2')
    expect(Dir.children(temp_dir)).to be_empty
  end

  it 'downloads and extracts the main branch tarball through BranchInstaller, then cleans up' do
    allow(Lich::Util::Update).to receive(:store_branch_tracking)
    branch_installer = Lich::Util::Update::BranchInstaller.new(snapshot_manager, release_installer)
    allow(branch_installer).to receive(:respond) { |message = ''| messages << message }

    branch_installer.download_branch_update('main')

    expect(probed.length).to eq(1), messages.join("\n")
    expect(probed.first).to include(valid: true, inside_temp: true)
    expect(probed.first[:version_rb]).to match(/\A\d+\.\d+\.\d+/)
    expect(probed.first[:version]).to eq(probed.first[:version_rb])
    expect(probed.first[:files]).to be > 900
    expect(messages.join("\n")).to include('Successfully updated to branch: main')
    expect(Dir.children(temp_dir)).to be_empty
  end
end
