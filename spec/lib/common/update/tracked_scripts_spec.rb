# frozen_string_literal: true

require_relative 'update_spec_helper'

RSpec.describe Lich::Util::Update::TrackedScripts do
  let(:tmpdir) { Dir.mktmpdir('ts-test') }
  let(:client) { instance_double(Lich::Util::Update::GitHubClient) }
  let(:tracker) { described_class.new(client) }

  # A game no built-in repo filters for, so examples that do not set one
  # behave the same alone and in the full suite. Examples that need DR or
  # GemStone set it in their own before.
  around do |example|
    saved = XMLData.game
    example.run
  ensure
    XMLData.game = saved
  end

  before do
    XMLData.game = 'rspec'
    stub_const('SCRIPT_DIR', tmpdir)
    UserVars.tracked_scripts = nil
    UserVars.custom_repos = nil
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
    let(:core_api) { Lich::Util::Update::SCRIPT_REPOS['scripts'][:api_url] }
    let(:core_tree) do
      { 'tree' => %w[lnet.lic alchemy.lic foo-setup.lic ewaggle.lic].map { |f| { 'path' => "scripts/#{f}", 'type' => 'blob' } } }
    end

    before do
      XMLData.game = 'DR'
      allow(client).to receive(:fetch_github_json).with(core_api).and_return(core_tree)
    end

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

      expect(UserVars.tracked_scripts&.dig('scripts')).to be_nil
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
      allow(client).to receive(:fetch_github_json).with(dr_api)

      tracker.track_script('scripts', 'alchemy.lic')

      expect(client).not_to have_received(:fetch_github_json).with(dr_api)
      expect(UserVars.tracked_scripts['scripts']).to eq(['alchemy.lic'])
    end

    it 'adds nothing and says why when the DR Scripts file list cannot be read' do
      reset = Time.new(2026, 11, 5, 14, 30, 0)
      error = Lich::Util::Update::FetchError.new(kind: :rate_limited, reset_at: reset)
      allow(client).to receive(:fetch_github_json).with(dr_api).and_return(nil)
      allow(client).to receive(:last_error).and_return(error)

      tracker.track_script('scripts', 'lnet.lic')

      expect(UserVars.tracked_scripts&.dig('scripts')).to be_nil
      expect(Vars).not_to have_received(:save)
      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono)
        .with(/rate limit reached, resets at 14:30\).*Could not check whether DR Scripts also contains 'lnet\.lic', so nothing was added\. Run the command again once the limit resets\./)
    end

    it 'treats a response without a tree as unreadable, not as no clash' do
      allow(client).to receive(:fetch_github_json).with(dr_api).and_return({ 'message' => 'x' })
      allow(client).to receive(:last_error).and_return(nil)

      tracker.track_script('scripts', 'alchemy.lic')

      expect(UserVars.tracked_scripts&.dig('scripts')).to be_nil
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

      expect(UserVars.tracked_scripts&.dig('scripts')).to be_nil
      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with(/'ewaggle\.lic' is already tracked in GS Scripts/)
    end

    it 'says the next sync replaces a file already in scripts/' do
      File.binwrite(File.join(tmpdir, 'lnet.lic'), '# hand-edited copy')
      allow(client).to receive(:fetch_github_json).with(dr_api).and_return(dr_tree)

      tracker.track_script('scripts', 'lnet.lic')

      expect(UserVars.tracked_scripts['scripts']).to eq(['lnet.lic'])
      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with(
        "[lich5-update: Added 'lnet.lic' to Core Scripts tracked list. scripts/lnet.lic already exists; " \
        'the next sync replaces it with the Core Scripts copy if they differ.]'
      )
    end

    it 'adds no such note when the file is not in scripts/' do
      allow(client).to receive(:fetch_github_json).with(dr_api).and_return(dr_tree)

      tracker.track_script('scripts', 'lnet.lic')

      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with("[lich5-update: Added 'lnet.lic' to Core Scripts tracked list.]")
    end

    it 'reports a default script as already tracked instead of adding a duplicate' do
      allow(client).to receive(:fetch_github_json)

      tracker.track_script('scripts', 'go2.lic')

      expect(client).not_to have_received(:fetch_github_json)
      expect(UserVars.tracked_scripts&.dig('scripts')).to be_nil
      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with(/'go2\.lic' is already tracked in Core Scripts/)
    end
  end

  describe 'tracks into a repo that never installs a tracked script here' do
    let(:dr_api) { Lich::Util::Update::SCRIPT_REPOS['dr-scripts'][:api_url] }
    let(:dr_tree) { { 'tree' => [{ 'path' => 'alchemy.lic', 'type' => 'blob' }] } }
    let(:core_api) { Lich::Util::Update::SCRIPT_REPOS['scripts'][:api_url] }

    before do
      XMLData.game = 'DR'
      allow(client).to receive(:fetch_github_json).with(core_api)
                                                  .and_return({ 'tree' => %w[lnet.lic alchemy.lic].map { |f| { 'path' => "scripts/#{f}", 'type' => 'blob' } } })
    end

    it 'does not point at Core Scripts for a name Core Scripts does not contain' do
      allow(client).to receive(:fetch_github_json).with(dr_api).and_return(dr_tree)

      tracker.track_script('gs-scripts', 'nosuch.lic')
      tracker.track_script('gs-scripts', 'LNET.lic')

      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with(
        '[lich5-update: GS Scripts is not synced for DR characters, so tracking it here would never install anything. Nothing was added. ' \
        "Core Scripts, which reads the same repository, cannot track it either: 'nosuch.lic' is not in Core Scripts.]"
      )
      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono)
        .with(/cannot track it either: 'LNET\.lic' is not in Core Scripts\. Did you mean 'lnet\.lic'\?\]/)
      expect(Lich::Util::Update::StatusReporter).not_to have_received(:respond_mono).with(/--track=scripts/)
    end

    it 'refuses DR Scripts, which syncs everything and ignores a tracked list' do
      tracker.track_script('dr-scripts', 'lnet.lic')

      expect(UserVars.tracked_scripts).to be_nil
      expect(Vars).not_to have_received(:save)
      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono)
        .with('[lich5-update: DR Scripts syncs its scripts automatically (all except -setup files), so it has no tracked list. Nothing was added.]')
    end

    it 'refuses GS Scripts on a DR character and points at Core Scripts' do
      allow(client).to receive(:fetch_github_json).with(dr_api).and_return(dr_tree)

      tracker.track_script('gs-scripts', 'lnet.lic')

      expect(UserVars.tracked_scripts).to be_nil
      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with(
        '[lich5-update: GS Scripts is not synced for DR characters, so tracking it here would never install anything. ' \
        "Nothing was added. To track it from the same repository, use #{$clean_lich_char}lich5-update --track=scripts:lnet.lic]"
      )
    end

    it 'does not point at Core Scripts for a file DR Scripts also ships, and says why' do
      allow(client).to receive(:fetch_github_json).with(dr_api).and_return(dr_tree)

      tracker.track_script('gs-scripts', 'alchemy.lic')

      expect(UserVars.tracked_scripts).to be_nil
      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with(
        '[lich5-update: GS Scripts is not synced for DR characters, so tracking it here would never install anything. Nothing was added. ' \
        "Core Scripts, which reads the same repository, cannot track it either: 'alchemy.lic' is also in DR Scripts, which syncs it " \
        'automatically. Tracking it here would make the two overwrite each other.]'
      )
      expect(Lich::Util::Update::StatusReporter).not_to have_received(:respond_mono).with(/--track=scripts/)
    end

    it 'says Core Scripts already tracks a default instead of suggesting a track it refuses' do
      allow(client).to receive(:fetch_github_json)

      tracker.track_script('gs-scripts', 'go2.lic')

      expect(client).not_to have_received(:fetch_github_json)
      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with(
        '[lich5-update: GS Scripts is not synced for DR characters, so tracking it here would never install anything. Nothing was added. ' \
        "Core Scripts, which reads the same repository, already tracks 'go2.lic' on this character.]"
      )
    end

    it 'says it could not check Core Scripts when GitHub cannot be reached' do
      allow(client).to receive(:fetch_github_json).with(dr_api).and_return(nil)
      allow(client).to receive(:last_error).and_return(nil)

      tracker.track_script('gs-scripts', 'lnet.lic')

      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono)
        .with('[lich5-update: GS Scripts is not synced for DR characters, so tracking it here would never install anything. Nothing was added. ' \
              'Could not check whether Core Scripts, which reads the same repository, can track it instead.]')
    end

    it 'tells a GemStone character DR Scripts is not synced, not that it syncs everything' do
      XMLData.game = 'GSIV'

      tracker.track_script('dr-scripts', 'lnet.lic')

      expect(UserVars.tracked_scripts).to be_nil
      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono)
        .with('[lich5-update: DR Scripts is not synced for GSIV characters, so tracking it here would never install anything. Nothing was added.]')
    end

    it 'still tracks GS Scripts on a GemStone character' do
      XMLData.game = 'GSIV'
      allow(client).to receive(:fetch_github_json).with(Lich::Util::Update::SCRIPT_REPOS['gs-scripts'][:api_url])
                                                  .and_return({ 'tree' => [{ 'path' => 'scripts/lnet.lic', 'type' => 'blob' }] })

      tracker.track_script('gs-scripts', 'lnet.lic')

      expect(UserVars.tracked_scripts['gs-scripts']).to eq(['lnet.lic'])
    end

    it 'gives no hint when no repo that syncs here reads the same files' do
      repos = Lich::Util::Update::SCRIPT_REPOS.merge(
        'odd' => { display_name: 'Odd', api_url: 'https://example.invalid/odd', tracking_mode: :explicit, game_filter: /^GS/, default_tracked: [] }
      )
      stub_const('Lich::Util::Update::SCRIPT_REPOS', repos)

      tracker.track_script('odd', 'x.lic')

      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono)
        .with('[lich5-update: Odd is not synced for DR characters, so tracking it here would never install anything. Nothing was added.]')
    end

    it 'does not break when the game is not known yet' do
      XMLData.game = nil

      tracker.track_script('gs-scripts', 'lnet.lic')

      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with(/GS Scripts is not synced for this game,/)
    end
  end

  describe 'cleaning up after the old --track' do
    let(:dr_api) { Lich::Util::Update::SCRIPT_REPOS['dr-scripts'][:api_url] }
    before { XMLData.game = 'DR' }

    it 'removes a leftover DR Scripts entry and does not tell the user to delete the file' do
      UserVars.tracked_scripts = { 'dr-scripts' => ['lnet.lic'], 'scripts' => ['lnet.lic'] }
      File.binwrite(File.join(tmpdir, 'lnet.lic'), '# synced by Core Scripts')

      tracker.untrack_script('dr-scripts', 'lnet.lic')

      expect(UserVars.tracked_scripts['dr-scripts']).to eq([])
      expect(UserVars.tracked_scripts['scripts']).to eq(['lnet.lic'])
      expect(Vars).to have_received(:save)
      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono)
        .with("[lich5-update: Removed the leftover 'lnet.lic' entry from DR Scripts. DR Scripts syncs its scripts automatically, so the entry did nothing.]")
      expect(Lich::Util::Update::StatusReporter).not_to have_received(:respond_mono).with(/still installed|Delete manually|tracked list\.\]/)
    end

    it 'says so when there is no such leftover entry' do
      tracker.untrack_script('dr-scripts', 'lnet.lic')

      expect(Vars).not_to have_received(:save)
      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono)
        .with("[lich5-update: DR Scripts has no tracked list, and 'lnet.lic' was not a leftover entry there.]")
    end

    it 'keeps the file note quiet when another built-in repo still tracks the file' do
      XMLData.game = 'GSIV'
      UserVars.tracked_scripts = { 'gs-scripts' => ['lnet.lic'], 'scripts' => ['lnet.lic'] }
      File.binwrite(File.join(tmpdir, 'lnet.lic'), '# synced')

      tracker.untrack_script('gs-scripts', 'lnet.lic')

      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono)
        .with('[lich5-update: lnet.lic stays installed, because Core Scripts still tracks it.]')
      expect(Lich::Util::Update::StatusReporter).not_to have_received(:respond_mono).with(/Delete manually/)
    end

    it 'does not count a repo that does not sync here as keeping the file' do
      UserVars.tracked_scripts = { 'scripts' => ['ewaggle.lic'] }
      File.binwrite(File.join(tmpdir, 'ewaggle.lic'), '# installed')

      tracker.untrack_script('scripts', 'ewaggle.lic')

      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with(/ewaggle\.lic is still installed\./)
      expect(Lich::Util::Update::StatusReporter).not_to have_received(:respond_mono).with(/stays installed/)
    end

    it 'does not claim the file stays installed when it is not on disk' do
      XMLData.game = 'GSIV'
      UserVars.tracked_scripts = { 'gs-scripts' => ['lnet.lic'], 'scripts' => ['lnet.lic'] }

      tracker.untrack_script('gs-scripts', 'lnet.lic')

      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with("[lich5-update: Removed 'lnet.lic' from GS Scripts tracked list.]")
      expect(Lich::Util::Update::StatusReporter).not_to have_received(:respond_mono).with(/stays installed|still installed/)
    end

    it 'shows leftover DR Scripts entries in --tracked, so they can be found' do
      UserVars.tracked_scripts = { 'dr-scripts' => ['zeta.lic', 'lnet.lic'] }

      tracker.show_tracked('dr-scripts')

      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono)
        .with(a_string_including('Scripts synced automatically (all except -setup files)', 'Ignored leftover entries: lnet.lic, zeta.lic', 'Remove with --untrack=dr-scripts:<script>'))
    end

    it 'shows no leftover row when there are none' do
      tracker.show_tracked('dr-scripts')

      expect(Lich::Util::Update::StatusReporter).not_to have_received(:respond_mono).with(/leftover/)
    end

    it 'marks a repo that does not sync here instead of claiming it syncs' do
      tracker.show_tracked

      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono)
        .with(a_string_including('Not synced for DR characters', 'Scripts synced automatically (all except -setup files)'))
      XMLData.game = 'GSIV'
      tracker.show_tracked('dr-scripts')
      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono)
        .with(satisfy { |t| t.include?('Not synced for GSIV characters') && !t.include?('Scripts synced automatically') })
    end

    it 'tells a GemStone character a leftover DR Scripts entry did nothing because DR Scripts is not synced' do
      XMLData.game = 'GSIV'
      UserVars.tracked_scripts = { 'dr-scripts' => ['lnet.lic'] }

      tracker.untrack_script('dr-scripts', 'lnet.lic')

      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono)
        .with("[lich5-update: Removed the leftover 'lnet.lic' entry from DR Scripts. DR Scripts is not synced for GSIV characters, so the entry did nothing.]")
    end

    it 'stays offline and hedges the note where DR Scripts syncs and might ship the file' do
      UserVars.tracked_scripts = { 'scripts' => ['alchemy.lic'] }
      File.binwrite(File.join(tmpdir, 'alchemy.lic'), '# installed')
      allow(client).to receive(:fetch_github_json)

      tracker.untrack_script('scripts', 'alchemy.lic')

      expect(client).not_to have_received(:fetch_github_json)
      expect(UserVars.tracked_scripts['scripts']).to eq([])
      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with(
        '[lich5-update: Note: alchemy.lic is still installed. If DR Scripts also ships it, its next sync keeps it; ' \
        'otherwise delete it by hand if it is no longer needed.]'
      )
    end

    it 'does not ask GitHub when the file is not on disk' do
      UserVars.tracked_scripts = { 'scripts' => ['gone.lic'] }
      allow(client).to receive(:fetch_github_json)

      tracker.untrack_script('scripts', 'gone.lic')

      expect(client).not_to have_received(:fetch_github_json)
      expect(Lich::Util::Update::StatusReporter).not_to have_received(:respond_mono).with(/Note|stays installed/)
    end

    it 'says an entry for a repo not synced here never installed anything, instead of a delete note' do
      UserVars.tracked_scripts = { 'gs-scripts' => ['alchemy.lic'] }
      File.binwrite(File.join(tmpdir, 'alchemy.lic'), '# from DR Scripts')
      allow(client).to receive(:fetch_github_json)

      tracker.untrack_script('gs-scripts', 'alchemy.lic')

      expect(client).not_to have_received(:fetch_github_json)
      expect(UserVars.tracked_scripts['gs-scripts']).to eq([])
      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono)
        .with('[lich5-update: GS Scripts is not synced for DR characters, so that entry never installed anything here.]')
      expect(Lich::Util::Update::StatusReporter).not_to have_received(:respond_mono).with(/Delete manually/)
    end
  end

  describe '#track_script refuses a script the repo does not contain' do
    let(:core_api) { Lich::Util::Update::SCRIPT_REPOS['scripts'][:api_url] }
    let(:dr_api) { Lich::Util::Update::SCRIPT_REPOS['dr-scripts'][:api_url] }
    let(:core_tree) do
      { 'tree' => [
        { 'path' => 'scripts/lnet.lic', 'type' => 'blob' },
        { 'path' => 'scripts/go2.lic', 'type' => 'blob' },
        { 'path' => 'scripts/alchemy.lic', 'type' => 'blob' },
        { 'path' => 'scripts/lich', 'type' => 'tree' },
        { 'path' => 'scripts/lich/nested.lic', 'type' => 'blob' },
        { 'path' => 'docs/readme.lic', 'type' => 'blob' }
      ] }
    end

    before do
      XMLData.game = 'GSIV'
      allow(client).to receive(:fetch_github_json).with(core_api).and_return(core_tree)
    end

    it 'refuses a misspelt name, so the sync is not left with a name it never installs' do
      tracker.track_script('scripts', 'lnte.lic')

      expect(UserVars.tracked_scripts&.dig('scripts')).to be_nil
      expect(Vars).not_to have_received(:save)
      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono)
        .with("[lich5-update: Error: 'lnte.lic' is not in Core Scripts.]")
    end

    it 'suggests the .lic name when the extension was left off' do
      tracker.track_script('scripts', 'lnet')

      expect(UserVars.tracked_scripts&.dig('scripts')).to be_nil
      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono)
        .with("[lich5-update: Error: 'lnet' is not in Core Scripts. Did you mean 'lnet.lic'?]")
    end

    it 'suggests the real name when only the case differs, and does not add the wrong case' do
      tracker.track_script('scripts', 'LNet.lic')

      expect(UserVars.tracked_scripts&.dig('scripts')).to be_nil
      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with(/Did you mean 'lnet\.lic'\?/)
    end

    it 'does not suggest a name that is already tracked' do
      tracker.track_script('scripts', 'Go2.lic')

      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono)
        .with("[lich5-update: Error: 'Go2.lic' is not in Core Scripts. It has 'go2.lic', which is already tracked there.]")
      expect(Lich::Util::Update::StatusReporter).not_to have_received(:respond_mono).with(/Did you mean/)
    end

    it 'does not suggest a name the next --track would refuse' do
      XMLData.game = 'DR'
      allow(client).to receive(:fetch_github_json).with(dr_api).and_return({ 'tree' => [{ 'path' => 'alchemy.lic', 'type' => 'blob' }] })

      tracker.track_script('scripts', 'alchemy')

      expect(UserVars.tracked_scripts&.dig('scripts')).to be_nil
      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with(
        "[lich5-update: Error: 'alchemy' is not in Core Scripts. It has 'alchemy.lic', but that cannot be tracked either: " \
        "'alchemy.lic' is also in DR Scripts, which syncs it automatically. Tracking it here would make the two overwrite each other.]"
      )
    end

    it 'still suggests the name when the clash check for it cannot reach GitHub' do
      XMLData.game = 'DR'
      calls = 0
      allow(client).to receive(:fetch_github_json).with(dr_api) { (calls += 1) == 1 ? { 'tree' => [] } : nil }
      allow(client).to receive(:last_error).and_return(nil)

      tracker.track_script('scripts', 'lnet')

      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono)
        .with("[lich5-update: Error: 'lnet' is not in Core Scripts. Did you mean 'lnet.lic'?]")
    end

    it 'does not count a file outside the repo script folder, or a subfolder, as present' do
      tracker.track_script('scripts', 'nested.lic')
      tracker.track_script('scripts', 'readme.lic')
      tracker.track_script('scripts', 'lich')

      expect(UserVars.tracked_scripts&.dig('scripts')).to be_nil
      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with(/'nested\.lic' is not in Core Scripts/)
      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with(/'readme\.lic' is not in Core Scripts/)
      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with(/'lich' is not in Core Scripts/)
    end

    it 'adds a script the repo does contain' do
      tracker.track_script('scripts', 'lnet.lic')

      expect(UserVars.tracked_scripts['scripts']).to eq(['lnet.lic'])
      expect(Vars).to have_received(:save)
    end

    it 'adds nothing when the repo file list cannot be read, and says to run it again' do
      error = Lich::Util::Update::FetchError.new(kind: :network)
      allow(client).to receive(:fetch_github_json).with(core_api).and_return(nil)
      allow(client).to receive(:last_error).and_return(error)

      tracker.track_script('scripts', 'lnet.lic')

      expect(UserVars.tracked_scripts&.dig('scripts')).to be_nil
      expect(Vars).not_to have_received(:save)
      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with(
        "[lich5-update: GitHub check failed. Could not check that Core Scripts contains 'lnet.lic', so nothing was added. " \
        'This is usually temporary; run the command again in a few minutes.]'
      )
    end

    it 'names a custom repo whose branch GitHub cannot find' do
      UserVars.custom_repos = { 'Someone/scripts' => { 'branch' => 'gone' } }
      custom_api = Lich::Util::Update::CustomRepos.build_config('Someone/scripts', { 'branch' => 'gone' })[:api_url]
      allow(client).to receive(:fetch_github_json).with(custom_api).and_return(nil)
      allow(client).to receive(:last_error).and_return(Lich::Util::Update::FetchError.new(kind: :not_found, status: 404))

      tracker.track_script('Someone/scripts', 'tool.lic')

      expect(UserVars.tracked_scripts&.dig('Someone/scripts')).to be_nil
      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono)
        .with(/GitHub check failed \(Custom: Someone\/scripts not found\)\. Could not check that Custom: Someone\/scripts contains 'tool\.lic'/)
    ensure
      UserVars.custom_repos = nil
    end

    it 'reports a name the repo lacks as missing, not as a clash with DR Scripts' do
      XMLData.game = 'DR'
      allow(client).to receive(:fetch_github_json).with(dr_api).and_return({ 'tree' => [{ 'path' => 'combat-trainer.lic', 'type' => 'blob' }] })

      tracker.track_script('scripts', 'combat-trainer.lic')

      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono)
        .with("[lich5-update: Error: 'combat-trainer.lic' is not in Core Scripts.]")
      expect(client).not_to have_received(:fetch_github_json).with(dr_api)
    end

    it 'still refuses a custom track over a file in scripts/ once the repo has the name' do
      UserVars.custom_repos = { 'Someone/scripts' => { 'branch' => 'main' } }
      custom_api = Lich::Util::Update::CustomRepos.build_config('Someone/scripts', { 'branch' => 'main' })[:api_url]
      allow(client).to receive(:fetch_github_json).with(custom_api).and_return({ 'tree' => [{ 'path' => 'lnet.lic', 'type' => 'blob' }] })
      File.binwrite(File.join(tmpdir, 'lnet.lic'), '# installed')

      tracker.track_script('Someone/scripts', 'lnet.lic')

      expect(UserVars.tracked_scripts).to be_nil
      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with(/already installed in scripts\//)
    ensure
      UserVars.custom_repos = nil
    end

    it 'tells the user only top-level .lic files of a custom repo can be tracked' do
      UserVars.custom_repos = { 'Someone/scripts' => { 'branch' => 'main' } }
      custom_api = Lich::Util::Update::CustomRepos.build_config('Someone/scripts', { 'branch' => 'main' })[:api_url]
      allow(client).to receive(:fetch_github_json).with(custom_api).and_return({ 'tree' => [{ 'path' => 'scripts/tool.lic', 'type' => 'blob' }] })

      tracker.track_script('Someone/scripts', 'tool.lic')

      expect(UserVars.tracked_scripts).to be_nil
      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with(
        "[lich5-update: Error: 'tool.lic' is not in Custom: Someone/scripts. Only .lic files at the top level of a custom repo can be tracked.]"
      )
    ensure
      UserVars.custom_repos = nil
    end
  end
end
