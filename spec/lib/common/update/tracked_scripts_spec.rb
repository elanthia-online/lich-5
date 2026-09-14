# frozen_string_literal: true

require_relative 'update_spec_helper'

RSpec.describe Lich::Util::Update::TrackedScripts do
  let(:tmpdir) { Dir.mktmpdir('ts-test') }
  let(:tracker) { described_class.new }

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
end
