# frozen_string_literal: true

require_relative 'update_spec_helper'

RSpec.describe Lich::Util::Update::TrackedScripts do
  let(:tmpdir) { Dir.mktmpdir('ts-test') }
  let(:client) { instance_double(Lich::Util::Update::GitHubClient) }
  let(:tracker) { described_class.new(client) }

  before do
    stub_const('SCRIPT_DIR', tmpdir)
    UserVars.tracked_scripts = nil
    allow(Lich::Util::Update::StatusReporter).to receive(:respond_mono)
    allow(Vars).to receive(:save)
  end

  after { FileUtils.remove_entry(tmpdir) }

  describe '#tracked_scripts' do
    it 'returns defaults when no user additions' do
      config = { tracking_mode: :explicit, default_tracked: %w[alias.lic go2.lic].freeze }
      result = tracker.tracked_scripts(config)
      expect(result).to contain_exactly('alias.lic', 'go2.lic')
    end

    it 'merges user additions with defaults' do
      UserVars.tracked_scripts = { 'scripts' => ['bigshot.lic'] }
      scripts_config = Lich::Util::Update::SCRIPT_REPOS['scripts']
      result = tracker.tracked_scripts(scripts_config)
      expect(result).to include('alias.lic', 'go2.lic', 'bigshot.lic')
    end

    it 'deduplicates defaults and user additions' do
      UserVars.tracked_scripts = { 'scripts' => ['alias.lic', 'custom.lic'] }
      config = Lich::Util::Update::SCRIPT_REPOS['scripts']

      result = tracker.tracked_scripts(config)

      expect(result.count('alias.lic')).to eq(1)
      expect(result).to include('custom.lic')
    end
  end

  describe '#untrack_script shows file-on-disk notice when file exists' do
    it 'warns user that untracked file is still installed' do
      File.binwrite(File.join(tmpdir, 'bigshot.lic'), '# bigshot')
      UserVars.tracked_scripts = { 'scripts' => ['bigshot.lic'] }

      tracker.untrack_script('scripts', 'bigshot.lic')

      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with(/Removed.*bigshot\.lic/)
      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with(/still installed.*Delete manually/)
    end
  end

  describe '#untrack_script omits notice when file is not on disk' do
    it 'does not show file-on-disk warning' do
      UserVars.tracked_scripts = { 'scripts' => ['ghost.lic'] }

      tracker.untrack_script('scripts', 'ghost.lic')

      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with(/Removed.*ghost\.lic/)
      expect(Lich::Util::Update::StatusReporter).not_to have_received(:respond_mono).with(/still installed/)
    end
  end

  describe '#untrack_script refuses to remove default scripts' do
    it 'blocks removal of alias.lic from Core Scripts defaults' do
      tracker.untrack_script('scripts', 'alias.lic')

      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with(/default script.*cannot be removed/)
    end
  end

  describe '#untrack_script with unknown repo' do
    it 'does not crash on nonexistent repo key' do
      expect { tracker.untrack_script('fake-repo', 'foo.lic') }.not_to raise_error
    end
  end

  describe '#untrack_script when script was never tracked' do
    it 'reports that script was not in tracked list' do
      UserVars.tracked_scripts = { 'scripts' => [] }

      tracker.untrack_script('scripts', 'never-tracked.lic')

      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with(/was not in your/)
    end
  end

  describe '#track_script into a built-in repo next to DR Scripts' do
    let(:dr_api) { Lich::Util::Update::SCRIPT_REPOS['dr-scripts'][:api_url] }
    let(:dr_tree) do
      { 'tree' => [
        { 'path' => 'alchemy.lic', 'type' => 'blob' },
        { 'path' => 'combat-trainer.lic', 'type' => 'blob' },
        { 'path' => 'foo-setup.lic', 'type' => 'blob' },
        { 'path' => 'profiles/lnet.lic', 'type' => 'blob' }
      ] }
    end

    around do |example|
      saved = XMLData.game
      example.run
    ensure
      XMLData.game = saved
    end

    before { XMLData.game = 'DR' }

    it 'tracks a Core Scripts script already in scripts/ that DR Scripts does not ship' do
      File.binwrite(File.join(tmpdir, 'lnet.lic'), '# lnet from EO/scripts')
      allow(client).to receive(:fetch_github_json).with(dr_api).and_return(dr_tree)

      tracker.track_script('scripts', 'lnet.lic')

      expect(UserVars.tracked_scripts['scripts']).to eq(['lnet.lic'])
      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with(/Added 'lnet\.lic' to Core Scripts/)
      expect(Lich::Util::Update::StatusReporter).not_to have_received(:respond_mono).with(/shadow|Error/)
    end

    it 'blocks a script DR Scripts really ships, whether or not it is on disk' do
      allow(client).to receive(:fetch_github_json).with(dr_api).and_return(dr_tree)

      tracker.track_script('scripts', 'alchemy.lic')

      expect(UserVars.tracked_scripts['scripts']).to eq([])
      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono)
        .with(/Error: 'alchemy\.lic' is also in DR Scripts, which syncs it automatically/)
    end

    it 'does not count a DR Scripts file the sync skips (-setup) as a clash' do
      allow(client).to receive(:fetch_github_json).with(dr_api).and_return(dr_tree)

      tracker.track_script('scripts', 'foo-setup.lic')

      expect(UserVars.tracked_scripts['scripts']).to eq(['foo-setup.lic'])
    end

    it 'does not count a same-named file in a DR Scripts subdirectory as a clash' do
      allow(client).to receive(:fetch_github_json).with(dr_api).and_return(dr_tree)

      tracker.track_script('scripts', 'lnet.lic')

      expect(UserVars.tracked_scripts['scripts']).to eq(['lnet.lic'])
    end

    it 'does not consult DR Scripts at all outside DR' do
      XMLData.game = 'GSIV'
      File.binwrite(File.join(tmpdir, 'alchemy.lic'), '# on disk')
      allow(client).to receive(:fetch_github_json)

      tracker.track_script('scripts', 'alchemy.lic')

      expect(client).not_to have_received(:fetch_github_json)
      expect(UserVars.tracked_scripts['scripts']).to eq(['alchemy.lic'])
    end

    it 'adds nothing and says why when the DR Scripts file list cannot be read' do
      reset = Time.new(2026, 11, 5, 14, 30, 0)
      error = Lich::Util::Update::FetchError.new(kind: :rate_limited, reset_at: reset)
      allow(client).to receive_messages(fetch_github_json: nil, last_error: error)

      tracker.track_script('scripts', 'lnet.lic')

      expect(UserVars.tracked_scripts['scripts']).to eq([])
      expect(Vars).not_to have_received(:save)
      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono)
        .with(/rate limit reached, resets at 14:30\).*Could not check whether DR Scripts also contains 'lnet\.lic', so nothing was added\. Run the command again once the limit resets\./)
    end

    it 'treats a response without a tree as unreadable, not as no clash' do
      allow(client).to receive(:fetch_github_json).with(dr_api).and_return({ 'message' => 'x' })
      allow(client).to receive(:last_error).and_return(nil)

      tracker.track_script('scripts', 'alchemy.lic')

      expect(UserVars.tracked_scripts['scripts']).to eq([])
      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with(
        "[lich5-update: GitHub check failed. Could not check whether DR Scripts also contains 'alchemy.lic', so nothing was added. " \
        'This is usually temporary; run the command again in a few minutes.]'
      )
    end

    it 'ignores the tracked list of a built-in repo that does not sync in DR' do
      allow(client).to receive(:fetch_github_json).with(dr_api).and_return(dr_tree)

      tracker.track_script('scripts', 'ewaggle.lic')

      expect(UserVars.tracked_scripts['scripts']).to eq(['ewaggle.lic'])
      expect(Lich::Util::Update::StatusReporter).not_to have_received(:respond_mono).with(/already tracked in GS Scripts/)
    end

    it 'still counts that tracked list where the repo does sync' do
      XMLData.game = 'GSIV'

      tracker.track_script('scripts', 'ewaggle.lic')

      expect(UserVars.tracked_scripts['scripts']).to eq([])
      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with(/'ewaggle\.lic' is already tracked in GS Scripts/)
    end

    it 'reports a default script as already tracked instead of adding a duplicate' do
      allow(client).to receive(:fetch_github_json)

      tracker.track_script('scripts', 'go2.lic')

      expect(client).not_to have_received(:fetch_github_json)
      expect(UserVars.tracked_scripts['scripts']).to eq([])
      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with(/'go2\.lic' is already tracked in Core Scripts/)
    end
  end
end
