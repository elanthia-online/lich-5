# spec/lib/archive/tar_gz_spec.rb
require 'fileutils'
require 'tmpdir'

require_relative '../../../lib/archive'
require_relative '../../support/tar_gz_builder'

RSpec.describe Lich::Archive::TarGz do
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

  it 'refuses a symbolic link, even one pointing inside the archive, and writes nothing' do
    write_tarball([{ name: 'r/real.rb', data: 'x' }, { name: 'r/link.rb', type: :symlink, target: 'real.rb' }])

    expect { described_class.extract(tarball, destination) }.to raise_error(Lich::Archive::Error, /link.*r\/link\.rb/)
    expect(Dir.exist?(destination)).to be(false)
  end

  it 'refuses a hard link' do
    write_tarball([{ name: 'r/real.rb', data: 'x' }, { name: 'r/hard.rb', type: :hardlink, target: 'r/real.rb' }])

    expect { described_class.extract(tarball, destination) }.to raise_error(Lich::Archive::Error, /link/)
  end

  it 'reports a file that is not gzip' do
    File.binwrite(tarball, 'not a gzip archive')

    expect { described_class.extract(tarball, destination) }.to raise_error(Lich::Archive::Error, /not a valid gzip archive/)
  end

  it 'reports gzip data that is not a tar archive' do
    File.binwrite(tarball, Zlib.gzip('x' * 1024))

    expect { described_class.extract(tarball, destination) }.to raise_error(Lich::Archive::Error, /not a valid tar archive/)
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
    write_tarball([{ name: 'r/a.rb', data: 'a' }])
    expect(Process).not_to receive(:spawn)
    expect(Kernel).not_to receive(:system)
    expect(IO).not_to receive(:popen)

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
end
