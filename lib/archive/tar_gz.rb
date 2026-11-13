# frozen_string_literal: true

require 'fileutils'
require 'rubygems/package'
require 'zlib'

module Lich
  module Archive
    # gzip-compressed tar reader behind Archive.extract_tar_gz, built on
    # RubyGems' public Gem::Package::TarReader. It replaces calls to
    # Gem::Package#extract_tar_gz, which RubyGems marks internal (:nodoc:)
    # and which was given File.open handles nobody closed. On Windows an
    # open handle keeps the tarball from being deleted afterwards.
    #
    # Regular files and directories are extracted. Global and per-file pax
    # headers are skipped, as RubyGems skipped them (`git archive` writes a
    # global one holding the commit id), unless they carry a path or
    # linkpath record: TarReader ignores those, so the entry would land
    # under its truncated ustar name. Every other entry type (GNU long
    # names, devices, FIFOs, contiguous files, unknown typeflags) is refused
    # by name rather than dropped while extraction reports success.
    #
    # Symbolic and hard links are refused, deliberately. RubyGems created
    # in-tree symlinks, falling back to a copy where File.symlink failed (as
    # it does on Windows without extra privileges), so refusing is not about
    # an old crash: it keeps the extractor simple, with no link targets to
    # resolve or confine. The cost is that a release containing a link would
    # be refused by every client, so lich-5 ships none, and a spec
    # (release tree, in spec/lib/archive/tar_gz_spec.rb) fails if a symlink
    # (git mode 120000) is ever committed.
    module TarGz
      FILE_MODE_MASK = 0o755
      OWNER_READ_WRITE = 0o600
      LINK_TYPES = %w[1 2].freeze
      FILE_TYPE = '0' # TarHeader also reads a NUL (pre-POSIX) typeflag as "0"
      DIRECTORY_TYPE = '5'
      PAX_TYPES = %w[g x].freeze
      # Pax records that change which file an entry names; TarReader ignores
      # them, so an entry carrying one cannot be extracted faithfully.
      PAX_PATH_KEYS = %w[path linkpath].freeze
      MAX_PAX_HEADER_SIZE = 1 << 20
      REFUSED_TYPES = {
        '3' => 'character device', '4' => 'block device', '6' => 'FIFO', '7' => 'contiguous file',
        'K' => 'GNU long link name', 'L' => 'GNU long name', 'M' => 'GNU multi-volume continuation',
        'S' => 'GNU sparse file', 'V' => 'GNU volume header'
      }.freeze
      CHUNK_SIZE = 1 << 16

      module_function

      # @param path [String] gzip-compressed tar file
      # @param destination [String] directory to extract into (created if absent)
      # @return [Array<String>] extracted entry names
      # @raise [Error] when the archive is corrupt, unsafe, or contains a link
      #   or an entry type other than a regular file or directory
      def extract(path, destination)
        root = File.expand_path(destination)
        # The first pass reads only headers, so nothing is written for an
        # archive with any unsafe or colliding entry.
        planned = []
        each_entry(path) { |entry| planned << [entry.full_name, entry.directory?] if validate!(entry, root) }
        Archive.plan(planned, root)
        FileUtils.mkdir_p(root)
        names = []
        each_entry(path) do |entry|
          next unless [FILE_TYPE, DIRECTORY_TYPE].include?(entry.header.typeflag)
          next if root_directory?(entry, root)

          write_entry(entry, Archive.safe_destination(entry.full_name, root))
          names << entry.full_name
        end
        names
      end

      # @param path [String]
      # @yieldparam entry [Gem::Package::TarReader::Entry]
      # @return [void]
      def each_entry(path, &block)
        File.open(path, 'rb') do |file|
          Zlib::GzipReader.wrap(file) do |gzip|
            Gem::Package::TarReader.new(gzip) { |tar| tar.each(&block) }
            drain(gzip)
          end
        end
      rescue Zlib::Error => e
        raise Error, "not a valid gzip archive: #{e.message}"
      rescue Gem::Package::Error => e
        raise Error, "not a valid tar archive: #{e.message}"
      rescue EOFError
        # An entry whose header declares more data than the archive holds.
        raise Error, 'tar archive is truncated: an entry runs past the end of the data'
      end

      # Reads the rest of the gzip member. TarReader stops at the tar end
      # blocks, before the gzip trailer, and only reading to the end makes
      # GzipReader check the trailer's CRC-32 and length. An update tarball
      # has no other checksum (RubyGems does not verify the tar header
      # checksum either), so a corrupt download must fail here, in the
      # validation pass, before anything is written.
      # @param gzip [Zlib::GzipReader]
      # @return [void]
      def drain(gzip)
        nil while gzip.read(CHUNK_SIZE)
      end

      # @param entry [Gem::Package::TarReader::Entry]
      # @param root [String]
      # @return [Boolean] whether the entry will be extracted
      # @raise [Error] when the entry is a link, a pax header naming a path,
      #   or any type other than a regular file or directory
      def validate!(entry, root)
        typeflag = entry.header.typeflag
        if LINK_TYPES.include?(typeflag)
          raise Error, "archive entry is a link, which Lich does not extract: #{Archive.printable(entry.full_name)}"
        end
        if PAX_TYPES.include?(typeflag)
          check_pax_header!(entry)
          return false
        end
        unless [FILE_TYPE, DIRECTORY_TYPE].include?(typeflag)
          kind = REFUSED_TYPES.fetch(typeflag) { "unknown type #{typeflag.inspect}" }
          raise Error, "archive entry is a #{kind}, which Lich does not extract: #{Archive.printable(entry.full_name)}"
        end

        !root_directory?(entry, root)
      end

      # Refuses a pax header whose records rename the next entry (or every
      # entry, for a global header), since TarReader would not apply them.
      # @param entry [Gem::Package::TarReader::Entry] a "g" or "x" header
      # @return [void]
      # @raise [Error]
      def check_pax_header!(entry)
        name = Archive.printable(entry.full_name)
        raise Error, "pax header is too large: #{name}" if entry.header.size > MAX_PAX_HEADER_SIZE

        keys = pax_keys(entry.read.to_s.b)
        raise Error, "malformed pax header: #{name}" unless keys

        overridden = keys & PAX_PATH_KEYS
        return if overridden.empty?

        raise Error, "pax header sets #{overridden.join(' and ')}, which Lich does not apply: #{name}"
      end

      # @param data [String] binary pax header body
      # @return [Array<String>, nil] the record keys, or nil when malformed
      def pax_keys(data)
        keys = []
        position = 0
        while position < data.bytesize
          digits = data.byteslice(position, 20)[/\A[0-9]+ /]
          return nil unless digits

          length = digits.to_i
          record = data.byteslice(position, length)
          return nil unless length > digits.bytesize && record && record.bytesize == length && record.end_with?("\n")

          key, separator, = record.byteslice(digits.bytesize..).partition('=')
          return nil if separator.empty? || key.empty?

          keys << key
          position += length
        end
        keys
      end

      # `tar -czf x.tar.gz .` starts with a "./" entry for the root itself.
      # @return [Boolean]
      def root_directory?(entry, root)
        entry.directory? && !Archive.unsafe_entry?(entry.full_name) && Archive.resolve(entry.full_name, root) == root
      end

      # @param entry [Gem::Package::TarReader::Entry]
      # @param target [String]
      # @return [void]
      def write_entry(entry, target)
        if entry.directory?
          FileUtils.mkdir_p(target)
          return
        end

        FileUtils.mkdir_p(File.dirname(target))
        File.open(target, 'wb') do |output|
          IO.copy_stream(entry, output)
          output.flush
          # Keeps the executable bit (lich.rbw) without granting group or
          # world write, and never leaves a file its owner cannot read.
          output.chmod(((entry.header.mode & FILE_MODE_MASK) | OWNER_READ_WRITE) & ~File.umask)
        end
      end
    end
  end
end
