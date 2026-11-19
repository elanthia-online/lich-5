# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative '../../../lib/genie'
require 'tmpdir'

RSpec.describe Lich::Genie::ConfigFile do
  around { |example| Dir.mktmpdir { |dir| @dir = dir; example.run } }

  def path = File.join(@dir, 'x.cfg')
  def fffd = [0xFFFD].pack('U')
  def bytes(*list) = list.pack('C*')

  describe '.read_lines' do
    it 'is nil for a missing file, a nil path and a directory' do
      expect(described_class.read_lines(File.join(@dir, 'nope'))).to be_nil
      expect(described_class.read_lines(nil)).to be_nil
      expect(described_class.read_lines(@dir)).to be_nil
    end

    it 'splits on CRLF, lone CR and lone LF like .NET ReadLine; a trailing terminator adds no line' do
      File.binwrite(path, "a\r\nb\rc\nd\r\n\r\ne\r\n")
      expect(described_class.read_lines(path)).to eq(['a', 'b', 'c', 'd', '', 'e'])
    end

    it 'keeps a final unterminated line and reads an empty file as no lines' do
      File.binwrite(path, "a\r\nlast")
      expect(described_class.read_lines(path)).to eq(%w[a last])
      File.binwrite(path, '')
      expect(described_class.read_lines(path)).to eq([])
    end

    it 'drops a UTF-8 BOM' do
      File.binwrite(path, "#{bytes(0xEF, 0xBB, 0xBF)}#var {a} {1}\r\n")
      expect(described_class.read_lines(path)).to eq(['#var {a} {1}'])
    end

    it 'decodes UTF-16 LE and BE files by their BOM' do
      File.binwrite(path, bytes(0xFF, 0xFE) + "#var {a} {1}\r\n".encode('UTF-16LE').b)
      expect(described_class.read_lines(path)).to eq(['#var {a} {1}'])
      File.binwrite(path, bytes(0xFE, 0xFF) + "#var {b} {2}\n".encode('UTF-16BE').b)
      expect(described_class.read_lines(path)).to eq(['#var {b} {2}'])
    end

    it 'turns invalid UTF-8 bytes into U+FFFD and returns valid UTF-8' do
      File.binwrite(path, "caf#{bytes(0xE9)} #{bytes(0xFF, 0xFE)}not-a-bom-here\r\n")
      lines = described_class.read_lines(path)
      expect(lines).to eq(["caf#{fffd} #{fffd}#{fffd}not-a-bom-here"])
      expect(lines.first.encoding).to eq(Encoding::UTF_8)
      expect(lines.first.valid_encoding?).to be(true)
    end
  end

  describe '.write_lines' do
    it 'writes UTF-8 without BOM, CRLF after every line, creating the directory' do
      target = File.join(@dir, 'a', 'b', 'x.cfg')
      described_class.write_lines(target, ['one', "caf#{[0xE9].pack('U')}"])
      expect(File.binread(target)).to eq("one\r\ncaf#{bytes(0xC3, 0xA9)}\r\n")
    end

    it 'writes an empty file for no lines' do
      described_class.write_lines(path, [])
      expect(File.binread(path)).to eq('')
    end

    it 'never writes invalid UTF-8 (binary or broken input is scrubbed)' do
      described_class.write_lines(path, ["bad#{bytes(0xFF)}", "worse#{bytes(0xE9)}".force_encoding('UTF-8')])
      expect(File.binread(path).force_encoding('UTF-8')).to eq("bad#{fffd}\r\nworse#{fffd}\r\n")
    end

    it 'replaces the target atomically and removes its temp file' do
      File.write(path, 'old')
      described_class.write_lines(path, ['new'])
      expect(File.binread(path)).to eq("new\r\n")
      expect(Dir.children(@dir)).to eq(['x.cfg'])
    end

    # SaveFileAtomic: a failed replace deletes the temp and rethrows, leaving the old
    # file untouched (Utility.cs:584-594 R). No in-place overwrite fallback.
    it 'raises and leaves the old file untouched when the rename keeps failing (Windows lock)' do
      File.write(path, 'old')
      allow(File).to receive(:rename).and_raise(Errno::EACCES)
      allow(described_class).to receive(:sleep)
      expect { described_class.write_lines(path, ['new']) }.to raise_error(Errno::EACCES)
      expect(File.binread(path)).to eq('old')
      expect(File).to have_received(:rename).exactly(10).times
      expect(Dir.children(@dir)).to eq(['x.cfg'])
    end

    it 'succeeds when a rename fails transiently and then goes through' do
      File.write(path, 'old')
      calls = 0
      allow(File).to receive(:rename).and_wrap_original do |orig, *args|
        calls += 1
        raise Errno::EACCES if calls < 3

        orig.call(*args)
      end
      allow(described_class).to receive(:sleep)
      described_class.write_lines(path, ['new'])
      expect(File.binread(path)).to eq("new\r\n")
      expect(Dir.children(@dir)).to eq(['x.cfg'])
    end

    it 'lets concurrent writers of one file each finish, leaving one complete snapshot and no temp file' do
      allow(described_class).to receive(:sleep)
      contents = Array.new(6) { |w| Array.new(200) { |i| "w#{w} row #{i}" } }
      errors = Queue.new
      Array.new(6) do |w|
        Thread.new do
          10.times { described_class.write_lines(path, contents[w]) }
        rescue StandardError => e
          errors << e
        end
      end.each(&:join)
      expect(errors.size).to eq(0)
      expect(contents.map { |rows| rows.map { |r| "#{r}\r\n" }.join }).to include(File.binread(path))
      expect(Dir.children(@dir)).to eq(['x.cfg'])
    end

    it 'raises (and leaves no temp file) when the directory cannot be created' do
      File.write(File.join(@dir, 'file'), 'x')
      expect { described_class.write_lines(File.join(@dir, 'file', 'x.cfg'), ['a']) }.to raise_error(SystemCallError)
      expect(Dir.children(@dir)).to eq(['file'])
    end
  end
end
