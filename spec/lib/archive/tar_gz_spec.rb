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
    'sharp s and ss'         => [u('r/<DF>.rb'), 'r/ss.rb'],
    # Folding U+01F0 after NFC leaves the caron before the dot below.
    'out-of-order marks'     => [u('r/<1F0><323>.rb'), u('r/J<323><30C>.rb')],
    # NFC keeps the iota subscript composed, and folding then puts the
    # iota ahead of the diaeresis; only NFD before folding matches them.
    'iota subscript'         => [u('r/<1FB3><308>.rb'), u('r/<391><308><399>.rb')],
    # Ruby's NFD leaves the grave ahead of the decomposed U+0F73; only the
    # final NFD reorders it.
    'Tibetan vowel sign'     => [u('r/<300><F73>.rb'), u('r/<F71><F72><300>.rb')]
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

    # macOS bsdtar writes a non-ASCII name both as a pax path and in full in
    # the ustar name. Any pax path is refused, matching or not.
    it 'refuses a pax path even when it repeats the ustar name' do
      refuses([first, pax('x', { 'path' => 'r/second.rb' }), { name: 'r/second.rb', data: 'x' }], /pax header sets path/)
    end

    it 'refuses a pax size, which TarReader would not apply' do
      refuses([first, pax('x', { 'size' => '5' }), { name: 'r/second.rb', data: 'x' }], /pax header sets size/)
    end

    # GNU tar's pax sparse format names the entry GNUSparseFile.0/<name> and
    # stores the sparse map in its data; extracting it would write the map.
    it 'refuses a GNU pax sparse file instead of extracting its sparse map' do
      records = { 'GNU.sparse.major' => '1', 'GNU.sparse.minor' => '0', 'GNU.sparse.name' => 'r/sparse.rb', 'GNU.sparse.realsize' => '4096' }
      refuses([first, pax('x', records), { name: 'r/GNUSparseFile.0/sparse.rb', data: "1\n0\n4096\n" }],
              /pax header sets GNU\.sparse\.major and GNU\.sparse\.minor and GNU\.sparse\.name and GNU\.sparse\.realsize/)
    end

    ['0', "\0"].each do |typeflag|
      it "refuses a pre-POSIX directory (typeflag #{typeflag.inspect}, name ending in a slash) instead of writing a file" do
        refuses([first, { name: 'r/old/', type: :raw, typeflag: typeflag, data: '' }, { name: 'r/old/a.rb', data: 'a' }],
                /unsupported archive entry type \(pre-POSIX directory\), which Lich does not extract: r\/old\//)
      end
    end

    it 'refuses a malformed pax header' do
      refuses([first, { name: 'r/PaxHeaders/x.rb', type: :raw, typeflag: 'x', data: "not a record\n" }], /malformed pax header/)
    end

    # A length too large for a native integer would otherwise raise
    # RangeError from byteslice instead of the named refusal.
    it 'refuses a pax record whose length runs past the header' do
      refuses([first, { name: 'r/PaxHeaders/x.rb', type: :raw, typeflag: 'x', data: "9999999999999999999 x=y\n" }], /malformed pax header/)
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

  # TarReader returns quietly at the end of the data, reading a header cut
  # short as an empty file, and GzipReader reads only the first member.
  describe 'the end of the archive' do
    let(:version) { "LICH_VERSION = '5.99.0'\n" }
    # One complete tar stream: r/a.rb (header and one data block), then
    # r/lib/version.rb at byte 1024, then the two end blocks.
    let(:tar) { Zlib.gunzip(TarGzBuilder.build([{ name: 'r/a.rb', data: 'a' }, { name: 'r/lib/version.rb', data: version }])) }

    def refuses(bytes, message)
      File.binwrite(tarball, bytes)

      expect { described_class.extract(tarball, destination) }.to raise_error(Lich::Archive::Error, message)
      expect(Dir.exist?(destination)).to be(false)
    end

    it 'refuses a tar stream cut short inside its last header, instead of writing an empty file' do
      refuses(TarGzBuilder.gzip(tar.byteslice(0, 1024 + 110)), /truncated: it does not end with two zero blocks/)
    end

    it 'refuses a tar stream with only one end block' do
      refuses(TarGzBuilder.gzip(tar.byteslice(0, tar.bytesize - 512)), /truncated: it does not end with two zero blocks/)
    end

    it 'refuses a tar stream split across two gzip members' do
      refuses(TarGzBuilder.gzip(tar.byteslice(0, 1024)) + TarGzBuilder.gzip(tar.byteslice(1024..)), /truncated: it does not end with two zero blocks/)
    end

    it 'refuses a second gzip member after a complete tar stream' do
      refuses(TarGzBuilder.gzip(tar) + TarGzBuilder.gzip(tar), /gzip archive has data after its first member/)
    end

    it 'refuses junk after the gzip member' do
      refuses(TarGzBuilder.gzip(tar) + 'junk', /gzip archive has data after its first member/)
    end

    # GzipReader reads the file 2 KiB at a time. A member ending exactly on
    # that boundary leaves nothing in #unused, so only the file still
    # holds what follows it.
    it 'refuses junk after a gzip member that ends on the read boundary' do
      unpadded = TarGzBuilder.gzip(tar, name: 'a').bytesize
      member = TarGzBuilder.gzip(tar, name: 'a' * (1 + ((2048 - (unpadded % 2048)) % 2048)))
      expect(member.bytesize % 2048).to eq(0)

      refuses(member + 'junk', /gzip archive has data after its first member/)
    end

    it 'refuses junk after zero padding after the gzip member' do
      refuses(TarGzBuilder.gzip(tar) + ("\0" * 20_000) + 'junk', /gzip archive has data after its first member/)
    end

    # bsdtar (macOS's /usr/bin/tar) pads to its block size when it writes
    # to a pipe: tar -czf - ... > f.tar.gz.
    it 'extracts a gzip member followed by zero padding, as bsdtar writes it to a pipe' do
      member = TarGzBuilder.gzip(tar)
      File.binwrite(tarball, member + ("\0" * (10_240 - member.bytesize)))

      described_class.extract(tarball, destination)

      expect(File.read(File.join(destination, 'r/lib/version.rb'))).to eq(version)
    end

    it 'refuses data after the end blocks' do
      refuses(TarGzBuilder.gzip(tar + 'x'), /tar archive has data after its end blocks/)
    end

    it 'extracts a tar stream zero-padded to the 10240-byte record, as tar and git archive write it' do
      File.binwrite(tarball, TarGzBuilder.gzip(tar + ("\0" * (10_240 - tar.bytesize))))

      described_class.extract(tarball, destination)

      expect(File.read(File.join(destination, 'r/lib/version.rb'))).to eq(version)
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

  # RubyGems reads a uid or gid field starting 0x80 or 0xff as base-256;
  # with NULs after it, its unpack raises ArgumentError.
  { 'uid' => 108, 'gid' => 116 }.each do |field, offset|
    it "reports a base-256 #{field} field with nothing after it as an invalid tar archive" do
      tar = Zlib.gunzip(TarGzBuilder.build([{ name: 'r/a.rb', data: 'a' }]))
      tar[offset, 8] = [0x80, 0, 0, 0, 0, 0, 0, 0].pack("C*")
      File.binwrite(tarball, TarGzBuilder.gzip(tar))

      expect { described_class.extract(tarball, destination) }.to raise_error(Lich::Archive::Error, /not a valid tar archive/)
      expect(Dir.exist?(destination)).to be(false)
    end
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

    # A name too long for a tar header is written as an entry TarGz refuses.
    # `git archive` (branch tarballs, root lich-5-<commit>/) writes a pax path
    # record once a path no longer fits the ustar name and prefix fields.
    # The release workflows build lich-5.tar.gz with GNU tar's default
    # format (`tar -czvf lich-5.tar.gz Lich5/`), which writes a GNU long name
    # entry for any name over 100 bytes, directories included.
    it 'keeps every path short enough for the tar headers of both update archives', skip: (in_git ? false : 'not a git checkout') do
      listing, status = Open3.capture2('git', '-C', root, 'ls-files', '-z')
      expect(status).to be_success
      paths = listing.split("\0")
      ustar = lambda do |path|
        path.bytesize <= 100 || (0..[path.bytesize - 1, 155].min).any? { |i| path.getbyte(i) == 47 && path.bytesize - i - 1 <= 100 }
      end
      branch_prefix = "lich-5-#{'0' * 40}/"
      too_long = paths.reject { |path| ustar.call(branch_prefix + path) }
      expect(too_long).to be_empty, "paths too long for a git archive ustar header: #{too_long.join(', ')}"

      release_names = paths.flat_map { |path| ["Lich5/#{path}", *path.split('/')[0...-1].each_index.map { |i| "Lich5/#{path.split('/')[0..i].join('/')}/" }] }
      too_long = release_names.uniq.select { |name| name.bytesize > 100 }
      expect(too_long).to be_empty, "names over 100 bytes, which GNU tar writes as long-name entries: #{too_long.join(', ')}"
    end
  end
end
