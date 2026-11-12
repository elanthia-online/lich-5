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

  it 'leaves nothing behind when the download fails' do
    allow(URI).to receive(:parse).with(url).and_return(double('uri').tap { |uri| allow(uri).to receive(:open).and_raise(SocketError, 'offline') })

    expect { described_class.with_extracted(url, 'lich5-5.99.0') { raise 'not reached' } }.to raise_error(SocketError)
    expect(Dir.children(temp_dir)).to be_empty
  end
end
