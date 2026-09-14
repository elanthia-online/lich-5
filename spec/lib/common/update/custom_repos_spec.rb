# frozen_string_literal: true

require_relative 'update_spec_helper'

RSpec.describe Lich::Util::Update::CustomRepos do
  let(:tmpdir) { Dir.mktmpdir('custom-repos-test') }
  let(:manager) { described_class.new }

  before do
    stub_const('SCRIPT_DIR', tmpdir)
    UserVars.custom_repos = nil
    UserVars.tracked_scripts = nil
    allow(Lich::Util::Update::StatusReporter).to receive(:respond_mono)
    allow(Vars).to receive(:save)
  end

  after { FileUtils.remove_entry(tmpdir) }

  describe '.repo_dir_name' do
    it 'converts owner/repo to owner-repo' do
      expect(described_class.repo_dir_name('MahtraDR/dr-scripts')).to eq('MahtraDR-dr-scripts')
    end
  end

  describe '.dest_dir' do
    it 'returns SCRIPT_DIR/custom/owner-repo' do
      expect(described_class.dest_dir('MahtraDR/dr-scripts')).to eq(File.join(tmpdir, 'custom', 'MahtraDR-dr-scripts'))
    end
  end

  describe '.build_config' do
    it 'returns a SCRIPT_REPOS-compatible config hash' do
      reg = { 'branch' => 'dev' }
      config = described_class.build_config('MahtraDR/dr-scripts', reg)

      expect(config[:display_name]).to eq('Custom: MahtraDR/dr-scripts')
      expect(config[:api_url]).to include('MahtraDR/dr-scripts')
      expect(config[:api_url]).to include('dev')
      expect(config[:raw_base_url]).to include('MahtraDR/dr-scripts/dev')
      expect(config[:tracking_mode]).to eq(:explicit)
      expect(config[:custom]).to eq(true)
      expect(config[:dest_dir]).to eq(described_class.dest_dir('MahtraDR/dr-scripts'))
    end

    it 'defaults to main branch' do
      config = described_class.build_config('owner/repo', {})
      expect(config[:api_url]).to include('main')
    end

    it 'handles nil registration gracefully' do
      config = described_class.build_config('owner/repo', nil)
      expect(config[:api_url]).to include('main')
      expect(config[:tracking_mode]).to eq(:explicit)
    end
  end

  describe '.all' do
    it 'returns empty hash when UserVars.custom_repos is nil' do
      UserVars.custom_repos = nil
      expect(described_class.all).to eq({})
    end

    it 'returns empty hash when UserVars.custom_repos is not a Hash' do
      UserVars.custom_repos = 'corrupted'
      expect(described_class.all).to eq({})
    end

    it 'returns the hash when UserVars.custom_repos is valid' do
      UserVars.custom_repos = { 'owner/repo' => { 'branch' => 'main' } }
      expect(described_class.all).to have_key('owner/repo')
    end
  end

  describe '#add_custom_repo' do
    it 'registers a new custom repo' do
      manager.add_custom_repo('MahtraDR/dr-scripts')

      expect(UserVars.custom_repos).to have_key('MahtraDR/dr-scripts')
      expect(UserVars.custom_repos['MahtraDR/dr-scripts']['branch']).to eq('main')
      expect(Vars).to have_received(:save)
      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with(/Registered.*MahtraDR\/dr-scripts/)
    end

    it 'registers with a specific branch' do
      manager.add_custom_repo('MahtraDR/dr-scripts', 'dev')

      expect(UserVars.custom_repos['MahtraDR/dr-scripts']['branch']).to eq('dev')
    end

    it 'rejects invalid format' do
      manager.add_custom_repo('not-a-repo')

      expect(UserVars.custom_repos).to be_nil
      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with(/Invalid format/)
    end

    it 'rejects duplicate registration' do
      UserVars.custom_repos = { 'MahtraDR/dr-scripts' => { 'branch' => 'main' } }

      manager.add_custom_repo('MahtraDR/dr-scripts')

      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with(/already registered/)
    end

    it 'rejects directory-colliding repos' do
      UserVars.custom_repos = { 'foo/bar-baz' => { 'branch' => 'main' } }

      manager.add_custom_repo('foo-bar/baz')

      expect(UserVars.custom_repos).not_to have_key('foo-bar/baz')
      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with(/collides with.*foo\/bar-baz/)
    end

    it 'rejects invalid branch names' do
      manager.add_custom_repo('owner/repo', 'branch with spaces')

      expect(UserVars.custom_repos).to be_nil
      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with(/Invalid branch name/)
    end

    it 'rejects empty branch string' do
      manager.add_custom_repo('owner/repo', '')

      expect(UserVars.custom_repos).to be_nil
      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with(/Invalid branch name/)
    end

    it 'rejects branch with shell metacharacters' do
      manager.add_custom_repo('owner/repo', 'main;rm -rf /')

      expect(UserVars.custom_repos).to be_nil
      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with(/Invalid branch name/)
    end

    it 'accepts valid branch names with slashes' do
      manager.add_custom_repo('owner/repo', 'feature/my-branch')

      expect(UserVars.custom_repos['owner/repo']['branch']).to eq('feature/my-branch')
    end

    it 'recovers from corrupted UserVars.custom_repos' do
      UserVars.custom_repos = 'corrupted-string'

      manager.add_custom_repo('owner/repo')

      expect(UserVars.custom_repos).to be_a(Hash)
      expect(UserVars.custom_repos).to have_key('owner/repo')
    end
  end

  describe '#remove_custom_repo' do
    it 'removes a registered repo' do
      UserVars.custom_repos = { 'MahtraDR/dr-scripts' => { 'branch' => 'main' } }
      UserVars.tracked_scripts = { 'MahtraDR/dr-scripts' => ['foo.lic'] }

      manager.remove_custom_repo('MahtraDR/dr-scripts')

      expect(UserVars.custom_repos).not_to have_key('MahtraDR/dr-scripts')
      expect(UserVars.tracked_scripts).not_to have_key('MahtraDR/dr-scripts')
      expect(Vars).to have_received(:save)
    end

    it 'warns about installed files' do
      UserVars.custom_repos = { 'MahtraDR/dr-scripts' => { 'branch' => 'main' } }
      dest = described_class.dest_dir('MahtraDR/dr-scripts')
      FileUtils.mkdir_p(dest)
      File.binwrite(File.join(dest, 'foo.lic'), '# test')

      manager.remove_custom_repo('MahtraDR/dr-scripts')

      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with(/1 script.*still installed/)
    end

    it 'reports error for unknown repo' do
      manager.remove_custom_repo('unknown/repo')

      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with(/not a registered/)
    end

    it 'does not crash when UserVars.custom_repos is corrupted' do
      UserVars.custom_repos = 42

      expect { manager.remove_custom_repo('owner/repo') }.not_to raise_error
      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with(/not a registered/)
    end
  end

  describe '#list_custom_repos' do
    it 'shows message when no repos registered' do
      manager.list_custom_repos

      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with(/No custom repos/)
    end

    it 'displays registered repos in a table' do
      UserVars.custom_repos = { 'MahtraDR/dr-scripts' => { 'branch' => 'main', 'added_at' => '2026-03-28' } }
      UserVars.tracked_scripts = { 'MahtraDR/dr-scripts' => ['foo.lic'] }

      manager.list_custom_repos

      expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with(/MahtraDR\/dr-scripts/)
    end
  end
end
