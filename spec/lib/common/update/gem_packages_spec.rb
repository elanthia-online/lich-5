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

    it 'skips an asset whose version RubyGems rejects and uses the next one' do
      described_class.save('x/y' => { 'deployed_gem' => 'tiny', 'deployed' => '1.2.0' })
      allow(client).to receive(:fetch_github_json).and_return(
        'tag_name' => 'v1.2.0',
        'assets'   => [{ 'name' => 'tiny-1..2.gem' }, { 'name' => 'tiny-1.2.0.gem', 'browser_download_url' => 'https://example.com/tiny-1.2.0.gem' }]
      )
      allow(described_class).to receive(:installed_version).with('tiny').and_return(Gem::Version.new('1.2.0'))
      expect(manager.sync_gem('x/y')).to eq(:current)
    end

    it 'treats a release with only invalid gem versions as having no gem' do
      allow(client).to receive(:fetch_github_json).and_return('tag_name' => 'v2', 'assets' => [{ 'name' => 'tiny-1..2.gem' }])
      expect(manager.sync_gem('x/y')).to eq(:skipped)
    end

    it 'refuses a gem name another registration already provides' do
      described_class.save('a/b' => { 'gem' => 'tiny', 'deployed_gem' => 'tiny', 'deployed' => '1.2.0' }, 'x/y' => {})
      allow(client).to receive(:fetch_github_json).and_return(release_with('tiny-1.2.0.gem'))
      allow(described_class).to receive(:installed_version).with('tiny').and_return(Gem::Version.new('1.2.0'))
      expect(manager.sync_gem('x/y')).to eq(:failed)
      expect(printed.last).to include("x/y publishes the gem 'tiny', which a/b already provides")
      expect(described_class.all['x/y']).not_to have_key('deployed')
    end

    it 'does nothing, silently, when the installed gem is as new and its scripts were deployed' do
      described_class.save('x/y' => { 'deployed_gem' => 'tiny', 'deployed' => '1.2.0' })
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
        expect(described_class.all['x/y']['deployed']).to eq('1.2.0')
      end

      it 'retries the script installer at the next sync when it failed, without downloading again' do
        gate = File.join(tmp, 'gate')
        serve(build_gem(metadata: { 'lich_install' => 'tiny/install#Tiny::Install' }, installer: <<~RUBY))
          raise Errno::EACCES, 'scripts' unless File.exist?('#{gate.gsub('\\', '/')}')
          FileUtils.mkdir_p(File.join(lich_dir, 'scripts'))
          File.write(File.join(lich_dir, 'scripts', 'tiny.lic'), 'ok')
        RUBY

        expect(manager.sync_gem('x/y')).to eq(:failed)
        expect(described_class.all['x/y']).not_to have_key('deployed')
        expect(File).not_to exist(File.join(lich_dir, 'scripts', 'tiny.lic'))

        # Now the gem is installed at 1.2.0 but its scripts are not.
        allow(described_class).to receive(:installed_version).with('tiny').and_return(Gem::Version.new('1.2.0'))
        allow(Gem::Specification).to receive(:find_all_by_name).and_call_original
        allow(Gem::Specification).to receive(:find_all_by_name).with('tiny', '= 1.2.0')
                                                               .and_return([Gem::Specification.load(File.join(gem_home, 'specifications', 'tiny-1.2.0.gemspec'))])
        expect(manager.sync_gem('x/y')).to eq(:failed)
        expect(printed.last).to include('the next sync tries again')

        FileUtils.touch(gate)
        allow_any_instance_of(URI::HTTP).to receive(:open).and_raise('must not download again')
        expect(manager.sync_gem('x/y')).to eq(:updated)
        expect(File.read(File.join(lich_dir, 'scripts', 'tiny.lic'))).to eq('ok')
        expect(described_class.all['x/y']['deployed']).to eq('1.2.0')
        expect(manager.sync_gem('x/y')).to eq(:current)
      end

      it 'refuses a gem that needs a newer Ruby' do
        serve(build_gem(metadata: { 'lich_install' => 'tiny/install#Tiny::Install' }, required_ruby: '> 99.0'))
        expect(manager.sync_gem('x/y')).to eq(:failed)
        expect(printed.last).to include('needs Ruby > 99.0', 'not installed')
        expect(File).not_to exist(File.join(gem_home, 'specifications', 'tiny-1.2.0.gemspec'))
        expect(File).not_to exist(File.join(lich_dir, 'scripts', 'tiny.lic'))
      end

      it 'reports an installer that fails to load and lets the sync go on' do
        serve(build_gem(metadata: { 'lich_install' => 'tiny/install#Tiny::Install' }, installer: "require 'no_such_gem_anywhere'"))
        expect(manager.sync_gem('x/y')).to eq(:failed)
        expect(printed.last).to include('its installer failed: LoadError')

        printed.clear
        serve(build_gem(metadata: { 'lich_install' => 'tiny/install#Tiny::Install' }, installer: 'def ('))
        allow(Gem::Specification).to receive(:find_all_by_name).and_return([])
        expect(manager.sync_gem('x/y')).to eq(:failed)
        expect(printed.last).to include('its installer failed: SyntaxError')
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
        expect(Dir.children(TEMP_DIR)).to be_empty
      end

      it 'deploys a renamed gem even when the old name was deployed at the same version' do
        described_class.save('x/y' => { 'gem' => 'old_name', 'deployed_gem' => 'old_name', 'deployed' => '1.2.0' })
        allow(described_class).to receive(:installed_version).with('tiny').and_return(Gem::Version.new('1.2.0'))
        allow(Gem::Specification).to receive(:find_all_by_name).and_call_original
        allow(Gem::Specification).to receive(:find_all_by_name).with('tiny', '= 1.2.0').and_return([])
        serve(build_gem(metadata: { 'lich_install' => 'tiny/install#Tiny::Install' }))

        expect(manager.sync_gem('x/y')).to eq(:updated)
        expect(described_class.all['x/y']).to include('gem' => 'tiny', 'deployed_gem' => 'tiny', 'deployed' => '1.2.0')
        expect(File).to exist(File.join(lich_dir, 'scripts', 'tiny.lic'))
      end

      it 'waits for another session holding the install lock before touching the gem directory' do
        serve(build_gem(metadata: { 'lich_install' => 'tiny/install#Tiny::Install' }))
        lock = File.join(gem_home, '.lich5-gem-packages.lock')
        held = Queue.new
        released = false
        other = Thread.new do
          described_class.with_lock(lock) do
            held << true
            sleep 0.3
            released = true
          end
        end
        held.pop

        seen = nil
        allow(manager).to receive(:sync_locked).and_wrap_original do |original, *args|
          seen = released
          original.call(*args)
        end
        expect(manager.sync_gem('x/y')).to eq(:updated)
        other.join
        expect(seen).to be(true)
      end

      it 'stops before downloading when the gem home is not writable' do
        allow(File).to receive(:write).and_call_original
        allow(File).to receive(:write).with(a_string_starting_with(File.join(gem_home, 'gems')), '').and_raise(Errno::EACCES)
        FileUtils.mkdir_p(File.join(gem_home, 'gems'))
        allow_any_instance_of(URI::HTTP).to receive(:open).and_raise('must not download')
        expect(manager.sync_gem('x/y')).to eq(:failed)
        expect(printed.last).to include('cannot write to', 'GEM_HOME')
        expect(printed.join).not_to include('must not download')
      end

      it 'refuses a gem whose contents do not match the asset name' do
        allow(client).to receive(:fetch_github_json).and_return(release_with('tiny-1.3.0.gem'))
        serve(build_gem(metadata: { 'lich_install' => 'tiny/install#Tiny::Install' }))
        expect(manager.sync_gem('x/y')).to eq(:failed)
        expect(printed.last).to include('named tiny 1.3.0 but contains tiny 1.2.0')
        expect(File).not_to exist(File.join(gem_home, 'specifications', 'tiny-1.2.0.gemspec'))
      end

      it 'downloads to a name unique to the process and thread, and removes it' do
        serve(build_gem(metadata: { 'lich_install' => 'tiny/install#Tiny::Install' }))
        written = []
        allow(File).to receive(:open).and_wrap_original do |original, path, *rest, &block|
          written << path if path.to_s.start_with?(TEMP_DIR)
          original.call(path, *rest, &block)
        end
        expect(manager.sync_gem('x/y')).to eq(:updated)
        # RubyGems reopens the file while installing; every open is the one path.
        expect(written.uniq).to eq([File.join(TEMP_DIR, "#{Process.pid}-#{Thread.current.object_id}-tiny-1.2.0.gem")])
        expect(Dir.children(TEMP_DIR)).to be_empty
      end

      let(:default_installer) do
        <<~RUBY
          FileUtils.mkdir_p(File.join(lich_dir, 'scripts'))
          File.write(File.join(lich_dir, 'scripts', 'tiny.lic'), "installed into \#{lich_dir}")
        RUBY
      end

      def build_gem(metadata:, extensions: [], installer: default_installer, required_ruby: nil)
        src = File.join(tmp, 'src')
        FileUtils.rm_rf(src)
        FileUtils.mkdir_p(File.join(src, 'lib', 'tiny'))
        File.write(File.join(src, 'lib', 'tiny', 'install.rb'), <<~RUBY)
          module Tiny
            module Install
              def self.install(lich_dir)
          #{installer}
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
          s.required_ruby_version = required_ruby if required_ruby
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

  describe '.update_registry' do
    it 'does not restore an entry another session removed while it waited' do
      described_class.save('a/b' => {}, 'x/y' => {})
      held = Queue.new
      other = Thread.new do
        described_class.update_registry do |data|
          held << true
          sleep 0.3
          data.delete('a/b')
        end
      end
      held.pop

      # Without the lock this read the registry before the removal was saved
      # and wrote 'a/b' back.
      manager.send(:remember, 'x/y', 'gem' => 'tiny')
      other.join

      expect(described_class.all).to eq('x/y' => { 'gem' => 'tiny' })
    end

    it 'keeps an addition made by another session' do
      described_class.save('x/y' => {})
      held = Queue.new
      other = Thread.new do
        described_class.update_registry do |data|
          held << true
          sleep 0.3
          data['c/d'] = {}
        end
      end
      held.pop
      manager.remove_gem('x/y')
      other.join

      expect(described_class.all).to eq('c/d' => {})
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
