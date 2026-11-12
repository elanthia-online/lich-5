# frozen_string_literal: true

require 'fileutils'

module Lich
  # In-process archive extraction shared across Lich: the Ruby4Lich5 gem
  # bundle (ZIP) used by dependency recovery, and the release and branch
  # tarballs (tar.gz) used by `lich5-update`.
  #
  # Every format follows the same contract:
  # - no external program is started (no PowerShell, WScript, tar or unzip),
  #   so nothing depends on execution policy, PATH or a console window;
  # - every entry name is validated before anything is written, so an unsafe
  #   archive leaves nothing behind;
  # - links are never created, and anything else this module cannot verify
  #   raises Archive::Error instead of being guessed at.
  module Archive
    class Error < StandardError; end

    module_function

    # @param path [String] ZIP file
    # @param destination [String] directory to extract into (created if absent)
    # @return [Array<String>] extracted entry names
    # @raise [Error]
    def extract_zip(path, destination)
      Zip.extract(path, destination)
    end

    # @param path [String] gzip-compressed tar file
    # @param destination [String] directory to extract into (created if absent)
    # @return [Array<String>] extracted entry names
    # @raise [Error]
    def extract_tar_gz(path, destination)
      TarGz.extract(path, destination)
    end

    # Extracts a tarball whose files all sit under one top-level directory,
    # as GitHub release and branch archives do, and returns that directory.
    # @param path [String] gzip-compressed tar file
    # @param destination [String] directory to extract into (created if absent)
    # @return [String] the archive's top-level directory, inside +destination+
    # @raise [Error] when the archive has no single top-level directory
    def extract_tar_gz_root(path, destination)
      extract_tar_gz(path, destination)
      single_root(destination)
    end

    # @param directory [String]
    # @return [String] the only entry of +directory+, which must be a directory
    # @raise [Error]
    def single_root(directory)
      children = Dir.children(directory)
      unless children.length == 1 && File.directory?(File.join(directory, children.first))
        raise Error, "expected one top-level directory in the archive, found #{children.empty? ? 'none' : children.sort.join(', ')}"
      end

      File.join(directory, children.first)
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

    # @param name [String] archive entry name
    # @param root [String] expanded extraction directory
    # @return [String] the absolute path +name+ extracts to
    # @raise [Error] when +name+ is unsafe or would land outside +root+
    def safe_destination(name, root)
      raise Error, "unsafe archive entry: #{name}" if unsafe_entry?(name)

      target = File.expand_path(name, root)
      raise Error, "unsafe archive entry: #{name}" unless target.start_with?("#{root}/", "#{root}#{File::SEPARATOR}")

      target
    end
  end
end

require_relative 'archive/zip'
require_relative 'archive/tar_gz'
