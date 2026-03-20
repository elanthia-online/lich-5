# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'tmpdir'

# Minimal stubs for Lich runtime dependencies needed by update.rb
LICH_VERSION = '5.15.1' unless defined?(LICH_VERSION)
SCRIPT_DIR = Dir.mktmpdir('lich-scripts') unless defined?(SCRIPT_DIR)
DATA_DIR = Dir.mktmpdir('lich-data') unless defined?(DATA_DIR)
BACKUP_DIR = Dir.mktmpdir('lich-backup') unless defined?(BACKUP_DIR)
LICH_DIR = Dir.mktmpdir('lich-root') unless defined?(LICH_DIR)
TEMP_DIR = Dir.mktmpdir('lich-temp') unless defined?(TEMP_DIR)
LIB_DIR = Dir.mktmpdir('lich-lib') unless defined?(LIB_DIR)

# Stub UserVars
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

# Stub XMLData
unless defined?(XMLData)
  module XMLData
    def self.game
      'DR'
    end
  end
end

# Stub respond for messaging
def respond(msg = '')
  # silent in tests
end unless defined?(respond)

require_relative '../../../lib/update'

RSpec.describe 'Lich::Util::Update ScriptSync' do
  let(:tmpdir) { Dir.mktmpdir('sync-test') }
  let(:content_lf) { "# test script\nputs 'hello'\n" }
  let(:content_modified) { "# test script v2\nputs 'hello world'\n" }

  after { FileUtils.remove_entry(tmpdir) }

  def git_blob_sha(content)
    Digest::SHA1.hexdigest("blob #{content.bytesize}\0#{content}")
  end

  describe '.build_local_sha_map' do
    it 'computes git blob SHAs for files matching the pattern' do
      File.binwrite(File.join(tmpdir, 'foo.lic'), content_lf)
      File.binwrite(File.join(tmpdir, 'bar.lic'), content_modified)
      File.binwrite(File.join(tmpdir, 'skip.txt'), 'ignored')

      map = Lich::Util::Update.build_local_sha_map(tmpdir, '*.lic')

      expect(map.keys).to contain_exactly('foo.lic', 'bar.lic')
      expect(map['foo.lic']).to eq(git_blob_sha(content_lf))
      expect(map['bar.lic']).to eq(git_blob_sha(content_modified))
    end

    it 'returns empty hash for empty directory' do
      expect(Lich::Util::Update.build_local_sha_map(tmpdir)).to eq({})
    end
  end

  describe '.safe_write' do
    it 'writes content in binary mode preserving LF endings' do
      path = File.join(tmpdir, 'test.lic')
      Lich::Util::Update.safe_write(path, content_lf)

      expect(File.binread(path)).to eq(content_lf)
    end

    it 'creates .old backup and cleans up on success' do
      path = File.join(tmpdir, 'test.lic')
      File.binwrite(path, 'original')

      Lich::Util::Update.safe_write(path, content_lf)

      expect(File.binread(path)).to eq(content_lf)
      expect(File.exist?("#{path}.old")).to be false
      expect(File.exist?("#{path}.tmp")).to be false
    end

    it 'round-trips content with matching SHA' do
      path = File.join(tmpdir, 'roundtrip.lic')
      Lich::Util::Update.safe_write(path, content_lf)
      read_back = File.binread(path)

      expect(git_blob_sha(read_back)).to eq(git_blob_sha(content_lf))
    end
  end

  describe '.filter_syncable_scripts' do
    let(:tree) do
      [
        { 'path' => 'forge.lic', 'type' => 'blob', 'sha' => 'abc' },
        { 'path' => 'pick.lic', 'type' => 'blob', 'sha' => 'def' },
        { 'path' => 'base-setup.lic', 'type' => 'blob', 'sha' => 'ghi' },
        { 'path' => 'data/base-spells.yaml', 'type' => 'blob', 'sha' => 'jkl' },
        { 'path' => 'profiles/base.yaml', 'type' => 'blob', 'sha' => 'mno' },
        { 'path' => 'subdir/nested.lic', 'type' => 'blob', 'sha' => 'pqr' },
      ]
    end

    context 'with :all tracking mode' do
      let(:config) do
        {
          tracking_mode: :all,
          script_pattern: /^[^\/]+\.lic$/,
        }
      end

      it 'returns all root .lic files except -setup files' do
        result = Lich::Util::Update.filter_syncable_scripts(tree, config)
        filenames = result.map { |e| e['path'] }

        expect(filenames).to contain_exactly('forge.lic', 'pick.lic')
      end
    end

    context 'with :explicit tracking mode' do
      let(:config) do
        {
          tracking_mode: :explicit,
          script_pattern: /^[^\/]+\.lic$/,
          default_tracked: %w[forge.lic].freeze,
        }
      end

      it 'returns only tracked scripts' do
        result = Lich::Util::Update.filter_syncable_scripts(tree, config)
        filenames = result.map { |e| e['path'] }

        expect(filenames).to contain_exactly('forge.lic')
      end
    end
  end

  describe '.tracked_scripts' do
    let(:config) do
      {
        tracking_mode: :explicit,
        default_tracked: %w[alias.lic go2.lic].freeze,
      }
    end

    before { UserVars.tracked_scripts = nil }

    it 'returns defaults when no user additions' do
      result = Lich::Util::Update.tracked_scripts(config)
      expect(result).to contain_exactly('alias.lic', 'go2.lic')
    end

    it 'merges user additions with defaults' do
      UserVars.tracked_scripts = { 'scripts' => ['bigshot.lic'] }
      # Use the actual scripts config from SCRIPT_REPOS so key lookup works
      scripts_config = Lich::Util::Update::SCRIPT_REPOS['scripts']
      result = Lich::Util::Update.tracked_scripts(scripts_config)
      expect(result).to include('alias.lic', 'go2.lic', 'bigshot.lic')
    end
  end

  describe 'SCRIPT_REPOS registry' do
    it 'defines dr-scripts with :all tracking mode' do
      config = Lich::Util::Update::SCRIPT_REPOS['dr-scripts']
      expect(config[:tracking_mode]).to eq(:all)
      expect(config[:game_filter]).to eq(/^DR/)
      expect(config[:subdirs]).to have_key('profiles')
      expect(config[:subdirs]).to have_key('data')
    end

    it 'defines scripts with :explicit tracking mode and defaults' do
      config = Lich::Util::Update::SCRIPT_REPOS['scripts']
      expect(config[:tracking_mode]).to eq(:explicit)
      expect(config[:game_filter]).to be_nil
      expect(config[:default_tracked]).to include('alias.lic', 'go2.lic', 'map.lic')
    end

    it 'has frozen configs' do
      Lich::Util::Update::SCRIPT_REPOS.each_value do |config|
        expect(config).to be_frozen
      end
    end
  end
end
