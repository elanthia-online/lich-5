# frozen_string_literal: true

require 'fileutils'

module Lich
  module Genie
    # Byte-level I/O shared by Genie's config files (`variables.cfg`, `triggers.cfg`).
    #
    # Reading ports `new StreamReader(path)` + `ReadLine` (Globals.cs:741-750 R): the
    # encoding is detected from a byte-order mark (UTF-8 by default), invalid bytes
    # decode to U+FFFD instead of raising, and lines end at CR, LF or CRLF.
    #
    # Writing ports `Utility.SaveFileAtomic` (Utility.cs:561-597 R) with
    # `new StreamWriter(temp, false)` + `WriteLine`: UTF-8 without a BOM, CRLF after
    # every line (Remix is a Windows build; the tester's real variables.cfg is CRLF), written
    # to a sibling temp file that then replaces the target, so a failed write leaves the
    # old file intact.
    module ConfigFile
      REPLACEMENT = [0xFFFD].pack('U').freeze
      NEWLINE = "\r\n"

      # Longest first: the UTF-32 LE mark starts with the UTF-16 LE one.
      BOMS = [
        [[0xEF, 0xBB, 0xBF], Encoding::UTF_8],
        [[0x00, 0x00, 0xFE, 0xFF], Encoding::UTF_32BE],
        [[0xFF, 0xFE, 0x00, 0x00], Encoding::UTF_32LE],
        [[0xFE, 0xFF], Encoding::UTF_16BE],
        [[0xFF, 0xFE], Encoding::UTF_16LE]
      ].map { |mark, encoding| [mark.pack('C*'), encoding] }.freeze

      module_function

      # @param path [String]
      # @return [Array<String>, nil] the file's lines (UTF-8), or nil if it is absent
      def read_lines(path)
        return nil unless path && File.file?(path)

        split_lines(decode(File.binread(path)))
      end

      # @param bytes [String] raw file content
      # @return [String] valid UTF-8 (invalid input bytes become U+FFFD)
      def decode(bytes)
        raw = bytes.b
        bom, encoding = BOMS.find { |mark, _| raw.start_with?(mark) }
        text = raw.byteslice((bom || '').bytesize..).force_encoding(encoding || Encoding::UTF_8)
        text = text.scrub(REPLACEMENT.encode(text.encoding)).encode(Encoding::UTF_8) unless text.encoding == Encoding::UTF_8
        text.scrub(REPLACEMENT)
      end

      # .NET ReadLine: a line ends at "\r\n", "\r" or "\n"; a final unterminated line
      # still counts, a trailing terminator does not add an empty line.
      # @param text [String]
      # @return [Array<String>]
      def split_lines(text)
        lines = text.split(/\r\n|\r|\n/, -1)
        lines.pop if lines.last == ''
        lines
      end

      # Atomically write +lines+ (each followed by CRLF) to +path+.
      # @param path [String]
      # @param lines [Array<String>]
      # @return [void]
      # @raise [SystemCallError, IOError] when the file cannot be written
      def write_lines(path, lines)
        FileUtils.mkdir_p(File.dirname(path))
        # One temp name per writer thread: two threads saving the same file at once
        # (the trigger thread and a script) must not truncate each other's temp file.
        tmp = "#{path}.tmp.#{Process.pid}.#{Thread.current.object_id}"
        content = lines.map { |line| "#{utf8(line)}#{NEWLINE}" }.join
        File.binwrite(tmp, content)
        atomic_replace(tmp, path)
      ensure
        File.delete(tmp) if tmp && File.exist?(tmp)
      end

      def utf8(text)
        str = text.to_s
        str = str.dup.force_encoding(Encoding::UTF_8) if str.encoding == Encoding::BINARY
        str = str.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: REPLACEMENT) unless str.encoding == Encoding::UTF_8
        str.scrub(REPLACEMENT).b
      end

      # Rename over the target. Windows can refuse while another handle (AV, indexer,
      # a second Lich process) briefly holds the file, so retry a few times (timing
      # only: Remix tries once). If it still fails, raise and leave the target
      # untouched, like SaveFileAtomic's delete-temp-and-rethrow (Utility.cs:584-594
      # R); write_lines' ensure removes the temp file. Never overwrite in place: that
      # is not atomic and is not what Remix does.
      def atomic_replace(tmp, path)
        attempts = 0
        begin
          File.rename(tmp, path)
        rescue SystemCallError
          attempts += 1
          raise if attempts >= 10

          sleep 0.05
          retry
        end
      end
    end
  end
end
