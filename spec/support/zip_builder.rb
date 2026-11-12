# frozen_string_literal: true

require 'zlib'

# Writes small ZIP archives for specs, so ZIP handling is exercised against
# real bytes on every platform without an external `zip` program. Each entry
# may override the fields a malformed or unsupported archive would carry.
module ZipBuilder
  module_function

  # @param entries [Array<Hash>] :name, :data, and optional :method (:deflate
  #   or :store), :descriptor, :flags, :crc32, :size, :compressed_size
  # @return [String] binary ZIP
  def build(entries)
    body = +''.b
    central = +''.b
    entries.each do |entry|
      name = entry.fetch(:name).b
      data = entry.fetch(:data, '').b
      deflate = entry.fetch(:method, :deflate) == :deflate
      payload = deflate ? raw_deflate(data) : data
      flags = entry.fetch(:flags, 0) | (entry[:descriptor] ? 0x0008 : 0)
      method = entry.fetch(:method_id, deflate ? 8 : 0)
      crc = entry.fetch(:crc32, Zlib.crc32(data))
      size = entry.fetch(:size, data.bytesize)
      compressed_size = entry.fetch(:compressed_size, payload.bytesize)
      offset = body.bytesize

      local_crc, local_compressed, local_size = entry[:descriptor] ? [0, 0, 0] : [crc, compressed_size, size]
      body << [0x04034b50, 20, flags, method, 0, 0, local_crc, local_compressed, local_size, name.bytesize, 0].pack('VvvvvvVVVvv')
      body << name << payload
      body << [0x08074b50, crc, compressed_size, size].pack('VVVV') if entry[:descriptor]

      central << [0x02014b50, 20, 20, flags, method, 0, 0, crc, compressed_size, size,
                  name.bytesize, 0, 0, 0, 0, 0, entry.fetch(:offset, offset)].pack('VvvvvvvVVVvvvvvVV')
      central << name
    end
    count = entries.length
    body + central + [0x06054b50, 0, 0, count, count, central.bytesize, body.bytesize, 0].pack('VvvvvVVv')
  end

  # @param data [String]
  # @return [String] raw (headerless) deflate stream
  def raw_deflate(data)
    deflater = Zlib::Deflate.new(Zlib::DEFAULT_COMPRESSION, -Zlib::MAX_WBITS)
    deflater.deflate(data, Zlib::FINISH)
  ensure
    deflater&.close
  end
end
