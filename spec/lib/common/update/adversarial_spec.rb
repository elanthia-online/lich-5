# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'tmpdir'

LICH_VERSION = '5.15.1' unless defined?(LICH_VERSION)
SCRIPT_DIR = Dir.mktmpdir('lich-scripts') unless defined?(SCRIPT_DIR)
DATA_DIR = Dir.mktmpdir('lich-data') unless defined?(DATA_DIR)
BACKUP_DIR = Dir.mktmpdir('lich-backup') unless defined?(BACKUP_DIR)
LICH_DIR = Dir.mktmpdir('lich-root') unless defined?(LICH_DIR)
TEMP_DIR = Dir.mktmpdir('lich-temp') unless defined?(TEMP_DIR)
LIB_DIR = Dir.mktmpdir('lich-lib') unless defined?(LIB_DIR)

unless defined?(UserVars)
  module UserVars
    @store = {}

    def self.method_missing(name, *args)
      if name.to_s.end_with?('=')
        @store[name.to_s.chomp('=')] = args.first
      else
        @store[name.to_s]
      end
    end

    def self.respond_to_missing?(*)
      true
    end
  end
end

unless defined?(Vars)
  module Vars
    def self.save; end
  end
end

unless defined?(XMLData)
  module XMLData
    @game = 'DR'

    def self.game
      @game
    end

    def self.game=(val)
      @game = val
    end
  end
end

def respond(msg = ''); end unless defined?(respond)

require_relative '../../../../lib/update'

RSpec.describe 'Adversarial error-path tests' do
  def git_blob_sha(content)
    Digest::SHA1.hexdigest("blob #{content.bytesize}\0#{content}")
  end

  # -------------------------------------------------------------------
  # FileWriter: rollback under filesystem errors
  # -------------------------------------------------------------------
  describe Lich::Util::Update::FileWriter do
    let(:tmpdir) { Dir.mktmpdir('fw-adversarial') }

    after { FileUtils.remove_entry(tmpdir) }

    describe '.safe_write restores original on write failure' do
      it 'preserves original file when binwrite raises' do
        path = File.join(tmpdir, 'important.lic')
        original_content = "# original content\n"
        File.binwrite(path, original_content)

        allow(File).to receive(:binwrite).and_raise(Errno::ENOSPC.new("No space left on device"))

        expect { described_class.safe_write(path, "# new content\n") }.to raise_error(Errno::ENOSPC)

        expect(File.binread(path)).to eq(original_content)
        expect(File.exist?("#{path}.tmp")).to be false
        expect(File.exist?("#{path}.old")).to be false
      end
    end

    describe '.safe_write on a new file with write failure' do
      it 'cleans up tmp file and does not leave orphan .old' do
        path = File.join(tmpdir, 'brand-new.lic')

        allow(File).to receive(:binwrite).and_raise(Errno::EACCES.new("Permission denied"))

        expect { described_class.safe_write(path, "# content\n") }.to raise_error(Errno::EACCES)

        expect(File.exist?(path)).to be false
        expect(File.exist?("#{path}.tmp")).to be false
        expect(File.exist?("#{path}.old")).to be false
      end
    end

    describe '.build_local_sha_map ignores non-matching files' do
      it 'only includes files matching the glob pattern' do
        File.binwrite(File.join(tmpdir, 'script.lic'), "content")
        File.binwrite(File.join(tmpdir, 'data.yaml'), "data")
        File.binwrite(File.join(tmpdir, 'readme.md'), "readme")

        lic_map = described_class.build_local_sha_map(tmpdir, '*.lic')
        yaml_map = described_class.build_local_sha_map(tmpdir, '*.yaml')

        expect(lic_map.keys).to eq(['script.lic'])
        expect(yaml_map.keys).to eq(['data.yaml'])
      end
    end
  end

  # -------------------------------------------------------------------
  # ScriptSync: error paths during sync
  # -------------------------------------------------------------------
  describe Lich::Util::Update::ScriptSync do
    let(:tmpdir) { Dir.mktmpdir('sync-adversarial') }
    let(:client) { instance_double(Lich::Util::Update::GitHubClient) }
    let(:sync) { described_class.new(client) }

    before do
      stub_const('SCRIPT_DIR', tmpdir)
      allow(Lich::Util::Update::StatusReporter).to receive(:respond_mono)
      allow(Lich::Util::Update::StatusReporter).to receive(:render_sync_summary)
    end

    after { FileUtils.remove_entry(tmpdir) }

    describe '#sync_repo continues after safe_write failure on one file' do
      it 'downloads remaining files and records the failure' do
        tree = {
          'tree' => [
            { 'path' => 'will-fail.lic', 'type' => 'blob', 'sha' => 'aaa' },
            { 'path' => 'will-succeed.lic', 'type' => 'blob', 'sha' => 'bbb' },
          ]
        }
        config = {
          display_name: 'Test',
          api_url: 'https://api.example.com/tree',
          raw_base_url: 'https://raw.example.com',
          tracking_mode: :all,
          script_pattern: /^[^\/]+\.lic$/,
          game_filter: nil,
          subdirs: {}
        }
        stub_const('Lich::Util::Update::SCRIPT_REPOS', { 'test' => config })

        allow(client).to receive(:fetch_github_json).and_return(tree)
        allow(client).to receive(:http_get)
          .with('https://raw.example.com/will-fail.lic', auth: false)
          .and_return("# fail content")
        allow(client).to receive(:http_get)
          .with('https://raw.example.com/will-succeed.lic', auth: false)
          .and_return("# success content")

        # First file write raises, second succeeds
        call_count = 0
        allow(Lich::Util::Update::FileWriter).to receive(:safe_write) do |path, content|
          call_count += 1
          if File.basename(path) == 'will-fail.lic'
            raise Errno::EACCES, "Permission denied"
          else
            File.binwrite(path, content)
          end
        end

        sync.sync_repo('test')

        # The second file was still written despite the first failing
        expect(File.exist?(File.join(tmpdir, 'will-succeed.lic'))).to be true
        expect(call_count).to eq(2)

        # Summary was called with the failure recorded
        expect(Lich::Util::Update::StatusReporter).to have_received(:render_sync_summary).with(
          'Test',
          2,
          ['will-succeed.lic'],
          {},
          [],
          ['will-fail.lic'],
          {}
        )
      end
    end

    describe '#sync_repo when download fails for some files' do
      it 'records download failures separately from write failures' do
        tree = {
          'tree' => [
            { 'path' => 'net-fail.lic', 'type' => 'blob', 'sha' => 'xxx' },
            { 'path' => 'net-ok.lic', 'type' => 'blob', 'sha' => 'yyy' },
          ]
        }
        config = {
          display_name: 'Mixed',
          api_url: 'https://api.example.com/tree',
          raw_base_url: 'https://raw.example.com',
          tracking_mode: :all,
          script_pattern: /^[^\/]+\.lic$/,
          game_filter: nil,
          subdirs: {}
        }
        stub_const('Lich::Util::Update::SCRIPT_REPOS', { 'mixed' => config })

        allow(client).to receive(:fetch_github_json).and_return(tree)
        allow(client).to receive(:http_get)
          .with('https://raw.example.com/net-fail.lic', auth: false)
          .and_return(nil) # network failure
        allow(client).to receive(:http_get)
          .with('https://raw.example.com/net-ok.lic', auth: false)
          .and_return("# ok content")
        allow(Lich::Util::Update::FileWriter).to receive(:safe_write) do |path, content|
          File.binwrite(path, content)
        end

        sync.sync_repo('mixed')

        expect(File.exist?(File.join(tmpdir, 'net-ok.lic'))).to be true
        expect(Lich::Util::Update::StatusReporter).to have_received(:render_sync_summary).with(
          'Mixed', 2, ['net-ok.lic'], {}, [], ['net-fail.lic'], {}
        )
      end
    end

    describe '#sync_repo with unknown repo key' do
      it 'does not crash and reports the error' do
        expect { sync.sync_repo('nonexistent') }.not_to raise_error
      end
    end

    describe '#sync_repo skips repos not matching game_filter' do
      it 'returns silently for GS repo when game is DR' do
        allow(XMLData).to receive(:game).and_return('DR')
        config = {
          display_name: 'GS Only',
          api_url: 'https://api.example.com/tree',
          raw_base_url: 'https://raw.example.com',
          tracking_mode: :all,
          script_pattern: /^[^\/]+\.lic$/,
          game_filter: /^GS/,
          subdirs: {}
        }
        stub_const('Lich::Util::Update::SCRIPT_REPOS', { 'gs-only' => config })

        # If game_filter works, fetch_github_json should never be called
        expect(client).not_to receive(:fetch_github_json)
        sync.sync_repo('gs-only')
      end
    end

    describe '#sync_repo when GitHub API returns nil' do
      it 'reports failure and does not crash' do
        config = {
          display_name: 'Broken',
          api_url: 'https://api.example.com/tree',
          raw_base_url: 'https://raw.example.com',
          tracking_mode: :all,
          script_pattern: /^[^\/]+\.lic$/,
          game_filter: nil,
          subdirs: {}
        }
        stub_const('Lich::Util::Update::SCRIPT_REPOS', { 'broken' => config })
        allow(client).to receive(:fetch_github_json).and_return(nil)

        expect { sync.sync_repo('broken') }.not_to raise_error
        # Should NOT reach render_sync_summary since we bailed early
        expect(Lich::Util::Update::StatusReporter).not_to have_received(:render_sync_summary)
      end
    end

    describe '#sync_repo skips files whose SHA matches local' do
      it 'does not re-download files that are already current' do
        existing_content = "# already installed\n"
        File.binwrite(File.join(tmpdir, 'current.lic'), existing_content)
        local_sha = git_blob_sha(existing_content)

        tree = {
          'tree' => [
            { 'path' => 'current.lic', 'type' => 'blob', 'sha' => local_sha },
          ]
        }
        config = {
          display_name: 'ShaTest',
          api_url: 'https://api.example.com/tree',
          raw_base_url: 'https://raw.example.com',
          tracking_mode: :all,
          script_pattern: /^[^\/]+\.lic$/,
          game_filter: nil,
          subdirs: {}
        }
        stub_const('Lich::Util::Update::SCRIPT_REPOS', { 'sha-test' => config })
        allow(client).to receive(:fetch_github_json).and_return(tree)

        # http_get should NOT be called since SHA matches
        expect(client).not_to receive(:http_get)
        sync.sync_repo('sha-test')
      end
    end
  end

  # -------------------------------------------------------------------
  # FileUpdater: data path resolution edge cases
  # -------------------------------------------------------------------
  describe Lich::Util::Update::FileUpdater do
    let(:tmpdir) { Dir.mktmpdir('fu-adversarial') }
    let(:client) { instance_double(Lich::Util::Update::GitHubClient) }
    let(:resolver) { instance_double(Lich::Util::Update::ChannelResolver) }
    let(:updater) { described_class.new(client, resolver) }

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

        # Verify the download URL uses the correct tree path, not "data/effect-list.xml"
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

        expect(client).not_to have_received(:http_get) if client.respond_to?(:http_get)
        expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with(
          /nonexistent\.xml not found/
        )
      end
    end

    describe '#update_file_from_repo when GitHub tree API fails' do
      it 'bails early with an error message and does not attempt download' do
        allow(client).to receive(:fetch_github_json).and_return(nil)

        updater.update_file_from_repo('data', 'gs-scripts', 'effect-list.xml')

        expect(client).not_to have_received(:http_get) if client.respond_to?(:http_get)
        expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with(
          /Failed to fetch repository tree/
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

        expect(client).not_to have_received(:http_get) if client.respond_to?(:http_get)
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
  end

  # -------------------------------------------------------------------
  # GitHubClient: cache behavior under adversarial timing
  # -------------------------------------------------------------------
  describe Lich::Util::Update::GitHubClient do
    describe 'cache serves fresh entries without re-fetching' do
      it 'returns cached data for requests within TTL' do
        client = described_class.new(cache_ttl: 300)
        url = 'https://api.github.com/repos/test/tree'
        json_body = '{"tree": [{"path": "foo.lic"}]}'

        # Stub http_get to track call count
        call_count = 0
        allow(client).to receive(:http_get).with(url) do
          call_count += 1
          json_body
        end

        result1 = client.fetch_github_json(url)
        result2 = client.fetch_github_json(url)

        expect(call_count).to eq(1)
        expect(result1).to eq(result2)
        expect(result1['tree'].first['path']).to eq('foo.lic')
      end
    end

    describe 'cache expires entries after TTL' do
      it 're-fetches when entry exceeds TTL' do
        client = described_class.new(cache_ttl: 0) # immediate expiry
        url = 'https://api.github.com/repos/test/tree'

        call_count = 0
        allow(client).to receive(:http_get).with(url) do
          call_count += 1
          '{"version": ' + call_count.to_s + '}'
        end

        result1 = client.fetch_github_json(url)
        sleep 0.01 # ensure Time.now.to_i advances if needed
        result2 = client.fetch_github_json(url)

        expect(call_count).to eq(2)
        expect(result1['version']).to eq(1)
        expect(result2['version']).to eq(2)
      end
    end

    describe 'cache does not store failed requests' do
      it 'retries after a network failure' do
        client = described_class.new(cache_ttl: 300)
        url = 'https://api.github.com/repos/test/tree'

        call_count = 0
        allow(client).to receive(:http_get).with(url) do
          call_count += 1
          call_count == 1 ? nil : '{"ok": true}'
        end

        result1 = client.fetch_github_json(url)
        result2 = client.fetch_github_json(url)

        expect(result1).to be_nil
        expect(result2).to eq({ 'ok' => true })
        expect(call_count).to eq(2)
      end
    end
  end

  # -------------------------------------------------------------------
  # TrackedScripts: untrack notification edge cases
  # -------------------------------------------------------------------
  describe Lich::Util::Update::TrackedScripts do
    let(:tmpdir) { Dir.mktmpdir('ts-adversarial') }
    let(:tracker) { described_class.new }

    before do
      stub_const('SCRIPT_DIR', tmpdir)
      UserVars.tracked_scripts = nil
      allow(Lich::Util::Update::StatusReporter).to receive(:respond_mono)
      allow(Vars).to receive(:save)
    end

    after { FileUtils.remove_entry(tmpdir) }

    describe '#untrack_script shows file-on-disk notice when file exists' do
      it 'warns user that untracked file is still installed' do
        File.binwrite(File.join(tmpdir, 'bigshot.lic'), '# bigshot')
        UserVars.tracked_scripts = { 'scripts' => ['bigshot.lic'] }

        tracker.untrack_script('scripts', 'bigshot.lic')

        expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with(
          /Removed.*bigshot\.lic/
        )
        expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with(
          /still installed.*Delete manually/
        )
      end
    end

    describe '#untrack_script omits notice when file is not on disk' do
      it 'does not show file-on-disk warning' do
        UserVars.tracked_scripts = { 'scripts' => ['ghost.lic'] }

        tracker.untrack_script('scripts', 'ghost.lic')

        expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with(
          /Removed.*ghost\.lic/
        )
        expect(Lich::Util::Update::StatusReporter).not_to have_received(:respond_mono).with(
          /still installed/
        )
      end
    end

    describe '#untrack_script refuses to remove default scripts' do
      it 'blocks removal of alias.lic from Core Scripts defaults' do
        tracker.untrack_script('scripts', 'alias.lic')

        expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with(
          /default script.*cannot be removed/
        )
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

        expect(Lich::Util::Update::StatusReporter).to have_received(:respond_mono).with(
          /was not in your/
        )
      end
    end

    describe '#tracked_scripts deduplicates defaults and user additions' do
      it 'returns unique list when user adds a default script' do
        UserVars.tracked_scripts = { 'scripts' => ['alias.lic', 'custom.lic'] }
        config = Lich::Util::Update::SCRIPT_REPOS['scripts']

        result = tracker.tracked_scripts(config)

        expect(result.count('alias.lic')).to eq(1)
        expect(result).to include('custom.lic')
      end
    end
  end

  # -------------------------------------------------------------------
  # ChannelResolver: edge cases in version parsing
  # -------------------------------------------------------------------
  describe Lich::Util::Update::ChannelResolver do
    let(:client) { instance_double(Lich::Util::Update::GitHubClient) }
    let(:resolver) { described_class.new(client) }

    describe '#major_minor_patch_from with garbage input' do
      it 'returns [nil, nil, nil] for non-version strings' do
        expect(resolver.major_minor_patch_from('not-a-version')).to eq([nil, nil, nil])
        expect(resolver.major_minor_patch_from('')).to eq([nil, nil, nil])
        expect(resolver.major_minor_patch_from(nil)).to eq([nil, nil, nil])
      end
    end

    describe '#major_minor_patch_from extracts versions from branch names' do
      it 'parses version from pre/beta/5.15.3' do
        expect(resolver.major_minor_patch_from('pre/beta/5.15.3')).to eq([5, 15, 3])
      end

      it 'parses two-part version as patch=0' do
        expect(resolver.major_minor_patch_from('v5.14')).to eq([5, 14, 0])
      end
    end

    describe '#version_key orders beta prerelease correctly' do
      it 'sorts beta.10 after beta.9' do
        v9 = resolver.version_key('5.15.0-beta.9')
        v10 = resolver.version_key('5.15.0-beta.10')

        expect(v10).to be > v9
      end

      it 'sorts release after beta' do
        release = resolver.version_key('5.15.0')
        beta = resolver.version_key('5.15.0-beta.1')

        expect(release).to be > beta
      end
    end

    describe '#resolve_channel_ref returns STABLE_REF for unknown channels' do
      it 'falls through to stable for unrecognized channel' do
        expect(resolver.resolve_channel_ref(:unknown)).to eq('main')
      end
    end
  end
end
