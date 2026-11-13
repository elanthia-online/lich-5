# spec/lib/archive/tar_gz_spec.rb
require 'fileutils'
require 'open3'
require 'tmpdir'

require_relative '../../../lib/archive'
require_relative '../../support/no_process_expectations'
require_relative '../../support/tar_gz_builder'

RSpec.describe Lich::Archive::TarGz do
  include NoProcessExpectations

  let(:work_dir) { Dir.mktmpdir('lich-tar-gz') }
  let(:tarball) { File.join(work_dir, 'lich.tar.gz') }
  let(:destination) { File.join(work_dir, 'out') }

  after { FileUtils.remove_entry(work_dir) if Dir.exist?(work_dir) }

  def write_tarball(entries, **options)
    File.binwrite(tarball, TarGzBuilder.build(entries, **options))
  end

  def extracted
    Dir.glob('**/*', File::FNM_DOTMATCH, base: destination).reject { |path| path.end_with?('.') }.sort
  end

  it 'extracts files and directories byte for byte, skipping the pax global header' do
    binary = (0..255).map(&:chr).join.b * 200
    write_tarball([{ name: 'lich-5-abc/', type: :directory },
                   { name: 'lich-5-abc/lib/version.rb', data: "LICH_VERSION = '5.99.0'\n" },
                   { name: 'lich-5-abc/data/blob.bin', data: binary },
                   { name: 'lich-5-abc/empty', data: '' }], pax_global_header: true)

    names = described_class.extract(tarball, destination)

    expect(names).to eq(%w[lich-5-abc lich-5-abc/lib/version.rb lich-5-abc/data/blob.bin lich-5-abc/empty])
    expect(extracted).to eq(%w[lich-5-abc lich-5-abc/data lich-5-abc/data/blob.bin lich-5-abc/empty lich-5-abc/lib lich-5-abc/lib/version.rb])
    expect(File.read(File.join(destination, 'lich-5-abc/lib/version.rb'))).to eq("LICH_VERSION = '5.99.0'\n")
    expect(File.binread(File.join(destination, 'lich-5-abc/data/blob.bin'))).to eq(binary)
    expect(File.exist?(File.join(destination, 'pax_global_header'))).to be(false)
  end

  it 'extracts names longer than 100 bytes stored in the ustar prefix' do
    deep = "lich-5-abc/#{'d' * 90}/#{'f' * 90}.rb"
    write_tarball([{ name: deep, data: 'deep' }])

    described_class.extract(tarball, destination)

    expect(File.read(File.join(destination, deep))).to eq('deep')
  end

  it 'accepts the "./" root entry that `tar -czf x.tar.gz .` writes' do
    write_tarball([{ name: './', type: :directory }, { name: './lich-5/lich.rbw', data: '# lich' }])

    expect(described_class.extract(tarball, destination)).to eq(['./lich-5/lich.rbw'])
    expect(File.read(File.join(destination, 'lich-5', 'lich.rbw'))).to eq('# lich')
  end

  it 'keeps the executable bit without granting group or world write', unless: Gem.win_platform? do
    write_tarball([{ name: 'r/lich.rbw', data: '#!', mode: 0o777 }, { name: 'r/locked.rb', data: '', mode: 0o000 }])

    described_class.extract(tarball, destination)

    expect(File.stat(File.join(destination, 'r/lich.rbw')).mode & 0o777).to eq(0o755 & ~File.umask)
    expect(File.stat(File.join(destination, 'r/locked.rb')).mode & 0o600).to eq(0o600)
  end

  ['../escape.rb', 'r/../../escape.rb', '/absolute.rb', 'C:/absolute.rb', 'r/file.rb:stream', "r/bad\nname.rb"].each do |name|
    it "refuses #{name.inspect} and writes nothing" do
      write_tarball([{ name: 'r/first.rb', data: 'first' }, { name: name, data: 'evil' }])

      expect { described_class.extract(tarball, destination) }.to raise_error(Lich::Archive::Error, /unsafe archive entry/)
      expect(Dir.exist?(destination)).to be(false)
      expect(File.exist?(File.join(work_dir, 'escape.rb'))).to be(false)
    end
  end

  it 'extracts names starting with "~" literally under the destination, not under a home directory' do
    write_tarball([{ name: '~nosuchuser123/', type: :directory },
                   { name: '~nosuchuser123/x.rb', data: 'unknown user' },
                   { name: '~/y.rb', data: 'current user' }])

    described_class.extract(tarball, destination)

    expect(File.read(File.join(destination, '~nosuchuser123', 'x.rb'))).to eq('unknown user')
    expect(File.read(File.join(destination, '~', 'y.rb'))).to eq('current user')
    expect(Dir.children(work_dir).sort).to eq(%w[lich.tar.gz out])
  end

  {
    'a file and a directory of the same name'           => [{ name: 'r/clash', data: 'x' }, { name: 'r/clash/', type: :directory }],
    'a directory and a file of the same name'           => [{ name: 'r/clash/', type: :directory }, { name: 'r/clash', data: 'x' }],
    'a file that another entry needs as its directory'  => [{ name: 'r/a', data: 'x' }, { name: 'r/a/b.rb', data: 'y' }],
    'a nested file whose directory another entry names' => [{ name: 'r/a/b.rb', data: 'y' }, { name: 'r/a', data: 'x' }],
    'a file and a directory differing only in case'     => [{ name: 'r/Clash', data: 'x' }, { name: 'r/clash/', type: :directory }]
  }.each do |label, entries|
    it "refuses #{label} and writes nothing" do
      write_tarball(entries)

      expect { described_class.extract(tarball, destination) }
        .to raise_error(Lich::Archive::Error, /archive entry is both a file and a directory/)
      expect(Dir.exist?(destination)).to be(false)
    end
  end

  [%w[r/same.rb r/same.rb], %w[r/same.rb r/Same.rb], %w[r/same.rb r/./same.rb]].each do |first, second|
    it "refuses #{first.inspect} followed by #{second.inspect} as a duplicate and writes nothing" do
      write_tarball([{ name: first, data: 'first' }, { name: second, data: 'second' }])

      expect { described_class.extract(tarball, destination) }
        .to raise_error(Lich::Archive::Error, /duplicate archive entry: #{Regexp.escape(second)}/)
      expect(Dir.exist?(destination)).to be(false)
    end
  end

  # Names a normalising or case-insensitive file system stores as one file,
  # spelled in ASCII source as hex code points ("caf<E9>"). Tar names reach
  # the check as binary strings, unlike ZIP names.
  def self.u(text)
    text.gsub(/<(\h+)>/) { [Regexp.last_match(1).hex].pack('U') }
  end

  def u(text)
    self.class.u(text)
  end

  {
    'NFC and NFD e-acute'    => [u('r/caf<E9>.rb'), u('r/cafe<301>.rb')],
    'final and medial sigma' => [u('r/<3C2>.rb'), u('r/<3C3>.rb')],
    'long s and s'           => [u('r/<17F>.rb'), 'r/s.rb'],
    'micro sign and mu'      => [u('r/<B5>.rb'), u('r/<3BC>.rb')],
    'sharp s and ss'         => [u('r/<DF>.rb'), 'r/ss.rb']
  }.each do |label, (first, second)|
    it "refuses #{label} as a duplicate and writes nothing" do
      write_tarball([{ name: first, data: 'first' }, { name: second, data: 'second' }])

      expect { described_class.extract(tarball, destination) }
        .to raise_error(Lich::Archive::Error, /duplicate archive entry: #{Regexp.escape(second)}/)
      expect(Dir.exist?(destination)).to be(false)
    end
  end

  it 'refuses a file and a directory whose names differ only in Unicode normalisation' do
    write_tarball([{ name: u('r/caf<E9>'), data: 'x' }, { name: u('r/cafe<301>/a.rb'), data: 'a' }])

    expect { described_class.extract(tarball, destination) }
      .to raise_error(Lich::Archive::Error, /archive entry is both a file and a directory/)
    expect(Dir.exist?(destination)).to be(false)
  end

  it 'accepts a directory listed more than once and directories implied by their files' do
    write_tarball([{ name: 'r/', type: :directory }, { name: 'r/lib/a.rb', data: 'a' }, { name: 'r/', type: :directory },
                   { name: 'r/lib/', type: :directory }])

    expect(described_class.extract(tarball, destination)).to eq(%w[r r/lib/a.rb r r/lib])
    expect(File.read(File.join(destination, 'r/lib/a.rb'))).to eq('a')
  end

  # A trailing space cannot be tested here: RubyGems strips it when reading a
  # tar header, so such a name never reaches the check.
  ['r/nul', 'r/CON.rb', 'r/lib./x.rb', 'r\x.rb', "r/x#{0xE9.chr}.rb".b].each do |name|
    it "refuses #{name.inspect}, which Windows would alter, and writes nothing" do
      write_tarball([{ name: 'r/first.rb', data: 'first' }, { name: name, data: 'evil' }])

      expect { described_class.extract(tarball, destination) }.to raise_error(Lich::Archive::Error, /unsafe archive entry/)
      expect(Dir.exist?(destination)).to be(false)
    end
  end

  it 'refuses a symbolic link, even one pointing inside the archive, and writes nothing' do
    write_tarball([{ name: 'r/real.rb', data: 'x' }, { name: 'r/link.rb', type: :symlink, target: 'real.rb' }])

    expect { described_class.extract(tarball, destination) }.to raise_error(Lich::Archive::Error, /link.*r\/link\.rb/)
    expect(Dir.exist?(destination)).to be(false)
  end

  it 'refuses a hard link' do
    write_tarball([{ name: 'r/real.rb', data: 'x' }, { name: 'r/hard.rb', type: :hardlink, target: 'r/real.rb' }])

    expect { described_class.extract(tarball, destination) }.to raise_error(Lich::Archive::Error, /link/)
  end

  describe 'entry types other than files and directories' do
    let(:first) { { name: 'r/first.rb', data: 'first' } }
    let(:long_name) { "r/#{'d' * 120}.rb" }

    def pax(typeflag, records, name: 'r/PaxHeaders/x.rb')
      { name: name, type: :raw, typeflag: typeflag, data: TarGzBuilder.pax_records(records) }
    end

    def refuses(entries, message)
      write_tarball(entries)

      expect { described_class.extract(tarball, destination) }.to raise_error(Lich::Archive::Error, message)
      expect(Dir.exist?(destination)).to be(false)
    end

    it 'refuses a GNU long name instead of extracting under the truncated name' do
      refuses([first, { name: '././@LongLink', type: :raw, typeflag: 'L', data: "#{long_name}\0" },
               { name: long_name[0, 100], data: 'long' }], /GNU long name.*@LongLink/)
    end

    it 'refuses a pax header that sets path' do
      refuses([first, pax('x', { 'path' => long_name }), { name: long_name[0, 100], data: 'long' }], /pax header sets path/)
    end

    it 'refuses a pax header that sets linkpath' do
      refuses([first, pax('x', { 'linkpath' => 'r/first.rb' }), { name: 'r/second.rb', data: 'x' }], /pax header sets linkpath/)
    end

    it 'refuses a global pax header that sets path' do
      refuses([pax('g', { 'path' => 'elsewhere' }, name: 'pax_global_header'), first], /pax header sets path/)
    end

    it 'refuses a malformed pax header' do
      refuses([first, { name: 'r/PaxHeaders/x.rb', type: :raw, typeflag: 'x', data: "not a record\n" }], /malformed pax header/)
    end

    it 'skips a per-file pax header that does not rename the entry' do
      write_tarball([pax('x', { 'mtime' => '1700000000.5', 'uname' => 'lich' }), first])

      expect(described_class.extract(tarball, destination)).to eq(['r/first.rb'])
      expect(extracted).to eq(%w[r r/first.rb])
    end

    { '7' => 'contiguous file', '6' => 'FIFO', '3' => 'character device', '4' => 'block device',
      'K' => 'GNU long link name', 'S' => 'GNU sparse file', 'Z' => 'unknown type "Z"' }.each do |typeflag, kind|
      it "refuses typeflag #{typeflag} (#{kind}) instead of dropping it" do
        refuses([first, { name: 'r/odd', type: :raw, typeflag: typeflag, data: '' }], /unsupported archive entry type \(#{Regexp.escape(kind)}\), which Lich does not extract: r\/odd/)
      end
    end
  end

  it 'reports a file that is not gzip' do
    File.binwrite(tarball, 'not a gzip archive')

    expect { described_class.extract(tarball, destination) }.to raise_error(Lich::Archive::Error, /not a valid gzip archive/)
  end

  it 'reports gzip data that is not a tar archive' do
    File.binwrite(tarball, Zlib.gzip('x' * 1024))

    expect { described_class.extract(tarball, destination) }.to raise_error(Lich::Archive::Error, /not a valid tar archive/)
  end

  describe 'gzip integrity' do
    let(:version) { "LICH_VERSION = '5.99.0'\n" }
    # Level 0 stores the tar bytes verbatim, so a byte of version.rb can be
    # changed without breaking the deflate stream: only the CRC catches it.
    let(:good) { TarGzBuilder.build([{ name: 'r/lib/version.rb', data: version }], level: 0) }

    def gzip_rejects?(path)
      _out, status = Open3.capture2e('gzip', '-t', path)
      !status.success?
    end

    {
      'a changed byte of file data'   => ->(bytes) { bytes.sub("5.99.0", "6.99.0") },
      'a wrong CRC-32 in the trailer' => ->(bytes) { bytes.dup.tap { |b| b.setbyte(-8, b.getbyte(-8) ^ 0xFF) } },
      'a wrong length in the trailer' => ->(bytes) { bytes.dup.tap { |b| b.setbyte(-4, b.getbyte(-4) ^ 0x01) } }
    }.each do |label, corrupt|
      it "refuses a tarball with #{label} and writes nothing" do
        bytes = corrupt.call(good.b)
        expect(bytes).not_to eq(good)
        File.binwrite(tarball, bytes)
        expect(gzip_rejects?(tarball)).to be(true) if system('gzip', '--version', out: File::NULL, err: File::NULL)

        expect { described_class.extract(tarball, destination) }
          .to raise_error(Lich::Archive::Error, /not a valid gzip archive: .*(crc|length) error/i)
        expect(Dir.exist?(destination)).to be(false)
      end
    end

    it 'still extracts the uncorrupted tarball' do
      File.binwrite(tarball, good)

      described_class.extract(tarball, destination)

      expect(File.read(File.join(destination, 'r/lib/version.rb'))).to eq(version)
    end
  end

  it 'refuses an entry whose declared size runs past the end of the data, and writes nothing' do
    write_tarball([{ name: 'r/a.rb', data: 'a' }, { name: 'r/short.rb', type: :raw, typeflag: '0', data: 'only this', size: 4096, pad: false }],
                  end_blocks: false)

    expect { described_class.extract(tarball, destination) }.to raise_error(Lich::Archive::Error, /truncated/)
    expect(Dir.exist?(destination)).to be(false)
  end

  it 'closes the tarball, so it can be deleted (Windows refuses to delete an open file)' do
    write_tarball([{ name: 'r/a.rb', data: 'a' }])
    opened = []
    allow(File).to receive(:open).and_wrap_original do |original, *args, **kwargs, &block|
      original.call(*args, **kwargs) do |file|
        opened << file
        block.call(file)
      end
    end

    described_class.extract(tarball, destination)

    archive_handles = opened.select { |file| file.path == tarball }
    expect(archive_handles).not_to be_empty
    expect(archive_handles).to all(be_closed)
  end

  it 'starts no external process' do
    write_tarball([{ name: 'r/', type: :directory }, { name: 'r/a.rb', data: 'a' }], pax_global_header: true)
    expect_no_process(described_class, Lich::Archive)

    described_class.extract(tarball, destination)
  end

  it 'extracts an archive written by the system tar program', if: system('tar', '--version', out: File::NULL, err: File::NULL) do
    source = File.join(work_dir, 'src', 'lich-5-abc')
    FileUtils.mkdir_p(File.join(source, 'lib'))
    File.write(File.join(source, 'lib', 'version.rb'), "LICH_VERSION = '1'\n")
    File.binwrite(File.join(source, 'blob'), Random.new(2).bytes(100_000))
    # Relative paths: GNU tar (Git for Windows) reads "D:/..." as host:path.
    system('tar', '-czf', File.basename(tarball), '-C', 'src', 'lich-5-abc', chdir: work_dir, exception: true)

    described_class.extract(tarball, destination)

    expect(File.binread(File.join(destination, 'lich-5-abc', 'blob'))).to eq(File.binread(File.join(source, 'blob')))
    expect(File.read(File.join(destination, 'lich-5-abc', 'lib', 'version.rb'))).to eq("LICH_VERSION = '1'\n")
  end

  # TarGz refuses every link, so a symlink committed to lich-5 would make
  # every client refuse the release that carries it. Catch it here instead.
  describe 'release tree' do
    root = File.expand_path('../../..', __dir__)
    in_git = system('git', '-C', root, 'rev-parse', '--is-inside-work-tree', out: File::NULL, err: File::NULL)

    it 'commits no symbolic links, which update extraction would refuse', skip: (in_git ? false : 'not a git checkout') do
      listing, status = Open3.capture2('git', '-C', root, 'ls-files', '-s', '-z')
      expect(status).to be_success
      links = listing.split("\0").select { |line| line.start_with?('120000 ') }.map { |line| line.split("\t", 2).last }
      expect(links).to be_empty, "symbolic links in the tree: #{links.join(', ')}"
    end

    # A path too long for a ustar header makes `git archive` write a pax
    # path record, which TarGz refuses. GitHub's root is lich-5-<commit>/.
    it 'keeps every path short enough for a ustar header under the GitHub archive root', skip: (in_git ? false : 'not a git checkout') do
      listing, status = Open3.capture2('git', '-C', root, 'ls-files', '-z')
      expect(status).to be_success
      prefix = "lich-5-#{'0' * 40}/"
      fits = lambda do |path|
        path.bytesize <= 100 || (0..[path.bytesize - 1, 155].min).any? { |i| path.getbyte(i) == 47 && path.bytesize - i - 1 <= 100 }
      end
      too_long = listing.split("\0").reject { |path| fits.call(prefix + path) }
      expect(too_long).to be_empty, "paths too long for ustar: #{too_long.join(', ')}"
    end
  end
end
