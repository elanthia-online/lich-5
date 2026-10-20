# frozen_string_literal: true

module Lich
  module Common
    # Bounded retry for filesystem mutations that Windows refuses with EACCES
    # (a sharing violation) while another process briefly holds the file open.
    #
    # Extend a module with this mixin to give it a private
    # +retry_sharing_violation+ singleton method. The backoff sleeps through the
    # extending module's own +sleep+, so specs can stub it there.
    module SharingViolationRetry
      # Backoff between attempts, 0.31 s in total.
      #
      # @return [Array<Float>]
      DELAYS = [0.01, 0.02, 0.04, 0.08, 0.16].freeze

      private

      # Runs a filesystem mutation, retrying EACCES once per entry in DELAYS.
      # Every other error is raised immediately.
      #
      # @yield the filesystem mutation to attempt
      # @return [Object] the mutation result
      # @raise [Errno::EACCES] when every bounded retry is exhausted
      # @raise [StandardError] any other error from the block, unretried
      def retry_sharing_violation
        attempt = 0
        begin
          yield
        rescue Errno::EACCES
          raise if attempt >= DELAYS.length

          sleep(DELAYS.fetch(attempt))
          attempt += 1
          retry
        end
      end
    end
  end
end
