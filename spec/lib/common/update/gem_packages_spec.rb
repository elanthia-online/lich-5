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
      expect(printed.last).to eq("[lich5-update: Removed gem package 'x/y'. The tiny gem and its scripts stay installed. To remove the gem from Lich's Ruby: gem uninstall tiny --all --executables]")
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

    before { described_class.save('x/y' => { 'gem' => 'tiny' }) }

    # This registration installed tiny 1.2.0 and deployed it.
    def seed_current
      described_class.save('x/y' => { 'gem' => 'tiny', 'installed_gem' => 'tiny', 'installed' => '1.2.0',
                                      'deployed_gem' => 'tiny', 'deployed' => '1.2.0' })
      allow(described_class).to receive(:installed_version).with('tiny').and_return(Gem::Version.new('1.2.0'))
      allow(Gem::Specification).to receive(:find_all_by_name).and_call_original
      allow(Gem::Specification).to receive(:find_all_by_name).with('tiny', '= 1.2.0')
                                                             .and_return([Gem::Specification.new { |s| s.name = 'tiny'; s.version = '1.2.0' }])
    end

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
      seed_current
      allow(client).to receive(:fetch_github_json).and_return(
        'tag_name' => 'v1.2.0',
        'assets'   => [{ 'name' => 'tiny-1..2.gem' }, { 'name' => 'tiny-1.2.0.gem', 'browser_download_url' => 'https://example.com/tiny-1.2.0.gem' }]
      )
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
      expect(printed.last).to include("x/y: it publishes the gem 'tiny', which a/b already provides")
      expect(described_class.all['x/y']).not_to have_key('deployed')
    end

    it 'does nothing, silently, when this registration installed and deployed the release' do
      seed_current
      allow(client).to receive(:fetch_github_json).and_return(release_with('tiny-1.2.0.gem'))
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

      it 'refuses a release that changes the gem name the package was added for' do
        described_class.save('x/y' => { 'gem' => 'old_name', 'deployed_gem' => 'old_name', 'deployed' => '1.2.0' })
        allow_any_instance_of(URI::HTTP).to receive(:open).and_raise('must not download')

        expect(manager.sync_gem('x/y')).to eq(:failed)
        expect(printed.last).to include("now publishes the gem 'tiny', but it was added for 'old_name'", '--remove-gem=x/y')
        expect(described_class.all['x/y']).to include('gem' => 'old_name', 'deployed_gem' => 'old_name')
        expect(File).not_to exist(File.join(gem_home, 'specifications', 'tiny-1.2.0.gemspec'))
      end

      it 'refuses a first release named after a gem already in Ruby that no package installed' do
        described_class.save('x/y' => {})
        allow(described_class).to receive(:installed_version).with('tiny').and_return(Gem::Version.new('9.0.0'))
        allow(Gem::Specification).to receive(:find_all_by_name).and_call_original
        allow(Gem::Specification).to receive(:find_all_by_name).with('tiny')
                                                               .and_return([Gem::Specification.new { |s| s.name = 'tiny'; s.version = '9.0.0'; s.homepage = 'https://github.com/someone/else' }])
        allow_any_instance_of(URI::HTTP).to receive(:open).and_raise('must not download')

        expect(manager.sync_gem('x/y')).to eq(:failed)
        expect(printed.last).to include("already installed in Lich's Ruby and was not installed by this package")
        expect(described_class.all['x/y']).not_to have_key('gem')
      end

      it 'accepts a hand-installed gem whose source is this repository' do
        described_class.save('x/y' => {})
        allow(described_class).to receive(:installed_version).with('tiny').and_return(Gem::Version.new('1.0.0'))
        allow(Gem::Specification).to receive(:find_all_by_name).and_call_original
        allow(Gem::Specification).to receive(:find_all_by_name).with('tiny')
                                                               .and_return([Gem::Specification.new { |s| s.name = 'tiny'; s.version = '1.0.0'; s.metadata = { 'source_code_uri' => 'https://github.com/X/Y' } }])
        serve(build_gem(metadata: { 'lich_install' => 'tiny/install#Tiny::Install' }))

        expect(manager.sync_gem('x/y')).to eq(:updated)
        expect(described_class.all['x/y']['gem']).to eq('tiny')
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

      it "links a gem's executables into Lich's own bin directory, not Ruby's" do
        stub_const('DATA_DIR', File.join(tmp, 'data'))
        serve(build_gem(metadata: { 'lich_install' => 'tiny/install#Tiny::Install' }, executables: ['tinycmd']))

        expect(manager.sync_gem('x/y')).to eq(:updated)
        expect(Dir[File.join(gem_home, 'bin', '*')]).to be_empty
        expect(Dir[File.join(tmp, 'data', 'gem-packages', 'bin', 'tinycmd*')]).not_to be_empty
      end

      it 'refuses a gem that ships a RubyGems plugin' do
        serve(build_gem(metadata: { 'lich_install' => 'tiny/install#Tiny::Install' }, plugin: true))
        expect(manager.sync_gem('x/y')).to eq(:failed)
        expect(printed.last).to include('ships a RubyGems plugin')
        expect(gemspecs_in(gem_home)).to be_empty
      end

      it 'stops before downloading when the plugins directory is read-only' do
        plugins = File.join(gem_home, 'plugins')
        FileUtils.mkdir_p(plugins)
        allow(File).to receive(:writable?).and_call_original
        allow(File).to receive(:writable?).with(plugins).and_return(false)
        allow_any_instance_of(URI::HTTP).to receive(:open).and_raise('must not download')

        expect(manager.sync_gem('x/y')).to eq(:failed)
        expect(printed.last).to include('plugins', 'gems cannot be installed')
        expect(printed.join).not_to include('must not download')
      end

      it "reports RubyGems' permission error with the gem home hint" do
        serve(build_gem(metadata: { 'lich_install' => 'tiny/install#Tiny::Install' }))
        allow_any_instance_of(Gem::Installer).to receive(:install).and_raise(Gem::FilePermissionError.new(File.join(gem_home, 'plugins')))
        expect(manager.sync_gem('x/y')).to eq(:failed)
        expect(printed.last).to include('not installed: cannot write to', 'GEM_HOME')
      end

      it 'refuses an asset over the size limit without downloading it' do
        allow(client).to receive(:fetch_github_json)
          .and_return(release_with('tiny-1.2.0.gem', size: described_class::MAX_ASSET_BYTES + 1))
        allow_any_instance_of(URI::HTTP).to receive(:open).and_raise('must not download')
        expect(manager.sync_gem('x/y')).to eq(:failed)
        expect(printed.last).to include('over the', 'limit for a script package; not downloaded')
      end

      it 'refuses a download whose SHA-256 does not match the published digest, and removes it' do
        allow(client).to receive(:fetch_github_json).and_return(release_with('tiny-1.2.0.gem', digest: "sha256:#{'0' * 64}"))
        serve(build_gem(metadata: { 'lich_install' => 'tiny/install#Tiny::Install' }))
        expect(manager.sync_gem('x/y')).to eq(:failed)
        expect(printed.last).to include('SHA-256 does not match')
        expect(Dir.children(TEMP_DIR)).to be_empty
        expect(gemspecs_in(gem_home)).to be_empty
      end

      it 'installs a download whose SHA-256 matches the published digest' do
        gem = build_gem(metadata: { 'lich_install' => 'tiny/install#Tiny::Install' })
        allow(client).to receive(:fetch_github_json)
          .and_return(release_with('tiny-1.2.0.gem', digest: "sha256:#{Digest::SHA256.file(gem).hexdigest}"))
        serve(gem)
        expect(manager.sync_gem('x/y')).to eq(:updated)
      end

      it 'gives up when another session holds the install lock past the wait, and downloads first' do
        stub_const("#{described_class}::INSTALL_LOCK_WAIT", 0.3)
        lock = File.join(gem_home, '.lich5-gem-packages.lock')
        held = Queue.new
        done = Queue.new
        other = Thread.new { described_class.with_lock(lock) { held << true; done.pop } }
        held.pop
        downloaded = false
        allow(manager).to(receive(:download).and_wrap_original { |original, *args| downloaded = true; original.call(*args) })
        serve(build_gem(metadata: { 'lich_install' => 'tiny/install#Tiny::Install' }))

        expect(manager.sync_gem('x/y')).to eq(:failed)
        expect(downloaded).to be(true)
        expect(printed.last).to include('Another Lich session is installing a gem package')
        expect(Dir.children(TEMP_DIR)).to be_empty
        done << true
        other.join
      end

      it 'uninstalls older versions only after the new one is installed and deployed' do
        stub_const('DATA_DIR', File.join(tmp, 'data'))
        old = build_gem(metadata: { 'lich_install' => 'tiny/install#Tiny::Install' }, version: '1.0.0')
        old_copy = File.join(tmp, 'tiny-1.0.0.gem')
        FileUtils.cp(old, old_copy)
        Gem::Installer.at(old_copy, install_dir: gem_home, bin_dir: File.join(tmp, 'data', 'gem-packages', 'bin'),
                                    ignore_dependencies: true, wrappers: false).install
        allow(Gem::Specification).to receive(:find_all_by_name).and_call_original
        allow(Gem::Specification).to receive(:find_all_by_name).with('tiny') do
          Dir[File.join(gem_home, 'specifications', 'tiny-*.gemspec')].map { |f| Gem::Specification.load(f) }
        end
        serve(build_gem(metadata: { 'lich_install' => 'tiny/install#Tiny::Install' }))

        expect(manager.sync_gem('x/y')).to eq(:updated)
        expect(gemspecs_in(gem_home)).to eq(['tiny-1.2.0.gemspec'])
      end

      it 'keeps the older version when the new one fails to deploy' do
        old = build_gem(metadata: { 'lich_install' => 'tiny/install#Tiny::Install' }, version: '1.0.0')
        old_copy = File.join(tmp, 'tiny-1.0.0.gem')
        FileUtils.cp(old, old_copy)
        Gem::Installer.at(old_copy, install_dir: gem_home, ignore_dependencies: true, wrappers: false).install
        allow(Gem::Specification).to receive(:find_all_by_name).and_call_original
        allow(Gem::Specification).to receive(:find_all_by_name).with('tiny') do
          Dir[File.join(gem_home, 'specifications', 'tiny-*.gemspec')].map { |f| Gem::Specification.load(f) }
        end
        serve(build_gem(metadata: { 'lich_install' => 'tiny/install#Tiny::Missing' }))

        expect(manager.sync_gem('x/y')).to eq(:failed)
        expect(gemspecs_in(gem_home)).to eq(['tiny-1.0.0.gemspec', 'tiny-1.2.0.gemspec'])
      end

      it 'does not adopt a higher version of the name installed from elsewhere' do
        foreign_dir = File.join(tmp, 'foreign')
        FileUtils.mkdir_p(File.join(foreign_dir, 'lib', 'tiny'))
        File.write(File.join(foreign_dir, 'lib', 'tiny', 'install.rb'), <<~RUBY)
          module Tiny
            module Install
              def self.install(lich_dir) = File.write(File.join(lich_dir, 'FOREIGN'), 'ran')
            end
          end
        RUBY
        foreign = Gem::Specification.new do |s|
          s.name = 'tiny'
          s.version = '9.0.0'
          s.metadata = { 'lich_install' => 'tiny/install#Tiny::Install', 'source_code_uri' => 'https://github.com/other/publisher' }
        end
        allow(foreign).to receive(:full_gem_path).and_return(foreign_dir)
        described_class.save('x/y' => { 'gem' => 'tiny', 'installed_gem' => 'tiny', 'installed' => '1.0.0',
                                        'deployed_gem' => 'tiny', 'deployed' => '1.0.0' })
        allow(described_class).to receive(:installed_version).with('tiny').and_return(Gem::Version.new('9.0.0'))
        allow(Gem::Specification).to receive(:find_all_by_name).and_call_original
        allow(Gem::Specification).to receive(:find_all_by_name).with('tiny', '= 9.0.0').and_return([foreign])
        serve(build_gem(metadata: { 'lich_install' => 'tiny/install#Tiny::Install' }))

        expect(manager.sync_gem('x/y')).to eq(:updated)
        expect(File).not_to exist(File.join(lich_dir, 'FOREIGN'))
        expect(File.read(File.join(lich_dir, 'scripts', 'tiny.lic'))).to eq("installed into #{lich_dir}")
        expect(described_class.all['x/y']).to include('installed' => '1.2.0', 'deployed' => '1.2.0')
      end

      it 'downloads and verifies the release version when someone else installed it' do
        described_class.save('x/y' => { 'gem' => 'tiny' })
        allow(described_class).to receive(:installed_version).with('tiny').and_return(Gem::Version.new('1.2.0'))
        allow(Gem::Specification).to receive(:find_all_by_name).and_call_original
        allow(Gem::Specification).to receive(:find_all_by_name).with('tiny', '= 1.2.0').and_return([marker_spec('1.2.0', 'FOREIGN')])
        downloaded = false
        allow(manager).to(receive(:download).and_wrap_original { |original, *args| downloaded = true; original.call(*args) })
        serve(build_gem(metadata: { 'lich_install' => 'tiny/install#Tiny::Install' }))

        expect(manager.sync_gem('x/y')).to eq(:updated)
        expect(downloaded).to be(true)
        expect(printed.last).to eq('[lich5-update: tiny 1.2.0 reinstalled.]')
        expect(File).not_to exist(File.join(lich_dir, 'FOREIGN'))
        expect(described_class.all['x/y']).to include('installed_gem' => 'tiny', 'installed' => '1.2.0')
      end

      it 'retries its own installed version, not a higher one from elsewhere' do
        described_class.save('x/y' => { 'gem' => 'tiny', 'installed_gem' => 'tiny', 'installed' => '1.2.0' })
        allow(described_class).to receive(:installed_version).with('tiny').and_return(Gem::Version.new('9.0.0'))
        allow(Gem::Specification).to receive(:find_all_by_name).and_call_original
        allow(Gem::Specification).to receive(:find_all_by_name).with('tiny', '= 1.2.0').and_return([marker_spec('1.2.0', 'OURS', source: 'https://github.com/x/y')])
        allow(Gem::Specification).to receive(:find_all_by_name).with('tiny', '= 9.0.0').and_return([marker_spec('9.0.0', 'FOREIGN')])
        allow_any_instance_of(URI::HTTP).to receive(:open).and_raise('must not download')

        expect(manager.sync_gem('x/y')).to eq(:updated)
        expect(File).to exist(File.join(lich_dir, 'OURS'))
        expect(File).not_to exist(File.join(lich_dir, 'FOREIGN'))
        expect(described_class.all['x/y']).to include('deployed' => '1.2.0')
      end

      it 'refuses a plugin the archive carries even when the metadata leaves it out' do
        gem = hide_from_metadata(build_gem(metadata: { 'lich_install' => 'tiny/install#Tiny::Install' }, plugin: true),
                                 'lib/rubygems_plugin.rb')
        expect(Gem::Package.new(gem).spec.files).not_to include('lib/rubygems_plugin.rb')
        expect(Gem::Package.new(gem).contents).to include('lib/rubygems_plugin.rb')
        serve(gem)

        expect(manager.sync_gem('x/y')).to eq(:failed)
        expect(printed.last).to include('ships a RubyGems plugin')
        expect(gemspecs_in(gem_home)).to be_empty
        expect(Dir[File.join(gem_home, 'plugins', '*')]).to be_empty
      end

      it 'refuses a plugin file whatever its case or suffix' do
        %w[RubyGems_Plugin.rb rubygems_plugin.so].each do |plugin_name|
          printed.clear
          serve(build_gem(metadata: { 'lich_install' => 'tiny/install#Tiny::Install' }, plugin: true, plugin_name: plugin_name))
          expect(manager.sync_gem('x/y')).to eq(:failed)
          expect(printed.last).to include('ships a RubyGems plugin')
        end
      end

      it 'aborts the transfer once it passes the size limit, whatever the asset metadata said' do
        stopped_at = nil
        allow_any_instance_of(URI::HTTP).to receive(:open) do |_uri, **opts|
          opts[:content_length_proc].call(nil)
          opts[:progress_proc].call(1024)
          begin
            opts[:progress_proc].call(described_class::MAX_ASSET_BYTES + 1)
          rescue StandardError
            stopped_at = described_class::MAX_ASSET_BYTES + 1
            raise
          end
          raise 'the transfer was not stopped'
        end

        expect(manager.sync_gem('x/y')).to eq(:failed)
        expect(stopped_at).to eq(described_class::MAX_ASSET_BYTES + 1)
        expect(printed.last).to include('Could not download tiny-1.2.0.gem', 'over the')
        expect(Dir.children(TEMP_DIR)).to be_empty
      end

      it 'aborts before the body when the declared length is over the limit' do
        allow_any_instance_of(URI::HTTP).to receive(:open) do |_uri, **opts|
          opts[:content_length_proc].call(described_class::MAX_ASSET_BYTES + 1)
          raise 'the body was read'
        end

        expect(manager.sync_gem('x/y')).to eq(:failed)
        expect(printed.last).to include('over the')
        expect(printed.last).not_to include('the body was read')
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

      def build_gem(metadata:, extensions: [], installer: default_installer, required_ruby: nil,
                    version: '1.2.0', executables: [], plugin: false, plugin_name: 'rubygems_plugin.rb')
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
        extra = []
        executables.each do |exe|
          FileUtils.mkdir_p(File.join(src, 'exe'))
          File.write(File.join(src, 'exe', exe), "#!/usr/bin/env ruby
")
          extra << "exe/#{exe}"
        end
        if plugin
          File.write(File.join(src, 'lib', plugin_name), '')
          extra << "lib/#{plugin_name}"
        end
        spec = Gem::Specification.new do |s|
          s.name = 'tiny'
          s.version = version
          s.summary = 'test package'
          s.authors = ['spec']
          s.files = ['lib/tiny/install.rb'] + extensions + extra
          s.metadata = metadata
          s.extensions = extensions
          s.bindir = 'exe'
          s.executables = executables
          s.required_ruby_version = required_ruby if required_ruby
        end
        Dir.chdir(src) { Gem::DefaultUserInteraction.use_ui(Gem::SilentUI.new) { Gem::Package.build(spec) } }
        File.join(src, "tiny-#{version}.gem")
      end

      # Rewrites a built gem so its metadata no longer lists +hidden+, while
      # the archive still carries it: what a publisher could ship.
      def hide_from_metadata(gem_path, hidden)
        spec = Gem::Package.new(gem_path).spec
        spec.files -= [hidden]
        entries = {}
        File.open(gem_path, 'rb') do |io|
          Gem::Package::TarReader.new(io) { |tar| tar.each { |e| entries[e.full_name] = e.read } }
        end
        entries['metadata.gz'] = Zlib.gzip(spec.to_yaml)
        entries.delete('checksums.yaml.gz')
        File.open(gem_path, 'wb') do |io|
          Gem::Package::TarWriter.new(io) do |tar|
            entries.each { |name, data| tar.add_file_simple(name, 0o444, data.bytesize) { |f| f.write(data) } }
          end
        end
        gem_path
      end

      # An installed-looking spec at +version+ whose installer writes +marker+
      # into the Lich directory, standing in for a gem from elsewhere.
      def marker_spec(version, marker, source: 'https://github.com/other/publisher')
        dir = File.join(tmp, "marker-#{marker}")
        FileUtils.mkdir_p(File.join(dir, 'lib', 'tiny'))
        File.write(File.join(dir, 'lib', 'tiny', 'install.rb'), <<~RUBY)
          module Tiny
            module Install
              def self.install(lich_dir) = File.write(File.join(lich_dir, '#{marker}'), 'ran')
            end
          end
        RUBY
        spec = Gem::Specification.new do |s|
          s.name = 'tiny'
          s.version = version
          s.metadata = { 'lich_install' => 'tiny/install#Tiny::Install', 'source_code_uri' => source }
        end
        allow(spec).to receive(:full_gem_path).and_return(dir)
        spec
      end

      def gemspecs_in(home)
        Dir[File.join(home, 'specifications', '*.gemspec')].map { |f| File.basename(f) }.sort
      end

      def serve(gem_path)
        bytes = File.binread(gem_path)
        allow_any_instance_of(URI::HTTP).to receive(:open).and_return(StringIO.new(bytes))
      end
    end

    def release_with(asset_name, size: nil, digest: nil)
      asset = { 'name' => asset_name, 'browser_download_url' => "https://github.com/x/y/releases/download/v1.2.0/#{asset_name}" }
      asset['size'] = size if size
      asset['digest'] = digest if digest
      { 'tag_name' => 'v1.2.0', 'assets' => [asset] }
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
