# frozen_string_literal: true

require_relative '../../../spec_helper'
require_relative 'update_spec_helper'
require 'rubygems/package'

RSpec.describe Lich::Util::Update::GemPackages do
  let(:client) { instance_double(Lich::Util::Update::GitHubClient) }
  let(:manager) { described_class.new(client) }
  let(:printed) { [] }

  before do
    Lich.db.reset!
    allow(Lich::Util::Update::StatusReporter).to receive(:respond_mono) { |msg| printed << msg }
  end

  describe '.all and .save' do
    it 'is empty until something is saved' do
      expect(described_class.all).to eq({})
    end

    it 'round-trips the registry through lich_settings' do
      described_class.save('a/b' => { 'added_at' => '2026-11-11' })
      expect(described_class.all).to eq('a/b' => { 'added_at' => '2026-11-11' })
    end

    it 'treats unreadable stored data as empty' do
      Lich.db.execute("INSERT OR REPLACE INTO lich_settings(name, value) VALUES('gem_packages', ?);", ['not json'])
      expect(described_class.all).to eq({})
    end
  end

  describe '#add_gem' do
    it 'rejects anything but owner/repo' do
      manager.add_gem('eohunter')
      expect(printed.last).to include("Invalid format 'eohunter'")
      expect(described_class.all).to eq({})
    end

    it 'registers the repository and checks it at once' do
      allow(manager).to receive(:sync_gem).with('x/y', retried_by: :user).and_return(:updated)
      manager.add_gem('x/y')
      expect(described_class.all).to have_key('x/y')
      expect(printed).to include("[lich5-update: Registered gem package 'x/y'.]")
    end

    it 'says so when the registered package is already current' do
      allow(manager).to receive(:sync_gem).and_return(:current)
      manager.add_gem('x/y')
      expect(printed.last).to eq('[lich5-update: x/y is already up to date.]')
    end

    it 'refuses a duplicate' do
      described_class.save('x/y' => {})
      manager.add_gem('x/y')
      expect(printed.last).to include('already registered')
    end
  end

  describe '#remove_gem' do
    it 'removes a registered repository and leaves the gem alone' do
      described_class.save('x/y' => { 'gem' => 'tiny' })
      manager.remove_gem('x/y')
      expect(described_class.all).to eq({})
      expect(printed.last).to eq("[lich5-update: Removed gem package 'x/y'. The tiny gem and its scripts stay installed.]")
    end

    it 'reports an unknown repository' do
      manager.remove_gem('x/y')
      expect(printed.last).to include('not a registered gem package')
    end
  end

  describe '#list_gems' do
    it 'hints at --add-gem when nothing is registered' do
      manager.list_gems
      expect(printed.last).to include('--add-gem=owner/repo')
    end

    it 'shows each package with its gem and installed version' do
      described_class.save('x/y' => { 'gem' => 'tiny', 'added_at' => '2026-11-11' })
      allow(described_class).to receive(:installed_version).with('tiny').and_return(Gem::Version.new('1.2.0'))
      manager.list_gems
      expect(printed.last).to include('x/y', 'tiny', '1.2.0', '2026-11-11')
    end
  end

  describe '#sync_gem' do
    let(:release_url) { 'https://api.github.com/repos/x/y/releases/latest' }

    before { described_class.save('x/y' => {}) }

    it 'reports a GitHub-wide failure and returns :github_unavailable' do
      allow(client).to receive(:fetch_github_json).with(release_url).and_return(nil)
      allow(client).to receive(:last_error).and_return(Lich::Util::Update::FetchError.new(kind: :network))
      expect(manager.sync_gem('x/y')).to eq(:github_unavailable)
      expect(printed.last).to include('GitHub check failed', 'x/y was not checked for a new release')
    end

    it 'treats a missing repository as that package failing, not GitHub' do
      allow(client).to receive(:fetch_github_json).and_return(nil)
      allow(client).to receive(:last_error).and_return(Lich::Util::Update::FetchError.new(kind: :not_found, status: 404))
      expect(manager.sync_gem('x/y')).to eq(:failed)
      expect(printed.last).to include('x/y releases not found')
    end

    it 'skips a release with no .gem attached and says so' do
      allow(client).to receive(:fetch_github_json).and_return('tag_name' => 'v2', 'assets' => [{ 'name' => 'notes.txt' }])
      expect(manager.sync_gem('x/y')).to eq(:skipped)
      expect(printed.last).to eq('[lich5-update: x/y: release v2 has no .gem attached; skipped.]')
    end

    it 'does nothing, silently, when the installed gem is as new' do
      allow(client).to receive(:fetch_github_json).and_return(release_with('tiny-1.2.0.gem'))
      allow(described_class).to receive(:installed_version).with('tiny').and_return(Gem::Version.new('1.2.0'))
      expect(manager.sync_gem('x/y')).to eq(:current)
      expect(printed).to be_empty
      expect(described_class.all['x/y']['gem']).to eq('tiny')
    end

    context 'with a newer release' do
      let(:tmp) { Dir.mktmpdir('gem-packages') }
      let(:gem_home) { File.join(tmp, 'gem_home') }
      let(:lich_dir) { File.join(tmp, 'lich') }

      before do
        FileUtils.mkdir_p(gem_home)
        FileUtils.mkdir_p(lich_dir)
        stub_const('LICH_DIR', lich_dir)
        stub_const('TEMP_DIR', File.join(tmp, 'temp'))
        allow(Gem).to receive(:dir).and_return(gem_home)
        allow(described_class).to receive(:installed_version).with('tiny').and_return(Gem::Version.new('1.0.0'))
        allow(client).to receive(:fetch_github_json).and_return(release_with('tiny-1.2.0.gem'))
      end

      after { FileUtils.remove_entry(tmp, true) }

      it 'downloads, installs the gem, runs its installer and reports one line' do
        serve(build_gem(metadata: { 'lich_install' => 'tiny/install#Tiny::Install' }))

        expect(manager.sync_gem('x/y')).to eq(:updated)

        expect(File).to exist(File.join(gem_home, 'specifications', 'tiny-1.2.0.gemspec'))
        expect(File.read(File.join(lich_dir, 'scripts', 'tiny.lic'))).to eq("installed into #{lich_dir}")
        expect(Dir.children(TEMP_DIR)).to be_empty
        expect(printed.last).to eq('[lich5-update: tiny updated to 1.2.0.]')
      end

      it 'refuses a gem without lich_install metadata' do
        serve(build_gem(metadata: {}))
        expect(manager.sync_gem('x/y')).to eq(:failed)
        expect(printed.last).to include("no 'lich_install' metadata")
        expect(File).not_to exist(File.join(gem_home, 'specifications', 'tiny-1.2.0.gemspec'))
      end

      it 'refuses a gem that builds extensions' do
        serve(build_gem(metadata: { 'lich_install' => 'tiny/install#Tiny::Install' }, extensions: ['ext/extconf.rb']))
        expect(manager.sync_gem('x/y')).to eq(:failed)
        expect(printed.last).to include('builds native extensions')
      end

      it 'keeps the gem but reports when its installer raises' do
        serve(build_gem(metadata: { 'lich_install' => 'tiny/install#Tiny::Missing' }))
        expect(manager.sync_gem('x/y')).to eq(:failed)
        expect(printed.last).to include('its installer failed', 'scripts were not copied')
      end

      it 'reports a failed download and installs nothing' do
        allow_any_instance_of(URI::HTTP).to receive(:open).and_raise(OpenURI::HTTPError.new('404 Not Found', StringIO.new))
        expect(manager.sync_gem('x/y')).to eq(:failed)
        expect(printed.last).to include('Could not download tiny-1.2.0.gem')
      end

      it 'stops before downloading when the gem home is not writable' do
        allow(File).to receive(:write).and_call_original
        allow(File).to receive(:write).with(a_string_starting_with(File.join(gem_home, 'gems')), '').and_raise(Errno::EACCES)
        FileUtils.mkdir_p(File.join(gem_home, 'gems'))
        serve(build_gem(metadata: { 'lich_install' => 'tiny/install#Tiny::Install' }))
        expect(manager.sync_gem('x/y')).to eq(:failed)
        expect(printed.last).to include('cannot write to', 'GEM_HOME')
      end

      def build_gem(metadata:, extensions: [])
        src = File.join(tmp, 'src')
        FileUtils.mkdir_p(File.join(src, 'lib', 'tiny'))
        File.write(File.join(src, 'lib', 'tiny', 'install.rb'), <<~RUBY)
          module Tiny
            module Install
              def self.install(lich_dir)
                FileUtils.mkdir_p(File.join(lich_dir, 'scripts'))
                File.write(File.join(lich_dir, 'scripts', 'tiny.lic'), "installed into \#{lich_dir}")
              end
            end
          end
        RUBY
        File.write(File.join(src, 'ext', 'extconf.rb'), '') if extensions.any? && FileUtils.mkdir_p(File.join(src, 'ext'))
        spec = Gem::Specification.new do |s|
          s.name = 'tiny'
          s.version = '1.2.0'
          s.summary = 'test package'
          s.authors = ['spec']
          s.files = ['lib/tiny/install.rb'] + extensions
          s.metadata = metadata
          s.extensions = extensions
        end
        Dir.chdir(src) { Gem::DefaultUserInteraction.use_ui(Gem::SilentUI.new) { Gem::Package.build(spec) } }
        File.join(src, 'tiny-1.2.0.gem')
      end

      def serve(gem_path)
        bytes = File.binread(gem_path)
        allow_any_instance_of(URI::HTTP).to receive(:open).and_return(StringIO.new(bytes))
      end
    end

    def release_with(asset_name)
      { 'tag_name' => 'v1.2.0', 'assets' => [{ 'name' => asset_name, 'browser_download_url' => "https://github.com/x/y/releases/download/v1.2.0/#{asset_name}" }] }
    end
  end

  describe '#sync_all' do
    it 'stops at the first GitHub-wide failure' do
      described_class.save('a/b' => {}, 'c/d' => {})
      allow(manager).to receive(:sync_gem).with('a/b').and_return(:github_unavailable)
      allow(manager).to receive(:sync_gem).with('c/d')
      manager.sync_all
      expect(manager).not_to have_received(:sync_gem).with('c/d')
    end

    it 'continues past a package that failed on its own' do
      described_class.save('a/b' => {}, 'c/d' => {})
      allow(manager).to receive(:sync_gem).with('a/b').and_return(:failed)
      allow(manager).to receive(:sync_gem).with('c/d').and_return(:current)
      manager.sync_all
      expect(manager).to have_received(:sync_gem).with('c/d')
    end
  end
end
