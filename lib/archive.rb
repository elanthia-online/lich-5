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
  #   archive, or one whose entries would collide on disk, leaves nothing
  #   behind;
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

    # Windows device names, reserved in any directory and with any extension
    # (NUL.txt is still NUL), including COM and LPT with a superscript 1-3.
    WINDOWS_DEVICE_NAME = /\A(?:con|prn|aux|nul|conin\$|conout\$|(?:com|lpt)[0-9#{[0xB9, 0xB2, 0xB3].pack('U*')}])\z/i

    # @param name [String] archive entry name
    # @return [Boolean] whether +name+ is empty, absolute, drive- or
    #   stream-qualified, not UTF-8, contains a control character, backslash
    #   or a character Windows forbids in file names (< > " | ? *),
    #   traverses upward, or has a segment Windows would rename or treat as
    #   a device
    def unsafe_entry?(name)
      # Tar names are raw bytes. One that is not UTF-8 is refused rather
      # than guessed at; matching it below would raise ArgumentError.
      name = name.dup.force_encoding(Encoding::UTF_8)
      return true unless name.valid_encoding?
      return true if name.empty? || name.start_with?('/') || name.match?(/[[:cntrl:]]/)
      # A colon names a drive (C:...) or an NTFS alternate data stream (a.gem:s).
      return true if name.include?(':')
      # Windows refuses these in any file name, so File.open would fail
      # partway with a raw Errno; refuse them before anything is written.
      return true if name.match?(/[<>"|?*]/)
      # ZIP and tar both separate with "/". Windows also splits on "\", so
      # a\b would be a file on one platform and a directory on another.
      return true if name.include?('\\')

      name.split('/').any? { |segment| unsafe_segment?(segment) }
    end

    # Windows silently drops a trailing dot or space ("a.gem." and "a.gem"
    # are one file) and opens a device for a reserved name, ignoring any
    # extension ("nul.gem" writes nowhere).
    # @param segment [String] one "/"-separated part of an entry name
    # @return [Boolean]
    def unsafe_segment?(segment)
      return true if segment == '..'
      return false if segment.empty? || segment == '.'
      return true if segment.end_with?('.', ' ')

      segment.split('.', 2).first.rstrip.match?(WINDOWS_DEVICE_NAME)
    end

    # @param name [String] archive entry name
    # @param root [String] expanded extraction directory
    # @return [String] the absolute path +name+ extracts to
    # @raise [Error] when +name+ is unsafe or would land outside +root+
    def safe_destination(name, root)
      raise Error, "unsafe archive entry: #{printable(name)}" if unsafe_entry?(name)

      target = resolve(name, root)
      raise Error, "unsafe archive entry: #{printable(name)}" unless target.start_with?("#{root}/", "#{root}#{File::SEPARATOR}")

      target
    end

    # @param name [String] archive entry name
    # @return [String] +name+ as UTF-8, with any invalid bytes replaced, for
    #   an error message
    def printable(name)
      name.dup.force_encoding(Encoding::UTF_8).scrub
    end

    # Joined before expanding: File.expand_path(name, root) would read a
    # leading "~" as a home directory, raising ArgumentError for an unknown
    # user. Callers refuse unsafe_entry? names first, so absolute and
    # drive-qualified names never get here.
    # @param name [String] archive entry name
    # @param root [String] expanded extraction directory
    # @return [String] the absolute path +name+ names under +root+
    def resolve(name, root)
      File.expand_path(File.join(root, name))
    end

    # Resolves every entry's output path, refusing the whole archive if any
    # name is unsafe or two entries would collide on disk. Nothing is written.
    # @param entries [Array<Array(String, Boolean)>] name and directory? of
    #   each entry that will be extracted
    # @param root [String] expanded extraction directory
    # @return [Array<String>] absolute output paths, in entry order
    # @raise [Error]
    def plan(entries, root)
      targets = entries.map { |name, _directory| safe_destination(name, root) }
      check_layout!(entries.map(&:first).zip(targets, entries.map(&:last)), root)
      targets
    end

    # Refuses entries that would overwrite each other or need one path to be
    # both a file and a directory (+a+ and +a/+, or +a+ and +a/b+), which
    # would otherwise fail midway with an OS error. Paths are compared by
    # layout_key, so names a case-insensitive or normalising file system
    # would store as one file collide here too. Repeated directory entries
    # are allowed.
    # @param entries [Array<Array(String, String, Boolean)>] name, target, directory?
    # @param root [String] expanded extraction directory
    # @return [void]
    # @raise [Error]
    def check_layout!(entries, root)
      files = {}
      directories = {}
      entries.each do |name, target, directory|
        key = layout_key(target, root)
        if directory
          directories[key] ||= name
        else
          raise Error, "duplicate archive entry: #{name}" if files.key?(key)

          files[key] = name
        end
        parent = File.dirname(target)
        while parent.length > root.length
          directories[layout_key(parent, root)] ||= name
          parent = File.dirname(parent)
        end
      end
      clash = files.keys.find { |key| directories.key?(key) }
      raise Error, "archive entry is both a file and a directory: #{files[clash]}" if clash
    end

    # The part of +path+ below +root+, in the form two names take when a file
    # system would store them as one file. macOS normalises names, so a
    # decomposed and a precomposed e-acute are one file; Windows and macOS
    # ignore case, and fold final and medial sigma, long s and s, and micro
    # sign and mu together. The key is Unicode's canonical caseless form,
    # NFD(fold(NFD(name))) (Unicode 3.13, D145):
    # - The first NFD has to come before folding. NFC would keep a
    #   precomposed letter with iota subscript (U+1FB3) whole, and folding
    #   it then puts the iota ahead of any mark that follows, so U+1FB3
    #   with a diaeresis and its uppercase spelling would get different
    #   keys although APFS stores them as one file. In NFD the marks are
    #   already in canonical order, which also covers j with caron (U+01F0)
    #   followed by a dot below.
    # - The final NFD is needed too. Ruby's NFD does not put a mark in
    #   canonical order before U+0F73, U+0F75 or U+0F81: U+0300 U+0F73
    #   becomes U+0300 U+0F71 U+0F72, while U+0F71 U+0F72 U+0300 stays as
    #   it is, and APFS stores the two as one file. Normalising again
    #   reorders the marks.
    #
    # This is deliberately stricter than any one file system: full folding
    # also joins sharp s and "ss", which NTFS keeps apart. Refusing such a
    # pair costs nothing for the archives Lich reads. The key follows
    # Unicode's default folding, so the Turkic dotless and dotted i stay
    # apart from i and I; spec/lib/archive/zip_spec.rb checks on each file
    # system its CI runs on that every such pair the file system merges is
    # refused here too.
    #
    # The bytes are read as UTF-8 whatever the string's encoding tag:
    # unsafe_entry? has already refused names that are not valid UTF-8.
    # @param path [String] expanded path at or below +root+
    # @param root [String] expanded extraction directory
    # @return [String]
    def layout_key(path, root)
      below = path.byteslice(root.bytesize..).force_encoding(Encoding::UTF_8)
      below.unicode_normalize(:nfd).downcase(:fold).unicode_normalize(:nfd)
    end
  end
end

require_relative 'archive/zip'
require_relative 'archive/tar_gz'
