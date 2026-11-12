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
    # headers and other metadata entries are skipped, as RubyGems skipped
    # them. Symbolic and hard links are refused: Lich ships none, and Windows
    # cannot create symlinks without extra privileges.
    module TarGz
      FILE_MODE_MASK = 0o755
      OWNER_READ_WRITE = 0o600
      LINK_TYPES = %w[1 2].freeze

      module_function

      # @param path [String] gzip-compressed tar file
      # @param destination [String] directory to extract into (created if absent)
      # @return [Array<String>] extracted entry names
      # @raise [Error] when the archive is corrupt, unsafe, or contains a link
      def extract(path, destination)
        root = File.expand_path(destination)
        # The first pass reads only headers, so nothing is written for an
        # archive with any unsafe entry.
        each_entry(path) { |entry| validate!(entry, root) }
        FileUtils.mkdir_p(root)
        names = []
        each_entry(path) do |entry|
          next unless entry.file? || entry.directory?
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
          end
        end
      rescue Zlib::Error => e
        raise Error, "not a valid gzip archive: #{e.message}"
      rescue Gem::Package::Error => e
        raise Error, "not a valid tar archive: #{e.message}"
      end

      # @param entry [Gem::Package::TarReader::Entry]
      # @param root [String]
      # @return [void]
      def validate!(entry, root)
        if entry.symlink? || LINK_TYPES.include?(entry.header.typeflag)
          raise Error, "archive entry is a link, which Lich does not extract: #{entry.full_name}"
        end
        return unless entry.file? || entry.directory?
        return if root_directory?(entry, root)

        Archive.safe_destination(entry.full_name, root)
      end

      # `tar -czf x.tar.gz .` starts with a "./" entry for the root itself.
      # @return [Boolean]
      def root_directory?(entry, root)
        entry.directory? && !Archive.unsafe_entry?(entry.full_name) && File.expand_path(entry.full_name, root) == root
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
