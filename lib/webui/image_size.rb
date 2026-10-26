# frozen_string_literal: true

module Lich
  module WebUI
    # Native map and creature image consumers need dimensions, not decoding or
    # a GTK image object. Read at most 1 MiB of headers; pixels stay in the browser.
    # PNG/GIF/JPEG and uncompressed true-color BMP are supported. Others refuse.
    module ImageSize
      HEADER_LIMIT = 1_048_576
      JPEG_FRAMES = [0xc0, 0xc1, 0xc2, 0xc3, 0xc5, 0xc6, 0xc7, 0xc9, 0xca, 0xcb, 0xcd, 0xce, 0xcf].freeze
      Info = Data.define(:format, :width, :height)

      # Reads bounded PNG, GIF, JPEG or true-color BMP headers without decoding pixels.
      # @param path [String] image file to inspect
      # @return [Array<Integer>] frozen width and height, each between 1 and 65,536
      # @raise [ArgumentError] for unsupported, truncated, or out-of-range image headers
      def self.read(path)
        result = info(path)
        [result.width, result.height].freeze
      end

      # Uses the same bounded read for format identity and dimensions.
      # @param path [String] image file to inspect
      # @return [Info] immutable format name, width and height
      # @raise [ArgumentError] for unsupported, truncated, or out-of-range headers
      def self.info(path)
        bytes, file_size = File.open(path, 'rb') { |file| [file.read(HEADER_LIMIT), file.stat.size] }
        format, size = if bytes&.start_with?([137, 80, 78, 71, 13, 10, 26, 10].pack('C*')) && bytes.byteslice(12, 4) == 'IHDR' && bytes.bytesize >= 24
                         ['png', bytes.byteslice(16, 8).unpack('NN')]
                       elsif bytes && %w[GIF87a GIF89a].include?(bytes.byteslice(0, 6)) && bytes.bytesize >= 10
                         ['gif', bytes.byteslice(6, 4).unpack('vv')]
                       elsif bytes&.start_with?([255, 216].pack('C*'))
                         ['jpeg', jpeg_dimensions(bytes)]
                       elsif bytes&.start_with?('BM')
                         ['bmp', bmp_dimensions(bytes, file_size)]
                       end
        raise ArgumentError, 'Unsupported or truncated image header (expected PNG, GIF, JPEG or uncompressed true-color BMP)' unless size
        raise ArgumentError, 'Image dimensions must be within 1..65536 pixels' unless size.all? { |value| value.between?(1, 65_536) }

        Info.new(format: format, width: size[0], height: size[1])
      end

      # Walks JPEG marker segments until a supported frame header supplies dimensions.
      # Stops at scan/end markers or malformed/truncated segments; it never decodes data.
      # @return [Array<Integer>, nil] width and height when found
      def self.jpeg_dimensions(bytes)
        offset = 2
        while offset + 4 <= bytes.bytesize
          return unless bytes.getbyte(offset) == 0xff

          offset += 1 while bytes.getbyte(offset) == 0xff
          marker = bytes.getbyte(offset)
          offset += 1
          return if marker.nil? || [0xda, 0xd9].include?(marker)
          next if marker == 0x01 || (0xd0..0xd7).cover?(marker)

          length = bytes.byteslice(offset, 2)&.unpack1('n')
          return unless length && length >= 2 && offset + length <= bytes.bytesize
          if JPEG_FRAMES.include?(marker)
            return unless length >= 8

            height, width = bytes.byteslice(offset + 3, 4).unpack('nn')
            return [width, height]
          end
          offset += length
        end
        nil
      end
      private_class_method :jpeg_dimensions

      # BITMAPINFOHEADER with BI_RGB, one plane and 24/32-bit pixels only.
      # Checks DWORD-padded rows against the same open file without reading pixels.
      # BI_RGB ignores biSizeImage; pixel extents determine whether rows are present.
      # @param bytes [String] bounded binary header bytes from the image file
      # @param file_size [Integer] size obtained from the same open file
      # @return [Array<Integer>, nil] dimensions, normalizing top-down height
      def self.bmp_dimensions(bytes, file_size)
        return unless bytes.bytesize >= 54 && bytes.byteslice(14, 4).unpack1('V') == 40

        declared_size = bytes.byteslice(2, 4).unpack1('V')
        offset = bytes.byteslice(10, 4).unpack1('V')
        width, height = bytes.byteslice(18, 8).unpack('l<l<')
        planes, depth = bytes.byteslice(26, 4).unpack('vv')
        compression = bytes.byteslice(30, 4).unpack1('V')
        return unless planes == 1 && [24, 32].include?(depth) && compression.zero?
        return unless width.positive? && !height.zero? && offset >= 54 && declared_size <= file_size

        required = ((width * depth + 31) / 32) * 4 * height.abs
        return unless offset + required <= declared_size

        [width, height.abs]
      end
      private_class_method :bmp_dimensions
    end
  end
end
