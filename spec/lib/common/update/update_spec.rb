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

  # logxml.lic was removed from elanthia-online/scripts (;log --xml replaced
  # it). A default script missing from the repo is reported as "not in repo,
  # not synced" on every ;lich5-update, so it must not stay a default.
  it 'does not track logxml.lic, which left the scripts repo, by default' do
    config = Lich::Util::Update::SCRIPT_REPOS['scripts']
    expect(config[:default_tracked]).to include('log.lic')
    expect(config[:default_tracked]).not_to include('logxml.lic')
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
    # A newer release already resolved, with its download URL, so --update
    # goes straight to its snapshot without asking GitHub.
    Lich::Util::Update::ReleaseInstaller.new(nil, nil, manager).tap do |installer|
      installer.instance_variable_set(:@update_to, '99.0.0')
      installer.instance_variable_set(:@zipfile, 'https://example.invalid/lich5.tar.gz')
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

  # The archive downloads follow GitHub's redirects, so they use open-uri
  # rather than GitHubClient, but with its timeouts instead of Net::HTTP's
  # 60-second defaults.
  describe 'archive downloads' do
    let(:timeouts) do
      { open_timeout: Lich::Util::Update::GitHubClient::OPEN_TIMEOUT,
        read_timeout: Lich::Util::Update::GitHubClient::READ_TIMEOUT }
    end

    before do
      stub_const('TEMP_DIR', File.join(root, 'tmp')).tap { FileUtils.mkdir_p(TEMP_DIR) }
      allow(OpenURI).to receive(:open_uri).and_raise(SocketError, 'offline')
    end

    it '--update passes the GitHubClient timeouts to open-uri' do
      expect { Lich::Util::Update.request('--update') }.to raise_error(SocketError)

      expect(OpenURI).to have_received(:open_uri).with(URI('https://example.invalid/lich5.tar.gz'), timeouts).once
    end

    it '--branch passes the GitHubClient timeouts to open-uri' do
      Lich::Util::Update.request('--branch=main')

      expect(OpenURI).to have_received(:open_uri)
        .with(URI("https://github.com/#{Lich::Util::Update::GITHUB_REPO}/archive/refs/heads/main.tar.gz"), timeouts).once
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

RSpec.describe 'Lich::Util::Update.request gem package routing' do
  let(:update) { Lich::Util::Update }
  let(:manager) { instance_double(Lich::Util::Update::GemPackages) }
  let(:messages) { [] }

  before do
    allow(update).to receive(:gem_packages_manager).and_return(manager)
    allow(update).to receive(:respond) { |message = ''| messages << message }
  end

  it 'routes --add-gem, --update-gem, --remove-gem and --gems to the gem package manager' do
    expect(manager).to receive(:add_gem).with('elanthia-online/eohunter')
    expect(manager).to receive(:update_gem).with('someone/pkg')
    expect(manager).to receive(:remove_gem).with('someone/pkg')
    expect(manager).to receive(:list_gems)

    update.request('--add-gem=elanthia-online/eohunter')
    update.request('--update-gem=someone/pkg')
    update.request('--remove-gem=someone/pkg')
    update.request('--gems')
  end

  describe 'malformed --update-gem' do
    let(:release_installer) { instance_double(Lich::Util::Update::ReleaseInstaller, download_release_update: nil) }

    before { allow(update).to receive(:release_installer).and_return(release_installer) }

    ['--update-gem x/y', '--update-gem', '--update-gem=', '--update-gems=x/y'].each do |form|
      it "does not start a Lich update for '#{form}'" do
        allow(manager).to receive(:update_gem)
        update.request(form)

        expect(release_installer).not_to have_received(:download_release_update)
        expect(manager).not_to have_received(:update_gem)
        expect(messages).to include("Command '#{form}' unknown, illegitimate and ignored.  Exiting . . .")
      end
    end

    ['--update', '-u', '--update now'].each do |form|
      it "still routes '#{form}' to the Lich update" do
        update.request(form)
        expect(release_installer).to have_received(:download_release_update)
      end
    end
  end

  it 'documents --update-gem and the trusted-owner rule in the help text' do
    update.request('--help')
    help = messages.join("\n")

    expect(help).to include('lich5-update --update-gem=owner/repo')
    expect(help).to include('Releases install automatically only from trusted owners (elanthia-online)')
  end
end

# --branch names a lich-5 branch, a fork's lich-5 branch (owner:branch), or a
# branch of any repository under an allowlisted owner (owner/repo:branch), so
# a successor project can be installed by opt-in.
RSpec.describe 'Lich::Util::Update::BranchInstaller branch specs' do
  let(:snapshot_manager) { instance_double(Lich::Util::Update::SnapshotManager) }
  let(:installer) { Lich::Util::Update::BranchInstaller.new(snapshot_manager, nil) }
  let(:messages) { [] }
  let(:downloads) { [] }

  before do
    allow(installer).to receive(:respond) { |message = ''| messages << message.to_s }
    allow(snapshot_manager).to receive(:snapshot).and_yield(nil)
    # Stop at the download: only the URL it would fetch matters here.
    allow(Lich::Util::Update::Tarball).to receive(:with_extracted) do |url, _filename|
      downloads << url
      raise SocketError, 'offline'
    end
  end

  def archive(repo, branch)
    "https://github.com/#{repo}/archive/refs/heads/#{branch}.tar.gz"
  end

  {
    'main'                            => ['elanthia-online/lich-5', 'main'],
    'pre/beta'                        => ['elanthia-online/lich-5', 'pre%2Fbeta'],
    'someone:feature'                 => ['someone/lich-5', 'feature'],
    'someone:feat/x'                  => ['someone/lich-5', 'feat%2Fx'],
    'someone/lich-5:feature'          => ['someone/lich-5', 'feature'],
    'someone/Lich-5:feat/x'           => ['someone/lich-5', 'feat%2Fx'],
    'Elanthia-Online:main'            => ['elanthia-online/lich-5', 'main'],
    'Elanthia-Online/LICH-5:main'     => ['elanthia-online/lich-5', 'main'],
    'someone/lich-5.git:main'         => ['someone/lich-5', 'main'],
    'elanthia-online/lich-6.git:main' => ['elanthia-online/lich-6', 'main'],
    'elanthia-online/lich-6:main'     => ['elanthia-online/lich-6', 'main'],
    'Elanthia-Online/lich-6:main'     => ['Elanthia-Online/lich-6', 'main'],
    'elanthia-online/lich-6:feat/web' => ['elanthia-online/lich-6', 'feat%2Fweb'],
    ' elanthia-online/lich-6:main '   => ['elanthia-online/lich-6', 'main']
  }.each do |spec, (repo, branch)|
    it "downloads #{repo} #{branch} for #{spec.inspect}" do
      installer.download_branch_update(spec)

      expect(downloads).to eq([archive(repo, branch)])
    end
  end

  it 'names the repository when it is not lich-5' do
    installer.download_branch_update('elanthia-online/lich-6:main')

    expect(messages).to include('Repository: elanthia-online/lich-6')
  end

  ['main', 'elanthia-online:main', 'Elanthia-Online:main'].each do |spec|
    it "does not name the repository for #{spec.inspect}, a lich-5 branch" do
      installer.download_branch_update(spec)

      expect(messages.grep(/^Repository:/)).to be_empty
    end
  end

  {
    ''                                    => /incomplete/,
    'someone:'                            => /incomplete/,
    ':main'                               => /incomplete/,
    'elanthia-online/lich-6:'             => /incomplete/,
    'someone/lich-6:main'                 => /only be installed from: elanthia-online/,
    'elanthia-online-evil/lich-6:main'    => /only be installed from: elanthia-online/,
    'elanthia-online/../x:main'           => /not a valid owner\/repo/,
    'elanthia-online/..:main'             => /not a valid owner\/repo/,
    'elanthia-online/:main'               => /not a valid owner\/repo/,
    '/lich-6:main'                        => /not a valid owner\/repo/,
    'elanthia-online/lich 6:main'         => /not a valid owner\/repo/,
    'elanthia-online/.git:main'           => /not a valid owner\/repo/,
    'someone/elanthia-online/lich-6:main' => /not a valid owner\/repo/,
    'x/y/elanthia-online/lich-6:main'     => /not a valid owner\/repo/,
    '..:main'                             => /not a valid GitHub owner/,
    'a b:main'                            => /not a valid GitHub owner/,
    'a?x=:main'                           => /not a valid GitHub owner/
  }.each do |spec, error|
    it "refuses #{spec.inspect} without taking a snapshot or downloading" do
      installer.download_branch_update(spec)

      expect(messages).to include(a_string_matching(error))
      expect(messages).to include(a_string_including('<owner>/<repo>:<branch_name>'))
      expect(snapshot_manager).not_to have_received(:snapshot)
      expect(downloads).to be_empty
    end
  end

  it 'records the other repository in branch tracking after installing' do
    release_installer = instance_double(Lich::Util::Update::ReleaseInstaller,
                                        validate_lich_structure: true,
                                        extract_version_from_file: '6.0.0',
                                        perform_update: true)
    installer = Lich::Util::Update::BranchInstaller.new(snapshot_manager, release_installer)
    allow(installer).to receive(:respond)
    allow(Lich::Util::Update).to receive(:store_branch_tracking)

    Dir.mktmpdir do |tree|
      FileUtils.mkdir_p(File.join(tree, 'lib'))
      File.write(File.join(tree, 'lib', 'version.rb'), "LICH_VERSION = '6.0.0'\n")
      allow(Lich::Util::Update::Tarball).to receive(:with_extracted).and_yield(tree)

      installer.download_branch_update('elanthia-online/lich-6:main')
    end

    expect(Lich::Util::Update).to have_received(:store_branch_tracking).with('main', 'elanthia-online/lich-6', '6.0.0')
  end
end

RSpec.describe 'Lich::Util::Update::BranchInstaller downloads that cannot be installed' do
  let(:snapshot_manager) { instance_double(Lich::Util::Update::SnapshotManager) }
  # The real check, so these examples test what it accepts, not a stub.
  let(:release_installer) { Lich::Util::Update::ReleaseInstaller.new(nil, nil, nil) }
  let(:installer) { Lich::Util::Update::BranchInstaller.new(snapshot_manager, release_installer) }
  let(:messages) { [] }
  let(:downloads) { [] }

  around do |example|
    Dir.mktmpdir do |dir|
      @tree = dir
      example.run
    end
  end

  before do
    allow(installer).to receive(:respond) { |message = ''| messages << message.to_s }
    allow(snapshot_manager).to receive(:snapshot).and_yield(nil)
    allow(Lich::Util::Update::Tarball).to receive(:with_extracted) do |url, _name, &block|
      downloads << url
      block.call(@tree)
    end
    allow(release_installer).to receive(:perform_update)
    allow(Lich::Util::Update).to receive(:store_branch_tracking)
  end

  def lay_out(*entries)
    entries.each do |entry|
      path = File.join(@tree, entry)
      FileUtils.mkdir_p(File.dirname(path))
      entry == 'lib' ? FileUtils.mkdir_p(path) : File.write(path, "# #{entry}\n")
    end
  end

  it 'downloads an allowlisted repository that is not Lich, then refuses it before installing' do
    # A scripts repository: a lib/ but no launcher.
    lay_out('lib/helper.rb', 'Gemfile', 'LICENSE')

    installer.download_branch_update('elanthia-online/scripts:master')

    expect(downloads).to eq(['https://github.com/elanthia-online/scripts/archive/refs/heads/master.tar.gz'])
    expect(release_installer).not_to have_received(:perform_update)
    expect(Lich::Util::Update).not_to have_received(:store_branch_tracking)
    expect(messages).to include(a_string_including('does not appear to be a valid Lich installation'))
    expect(messages).to include('Your installation has been preserved.')
  end

  it 'refuses a tree without lib/version.rb before installing' do
    lay_out('lib/lich.rb', 'lich.rbw', 'Gemfile', 'LICENSE')

    installer.download_branch_update('elanthia-online/lich-6:main')

    expect(release_installer).not_to have_received(:perform_update)
    expect(messages).to include(a_string_including('has no lib/version.rb'))
    expect(messages).to include('Your installation has been preserved.')
  end

  it 'says the installation was changed when a step after replacing lib/ fails' do
    lay_out('lib/version.rb', 'lich.rbw', 'Gemfile', 'LICENSE')
    allow(Lich::Util::Update).to receive(:store_branch_tracking).and_raise(Errno::ENOENT, 'lib/version.rb')

    installer.download_branch_update('elanthia-online/lich-6:main')

    expect(release_installer).to have_received(:perform_update)
    expect(messages).to include('The update failed after it had started replacing your installation.')
    expect(messages).to include(a_string_including('lich5-update --revert\' to restore the snapshot'))
    expect(messages).not_to include('Your installation has been preserved.')
  end

  it 'says the installation was changed when perform_update itself fails' do
    lay_out('lib/version.rb', 'lich.rbw', 'Gemfile', 'LICENSE')
    allow(release_installer).to receive(:perform_update).and_raise(Errno::EACCES, 'lich.rbw')

    installer.download_branch_update('elanthia-online/lich-6:main')

    expect(messages).to include('The update failed after it had started replacing your installation.')
    expect(messages).not_to include('Your installation has been preserved.')
  end

  context 'when the download fails' do
    def fail_download(status)
      allow(Lich::Util::Update::Tarball).to receive(:with_extracted)
        .and_raise(OpenURI::HTTPError.new(status, StringIO.new))
    end

    it 'names the repository when it is not found' do
      fail_download('404 Not Found')

      installer.download_branch_update('elanthia-online/lich-6:main')

      expect(messages).to include(a_string_including("repository 'elanthia-online/lich-6' and its branch 'main'"))
      expect(messages.grep(/another repository/)).to be_empty
    end

    it 'suggests the owner/repo:branch form for a lich-5 branch with a slash that is not found' do
      fail_download('404 Not Found')

      installer.download_branch_update('elanthia-online/lich-6')

      expect(messages).to include(a_string_including('--branch=<owner>/<repo>:<branch_name>'))
    end

    it 'does not claim the branch may not exist for other HTTP errors' do
      fail_download('403 rate limit exceeded')

      installer.download_branch_update('elanthia-online/lich-6:main')

      expect(messages).to include('HTTP Error: 403 rate limit exceeded')
      expect(messages.grep(/verify that repository/)).to be_empty
    end
  end
end
