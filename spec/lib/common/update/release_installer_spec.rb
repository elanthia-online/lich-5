# frozen_string_literal: true

require_relative 'update_spec_helper'

RSpec.describe Lich::Util::Update::ReleaseInstaller do
  subject(:installer) { described_class.new(client, resolver, snapshot_manager) }

  let(:client) { double('GitHubClient') }
  let(:resolver) { double('ChannelResolver') }
  let(:snapshot_manager) { double('SnapshotManager') }

  # A freshly extracted archive directory populated with the given entries.
  # Directories are created for names ending in '/', regular files otherwise.
  #
  # @param entries [Array<String>] archive-relative names to materialize
  # @return [String] path to the populated temporary directory
  def build_archive(*entries)
    dir = Dir.mktmpdir('lich-archive')
    entries.each do |entry|
      path = File.join(dir, entry)
      if entry.end_with?('/')
        FileUtils.mkdir_p(path)
      else
        File.write(path, "# #{entry}\n")
      end
    end
    dir
  end

  describe 'TOP_LEVEL_FILES' do
    it 'carries Gemfile.lock alongside Gemfile so the resolved set stays in sync' do
      expect(described_class::TOP_LEVEL_FILES).to include('Gemfile', 'Gemfile.lock')
    end
  end

  describe 'REQUIRED_ARCHIVE_ITEMS' do
    it 'requires the core install entries' do
      expect(described_class::REQUIRED_ARCHIVE_ITEMS).to include('lib', 'lich.rbw', 'Gemfile', 'LICENSE')
    end

    it 'does not require the optional Gemfile.lock' do
      expect(described_class::REQUIRED_ARCHIVE_ITEMS).not_to include('Gemfile.lock')
    end
  end

  describe '#copy_top_level_files' do
    let(:target_dir) { Dir.mktmpdir('lich-target') }

    before { stub_const('LICH_DIR', target_dir) }

    after { FileUtils.remove_entry(target_dir) if Dir.exist?(target_dir) }

    it 'copies the Gemfile.lock into LICH_DIR alongside the Gemfile' do
      source_dir = build_archive('Gemfile', 'Gemfile.lock', 'LICENSE')

      installer.copy_top_level_files(source_dir)

      expect(File).to exist(File.join(target_dir, 'Gemfile'))
      expect(File).to exist(File.join(target_dir, 'Gemfile.lock'))
      expect(File).to exist(File.join(target_dir, 'LICENSE'))
    ensure
      FileUtils.remove_entry(source_dir)
    end

    it 'skips top-level files absent from the archive without raising' do
      source_dir = build_archive('Gemfile') # no Gemfile.lock, no LICENSE

      expect { installer.copy_top_level_files(source_dir) }.not_to raise_error

      expect(File).to exist(File.join(target_dir, 'Gemfile'))
      expect(File).not_to exist(File.join(target_dir, 'Gemfile.lock'))
      expect(File).not_to exist(File.join(target_dir, 'LICENSE'))
    ensure
      FileUtils.remove_entry(source_dir)
    end
  end

  describe '#validate_lich_structure' do
    it 'accepts an archive containing every required entry' do
      source_dir = build_archive('lib/', 'lich.rbw', 'Gemfile', 'Gemfile.lock', 'LICENSE')

      expect(installer.validate_lich_structure(source_dir)).to be(true)
    ensure
      FileUtils.remove_entry(source_dir)
    end

    it 'accepts an archive that omits the optional Gemfile.lock' do
      source_dir = build_archive('lib/', 'lich.rbw', 'Gemfile', 'LICENSE')

      expect(installer.validate_lich_structure(source_dir)).to be(true)
    ensure
      FileUtils.remove_entry(source_dir)
    end

    it 'rejects an archive missing a required entry' do
      source_dir = build_archive('lib/', 'Gemfile', 'LICENSE') # no lich.rbw

      expect(installer.validate_lich_structure(source_dir)).to be(false)
    ensure
      FileUtils.remove_entry(source_dir)
    end
  end
end
