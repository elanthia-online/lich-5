# frozen_string_literal: true

require 'rubygems/package'
require 'stringio'
require 'zlib'

# Writes small gzip-compressed tar archives for specs. Entries may be files,
# directories, links, or raw headers with any typeflag, so unsafe and
# unsupported archives can be built from real bytes.
module TarGzBuilder
  module_function

  # @param entries [Array<Hash>] :name, and :data (file), :type (:file,
  #   :directory, :symlink, :hardlink, :raw), :target (links), :mode;
  #   :raw entries take :typeflag, and optional :size (declared size, which
  #   may exceed the :data written) and :pad (false to omit block padding)
  # @param pax_global_header [Boolean] lead with the pax header `git archive`
  #   writes into every GitHub tarball
  # @param level [Integer] zlib compression level (0 stores the tar bytes
  #   verbatim inside the gzip member, so specs can corrupt known bytes)
  # @param end_blocks [Boolean] false to leave off the two zero blocks that
  #   close a tar archive
  # @return [String] binary .tar.gz
  def build(entries, pax_global_header: false, level: Zlib::DEFAULT_COMPRESSION, end_blocks: true)
    tar = StringIO.new(+''.b)
    Gem::Package::TarWriter.new(tar) do |writer|
      if pax_global_header
        comment = "52 comment=0123456789abcdef0123456789abcdef01234567\n"
        raw(writer, tar, 'pax_global_header', 'g', comment)
      end
      entries.each do |entry|
        name = entry.fetch(:name)
        case entry.fetch(:type, :file)
        when :file then writer.add_file_simple(name, entry.fetch(:mode, 0o644), entry.fetch(:data, '').bytesize) { |io| io.write(entry.fetch(:data, '')) }
        when :directory then writer.mkdir(name.chomp('/'), entry.fetch(:mode, 0o755))
        when :symlink then writer.add_symlink(name, entry.fetch(:target), 0o777)
        when :hardlink then raw(writer, tar, name, '1', '', linkname: entry.fetch(:target))
        when :raw
          raw(writer, tar, name, entry.fetch(:typeflag), entry.fetch(:data, ''),
              size: entry[:size], pad: entry.fetch(:pad, true), linkname: entry.fetch(:target, ''))
        end
      end
    end
    bytes = tar.string
    # TarWriter#close appends the two end blocks; drop them when asked.
    bytes = bytes.byteslice(0, bytes.bytesize - 1024) unless end_blocks
    gzip(bytes, level: level)
  end

  # @param bytes [String]
  # @param level [Integer]
  # @return [String] one gzip member holding +bytes+
  # @param name [String, nil] original file name for the gzip header, which
  #   also sets the member's length exactly
  def gzip(bytes, level: Zlib::DEFAULT_COMPRESSION, name: nil)
    gzip = StringIO.new(+''.b)
    Zlib::GzipWriter.wrap(gzip, level) do |gz|
      gz.orig_name = name if name
      gz.write(bytes)
    end
    gzip.string
  end

  # @param data [Hash{String => String}] pax extended header records
  # @return [String] the records in "<length> <key>=<value>\n" form
  def pax_records(data)
    data.map do |key, value|
      body = " #{key}=#{value}\n"
      length = body.bytesize + 1
      length += 1 while "#{length}#{body}".bytesize > length
      "#{length}#{body}"
    end.join
  end

  # Writes one entry with an arbitrary typeflag, which TarWriter has no
  # public method for.
  # @return [void]
  def raw(_writer, tar, name, typeflag, data, linkname: '', size: nil, pad: true)
    header = Gem::Package::TarHeader.new(name: name, mode: 0o644, size: size || data.bytesize, prefix: '',
                                         typeflag: typeflag, linkname: linkname, mtime: Time.at(0))
    tar.write(header.to_s)
    tar.write(data)
    remainder = data.bytesize % 512
    tar.write("\0" * (512 - remainder)) if pad && !remainder.zero?
  end
end
