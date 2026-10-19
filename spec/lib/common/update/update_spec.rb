# frozen_string_literal: true

require_relative 'update_spec_helper'

RSpec.describe 'Lich::Util::Update SCRIPT_REPOS registry' do
  it 'defines dr-scripts with :all tracking mode' do
    config = Lich::Util::Update::SCRIPT_REPOS['dr-scripts']
    expect(config[:tracking_mode]).to eq(:all)
    expect(config[:game_filter]).to eq(/^DR/)
    expect(config[:subdirs]).to have_key('profiles')
    expect(config[:subdirs]).to have_key('data')
  end

  it 'defines scripts with :explicit tracking mode and defaults' do
    config = Lich::Util::Update::SCRIPT_REPOS['scripts']
    expect(config[:tracking_mode]).to eq(:explicit)
    expect(config[:game_filter]).to be_nil
    expect(config[:default_tracked]).to include('alias.lic', 'go2.lic', 'map.lic')
  end

  it 'has frozen configs' do
    Lich::Util::Update::SCRIPT_REPOS.each_value do |config|
      expect(config).to be_frozen
    end
  end
end

# SnapshotManager#snapshot raises RevertRunningError, after saying why, when
# a revert is running on the same installation. The client thread that runs
# ;lich5-update would otherwise print it as an error with a backtrace line.
RSpec.describe 'Lich::Util::Update.request while a revert is running' do
  let(:root) { Dir.mktmpdir('update-request-spec') }
  let(:manager) { Lich::Util::Update::SnapshotManager.new }
  let(:release_installer) do
    # A newer release already resolved, so --update goes straight to its
    # snapshot without asking GitHub.
    Lich::Util::Update::ReleaseInstaller.new(nil, nil, manager).tap do |installer|
      installer.instance_variable_set(:@update_to, '99.0.0')
      allow(installer).to receive(:respond)
    end
  end
  let(:branch_installer) do
    Lich::Util::Update::BranchInstaller.new(manager, release_installer).tap do |installer|
      allow(installer).to receive(:respond)
    end
  end
  let(:messages) { [] }

  before do
    stub_const('LICH_DIR', File.join(root, 'lich'))
    stub_const('SCRIPT_DIR', File.join(root, 'lich', 'scripts'))
    stub_const('BACKUP_DIR', File.join(root, 'lich', 'backup'))
    FileUtils.mkdir_p([SCRIPT_DIR, BACKUP_DIR])
    File.write(File.join(LICH_DIR, File.basename($PROGRAM_NAME)), "# lich\n")
    File.write(File.join(LIB_DIR, 'version.rb'), "LICH_VERSION = '5.22.0'\n")
    allow(manager).to receive(:respond) { |msg = ''| messages << msg.to_s }
    allow(Lich::Util::Update).to receive_messages(snapshot_manager: manager, release_installer: release_installer,
                                                  branch_installer: branch_installer)
    allow(URI).to receive(:open).and_raise('no download may start')
    allow(Net::HTTP).to receive(:get_response).and_raise('no download may start')
  end

  after { FileUtils.remove_entry(root, true) }

  def holding_revert_lock
    lock_path = File.join(BACKUP_DIR, Lich::Util::Update::SnapshotManager::REVERT_LOCK_NAME)
    File.open(lock_path, File::RDWR | File::CREAT, 0o644) do |lock|
      expect(lock.flock(File::LOCK_EX | File::LOCK_NB)).to be_truthy
      yield
    end
  end

  def published
    Dir.glob(File.join(BACKUP_DIR, 'L5-snapshot-*'))
  end

  ['--snapshot', '-s', '--update', '--branch=main'].each do |command|
    it "ends #{command} after the snapshot's own message instead of raising" do
      holding_revert_lock do
        expect { Lich::Util::Update.request(command) }.not_to raise_error
      end

      expect(messages).to include('A revert is running on this installation, so no snapshot was saved and nothing was changed.')
      expect(published).to be_empty
    end
  end

  it 'still lets other errors from a snapshot through' do
    allow(manager).to receive(:copy_core_files).and_raise(Errno::EACCES, 'lib')

    expect { Lich::Util::Update.request('--snapshot') }.to raise_error(Errno::EACCES)
  end
end
