# frozen_string_literal: true

module Lich
  module Main
    # Waits for a character name to become available (e.g. XMLData.name after a
    # bare --sal connect), so the detachable session file can be created once
    # one is known. Pulled out of the listener thread so its two exit
    # conditions -- a usable name, or shutdown -- are unit-testable without
    # threads or sleeps.
    module DetachableSessionPoller
      DEFAULT_INTERVAL = 0.2

      # Polls until shutdown_requested says stop or name_source returns a
      # non-blank String. No fixed timeout: a capped wait either drops a name
      # that arrives late (silently, with no session file for the rest of the
      # session) or has to guess how long is long enough. Shutdown is what
      # already has to stop this thread either way, so it's the only cap.
      #
      # @param name_source [#call] returns the current candidate name (may be nil/blank)
      # @param shutdown_requested [#call] returns true once teardown has begun
      # @param interval [Numeric] seconds to sleep between checks
      # @return [String, nil] the first non-blank, stripped name seen, or nil if
      #   shutdown was requested first
      def self.wait_for_name(name_source:, shutdown_requested:, interval: DEFAULT_INTERVAL)
        # `until`, not Kernel#loop: loop silently rescues StopIteration and
        # returns whatever it was carrying, which would violate the
        # [String, nil] contract here if name_source ever raised one.
        until shutdown_requested.call
          candidate = name_source.call
          return candidate.strip if candidate.is_a?(String) && !candidate.strip.empty?

          sleep(interval)
        end
        nil
      end
    end
  end
end
