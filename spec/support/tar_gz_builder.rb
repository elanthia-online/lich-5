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
  #   :directory, :symlink, :hardlink), :target (links), :mode
  # @param pax_global_header [Boolean] lead with the pax header `git archive`
  #   writes into every GitHub tarball
  # @return [String] binary .tar.gz
  def build(entries, pax_global_header: false)
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
        end
      end
    end
    gzip = StringIO.new(+''.b)
    Zlib::GzipWriter.wrap(gzip) { |gz| gz.write(tar.string) }
    gzip.string
  end

  # Writes one entry with an arbitrary typeflag, which TarWriter has no
  # public method for.
  # @return [void]
  def raw(_writer, tar, name, typeflag, data, linkname: '')
    header = Gem::Package::TarHeader.new(name: name, mode: 0o644, size: data.bytesize, prefix: '',
                                         typeflag: typeflag, linkname: linkname, mtime: Time.at(0))
    tar.write(header.to_s)
    tar.write(data)
    remainder = data.bytesize % 512
    tar.write("\0" * (512 - remainder)) unless remainder.zero?
  end
end
