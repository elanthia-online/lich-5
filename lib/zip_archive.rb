# frozen_string_literal: true

require 'fileutils'
require 'zlib'

module Lich
  # Minimal ZIP reader for the gem bundles Ruby4Lich5 publishes. Extraction
  # runs in-process with Zlib, so it needs no external program: no PowerShell
  # (blocked by the default Restricted execution policy on Windows client
  # editions), no Windows Script Host, no console window and no `unzip`.
  #
  # Supported: single-disk archives whose entries are stored or deflated,
  # with or without data descriptors. Anything else (ZIP64, encryption,
  # spanning, other compression methods) is rejected with an Error rather
  # than guessed at. Entries are located through the central directory, whose
  # sizes are authoritative even when local headers defer them to a data
  # descriptor.
  module ZipArchive
    class Error < StandardError; end

    Entry = Struct.new(:name, :compression, :flags, :crc32, :compressed_size, :uncompressed_size,
                       :local_header_offset, keyword_init: true) do
      # @return [Boolean] whether the entry names a directory
      def directory?
        name.end_with?('/')
      end
    end

    END_OF_CENTRAL_DIRECTORY = "PK\x05\x06".b
    CENTRAL_DIRECTORY_HEADER = 0x02014b50
    LOCAL_FILE_HEADER = 0x04034b50
    END_RECORD_SIZE = 22
    CENTRAL_HEADER_SIZE = 46
    LOCAL_HEADER_SIZE = 30
    MAX_COMMENT_SIZE = 0xFFFF
    STORED = 0
    DEFLATED = 8
    ENCRYPTED_FLAG = 0x0001
    UTF8_NAME_FLAG = 0x0800
    ZIP64_COUNT = 0xFFFF
    ZIP64_SIZE = 0xFFFFFFFF
    CHUNK_SIZE = 1 << 16

    module_function

    # Lists the archive's entries from its central directory.
    # @param path [String] ZIP file
    # @return [Array<Entry>]
    # @raise [Error] when the archive is malformed or uses an unsupported feature
    def entries(path)
      File.open(path, 'rb') { |file| read_central_directory(file) }
    end

    # Extracts every entry beneath +destination+. All names are validated
    # before anything is written, so an unsafe archive leaves nothing behind.
    # Each file's size and CRC-32 are checked against the central directory.
    # @param path [String] ZIP file
    # @param destination [String] existing or creatable directory
    # @return [Array<String>] extracted entry names
    # @raise [Error] when the archive is malformed, unsafe, or unsupported
    def extract(path, destination)
      root = File.expand_path(destination)
      File.open(path, 'rb') do |file|
        list = read_central_directory(file)
        list.each do |entry|
          raise Error, "unsafe archive entry: #{entry.name}" if unsafe_entry?(entry.name)
          raise Error, "unsafe archive entry: #{entry.name}" unless within?(File.expand_path(entry.name, root), root)
        end
        FileUtils.mkdir_p(root)
        list.each { |entry| extract_entry(file, entry, File.expand_path(entry.name, root)) }
        list.map(&:name)
      end
    end

    # @param name [String] archive entry name
    # @return [Boolean] whether +name+ is empty, absolute, drive- or
    #   stream-qualified, contains a control character, or traverses upward
    def unsafe_entry?(name)
      return true if name.empty? || name.start_with?('/', '\\') || name.match?(/[[:cntrl:]]/)
      # A colon names a drive (C:...) or an NTFS alternate data stream (a.gem:s).
      return true if name.include?(':')

      name.split(/[\\\/]/).include?('..')
    end

    # @param path [String]
    # @param root [String]
    # @return [Boolean]
    def within?(path, root)
      path.start_with?("#{root}#{File::SEPARATOR}") || path.start_with?("#{root}/")
    end

    # @param file [File]
    # @return [Array<Entry>]
    def read_central_directory(file)
      file_size = file.size
      raise Error, 'not a ZIP archive (too short)' if file_size < END_RECORD_SIZE

      tail_size = [file_size, END_RECORD_SIZE + MAX_COMMENT_SIZE].min
      file.seek(file_size - tail_size)
      tail = file.read(tail_size)
      record_at = tail.rindex(END_OF_CENTRAL_DIRECTORY)
      raise Error, 'not a ZIP archive (no end of central directory record)' unless record_at && tail.bytesize - record_at >= END_RECORD_SIZE

      _signature, disk, directory_disk, disk_count, total_count, directory_size, directory_offset, _comment =
        tail.byteslice(record_at, END_RECORD_SIZE).unpack('VvvvvVVv')
      raise Error, 'multi-disk ZIP archives are not supported' unless disk.zero? && directory_disk.zero? && disk_count == total_count
      if total_count == ZIP64_COUNT || directory_size == ZIP64_SIZE || directory_offset == ZIP64_SIZE
        raise Error, 'ZIP64 archives are not supported'
      end

      record_offset = file_size - tail_size + record_at
      raise Error, 'central directory lies outside the archive' if directory_offset + directory_size > record_offset

      file.seek(directory_offset)
      directory = file.read(directory_size)
      raise Error, 'central directory is truncated' unless directory && directory.bytesize == directory_size

      parse_central_directory(directory, total_count, record_offset)
    end

    # @param directory [String] binary central directory
    # @param count [Integer] declared entry count
    # @param limit [Integer] offset where entry data must end
    # @return [Array<Entry>]
    def parse_central_directory(directory, count, limit)
      position = 0
      Array.new(count) do
        raise Error, 'central directory is truncated' if position + CENTRAL_HEADER_SIZE > directory.bytesize

        fields = directory.byteslice(position, CENTRAL_HEADER_SIZE).unpack('VvvvvvvVVVvvvvvVV')
        signature, _made_by, _needed, flags, compression, _time, _date, crc32, compressed_size, size,
          name_length, extra_length, comment_length, _disk, _internal, _external, local_offset = fields
        raise Error, 'central directory entry has a bad signature' unless signature == CENTRAL_DIRECTORY_HEADER

        name_end = position + CENTRAL_HEADER_SIZE + name_length
        raise Error, 'central directory is truncated' if name_end + extra_length + comment_length > directory.bytesize

        name = entry_name(directory.byteslice(position + CENTRAL_HEADER_SIZE, name_length), flags)
        position = name_end + extra_length + comment_length
        validate_entry!(name, flags, compression, compressed_size, size, local_offset, limit)
        Entry.new(name: name, compression: compression, flags: flags, crc32: crc32,
                  compressed_size: compressed_size, uncompressed_size: size, local_header_offset: local_offset)
      end
    end

    # Entry names are compared as text; a name that is not valid UTF-8 (or
    # ASCII, its subset) is refused instead of being reinterpreted.
    # @param raw [String]
    # @param flags [Integer]
    # @return [String]
    def entry_name(raw, flags)
      name = raw.dup.force_encoding(Encoding::UTF_8)
      raise Error, 'archive entry name is not valid UTF-8' unless name.valid_encoding?
      raise Error, 'archive entry name must be ASCII unless flagged UTF-8' unless name.ascii_only? || flags.anybits?(UTF8_NAME_FLAG)

      name
    end

    # @return [void]
    def validate_entry!(name, flags, compression, compressed_size, size, local_offset, limit)
      raise Error, "encrypted archive entry: #{name}" if flags.anybits?(ENCRYPTED_FLAG)
      raise Error, "unsupported compression method #{compression} for #{name}" unless [STORED, DEFLATED].include?(compression)
      if [compressed_size, size, local_offset].include?(ZIP64_SIZE)
        raise Error, "ZIP64 archive entry is not supported: #{name}"
      end
      raise Error, "archive entry data lies outside the archive: #{name}" if local_offset + LOCAL_HEADER_SIZE + compressed_size > limit
    end

    # @param file [File]
    # @param entry [Entry]
    # @param target [String] absolute output path
    # @return [void]
    def extract_entry(file, entry, target)
      if entry.directory?
        FileUtils.mkdir_p(target)
        return
      end

      file.seek(entry.local_header_offset)
      header = file.read(LOCAL_HEADER_SIZE)
      raise Error, "local header is truncated: #{entry.name}" unless header && header.bytesize == LOCAL_HEADER_SIZE

      signature, = header.unpack('V')
      raise Error, "local header has a bad signature: #{entry.name}" unless signature == LOCAL_FILE_HEADER

      name_length, extra_length = header.byteslice(26, 4).unpack('vv')
      file.seek(entry.local_header_offset + LOCAL_HEADER_SIZE + name_length + extra_length)
      FileUtils.mkdir_p(File.dirname(target))
      File.open(target, 'wb') { |output| copy_data(file, entry, output) }
    end

    # Streams one entry's data, verifying its declared size and CRC-32.
    # @param file [File] positioned at the entry's data
    # @param entry [Entry]
    # @param output [IO]
    # @return [void]
    def copy_data(file, entry, output)
      inflater = Zlib::Inflate.new(-Zlib::MAX_WBITS) if entry.compression == DEFLATED
      remaining = entry.compressed_size
      written = 0
      crc = Zlib.crc32
      write = lambda do |data|
        written += data.bytesize
        raise Error, "archive entry is larger than declared: #{entry.name}" if written > entry.uncompressed_size

        crc = Zlib.crc32(data, crc)
        output.write(data)
      end

      while remaining.positive?
        chunk = file.read([remaining, CHUNK_SIZE].min)
        raise Error, "archive entry data is truncated: #{entry.name}" unless chunk && !chunk.empty?

        remaining -= chunk.bytesize
        write.call(inflater ? inflater.inflate(chunk) : chunk)
      end
      if inflater
        write.call(inflater.finish)
        raise Error, "archive entry data is truncated: #{entry.name}" unless inflater.finished?
      end
      raise Error, "archive entry is smaller than declared: #{entry.name}" unless written == entry.uncompressed_size
      raise Error, "archive entry failed its CRC-32 check: #{entry.name}" unless crc == entry.crc32
    rescue Zlib::Error => e
      raise Error, "archive entry is corrupt: #{entry.name} (#{e.message})"
    ensure
      inflater&.close
    end
  end
end
