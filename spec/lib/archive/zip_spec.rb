# spec/lib/archive/zip_spec.rb
require 'fileutils'
require 'tmpdir'

require_relative '../../../lib/archive'
require_relative '../../support/no_process_expectations'
require_relative '../../support/zip_builder'

RSpec.describe Lich::Archive::Zip do
  include NoProcessExpectations

  let(:work_dir) { Dir.mktmpdir('lich-zip-archive') }
  let(:zip_path) { File.join(work_dir, 'bundle.zip') }
  let(:destination) { File.join(work_dir, 'packages') }
  # "cafe.gem" with an e-acute, built from its code point to keep the source ASCII.
  let(:accented_name) { "caf#{[0xE9].pack('U')}.gem" }

  after { FileUtils.remove_entry(work_dir) if Dir.exist?(work_dir) }

  def write_zip(entries)
    File.binwrite(zip_path, ZipBuilder.build(entries))
  end

  def extracted
    Dir.glob('**/*', base: destination).select { |path| File.file?(File.join(destination, path)) }.sort
  end

  describe '.extract' do
    it 'extracts deflated and stored entries byte for byte' do
      gem_bytes = (0..255).map(&:chr).join.b * 500
      write_zip([
                  { name: 'gtk3-4.3.9-x64-mingw-ucrt.gem', data: gem_bytes },
                  { name: 'resolution-lock.json', data: '{"ok":true}', method: :store }
                ])

      names = described_class.extract(zip_path, destination)

      expect(names).to eq(%w[gtk3-4.3.9-x64-mingw-ucrt.gem resolution-lock.json])
      expect(File.binread(File.join(destination, 'gtk3-4.3.9-x64-mingw-ucrt.gem'))).to eq(gem_bytes)
      expect(File.read(File.join(destination, 'resolution-lock.json'))).to eq('{"ok":true}')
    end

    it 'reads sizes from the central directory when entries use data descriptors' do
      # The published R4L5 bundle has this layout: local headers carry zero
      # sizes and a descriptor follows each entry's data.
      write_zip([
                  { name: 'ox.gem', data: 'ox payload' * 1000, descriptor: true },
                  { name: 'glib2.gem', data: 'glib payload' * 1000, descriptor: true }
                ])

      described_class.extract(zip_path, destination)

      expect(File.binread(File.join(destination, 'ox.gem'))).to eq('ox payload' * 1000)
      expect(File.binread(File.join(destination, 'glib2.gem'))).to eq('glib payload' * 1000)
    end

    it 'creates directory entries and nested files inside the destination' do
      write_zip([{ name: 'gems/', data: '', method: :store }, { name: 'gems/native/sqlite3.gem', data: 'sqlite' }])

      described_class.extract(zip_path, destination)

      expect(extracted).to eq(['gems/native/sqlite3.gem'])
    end

    it 'extracts an empty file' do
      write_zip([{ name: 'empty.txt', data: '' }])

      described_class.extract(zip_path, destination)

      expect(File.size(File.join(destination, 'empty.txt'))).to eq(0)
    end

    ['../escape.gem', 'gems/../../escape.gem', '/absolute.gem', '\\absolute.gem', 'C:\\absolute.gem',
     'C:relative.gem', 'sqlite3.gem:stream', "bad\nname.gem", '..\\escape.gem'].each do |name|
      it "refuses #{name.inspect} and writes nothing" do
        write_zip([{ name: 'first.gem', data: 'first' }, { name: name, data: 'evil' }])

        expect { described_class.extract(zip_path, destination) }.to raise_error(Lich::Archive::Error, /unsafe archive entry/)
        expect(Dir.exist?(destination) ? extracted : []).to be_empty
        expect(File.exist?(File.join(work_dir, 'escape.gem'))).to be(false)
      end
    end

    it 'extracts names starting with "~" literally under the destination, not under a home directory' do
      write_zip([
                  { name: '~nosuchuser123/x.gem', data: 'unknown user' },
                  { name: '~/y.gem', data: 'current user' },
                  { name: '~bare', data: 'bare' }
                ])

      described_class.extract(zip_path, destination)

      expect(File.read(File.join(destination, '~nosuchuser123', 'x.gem'))).to eq('unknown user')
      expect(File.read(File.join(destination, '~', 'y.gem'))).to eq('current user')
      expect(File.read(File.join(destination, '~bare'))).to eq('bare')
      expect(Dir.children(work_dir).sort).to eq(%w[bundle.zip packages])
    end

    {
      'a file and a directory of the same name'              => [['clash', false], ['clash/', true]],
      'a directory and a file of the same name'              => [['clash/', true], ['clash', false]],
      'a file that another entry needs as its directory'     => [['a', false], ['a/b.gem', false]],
      'a nested file whose directory another entry names'    => [['a/b.gem', false], ['a', false]],
      'a file and a directory differing only in case'        => [['Clash', false], ['clash/', true]],
      'a file that a later entry uses as a deeper directory' => [['a/b', false], ['a/b/c/d.gem', false]]
    }.each do |label, layout|
      it "refuses #{label} and writes nothing" do
        write_zip(layout.map { |name, directory| { name: name, data: directory ? '' : 'x', method: :store } })

        expect { described_class.extract(zip_path, destination) }
          .to raise_error(Lich::Archive::Error, /archive entry is both a file and a directory/)
        expect(Dir.exist?(destination)).to be(false)
      end
    end

    [%w[same.gem same.gem], %w[same.gem Same.gem], %w[same.gem ./same.gem], %w[dir/x.gem dir//x.gem]].each do |first, second|
      it "refuses #{first.inspect} followed by #{second.inspect} as a duplicate and writes nothing" do
        write_zip([{ name: first, data: 'first' }, { name: second, data: 'second' }])

        expect { described_class.extract(zip_path, destination) }
          .to raise_error(Lich::Archive::Error, /duplicate archive entry: #{Regexp.escape(second)}/)
        expect(Dir.exist?(destination)).to be(false)
      end
    end

    it 'accepts a directory listed more than once and directories implied by their files' do
      write_zip([
                  { name: 'gems/', data: '', method: :store },
                  { name: 'gems/a.gem', data: 'a' },
                  { name: 'gems/', data: '', method: :store },
                  { name: 'gems/native/b.gem', data: 'b' }
                ])

      expect(described_class.extract(zip_path, destination).length).to eq(4)
      expect(extracted).to eq(%w[gems/a.gem gems/native/b.gem])
    end

    ['nul.gem', 'gems/COM1.gem', 'a.gem.', 'gems /a.gem', 'gems\a.gem'].each do |name|
      it "refuses #{name.inspect}, which Windows would alter, and writes nothing" do
        write_zip([{ name: 'first.gem', data: 'first' }, { name: name, data: 'evil' }])

        expect { described_class.extract(zip_path, destination) }.to raise_error(Lich::Archive::Error, /unsafe archive entry/)
        expect(Dir.exist?(destination)).to be(false)
      end
    end

    it 'rejects an entry whose CRC-32 does not match' do
      write_zip([{ name: 'a.gem', data: 'payload', crc32: 1234 }])

      expect { described_class.extract(zip_path, destination) }.to raise_error(Lich::Archive::Error, /CRC-32/)
    end

    it 'rejects an entry that inflates past its declared size' do
      write_zip([{ name: 'a.gem', data: 'x' * 10_000, size: 100 }])

      expect { described_class.extract(zip_path, destination) }.to raise_error(Lich::Archive::Error, /larger than declared/)
    end

    it 'rejects an entry that inflates short of its declared size' do
      write_zip([{ name: 'a.gem', data: 'x' * 100, size: 101 }])

      expect { described_class.extract(zip_path, destination) }.to raise_error(Lich::Archive::Error, /smaller than declared/)
    end

    it 'rejects bytes after the end of a deflate stream instead of writing them' do
      # Size and CRC-32 describe the data plus the trailing bytes, so only the
      # stream-length check stops them reaching the output file.
      write_zip([{ name: 'a.gem', data: 'payload' * 10, trailing: 'junk', size: 74, crc32: Zlib.crc32("#{'payload' * 10}junk") }])

      expect { described_class.extract(zip_path, destination) }
        .to raise_error(Lich::Archive::Error, /data after its compressed stream: a\.gem/)
    end

    it 'rejects trailing bytes that arrive in a later chunk than the end of the stream' do
      data = Random.new(2).bytes(200_000)
      write_zip([{ name: 'a.gem', data: data, method: :deflate, trailing: 'x' * 70_000 }])

      expect { described_class.extract(zip_path, destination) }
        .to raise_error(Lich::Archive::Error, /data after its compressed stream: a\.gem/)
    end

    it 'rejects a deflate stream that stops before its final block' do
      deflater = Zlib::Deflate.new(Zlib::DEFAULT_COMPRESSION, -Zlib::MAX_WBITS)
      unfinished = deflater.deflate('x' * 100, Zlib::SYNC_FLUSH)
      deflater.close
      write_zip([{ name: 'a.gem', data: 'x' * 100, payload: unfinished }])

      expect { described_class.extract(zip_path, destination) }.to raise_error(Lich::Archive::Error, /corrupt: a\.gem/)
    end

    it 'rejects corrupt deflate data' do
      write_zip([{ name: 'a.gem', data: 'x' * 100 }])
      bytes = File.binread(zip_path)
      data_at = 30 + 'a.gem'.bytesize
      bytes.setbyte(data_at, 0xFF)
      bytes.setbyte(data_at + 1, 0xFF)
      File.binwrite(zip_path, bytes)

      expect { described_class.extract(zip_path, destination) }.to raise_error(Lich::Archive::Error, /corrupt|CRC-32|declared/)
    end

    it 'rejects encrypted entries' do
      write_zip([{ name: 'a.gem', data: 'x', flags: 0x0001 }])

      expect { described_class.extract(zip_path, destination) }.to raise_error(Lich::Archive::Error, /encrypted/)
    end

    it 'rejects compression methods other than stored and deflated' do
      write_zip([{ name: 'a.gem', data: 'x', method: :store, method_id: 12 }])

      expect { described_class.extract(zip_path, destination) }.to raise_error(Lich::Archive::Error, /compression method 12/)
    end

    it 'rejects ZIP64 entries' do
      write_zip([{ name: 'a.gem', data: 'x', size: 0xFFFFFFFF }])

      expect { described_class.extract(zip_path, destination) }.to raise_error(Lich::Archive::Error, /ZIP64/)
    end

    it 'rejects an entry whose data offset lies outside the archive' do
      write_zip([{ name: 'a.gem', data: 'x', offset: 50_000 }])

      expect { described_class.extract(zip_path, destination) }.to raise_error(Lich::Archive::Error, /entry data lies outside the archive: a\.gem/)
    end

    # Each archive below is otherwise valid, so removing the check it targets
    # lets the extraction succeed and the example fail.
    it 'rejects an archive that spans disks' do
      File.binwrite(zip_path, ZipBuilder.build([{ name: 'a.gem', data: 'x' }], disk_count: 0))

      expect { described_class.extract(zip_path, destination) }.to raise_error(Lich::Archive::Error, /multi-disk/)
    end

    it 'rejects an archive whose end record names another disk' do
      File.binwrite(zip_path, ZipBuilder.build([{ name: 'a.gem', data: 'x' }], disk: 1, directory_disk: 1))

      expect { described_class.extract(zip_path, destination) }.to raise_error(Lich::Archive::Error, /multi-disk/)
    end

    it 'rejects a central directory that runs into the end record' do
      entries = [{ name: 'a.gem', data: 'x' }]
      directory_size = ZipBuilder.build(entries).byteslice(-22, 22).unpack('VvvvvVVv')[5]
      File.binwrite(zip_path, ZipBuilder.build(entries, directory_size: directory_size + 4))

      expect { described_class.extract(zip_path, destination) }.to raise_error(Lich::Archive::Error, /central directory lies outside the archive/)
    end

    it 'rejects an entry whose local header has the wrong signature' do
      write_zip([{ name: 'a.gem', data: 'x', local_signature: 0x04034b51 }])

      expect { described_class.extract(zip_path, destination) }.to raise_error(Lich::Archive::Error, /local header has a bad signature: a\.gem/)
    end

    it 'rejects a non-ASCII name that is not flagged as UTF-8' do
      write_zip([{ name: accented_name, data: 'x' }])

      expect { described_class.extract(zip_path, destination) }.to raise_error(Lich::Archive::Error, /must be ASCII unless flagged UTF-8/)
      expect(Dir.exist?(destination)).to be(false)
    end

    it 'extracts a non-ASCII name flagged as UTF-8' do
      write_zip([{ name: accented_name, data: 'x', flags: 0x0800 }])

      expect(described_class.extract(zip_path, destination)).to eq([accented_name])
      expect(File.read(File.join(destination, accented_name))).to eq('x')
    end

    it 'rejects a name that is not valid UTF-8' do
      write_zip([{ name: "caf#{0xE9.chr}.gem".b, data: 'x', flags: 0x0800 }])

      expect { described_class.extract(zip_path, destination) }.to raise_error(Lich::Archive::Error, /not valid UTF-8/)
    end

    ['./', '.'].each do |name|
      it "refuses #{name.inspect}, which names the destination itself" do
        write_zip([{ name: name, data: '', method: :store }])

        expect { described_class.extract(zip_path, destination) }.to raise_error(Lich::Archive::Error, /unsafe archive entry: #{Regexp.escape(name)}\z/)
      end
    end

    it 'rejects a file that is not a ZIP archive' do
      File.binwrite(zip_path, 'not a zip archive at all, just some bytes')

      expect { described_class.extract(zip_path, destination) }.to raise_error(Lich::Archive::Error, /not a ZIP archive/)
    end

    it 'rejects a truncated archive' do
      write_zip([{ name: 'a.gem', data: 'payload' * 100 }])
      File.binwrite(zip_path, File.binread(zip_path)[0, 40])

      expect { described_class.extract(zip_path, destination) }.to raise_error(Lich::Archive::Error)
    end

    it 'starts no external process' do
      write_zip([{ name: 'gems/', data: '', method: :store }, { name: 'gems/a.gem', data: 'payload' }, { name: 'b.gem', data: 'b', method: :store }])
      expect_no_process(described_class, Lich::Archive)

      described_class.extract(zip_path, destination)
    end

    it 'extracts an archive written by the system zip program', if: system('zip', '-v', out: File::NULL, err: File::NULL) do
      source = File.join(work_dir, 'source')
      FileUtils.mkdir_p(source)
      File.binwrite(File.join(source, 'tzinfo-2.0.6.gem'), Random.new(1).bytes(200_000))
      File.binwrite(File.join(source, 'text.json'), '{"a":1}' * 2000)
      system('zip', '-q', '-X', zip_path, 'tzinfo-2.0.6.gem', 'text.json', chdir: source, exception: true)

      described_class.extract(zip_path, destination)

      %w[tzinfo-2.0.6.gem text.json].each do |name|
        expect(File.binread(File.join(destination, name))).to eq(File.binread(File.join(source, name)))
      end
    end
  end

  describe '.entries' do
    it 'lists names and declared sizes from the central directory' do
      write_zip([{ name: 'a.gem', data: 'abc' }, { name: 'b.gem', data: 'defg', method: :store }])

      expect(described_class.entries(zip_path).map { |entry| [entry.name, entry.uncompressed_size] }).to eq([['a.gem', 3], ['b.gem', 4]])
    end
  end
end
