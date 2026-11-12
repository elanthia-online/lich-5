# spec/lib/archive_spec.rb
require 'fileutils'
require 'tmpdir'

require_relative '../../lib/archive'
require_relative '../support/no_process_expectations'
require_relative '../support/zip_builder'
require_relative '../support/tar_gz_builder'

RSpec.describe Lich::Archive do
  include NoProcessExpectations

  let(:work_dir) { Dir.mktmpdir('lich-archive') }
  let(:destination) { File.join(work_dir, 'out') }

  after { FileUtils.remove_entry(work_dir) if Dir.exist?(work_dir) }

  describe '.unsafe_entry?' do
    it 'rejects empty, absolute, drive, stream, control-character, and parent-traversal names' do
      ['', '/absolute.gem', '\\absolute.gem', 'C:\\absolute.gem', 'C:/absolute.gem', 'C:relative.gem',
       'a.gem:stream', "a\tb.gem", '../escape.gem', 'gems/../escape.gem', 'gems\..\escape.gem', 'gems/..'].each do |name|
        expect(described_class.unsafe_entry?(name)).to be(true), name.inspect
      end
    end

    it 'accepts safe relative filenames and subpaths' do
      %w[sqlite3.gem gems/sqlite3.gem gems/native/sqlite3.gem gems/ a..b.gem].each do |name|
        expect(described_class.unsafe_entry?(name)).to be(false), name.inspect
      end
    end
  end

  describe '.unsafe_entry? on names Windows would alter' do
    superscript_one = [0xB9].pack('U')

    ['dir\file.gem', 'a\b', 'a.gem.', 'a.gem ', 'dir./a.gem', 'dir /a.gem', '...', 'CON', 'con', 'nul.gem', 'NUL.tar.gz',
     'gems/aux', 'gems/Aux.rb', 'aux .rb', 'prn', 'COM1', 'com9.txt', 'LPT0', 'lpt3.log', 'CONIN$', 'conout$.x',
     "COM#{superscript_one}", "r/x#{0xE9.chr}.rb".b].each do |name|
      it "refuses #{name.inspect}" do
        expect(described_class.unsafe_entry?(name)).to be(true)
      end
    end

    ['console.rb', 'connect/x.rb', 'nullable.rb', 'auxiliary/a.rb', 'com10.rb', 'lpt.rb', 'COMX', 'a..b.gem', '.github/x.yml',
     './lich-5/lich.rbw', 'gems/./a.gem', 'gems//a.gem', 'lich-5-main/', '~/a.gem', 'caf' + [0xE9].pack('U') + '.gem'].each do |name|
      it "accepts #{name.inspect}" do
        expect(described_class.unsafe_entry?(name)).to be(false)
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

  describe '.resolve' do
    let(:root) { File.expand_path(destination) }

    it 'keeps a leading "~" literal instead of expanding it as a home directory' do
      expect(described_class.resolve('~nosuchuser123/x.gem', root)).to eq(File.join(root, '~nosuchuser123', 'x.gem'))
      expect(described_class.safe_destination('~/x.gem', root)).to eq(File.join(root, '~', 'x.gem'))
    end
  end

  describe '.plan' do
    let(:root) { File.expand_path(destination) }

    it 'returns each target in entry order' do
      expect(described_class.plan([['a/', true], ['a/b.gem', false], ['c.gem', false]], root))
        .to eq([File.join(root, 'a'), File.join(root, 'a', 'b.gem'), File.join(root, 'c.gem')])
    end

    it 'refuses an unsafe name before checking the layout' do
      expect { described_class.plan([['a.gem', false], ['../a.gem', false]], root) }.to raise_error(described_class::Error, /unsafe archive entry: \.\.\/a\.gem/)
    end

    it 'refuses a duplicate file and a path that is both a file and a directory' do
      expect { described_class.plan([['a.gem', false], ['A.GEM', false]], root) }.to raise_error(described_class::Error, /duplicate archive entry: A\.GEM/)
      expect { described_class.plan([['a/b/c', false], ['a/b', false]], root) }.to raise_error(described_class::Error, %r{both a file and a directory: a/b\z})
    end

    it 'allows a repeated directory' do
      expect(described_class.plan([['a/', true], ['a/', true], ['a/x', false]], root).length).to eq(3)
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

  it 'starts no external process for either format' do
    zip = File.join(work_dir, 'a.zip')
    tarball = File.join(work_dir, 'a.tar.gz')
    File.binwrite(zip, ZipBuilder.build([{ name: 'a.gem', data: 'gem' }]))
    File.binwrite(tarball, TarGzBuilder.build([{ name: 'r/', type: :directory }, { name: 'r/a.rb', data: 'a' }]))
    expect_no_process(described_class, described_class::Zip, described_class::TarGz)

    described_class.extract_zip(zip, File.join(destination, 'zip'))
    described_class.extract_tar_gz_root(tarball, File.join(destination, 'tar'))
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
