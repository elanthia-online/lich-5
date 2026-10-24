# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative '../../../lib/genie'
require 'tmpdir'

RSpec.describe Lich::Genie::VariableFile do
  around { |example| Dir.mktmpdir { |dir| @dir = dir; example.run } }

  def path = File.join(@dir, 'variables.cfg')

  describe '.dump' do
    it 'writes `#var {key} {value}` CRLF rows in Remix SortedList order, with no escaping' do
      dumped = described_class.dump({ 'target' => 'a large kobold', 'Mode' => 'hunt', 'b' => 'x {y} z', 'e' => '' })
      expect(dumped).to eq("#var {b} {x {y} z}\r\n#var {e} {}\r\n#var {Mode} {hunt}\r\n#var {target} {a large kobold}\r\n")
    end

    it 'is empty for no entries' do
      expect(described_class.dump({})).to eq('')
    end
  end

  describe '.load / .read' do
    it 'returns empty (and false) for a missing file' do
      expect(described_class.load(File.join(@dir, 'nope.cfg'))).to eq({})
      expect(described_class.read(nil)).to eq([{}, false])
    end

    it 'loads only rows that parse to exactly three args (LoadRow)' do
      File.binwrite(path, "#var {ok} {yes}\r\ngarbage\r\none two\r\n#var {two} {a b c}\r\na b c d\r\nx y z\r\n")
      expect(described_class.load(path)).to eq({ 'ok' => 'yes', 'two' => 'a b c', 'y' => 'z' })
    end

    it 'loads a file written by the old write-through store (LF, insertion order)' do
      File.binwrite(path, "#var {zeta} {1}\n#var {alpha} {2}\n")
      expect(described_class.read(path)).to eq([{ 'zeta' => '1', 'alpha' => '2' }, true])
    end

    it 'strips the quotes ParseArgs strips (AddArrayItem) and keeps the last of duplicate keys' do
      File.binwrite(path, "#var {q} {\"hi there\"}\r\n#var {d} {1}\r\n#var {d} {2}\r\n")
      expect(described_class.load(path)).to eq({ 'q' => 'hi there', 'd' => '2' })
    end

    # Verified on the real Remix Load (genieflow --vars): AddArrayItem's Substring(1, -1)
    # on a lone quote throws, ParseArgs rethrows, Load's catch sits outside the read loop.
    it 'aborts at a row ParseArgs throws on, keeping the rows before it and reporting false' do
      File.binwrite(path, "#var {x} {1}\r\n#var {'} {1}\r\n#var {y} {1}\r\n")
      expect(described_class.read(path)).to eq([{ 'x' => '1' }, false])
    end

    it 'is empty and false (never raises) when the file cannot be read (Load is catch (Exception), Globals.cs:757-762 R)' do
      path = File.join(@dir, 'locked.cfg')
      File.binwrite(path, "#var {a} {1}\r\n")
      allow(File).to receive(:binread).and_call_original
      allow(File).to receive(:binread).with(path).and_raise(Errno::EACCES, path)
      expect(described_class.read(path)).to eq([{}, false])
      expect(described_class.load(path)).to eq({})
    end

    it 'is empty and false for a real unreadable file (chmod 000)' do
      skip 'root can read a mode-000 file' if Process.euid.zero?
      path = File.join(@dir, 'mode000.cfg')
      File.binwrite(path, "#var {a} {1}\r\n")
      File.chmod(0o000, path)
      expect(described_class.read(path)).to eq([{}, false])
    ensure
      File.chmod(0o600, path) if path && File.exist?(path)
    end

    it 'decodes invalid UTF-8 to U+FFFD instead of raising (StreamReader)' do
      File.binwrite(path, "#var {name} {caf#{[0xE9].pack('C')}}\r\n#var {after} {ok}\r\n")
      expect(described_class.load(path)).to eq({ 'name' => "caf#{[0xFFFD].pack('U')}", 'after' => 'ok' })
    end
  end

  describe '.save' do
    it 'creates the directory and leaves no temp file behind' do
      target = File.join(@dir, 'Config', 'variables.cfg')
      described_class.save(target, { 'x' => '1' })
      expect(File.binread(target)).to eq("#var {x} {1}\r\n")
      expect(Dir.children(File.dirname(target))).to eq(['variables.cfg'])
    end

    it 'round-trips values that contain braces, quotes-inside and non-ASCII' do
      entries = { 'b' => 'x {y} z', 'q' => 'say "hi" now', 'u' => "caf#{[0xE9].pack('U')}" }
      described_class.save(path, entries)
      expect(described_class.load(path)).to eq(entries)
      expect(File.binread(path).encoding).to eq(Encoding::BINARY)
      expect(File.binread(path)).not_to start_with([0xEF, 0xBB, 0xBF].pack('C*')) # UTF-8 without BOM
    end
  end
end
