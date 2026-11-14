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
    # global one holding the commit id), unless they carry a record
    # TarReader would not apply: any path or linkpath (even one that only
    # repeats the ustar name, as macOS bsdtar writes for non-ASCII names),
    # a size, or GNU sparse-file records. Every other entry type (GNU long
    # names, devices, FIFOs, contiguous files, unknown typeflags, and
    # pre-POSIX directories) is refused by name rather than extracted
    # wrongly or dropped while extraction reports success. So is an archive
    # whose tar stream does not end with its two zero blocks, or has data
    # after them or after its gzip member.
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
      # TarHeader also reads a NUL (pre-POSIX) typeflag as "0". A pre-POSIX
      # directory, such an entry whose name ends in "/", is refused.
      FILE_TYPE = '0'
      DIRECTORY_TYPE = '5'
      PAX_TYPES = %w[g x].freeze
      # Pax records that change which file an entry names or what it holds;
      # TarReader ignores them, so an entry carrying one cannot be extracted
      # faithfully.
      PAX_REFUSED_KEYS = %w[path linkpath size].freeze
      PAX_SPARSE_PREFIX = 'GNU.sparse.'
      MAX_PAX_HEADER_SIZE = 1 << 20
      REFUSED_TYPES = {
        '3' => 'character device', '4' => 'block device', '6' => 'FIFO', '7' => 'contiguous file',
        'K' => 'GNU long link name', 'L' => 'GNU long name', 'M' => 'GNU multi-volume continuation',
        'S' => 'GNU sparse file', 'V' => 'GNU volume header'
      }.freeze
      CHUNK_SIZE = 1 << 16
      BLOCK_SIZE = 512
      ZERO_BLOCK = ("\0" * BLOCK_SIZE).b.freeze

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
            finish(gzip, file)
          end
        end
      rescue Zlib::Error => e
        raise Error, "not a valid gzip archive: #{e.message}"
      rescue Gem::Package::Error => e
        raise Error, "not a valid tar archive: #{e.message}"
      rescue ArgumentError => e
        # RubyGems reads a uid or gid starting 0x80 or 0xff as base-256, and
        # unpack raises ArgumentError when the rest of the field is NULs or
        # spaces. Only an error from RubyGems' tar code is the archive's
        # fault; one from Lich's own code is re-raised.
        raise unless e.backtrace_locations&.first&.path.to_s.include?('rubygems/package/')

        raise Error, "not a valid tar archive: #{e.message}"
      rescue EOFError
        # An entry whose header declares more data than the archive holds.
        raise Error, 'tar archive is truncated: an entry runs past the end of the data'
      end

      # Checks the end of the archive and reads the rest of the gzip member.
      #
      # TarReader returns at the first zero block, or quietly at the end of
      # the data, reading a header cut short as an empty file. Every tar
      # writer ends with two zero blocks, so the next block must be the
      # second one; anything after it may only be zero padding to the
      # record size. Without this, a tar stream that ends early inside a
      # valid gzip member extracts as success, missing files or with an
      # empty lib/version.rb.
      #
      # Reading to the end also makes GzipReader check the trailer's CRC-32
      # and length. An update tarball has no other checksum (RubyGems does
      # not verify the tar header checksum either), so a corrupt download
      # must fail here, in the validation pass, before anything is written.
      # GzipReader reads only the first member, so data after it, other than
      # zero padding, is refused too rather than ignored.
      # @param gzip [Zlib::GzipReader]
      # @param file [File] the file +gzip+ reads
      # @return [void]
      # @raise [Error]
      def finish(gzip, file)
        unless gzip.read(BLOCK_SIZE) == ZERO_BLOCK
          raise Error, 'tar archive is truncated: it does not end with two zero blocks'
        end

        while (chunk = gzip.read(CHUNK_SIZE))
          raise Error, 'tar archive has data after its end blocks' if chunk.match?(/[^\0]/n)
        end
        # bsdtar pads its compressed output with zeros to its block size when
        # it writes to a pipe, so zeros after the member are allowed. Anything
        # else, including a second member (which starts 1f 8b), is refused.
        # GzipReader keeps what it read past the member in #unused; the rest
        # is still in the file, which is all that holds it when the member
        # ends on GzipReader's read boundary. Each chunk is checked as it is
        # read, so a long trailer is never held in memory.
        chunk = gzip.unused || file.read(CHUNK_SIZE)
        while chunk
          raise Error, 'gzip archive has data after its first member' if chunk.match?(/[^\0]/n)

          chunk = file.read(CHUNK_SIZE)
        end
      end

      # @param entry [Gem::Package::TarReader::Entry]
      # @param root [String]
      # @return [Boolean] whether the entry will be extracted
      # @raise [Error] when the entry is a link, a pax header TarReader would
      #   not apply, or any type other than a regular file or directory
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
          raise Error, "unsupported archive entry type (#{kind}), which Lich does not extract: #{Archive.printable(entry.full_name)}"
        end
        if typeflag == FILE_TYPE && entry.full_name.end_with?('/')
          raise Error, "unsupported archive entry type (pre-POSIX directory), which Lich does not extract: #{Archive.printable(entry.full_name)}"
        end

        !root_directory?(entry, root)
      end

      # Refuses a pax header whose records rename or resize the next entry
      # (or every entry, for a global header), or describe a GNU sparse
      # file, since TarReader would not apply them.
      # @param entry [Gem::Package::TarReader::Entry] a "g" or "x" header
      # @return [void]
      # @raise [Error]
      def check_pax_header!(entry)
        name = Archive.printable(entry.full_name)
        raise Error, "pax header is too large: #{name}" if entry.header.size > MAX_PAX_HEADER_SIZE

        keys = pax_keys(entry.read.to_s.b)
        raise Error, "malformed pax header: #{name}" unless keys

        overridden = keys.select { |key| PAX_REFUSED_KEYS.include?(key) || key.start_with?(PAX_SPARSE_PREFIX) }.uniq
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
          return nil if length > data.bytesize - position

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
