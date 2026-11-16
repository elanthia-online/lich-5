# frozen_string_literal: true

require 'json'

# Private one-record transport shared by the acceptance supervisor and probe.
# A file in the isolated temporary root avoids inherited descriptors on Windows.
module DefaultWebUIAcceptanceReport
  module_function

  # Publishes a complete JSON record; the receiver never observes a partial write.
  # @param path [String] unused destination in the supervisor's temporary root
  # @param result [Hash] acceptance result
  # @return [void]
  # @api private
  def publish(path, result)
    pending = "#{path}.pending"
    File.write(pending, JSON.generate(result))
    File.rename(pending, path)
  ensure
    File.delete(pending) if pending && File.exist?(pending)
  end

  # Waits for publication, child exit, or the monotonic report deadline.
  # @param path [String] report destination
  # @param waiter [Thread] Open3 child waiter
  # @param timeout [Numeric] maximum seconds to await publication
  # @return [String, nil] complete record, or nil on exit/timeout without a report
  # @api private
  def receive(path, waiter, timeout: 20)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    loop do
      return File.read(path) if File.file?(path)

      remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
      if remaining <= 0 || !waiter.alive?
        # Publication can occur between the first file check and child exit.
        return File.file?(path) ? File.read(path) : nil
      end

      waiter.join([remaining, 0.05].min)
    end
  end
end
