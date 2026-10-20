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
    # The installers download with URI.parse(url).open, which goes through
    # OpenURI.open_uri rather than URI.open.
    allow(OpenURI).to receive(:open_uri).and_raise('no download may start')
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

      expect(messages).to include('Another update, snapshot or revert is running on this installation, so no snapshot was saved and nothing was changed.')
      expect(published).to be_empty
    end
  end

  it 'still lets other errors from a snapshot through' do
    allow(manager).to receive(:copy_core_files).and_raise(Errno::EACCES, 'lib')

    expect { Lich::Util::Update.request('--snapshot') }.to raise_error(Errno::EACCES)
  end

  # A revert in another session of the same installation, started while this
  # update is past its snapshot, must not swap lib/ under the download or
  # the install.
  describe 'a revert started after the snapshot' do
    let(:revert_messages) { [] }
    let(:refusal) { 'Another revert, a snapshot or an update is running on this installation. Nothing was changed.' }

    before { stub_const('TEMP_DIR', File.join(root, 'tmp')).tap { FileUtils.mkdir_p(TEMP_DIR) } }

    def revert_from_other_session
      other = Lich::Util::Update::SnapshotManager.new
      allow(other).to receive(:respond) { |msg = ''| revert_messages << msg.to_s }
      other.revert
    end

    # A gzipped tarball holding one top-level directory with a Lich layout.
    def lich_tarball
      io = StringIO.new(+'', 'wb')
      Zlib::GzipWriter.wrap(io) do |gz|
        Gem::Package::TarWriter.new(gz) do |tar|
          { 'lib/version.rb' => "LICH_VERSION = '99.0.0'\n", 'lich.rbw' => "# lich\n",
            'Gemfile' => '', 'LICENSE' => '' }.each do |path, body|
            tar.add_file_simple("lich-5-99.0.0/#{path}", 0o644, body.bytesize) { |f| f.write(body) }
          end
        end
      end
      io.string
    end

    def expect_revert_refused
      expect(revert_messages).to include(refusal)
      expect(revert_messages.grep(/has been reverted/)).to be_empty
      expect(File.read(File.join(LIB_DIR, 'version.rb'))).to eq("LICH_VERSION = '5.22.0'\n")
    end

    it 'is refused while --update downloads, and the lock is free afterwards' do
      release_installer.instance_variable_set(:@zipfile, 'https://example.invalid/lich5.tar.gz')
      allow(OpenURI).to receive(:open_uri) do
        revert_from_other_session
        raise SocketError, 'offline'
      end

      expect { Lich::Util::Update.request('--update') }.to raise_error(SocketError)
      expect_revert_refused
      expect(published.size).to eq(1)

      revert_messages.clear
      revert_from_other_session
      expect(revert_messages).not_to include(refusal)
    end

    it 'is refused while --update installs' do
      release_installer.instance_variable_set(:@zipfile, 'https://example.invalid/lich5.tar.gz')
      allow(OpenURI).to receive(:open_uri).and_return(StringIO.new(lich_tarball))
      allow(release_installer).to receive(:perform_update) do
        revert_from_other_session
        false
      end

      Lich::Util::Update.request('--update')

      expect(release_installer).to have_received(:perform_update)
      expect_revert_refused
    end

    it 'is refused while --branch downloads' do
      allow(OpenURI).to receive(:open_uri) do
        revert_from_other_session
        raise SocketError, 'offline'
      end

      Lich::Util::Update.request('--branch=main')

      expect(OpenURI).to have_received(:open_uri)
      expect_revert_refused
    end

    it 'is refused while --branch installs' do
      allow(OpenURI).to receive(:open_uri).and_return(StringIO.new(lich_tarball))
      allow(release_installer).to receive(:perform_update) do
        revert_from_other_session
        true
      end
      allow(Lich::Util::Update).to receive(:store_branch_tracking)

      Lich::Util::Update.request('--branch=main')

      expect(release_installer).to have_received(:perform_update)
      expect_revert_refused
    end
  end
end

RSpec.describe 'Lich::Util::Update.request beta routing' do
  let(:update) { Lich::Util::Update }
  let(:client) { instance_double(Lich::Util::Update::GitHubClient) }
  let(:resolver) { instance_double(Lich::Util::Update::ChannelResolver, last_error: nil) }
  let(:snapshot_manager) { instance_double(Lich::Util::Update::SnapshotManager) }
  let(:installer) { Lich::Util::Update::ReleaseInstaller.new(client, resolver, snapshot_manager) }
  let(:messages) { [] }

  before do
    allow(update).to receive(:release_installer).and_return(installer)
    allow(installer).to receive(:respond) { |message = ''| messages << message }
    allow(update).to receive(:respond) { |message = ''| messages << message }
    allow(resolver).to receive(:resolve_channel_ref).with(:beta).and_return(nil)
  end

  ['--beta --confirm', '--beta confirm', '--test --confirm', '--test confirm', '--beta --confirm '].each do |form|
    it "installs after the notice when confirmed with '#{form}'" do
      update.request('--beta')
      update.request(form)

      expect(resolver).to have_received(:resolve_channel_ref).with(:beta).once
      expect(messages).to include('No viable beta found. Aborting beta update.')
    end
  end

  it 'does not install from a confirmation that was never preceded by the notice' do
    update.request('--beta --confirm')

    expect(resolver).not_to have_received(:resolve_channel_ref)
    expect(messages).to include(a_string_matching(/There is no beta test request to confirm/))
  end

  ['--beta --confirmed', '--beta --confirm --library=foo.rb', '--beta --CONFIRM', '--beta-confirm'].each do |form|
    it "does not treat '#{form}' as a confirmation" do
      update.request('--beta')
      update.request(form)

      expect(resolver).not_to have_received(:resolve_channel_ref)
    end
  end

  it 'still routes a single-file beta update to the file updater' do
    expect(installer).to receive(:prep_betatest).with('library', 'foo.rb')

    update.request('--beta --library=foo.rb')
  end

  it 'documents the beta commands in the help text' do
    update.request('--help')
    help = messages.join("\n")

    expect(help).to include('lich5-update --beta --confirm')
    expect(help).to match(/lich5-update --beta\s+Show the beta notice; confirm within #{Lich::Util::Update::ReleaseInstaller::BETA_CONFIRM_WINDOW} seconds/)
    expect(help).to include('lich5-update --beta --library=<name>')
  end
end
