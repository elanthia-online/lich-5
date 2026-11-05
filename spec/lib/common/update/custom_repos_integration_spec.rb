# frozen_string_literal: true

require_relative 'update_spec_helper'

RSpec.describe 'Custom repos integration with TrackedScripts' do
  let(:tmpdir) { Dir.mktmpdir('custom-int-test') }
  let(:client) { instance_double(Lich::Util::Update::GitHubClient) }
  let(:tracker) { Lich::Util::Update::TrackedScripts.new(client) }

  # DR, where DR Scripts syncs and a custom track also checks its file
  # list. Set in before, because spec_helper resets XMLData before each
  # example.
  around do |example|
    saved = XMLData.game
    example.run
  ensure
    XMLData.game = saved
  end

  let(:dr_api) { Lich::Util::Update::SCRIPT_REPOS['dr-scripts'][:api_url] }

  before do
    XMLData.game = 'DR'
    allow(client).to receive(:fetch_github_json).with(dr_api).and_return({ 'tree' => [{ 'path' => 'alchemy.lic', 'type' => 'blob' }] })
    # Every custom repo here has these top-level scripts.
    custom_tree = { 'tree' => %w[foo.lic alchemy.lic tool.lic new-script.lic something.lic conflict.lic].map { |f| { 'path' => f, 'type' => 'blob' } } }
    allow(client).to receive(:fetch_github_json).with(%r{/repos/(?!elanthia-online/)[^/]+/[^/]+/git/trees/}).and_return(custom_tree)
    stub_const('SCRIPT_DIR', tmpdir)
    UserVars.custom_repos = nil
    UserVars.tracked_scripts = nil
    allow(Lich::Util::Update::StatusReporter).to receive(:respond_mono)
    allow(Vars).to receive(:save)
  end

  after { FileUtils.remove_entry(tmpdir) }

  describe '#track_script with custom repo' do
    it 'tracks a script in a registered custom repo' do
      UserVars.custom_repos = { 'MahtraDR/dr-scripts' => { 'branch' => 'main' } }

      tracker.track_script('MahtraDR/dr-scripts', 'foo.lic')

      expect(UserVars.tracked_scripts['MahtraDR/dr-scripts']).to include('foo.lic')
      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with(/Added.*foo\.lic/)
    end

    it 'rejects tracking in unregistered custom repo' do
      allow(tracker).to receive(:respond)

      tracker.track_script('unknown/repo', 'foo.lic')

      expect(tracker).to have_received(:respond).with(/Unknown repository/)
      expect(UserVars.tracked_scripts).to be_nil
    end
  end

  describe '#tracked_scripts identity resolution' do
    it 'resolves custom repo scripts by key, not config equality' do
      UserVars.custom_repos = { 'MahtraDR/test' => { 'branch' => 'dev' } }
      UserVars.tracked_scripts = { 'MahtraDR/test' => ['my-script.lic'] }

      config = Lich::Util::Update::CustomRepos.build_config('MahtraDR/test', { 'branch' => 'dev' })
      result = tracker.tracked_scripts(config, repo_key: 'MahtraDR/test')

      expect(result).to include('my-script.lic')
    end

    it 'still resolves when non-identity config fields differ' do
      UserVars.custom_repos = { 'MahtraDR/test' => { 'branch' => 'dev' } }
      UserVars.tracked_scripts = { 'MahtraDR/test' => ['my-script.lic'] }

      config = Lich::Util::Update::CustomRepos.build_config('MahtraDR/test', { 'branch' => 'dev' })
      config[:some_new_field] = 'added later'

      result = tracker.tracked_scripts(config, repo_key: 'MahtraDR/test')

      expect(result).to include('my-script.lic')
    end

    it 'would fail to resolve custom repo without explicit key' do
      UserVars.custom_repos = { 'MahtraDR/test' => { 'branch' => 'dev' } }
      UserVars.tracked_scripts = { 'MahtraDR/test' => ['my-script.lic'] }

      config = Lich::Util::Update::CustomRepos.build_config('MahtraDR/test', { 'branch' => 'dev' })
      result = tracker.tracked_scripts(config)

      expect(result).not_to include('my-script.lic')
    end
  end

  describe '#untrack_script with custom repo' do
    it 'untracks a script from a custom repo' do
      UserVars.custom_repos = { 'MahtraDR/dr-scripts' => { 'branch' => 'main' } }
      UserVars.tracked_scripts = { 'MahtraDR/dr-scripts' => ['foo.lic'] }

      tracker.untrack_script('MahtraDR/dr-scripts', 'foo.lic')

      expect(UserVars.tracked_scripts['MahtraDR/dr-scripts']).not_to include('foo.lic')
      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with(/Removed.*foo\.lic/)
    end

    it 'checks custom dest_dir for installed file notice' do
      UserVars.custom_repos = { 'MahtraDR/dr-scripts' => { 'branch' => 'main' } }
      UserVars.tracked_scripts = { 'MahtraDR/dr-scripts' => ['foo.lic'] }
      dest = Lich::Util::Update::CustomRepos.dest_dir('MahtraDR/dr-scripts')
      FileUtils.mkdir_p(dest)
      File.binwrite(File.join(dest, 'foo.lic'), '# test')

      tracker.untrack_script('MahtraDR/dr-scripts', 'foo.lic')

      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with(/still installed/)
    end
  end

  describe '#check_collision' do
    it 'blocks a custom track over any script in scripts/, from the disk alone' do
      client = instance_double(Lich::Util::Update::GitHubClient)
      tracker = Lich::Util::Update::TrackedScripts.new(client)
      File.binwrite(File.join(tmpdir, 'lnet.lic'), '# from Core Scripts, not DR Scripts')

      result = tracker.check_collision('lnet.lic', 'MahtraDR/custom')

      expect(result).to match(/Error:.*'lnet\.lic' is already installed in scripts\/.*shadow/)
      expect(result).not_to match(/DR Scripts/)
    end

    it 'refuses a custom track of a script DR Scripts ships, before the sync has installed it' do
      UserVars.custom_repos = { 'MahtraDR/test' => { 'branch' => 'main' } }

      tracker.track_script('MahtraDR/test', 'alchemy.lic')

      expect(UserVars.tracked_scripts).to be_nil
      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with(
        "[lich5-update: Error: 'alchemy.lic' is also in DR Scripts, which syncs it automatically. The custom version would shadow it at runtime.]"
      )
    end

    it 'does not read the DR Scripts file list for a custom track outside DR' do
      XMLData.game = 'GSIV'
      UserVars.custom_repos = { 'MahtraDR/test' => { 'branch' => 'main' } }

      tracker.track_script('MahtraDR/test', 'alchemy.lic')

      expect(client).not_to have_received(:fetch_github_json).with(dr_api)
      expect(UserVars.tracked_scripts['MahtraDR/test']).to eq(['alchemy.lic'])
    end

    it 'refuses a custom track when the DR Scripts file list cannot be read' do
      UserVars.custom_repos = { 'MahtraDR/test' => { 'branch' => 'main' } }
      allow(client).to receive(:fetch_github_json).with(dr_api).and_return(nil)
      allow(client).to receive(:last_error).and_return(nil)

      tracker.track_script('MahtraDR/test', 'tool.lic')

      expect(UserVars.tracked_scripts).to be_nil
      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with(/Could not check whether DR Scripts also contains 'tool\.lic'/)
    end

    it 'blocks a custom track over a file already in scripts/' do
      File.binwrite(File.join(tmpdir, 'anything.lic'), '# existing')

      result = tracker.check_collision('anything.lic', 'MahtraDR/custom')

      expect(result).to match(/Error:.*already installed in scripts\//)
    end

    it 'allows a custom track when the name is not in scripts/ and DR Scripts does not ship it' do
      result = tracker.check_collision('not-installed.lic', 'MahtraDR/custom')

      expect(result).to be_nil
    end

    it 'detects collision with built-in explicit repo (excluding :all repos)' do
      UserVars.tracked_scripts = { 'scripts' => ['bigshot.lic'] }
      # Exclude dr-scripts from check to test explicit repo collision
      result = tracker.check_collision('bigshot.lic', 'dr-scripts')

      expect(result).to match(/already tracked.*Core Scripts/)
    end

    it 'detects collision between custom repos' do
      UserVars.custom_repos = {
        'Repo1/scripts' => { 'branch' => 'main' },
        'Repo2/scripts' => { 'branch' => 'main' }
      }
      UserVars.tracked_scripts = { 'Repo1/scripts' => ['conflict.lic'] }

      result = tracker.check_collision('conflict.lic', 'Repo2/scripts')

      expect(result).to match(/Error:.*already tracked.*Repo1\/scripts/)
    end

    it 'returns nil when no collision exists' do
      result = tracker.check_collision('unique-script.lic', 'dr-scripts')

      expect(result).to be_nil
    end

    it 'looks for the shadowed file in scripts/ itself' do
      File.binwrite(File.join(tmpdir, 'common.lic'), '# installed in scripts/')

      result = tracker.check_collision('common.lic', 'MahtraDR/custom')

      expect(result).to match(/Error:.*already installed in scripts\//)
      expect(result).to match(/shadow/)
    end

    it 'refuses a custom track over a file already in scripts/' do
      UserVars.custom_repos = { 'MahtraDR/test' => { 'branch' => 'main' } }
      File.binwrite(File.join(tmpdir, 'something.lic'), '# installed in scripts/')

      tracker.track_script('MahtraDR/test', 'something.lic')

      expect(UserVars.tracked_scripts).to be_nil
      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with(/Error:.*already installed in scripts\//)
    end

    it 'adds a custom track when the name is not in scripts/' do
      UserVars.custom_repos = { 'MahtraDR/test' => { 'branch' => 'main' } }

      tracker.track_script('MahtraDR/test', 'new-script.lic')

      expect(UserVars.tracked_scripts['MahtraDR/test']).to include('new-script.lic')
    end

    it 'blocks track when collision with another custom repo' do
      UserVars.custom_repos = {
        'Repo1/scripts' => { 'branch' => 'main' },
        'Repo2/scripts' => { 'branch' => 'main' }
      }
      UserVars.tracked_scripts = { 'Repo1/scripts' => ['conflict.lic'] }

      tracker.track_script('Repo2/scripts', 'conflict.lic')

      expect(UserVars.tracked_scripts['Repo2/scripts']).to be_nil
      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with(/Error:.*already tracked.*Repo1/)
    end
  end

  describe '#show_tracked with custom repos' do
    it 'includes custom repos in the display' do
      UserVars.custom_repos = { 'MahtraDR/dr-scripts' => { 'branch' => 'main' } }
      UserVars.tracked_scripts = { 'MahtraDR/dr-scripts' => ['foo.lic'] }

      tracker.show_tracked

      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with(/Custom: MahtraDR\/dr-scripts/)
    end

    it 'shows specific custom repo when requested' do
      UserVars.custom_repos = { 'MahtraDR/dr-scripts' => { 'branch' => 'main' } }
      UserVars.tracked_scripts = { 'MahtraDR/dr-scripts' => ['foo.lic'] }

      tracker.show_tracked('MahtraDR/dr-scripts')

      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with(/Custom: MahtraDR\/dr-scripts/)
    end

    it 'shows empty message for custom repo with no tracked scripts' do
      UserVars.custom_repos = { 'MahtraDR/dr-scripts' => { 'branch' => 'main' } }

      tracker.show_tracked('MahtraDR/dr-scripts')

      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with(/No scripts tracked/)
    end
  end
end

RSpec.describe 'Custom repos integration with ScriptSync' do
  let(:tmpdir) { Dir.mktmpdir('custom-sync-test') }
  let(:client) { instance_double(Lich::Util::Update::GitHubClient) }
  let(:sync) { Lich::Util::Update::ScriptSync.new(client) }

  before do
    stub_const('SCRIPT_DIR', tmpdir)
    UserVars.custom_repos = nil
    UserVars.tracked_scripts = nil
    allow(Lich::Util::Update::StatusReporter).to receive(:respond_mono)
    allow(Lich::Util::Update::StatusReporter).to receive(:render_sync_summary)
  end

  after { FileUtils.remove_entry(tmpdir) }

  describe '#sync_all_repos includes custom repos' do
    it 'syncs both built-in and custom repos' do
      UserVars.custom_repos = { 'MahtraDR/test' => { 'branch' => 'main' } }
      UserVars.tracked_scripts = { 'MahtraDR/test' => ['foo.lic'] }

      tree = { 'tree' => [{ 'path' => 'foo.lic', 'type' => 'blob', 'sha' => 'abc123' }] }
      allow(client).to receive(:fetch_github_json).and_return(tree)
      allow(client).to receive(:http_get).and_return('# content')
      allow(Lich::Util::Update::FileWriter).to receive(:safe_write) do |path, content|
        FileUtils.mkdir_p(File.dirname(path))
        File.binwrite(path, content)
      end

      sync.sync_all_repos

      # Should have been called for built-in repos + custom repo
      expect(Lich::Util::Update::StatusReporter).to have_received(:render_sync_summary).with(
        'Custom: MahtraDR/test', anything, anything, anything, anything, anything, anything, anything, missing_tracked: []
      )
    end
  end

  describe '#sync_repo with custom repo' do
    it 'syncs to per-repo subdirectory under custom/' do
      UserVars.custom_repos = { 'MahtraDR/test' => { 'branch' => 'main' } }
      UserVars.tracked_scripts = { 'MahtraDR/test' => ['my-script.lic'] }

      tree = { 'tree' => [{ 'path' => 'my-script.lic', 'type' => 'blob', 'sha' => 'abc123' }] }
      allow(client).to receive(:fetch_github_json).and_return(tree)
      allow(client).to receive(:http_get)
        .with('https://raw.githubusercontent.com/MahtraDR/test/main/my-script.lic', auth: false)
        .and_return('# my script content')
      allow(Lich::Util::Update::FileWriter).to receive(:safe_write) do |path, content|
        FileUtils.mkdir_p(File.dirname(path))
        File.binwrite(path, content)
      end

      sync.sync_repo('MahtraDR/test')

      expected_path = File.join(tmpdir, 'custom', 'MahtraDR-test', 'my-script.lic')
      expect(File.exist?(expected_path)).to be true
      expect(File.read(expected_path)).to eq('# my script content')
    end

    it 'reports unknown for unregistered custom repo' do
      allow(sync).to receive(:respond)

      sync.sync_repo('unknown/repo')

      expect(sync).to have_received(:respond).with(/Unknown repository/)
    end

    it 'skips files with matching SHA' do
      UserVars.custom_repos = { 'MahtraDR/test' => { 'branch' => 'main' } }
      UserVars.tracked_scripts = { 'MahtraDR/test' => ['current.lic'] }

      dest = Lich::Util::Update::CustomRepos.dest_dir('MahtraDR/test')
      FileUtils.mkdir_p(dest)
      existing_content = "# already installed\n"
      File.binwrite(File.join(dest, 'current.lic'), existing_content)
      local_sha = Digest::SHA1.hexdigest("blob #{existing_content.bytesize}\0#{existing_content}")

      tree = { 'tree' => [{ 'path' => 'current.lic', 'type' => 'blob', 'sha' => local_sha }] }
      allow(client).to receive(:fetch_github_json).and_return(tree)

      expect(client).not_to receive(:http_get)
      sync.sync_repo('MahtraDR/test')
    end
  end
end

RSpec.describe 'Custom repos integration with FileUpdater' do
  let(:tmpdir) { Dir.mktmpdir('custom-file-updater-test') }
  let(:client) { instance_double(Lich::Util::Update::GitHubClient) }
  let(:resolver) { instance_double(Lich::Util::Update::ChannelResolver) }
  let(:snapshot_manager) { instance_double(Lich::Util::Update::SnapshotManager) }
  let(:updater) { Lich::Util::Update::FileUpdater.new(client, resolver, snapshot_manager) }

  before do
    stub_const('SCRIPT_DIR', tmpdir)
    UserVars.custom_repos = nil
    allow(updater).to receive(:respond)
  end

  after { FileUtils.remove_entry(tmpdir) }

  it 'rejects data downloads from custom repos' do
    UserVars.custom_repos = { 'MahtraDR/test' => { 'branch' => 'main' } }

    updater.update_file_from_repo('data', 'MahtraDR/test', 'some-file.yaml')

    expect(updater).to have_received(:respond).with(/not supported for custom repos/)
  end
end
