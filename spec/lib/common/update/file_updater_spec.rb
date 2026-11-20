# frozen_string_literal: true

require_relative 'update_spec_helper'

RSpec.describe Lich::Util::Update::FileUpdater do
  # Every script install reads the script's Lich version floor.
  include_context 'with the real script floor reader'

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
      allow(client).to receive(:last_error).and_return(Lich::Util::Update::FetchError.new(kind: :unavailable, status: 502))

      updater.update_file_from_repo('data', 'gs-scripts', 'effect-list.xml')

      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with(
        /GitHub check failed\. effect-list\.xml was not updated\. This is a temporary error/
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

    # The GS login sync fetches effect-list.xml again, so a failure here can
    # say the next login fixes it.
    it 'updates effect-list.xml with the login wording for failures' do
      allow(snapshot_manager).to receive(:new_data_backup_dir).and_return(Dir.mktmpdir('databackup-test'))

      updater.update_core_data_and_scripts('5.16.0')

      expect(updater).to have_received(:update_file).with('data', 'effect-list.xml', retried_by: :login)
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

  describe '#update_file_from_repo when the raw download fails after the tree listed the file' do
    it 'does not tell the user to check that the repository exists' do
      printed = []
      allow(Lich::Util::Update::StatusReporter).to receive(:respond_mono) { |msg| printed << msg }
      tree = { 'tree' => [{ 'path' => 'scripts/foo.lic', 'type' => 'blob', 'sha' => 'abc' }] }
      allow(client).to receive(:fetch_github_json).and_return(tree)
      allow(client).to receive(:http_get).and_return(nil)
      allow(client).to receive(:last_error).and_return(Lich::Util::Update::FetchError.new(kind: :not_found, status: 404))

      updater.update_file_from_repo('script', 'scripts', 'foo.lic')

      expect(printed.last).to include('foo.lic was not updated.', 'temporary error')
      expect(printed.last).not_to include('not found')
    end
  end

  describe 'a script whose newest version needs a newer Lich' do
    let(:printed) { [] }
    let(:shas) { %w[a b c].map { |letter| letter * 40 } }
    let(:newest) { script_requiring('5.26.0', 'v3') }
    let(:compatible) { script_requiring('5.25.0', 'v2') }
    let(:history) { [newest, compatible, script_requiring('5.24.0', 'v1')] }
    let(:live_path) { File.join(tmpdir, 'foo.lic') }

    before do
      stub_const('LICH_VERSION', '5.25.1')
      allow(updater).to receive(:respond) { |msg = ''| printed << msg }
      allow(Lich::Util::Update::StatusReporter).to receive(:respond_mono) { |msg| printed << msg }
      allow(client).to receive(:last_error).and_return(nil)
    end

    # Stubs the newest version on the branch, the commit list for the file
    # and the file as it was at each commit, in +repo+.
    def stub_repo(repo, branch, path)
      raw = "https://raw.githubusercontent.com/#{repo}"
      commits_url = "https://api.github.com/repos/#{repo}/commits?sha=#{branch}&path=#{path.gsub('/', '%2F')}&per_page=30"
      allow(client).to receive(:http_get).with("#{raw}/#{branch}/#{path}", auth: false) { newest }
      allow(client).to receive(:fetch_github_json).with(commits_url) { history.each_index.map { |index| { 'sha' => shas[index] } } }
      shas.each_with_index do |sha, index|
        allow(client).to receive(:http_get).with("#{raw}/#{sha}/#{path}", auth: false) { history[index] }
      end
      commits_url
    end

    describe '#update_file (--script=name)' do
      let!(:commits_url) { stub_repo('elanthia-online/scripts', 'master', 'scripts/foo.lic') }

      it 'installs the newest version the running Lich can run instead' do
        updater.update_file('script', 'foo.lic')

        expect(File.binread(live_path)).to eq(compatible)
        expect(printed).to include(
          '[lich5-update: The newest foo.lic needs Lich 5.26.0+ and this is Lich 5.25.1. ' \
          'Installing the newest version this Lich can run instead (commit bbbbbbb).]',
          'foo.lic has been updated.'
        )
      end

      it 'never writes the version with the unmet floor, even over nothing' do
        written = []
        allow(Lich::Util::Update::FileWriter).to receive(:safe_write) { |_path, content| written << content }

        updater.update_file('script', 'foo.lic')

        expect(written).to eq([compatible])
      end

      it 'refuses, and leaves the installed copy alone, when no version in the history can run here' do
        history.replace([newest, script_requiring('5.26.0', 'v2')])
        File.binwrite(live_path, "# mine\n")

        updater.update_file('script', 'foo.lic')

        expect(File.binread(live_path)).to eq("# mine\n")
        expect(printed).to eq(
          ['[lich5-update: The newest foo.lic needs Lich 5.26.0+ and this is Lich 5.25.1. No older version that runs on ' \
           'this Lich was found (2 checked), so foo.lic was not updated. Update Lich to use it.]']
        )
      end

      it 'says a missing script was not installed when no version can run here' do
        history.replace([newest])

        updater.update_file('script', 'foo.lic')

        expect(File.exist?(live_path)).to be(false)
        expect(printed.last).to include('so foo.lic was not installed. Update Lich to use it.')
      end

      it 'says so, without rewriting the file, when the installed copy already is that version' do
        File.binwrite(live_path, compatible)
        allow(Lich::Util::Update::FileWriter).to receive(:safe_write)

        updater.update_file('script', 'foo.lic')

        expect(Lich::Util::Update::FileWriter).not_to have_received(:safe_write)
        expect(printed).to eq(
          ['[lich5-update: The newest foo.lic needs Lich 5.26.0+ and this is Lich 5.25.1. ' \
           'foo.lic is already at the newest version this Lich can run.]']
        )
      end

      it 'installs nothing and reports the GitHub failure when the history cannot be read' do
        allow(client).to receive(:fetch_github_json).with(commits_url).and_return(nil)
        allow(client).to receive(:last_error).and_return(Lich::Util::Update::FetchError.new(kind: :rate_limited, status: 403))

        updater.update_file('script', 'foo.lic')

        expect(File.exist?(live_path)).to be(false)
        expect(printed).to eq(
          ['[lich5-update: GitHub check failed (rate limit reached). The newest foo.lic needs Lich 5.26.0+ and this is Lich 5.25.1, ' \
           'and its older versions could not be checked, so foo.lic was not updated. Run the command again once the limit resets.]']
        )
      end

      it 'installs the newest version as before when the running Lich meets its floor' do
        stub_const('LICH_VERSION', '5.26.0')

        updater.update_file('script', 'foo.lic')

        expect(File.binread(live_path)).to eq(newest)
        expect(client).not_to have_received(:fetch_github_json)
      end

      it 'reads the history of dependency.lic from the repository it is downloaded from' do
        stub_repo('elanthia-online/dr-scripts', 'main', 'dependency.lic')

        updater.update_file('script', 'dependency.lic')

        expect(File.binread(File.join(tmpdir, 'dependency.lic'))).to eq(compatible)
      end

      it 'does not read a floor from a data file' do
        stub_const('DATA_DIR', tmpdir)
        allow(client).to receive(:http_get).and_return(newest)

        updater.update_file('data', 'effect-list.xml')

        expect(File.binread(File.join(tmpdir, 'effect-list.xml'))).to eq(newest)
      end
    end

    describe '#update_file_from_repo (--script=repo:name)' do
      let(:tree) { { 'tree' => [{ 'path' => 'scripts/foo.lic', 'type' => 'blob', 'sha' => git_blob_sha(newest) }] } }
      let!(:commits_url) { stub_repo('elanthia-online/scripts', 'master', 'scripts/foo.lic') }

      before do
        allow(client).to receive(:fetch_github_json)
          .with(Lich::Util::Update::SCRIPT_REPOS['scripts'][:api_url]).and_return(tree)
      end

      it 'installs the newest version the running Lich can run instead' do
        updater.update_file_from_repo('script', 'scripts', 'foo.lic')

        expect(File.binread(live_path)).to eq(compatible)
        expect(printed.first).to include('needs Lich 5.26.0+ and this is Lich 5.25.1. Installing the newest version this Lich can run instead')
        expect(printed.last).to eq('[lich5-update: foo.lic has been updated from Core Scripts.]')
      end

      it 'replaces an installed copy of the newest version instead of calling it up to date' do
        File.binwrite(live_path, newest)

        updater.update_file_from_repo('script', 'scripts', 'foo.lic')

        expect(File.binread(live_path)).to eq(compatible)
        expect(printed.grep(/already up to date/)).to be_empty
        expect(client).not_to have_received(:http_get).with('https://raw.githubusercontent.com/elanthia-online/scripts/master/scripts/foo.lic', auth: false)
      end

      it 'still calls an installed copy of the newest version up to date when the running Lich can run it' do
        stub_const('LICH_VERSION', '5.26.0')
        File.binwrite(live_path, newest)

        updater.update_file_from_repo('script', 'scripts', 'foo.lic')

        expect(printed).to eq(['[lich5-update: foo.lic is already up to date.]'])
      end

      it 'refuses when no version in the history can run here' do
        history.replace([newest])

        updater.update_file_from_repo('script', 'scripts', 'foo.lic')

        expect(File.exist?(live_path)).to be(false)
        expect(printed.last).to include('No older version that runs on this Lich was found (1 checked), so foo.lic was not installed.')
        expect(printed.grep(/has been updated/)).to be_empty
      end

      it 'holds a repo that the login sync does not floor-check to the same rule' do
        stub_repo('elanthia-online/dr-scripts', 'main', 'foo.lic')
        allow(client).to receive(:fetch_github_json)
          .with(Lich::Util::Update::SCRIPT_REPOS['dr-scripts'][:api_url])
          .and_return({ 'tree' => [{ 'path' => 'foo.lic', 'type' => 'blob', 'sha' => git_blob_sha(newest) }] })

        updater.update_file_from_repo('script', 'dr-scripts', 'foo.lic')

        expect(File.binread(live_path)).to eq(compatible)
      end

      it 'installs nothing from a custom repo, whose history is not searched' do
        allow(Lich::Util::Update::CustomRepos).to receive(:all).and_return({ 'me/repo' => { 'branch' => 'dev' } })
        commits_url = stub_repo('me/repo', 'dev', 'foo.lic')
        allow(client).to receive(:fetch_github_json)
          .with('https://api.github.com/repos/me/repo/git/trees/dev?recursive=1')
          .and_return({ 'tree' => [{ 'path' => 'foo.lic', 'type' => 'blob', 'sha' => git_blob_sha(newest) }] })

        updater.update_file_from_repo('script', 'me/repo', 'foo.lic')

        expect(File.exist?(File.join(tmpdir, 'custom', 'me-repo', 'foo.lic'))).to be(false)
        expect(client).not_to have_received(:fetch_github_json).with(commits_url)
        expect(printed).to eq(
          ['[lich5-update: The newest foo.lic needs Lich 5.26.0+ and this is Lich 5.25.1, so foo.lic was not installed. Update Lich to use it.]']
        )
      end
    end
  end

  describe '#update_file beta library when no beta ref resolves' do
    let(:printed) { [] }

    before do
      allow(updater).to receive(:respond) { |msg = ''| printed << msg }
      allow(Lich::Util::Update::StatusReporter).to receive(:respond_mono) { |msg| printed << msg }
      allow(resolver).to receive(:resolve_channel_ref).with(:beta).and_return(nil)
    end

    it 'reports a GitHub failure instead of claiming no beta exists' do
      allow(resolver).to receive(:last_error).and_return(Lich::Util::Update::FetchError.new(kind: :network))

      updater.update_file('library', 'foo.rb', 'beta')

      expect(printed).to eq(['[lich5-update: GitHub check failed. No beta update was installed. This is usually temporary; run the command again in a few minutes.]'])
    end

    it 'still says no viable beta when GitHub answered' do
      allow(resolver).to receive(:last_error).and_return(nil)

      updater.update_file('library', 'foo.rb', 'beta')

      expect(printed).to eq(['No viable beta found. Aborting beta update.'])
    end
  end

  describe '#update_file legacy download' do
    let(:printed) { [] }
    let(:live_path) { File.join(tmpdir, 'foo.lic') }
    let(:url) { 'https://raw.githubusercontent.com/elanthia-online/scripts/master/scripts/foo.lic' }
    let(:mono) { [] }

    before do
      allow(updater).to receive(:respond) { |msg = ''| printed << msg }
      allow(Lich::Util::Update::StatusReporter).to receive(:respond_mono) { |msg| mono << msg }
      File.binwrite(live_path, "# foo v1\n")
    end

    def fail_download(kind, status = nil)
      allow(client).to receive(:http_get).with(url, auth: false).and_return(nil)
      allow(client).to receive(:last_error).and_return(Lich::Util::Update::FetchError.new(kind: kind, status: status))
    end

    it 'downloads through the GitHub client, without the token' do
      allow(client).to receive(:http_get).and_return("# foo v2\n")

      updater.update_file('script', 'foo.lic')

      expect(client).to have_received(:http_get).with(url, auth: false).once
    end

    it 'keeps the live file in place for the whole download' do
      seen_during_download = nil
      allow(client).to receive(:http_get).with(url, auth: false) do
        seen_during_download = File.exist?(live_path) ? File.binread(live_path) : :missing
        "# foo v2\n"
      end

      updater.update_file('script', 'foo.lic')

      expect(seen_during_download).to eq("# foo v1\n")
      expect(File.binread(live_path)).to eq("# foo v2\n")
      expect(Dir.children(tmpdir)).to eq(['foo.lic'])
      expect(printed).to include('foo.lic has been updated.')
    end

    it 'reports a network failure as a GitHub failure and leaves the existing file untouched' do
      fail_download(:network)

      updater.update_file('script', 'foo.lic')

      expect(File.binread(live_path)).to eq("# foo v1\n")
      expect(Dir.children(tmpdir)).to eq(['foo.lic'])
      expect(mono).to eq(['[lich5-update: GitHub check failed. foo.lic was not updated. This is usually temporary; run the command again in a few minutes.]'])
      expect(printed.grep(/not available via lich5-update|has been updated/)).to be_empty
    end

    it 'reports a rate limit as a rate limit, not as a missing file' do
      fail_download(:rate_limited, 429)

      updater.update_file('script', 'foo.lic')

      expect(mono.grep(/rate limit reached.*foo\.lic was not updated/).size).to eq(1)
      expect(printed.grep(/not available via lich5-update/)).to be_empty
    end

    it 'tells the user a file the repository does not have is not available' do
      fail_download(:not_found, 404)

      updater.update_file('script', 'foo.lic')

      expect(File.binread(live_path)).to eq("# foo v1\n")
      expect(mono).to be_empty
      expect(printed).to include('The existing foo.lic was left unchanged.')
      expect(printed).to include('The filename foo.lic is not available via lich5-update.')
    end

    it 'does not claim a file was left unchanged when there was none' do
      File.delete(live_path)
      fail_download(:not_found, 404)

      updater.update_file('script', 'foo.lic')

      expect(Dir.children(tmpdir)).to be_empty
      expect(printed.grep(/left unchanged/)).to be_empty
      expect(printed).to include('The filename foo.lic is not available via lich5-update.')
    end

    it 'reports a name that cannot form a URL as not available, without a request' do
      allow(client).to receive(:http_get)

      updater.update_file('script', 'f oo.lic')

      expect(client).not_to have_received(:http_get)
      expect(mono).to be_empty
      expect(printed).to include('The filename f oo.lic is not available via lich5-update.')
    end

    it 'says the next login fixes a failure only when the login sync fetches the file again' do
      allow(client).to receive(:http_get).and_return(nil)
      allow(client).to receive(:last_error).and_return(Lich::Util::Update::FetchError.new(kind: :network))

      updater.update_file('data', 'effect-list.xml', retried_by: :login)

      expect(mono).to eq(['[lich5-update: GitHub check failed. effect-list.xml was not updated. This is a temporary error that should resolve itself by your next login.]'])
    end

    ['./foo.lic', '../scripts/foo.lic', 'sub//foo.lic', '/foo.lic', '..\\foo.lic'].each do |name|
      it "refuses #{name.inspect} as not available, without a request or a write outside the directory" do
        allow(client).to receive(:http_get)

        updater.update_file('script', name)

        expect(client).not_to have_received(:http_get)
        expect(mono).to be_empty
        expect(printed).to include("The filename #{name} is not available via lich5-update.")
        expect(Dir.children(tmpdir)).to eq(['foo.lic'])
      end
    end

    it 'still downloads a library file from a subdirectory of lib' do
      stub_const('LIB_DIR', tmpdir)
      FileUtils.mkdir_p(File.join(tmpdir, 'common'))
      allow(resolver).to receive(:resolve_channel_ref).with(:stable).and_return('main')
      allow(client).to receive(:http_get).and_return("# spell v2\n")

      updater.update_file('library', 'common/spell.rb')

      expect(client).to have_received(:http_get)
        .with("https://raw.githubusercontent.com/#{Lich::Util::Update::GITHUB_REPO}/main/lib/common/spell.rb", auth: false)
      expect(File.binread(File.join(tmpdir, 'common', 'spell.rb'))).to eq("# spell v2\n")
    end

    it 'reports a library channel with no remote as not available instead of raising' do
      stub_const('LIB_DIR', tmpdir)
      allow(client).to receive(:http_get)

      expect { updater.update_file('library', 'foo.rb', 'nightly') }.not_to raise_error

      expect(client).not_to have_received(:http_get)
      expect(printed).to include('The filename foo.rb is not available via lich5-update.')
    end

    it 'leaves the existing file untouched when the write fails, without blaming the name' do
      allow(client).to receive(:http_get).and_return("# foo v2\n")
      allow(File).to receive(:rename).and_raise(Errno::EACCES.new('Permission denied'))

      updater.update_file('script', 'foo.lic')

      expect(File.binread(live_path)).to eq("# foo v1\n")
      expect(Dir.children(tmpdir)).to eq(['foo.lic'])
      expect(printed.grep(/\AError updating foo\.lic: Errno::EACCES/).size).to eq(1)
      expect(printed).to include('The existing foo.lic was left unchanged.')
      expect(printed.grep(/not available via lich5-update/)).to be_empty
    end

    it 'removes a .old file left by an interrupted older update' do
      File.delete(live_path)
      File.binwrite("#{live_path}.old", "# foo v1\n")
      allow(client).to receive(:http_get).and_return("# foo v2\n")

      updater.update_file('script', 'foo.lic')

      expect(File.binread(live_path)).to eq("# foo v2\n")
      expect(Dir.children(tmpdir)).to eq(['foo.lic'])
    end
  end
end
