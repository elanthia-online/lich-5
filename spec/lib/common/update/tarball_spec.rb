# frozen_string_literal: true

require 'stringio'
require_relative 'update_spec_helper'
require_relative '../../../support/tar_gz_builder'

RSpec.describe Lich::Util::Update::Tarball do
  let(:temp_dir) { Dir.mktmpdir('lich-update-temp') }
  let(:url) { 'https://example.test/lich-5.tar.gz' }
  let(:tarball_path) { File.join(temp_dir, 'lich5-5.99.0.tar.gz') }
  let(:extract_dir) { File.join(temp_dir, 'lich5-5.99.0') }
  let(:archive) do
    TarGzBuilder.build([{ name: 'lich-5-abc/', type: :directory },
                        { name: 'lich-5-abc/lib/version.rb', data: "LICH_VERSION = '5.99.0'\n" }], pax_global_header: true)
  end
  let(:remote) { StringIO.new(archive) }

  before do
    stub_const('TEMP_DIR', temp_dir)
    allow(Lich::Util::Update::GitHubClient).to receive(:open_uri_timeouts).and_return({ read_timeout: 1 })
    allow(URI).to receive(:parse).with(url).and_return(double('uri', open: remote))
  end

  after { FileUtils.remove_entry(temp_dir) if Dir.exist?(temp_dir) }

  it 'yields the top-level directory, returns the block value, and removes everything afterwards' do
    seen = nil
    result = described_class.with_extracted(url, 'lich5-5.99.0') do |source_dir|
      seen = source_dir
      File.read(File.join(source_dir, 'lib', 'version.rb'))
    end

    expect(seen).to eq(File.join(extract_dir, 'lich-5-abc'))
    expect(result).to eq("LICH_VERSION = '5.99.0'\n")
    expect(Dir.children(temp_dir)).to be_empty
    expect(remote).to be_closed
  end

  it 'removes everything when the block raises' do
    expect { described_class.with_extracted(url, 'lich5-5.99.0') { raise 'install failed' } }.to raise_error('install failed')
    expect(Dir.children(temp_dir)).to be_empty
  end

  it 'removes everything when the archive is corrupt' do
    allow(URI).to receive(:parse).with(url).and_return(double('uri', open: StringIO.new('not gzip')))

    expect { described_class.with_extracted(url, 'lich5-5.99.0') { raise 'not reached' } }
      .to raise_error(Lich::Archive::Error, /not a valid gzip archive/)
    expect(Dir.children(temp_dir)).to be_empty
  end

  it 'removes leftovers of an interrupted run before extracting, so they cannot mix in' do
    FileUtils.mkdir_p(File.join(extract_dir, 'lich-5-old'))
    File.write(tarball_path, 'stale')

    described_class.with_extracted(url, 'lich5-5.99.0') do |source_dir|
      expect(Dir.children(extract_dir)).to eq(['lich-5-abc'])
      expect(source_dir).to end_with('lich-5-abc')
    end
  end

  describe 'the name, which comes from what the player typed' do
    let(:base) { Dir.mktmpdir('lich-update-base') }
    let(:temp_dir) { File.join(base, 'temp').tap { |dir| FileUtils.mkdir_p(dir) } }
    let(:keep) { File.join(base, 'data', 'keep.txt') }

    before do
      FileUtils.mkdir_p(File.dirname(keep))
      File.write(keep, 'keep')
    end

    after { FileUtils.remove_entry(base) if Dir.exist?(base) }

    ['x\\..\\..\\data', '../data', '../../data', '..', '.', '...', 'a/../../data', 'CON', ''].each do |name|
      it "never removes anything outside TEMP_DIR for #{name.inspect}" do
        removed = []
        allow(FileUtils).to receive(:rm_rf).and_wrap_original do |original, paths, **options|
          removed.concat(Array(paths))
          original.call(paths, **options)
        end

        begin
          described_class.with_extracted(url, name) { |source_dir| expect(source_dir).to start_with("#{temp_dir}/") }
        rescue ArgumentError
          # An unusable name is refused before anything is removed.
        end

        expect(File.read(keep)).to eq('keep')
        removed.each do |path|
          expect(File.dirname(File.expand_path(path))).to eq(File.expand_path(temp_dir)), path
        end
      end
    end

    # Windows drops trailing dots, so "..." would name TEMP_DIR itself there,
    # and opens a device for CON whatever follows it. Neither shows on POSIX.
    it 'never returns a name Windows would shorten or treat as a device' do
      ['...', 'x.', 'x..', 'CON', 'nul.x', 'COM1'].each do |name|
        safe = described_class.safe_name(name)
        expect(safe).not_to end_with('.'), name
        expect(Lich::Archive.unsafe_segment?(safe)).to be(false), name
      end
    end

    it 'keeps an ordinary release or branch name as it is' do
      described_class.with_extracted(url, 'lich5-branch-feature-x_1.2') do |source_dir|
        expect(source_dir).to eq(File.join(temp_dir, 'lich5-branch-feature-x_1.2', 'lich-5-abc'))
      end
    end
  end

  it 'leaves nothing behind when the download fails' do
    allow(URI).to receive(:parse).with(url).and_return(double('uri').tap { |uri| allow(uri).to receive(:open).and_raise(SocketError, 'offline') })

    expect { described_class.with_extracted(url, 'lich5-5.99.0') { raise 'not reached' } }.to raise_error(SocketError)
    expect(Dir.children(temp_dir)).to be_empty
  end
end
