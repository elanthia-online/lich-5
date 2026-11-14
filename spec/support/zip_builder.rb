# frozen_string_literal: true

require 'zlib'

# Writes small ZIP archives for specs, so ZIP handling is exercised against
# real bytes on every platform without an external `zip` program. Each entry
# may override the fields a malformed or unsupported archive would carry.
module ZipBuilder
  module_function

  # @param entries [Array<Hash>] :name, :data, and optional :method (:deflate
  #   or :store), :descriptor, :flags, :crc32, :size, :compressed_size,
  #   :payload (raw entry data, replacing the compressed :data), :trailing
  #   (bytes appended to the payload and counted in its compressed size),
  #   :local_signature
  # @param end_record [Hash] optional :disk, :directory_disk, :disk_count,
  #   :total_count, :directory_size, :directory_offset overrides, an
  #   archive :comment, and :zip64_end to write a ZIP64 end record and
  #   locator before the end record, as Info-ZIP does writing from a pipe
  # @return [String] binary ZIP
  def build(entries, end_record = {})
    body = +''.b
    central = +''.b
    entries.each do |entry|
      name = entry.fetch(:name).b
      data = entry.fetch(:data, '').b
      deflate = entry.fetch(:method, :deflate) == :deflate
      payload = entry.fetch(:payload) { deflate ? raw_deflate(data) : data }.b + entry.fetch(:trailing, '').b
      flags = entry.fetch(:flags, 0) | (entry[:descriptor] ? 0x0008 : 0)
      method = entry.fetch(:method_id, deflate ? 8 : 0)
      crc = entry.fetch(:crc32, Zlib.crc32(data))
      size = entry.fetch(:size, data.bytesize)
      compressed_size = entry.fetch(:compressed_size, payload.bytesize)
      offset = body.bytesize

      local_crc, local_compressed, local_size = entry[:descriptor] ? [0, 0, 0] : [crc, compressed_size, size]
      body << [entry.fetch(:local_signature, 0x04034b50), 20, flags, method, 0, 0, local_crc, local_compressed, local_size, name.bytesize, 0].pack('VvvvvvVVVvv')
      body << name << payload
      body << [0x08074b50, crc, compressed_size, size].pack('VVVV') if entry[:descriptor]

      central << [0x02014b50, 20, 20, flags, method, 0, 0, crc, compressed_size, size,
                  name.bytesize, 0, 0, 0, 0, 0, entry.fetch(:offset, offset)].pack('VvvvvvvVVVvvvvvVV')
      central << name
    end
    count = entries.length
    comment = end_record.fetch(:comment, '').b
    fields = { disk: 0, directory_disk: 0, disk_count: count, total_count: count,
               directory_size: central.bytesize, directory_offset: body.bytesize }.merge(end_record.except(:comment, :zip64_end))
    zip64 = +''.b
    if end_record[:zip64_end]
      zip64_at = body.bytesize + central.bytesize
      zip64 << [0x06064b50, 44, 45, 45, 0, 0, count, count, central.bytesize, body.bytesize].pack('VQ<vvVVQ<Q<Q<Q<')
      zip64 << [0x07064b50, 0, zip64_at, 1].pack('VVQ<V')
    end
    body + central + zip64 + [0x06054b50, *fields.values_at(:disk, :directory_disk, :disk_count, :total_count,
                                                            :directory_size, :directory_offset), comment.bytesize].pack('VvvvvVVv') + comment
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
