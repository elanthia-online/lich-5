# frozen_string_literal: true

# Socket send-buffer helper for WebUI write-stall examples. Include in an example group to use it.
module WebUISocketBuffer
  # Writes until the kernel refuses more, so the next write stalls whatever the platform's
  # socket buffer size. Windows AF_UNIX sockets absorb far more than SO_SNDBUF suggests, so a
  # fixed message size does not reliably stall there. Bounded by time and by bytes.
  # @param sender [Socket] writable end of the pair to fill
  # @param limit [Integer] most bytes to write before giving up
  # @return [void]
  # @raise [RuntimeError] when the buffer never refuses a write within the limit or 5 seconds
  def fill_send_buffer(sender, limit: 512 * 1024 * 1024)
    chunk = 'f' * 65_536
    total = 0
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
    loop do
      written = sender.write_nonblock(chunk, exception: false)
      break if written == :wait_writable

      total += written
      raise "send buffer never filled (#{total} bytes)" if total > limit || Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
    end
  end
end
