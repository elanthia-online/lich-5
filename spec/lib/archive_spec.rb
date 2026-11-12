# spec/lib/archive_spec.rb
require 'fileutils'
require 'tmpdir'

require_relative '../../lib/archive'
require_relative '../support/zip_builder'
require_relative '../support/tar_gz_builder'

RSpec.describe Lich::Archive do
  let(:work_dir) { Dir.mktmpdir('lich-archive') }
  let(:destination) { File.join(work_dir, 'out') }

  after { FileUtils.remove_entry(work_dir) if Dir.exist?(work_dir) }

  describe '.unsafe_entry?' do
    it 'rejects empty, absolute, drive, stream, control-character, and parent-traversal names' do
      ['', '/absolute.gem', '\\absolute.gem', 'C:\\absolute.gem', 'C:/absolute.gem', 'C:relative.gem',
       'a.gem:stream', "a\tb.gem", '../escape.gem', 'gems/../escape.gem', 'gems\\..\\escape.gem'].each do |name|
        expect(described_class.unsafe_entry?(name)).to be(true), name.inspect
      end
    end

    it 'accepts safe relative filenames and subpaths' do
      %w[sqlite3.gem gems/sqlite3.gem gems/native/sqlite3.gem gems/ a..b.gem].each do |name|
        expect(described_class.unsafe_entry?(name)).to be(false), name.inspect
      end
    end
  end

  describe '.safe_destination' do
    let(:root) { File.expand_path(destination) }

    it 'returns the absolute path inside the root' do
      expect(described_class.safe_destination('lib/version.rb', root)).to eq(File.join(root, 'lib', 'version.rb'))
    end

    it 'raises for a name that resolves to the root itself or outside it' do
      ['.', './', '../out-sibling/x'].each do |name|
        expect { described_class.safe_destination(name, root) }.to raise_error(described_class::Error, /unsafe archive entry/), name
      end
    end
  end

  describe '.extract_zip' do
    it 'extracts through the ZIP reader' do
      zip = File.join(work_dir, 'a.zip')
      File.binwrite(zip, ZipBuilder.build([{ name: 'a.gem', data: 'gem' }]))

      expect(described_class.extract_zip(zip, destination)).to eq(['a.gem'])
      expect(File.binread(File.join(destination, 'a.gem'))).to eq('gem')
    end
  end

  describe '.extract_tar_gz_root' do
    let(:tarball) { File.join(work_dir, 'lich.tar.gz') }

    it 'returns the single top-level directory of a GitHub-style archive' do
      File.binwrite(tarball, TarGzBuilder.build([{ name: 'lich-5-abc/', type: :directory },
                                                 { name: 'lich-5-abc/lich.rbw', data: '# lich' }], pax_global_header: true))

      root = described_class.extract_tar_gz_root(tarball, destination)

      expect(root).to eq(File.join(destination, 'lich-5-abc'))
      expect(File.read(File.join(root, 'lich.rbw'))).to eq('# lich')
    end

    it 'refuses an archive without exactly one top-level directory' do
      File.binwrite(tarball, TarGzBuilder.build([{ name: 'a/x', data: '' }, { name: 'b/y', data: '' }]))

      expect { described_class.extract_tar_gz_root(tarball, destination) }
        .to raise_error(described_class::Error, /one top-level directory.*found a, b/)
    end

    it 'refuses an archive whose only top-level entry is a file' do
      File.binwrite(tarball, TarGzBuilder.build([{ name: 'lich.rbw', data: '' }]))

      expect { described_class.extract_tar_gz_root(tarball, destination) }.to raise_error(described_class::Error, /found lich\.rbw/)
    end
  end
end
