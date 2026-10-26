# frozen_string_literal: true

module Lich
  module WebUI
    # Resolves the same preference used by GTK startup and child-session flags.
    # Persistence and command-line precedence remain owned by Lich/StartupTheme.
    module Theme
      # Reads the current application preference without caching a second copy.
      # Standalone consumers without Lich settings retain the light default.
      # @return [Symbol] :dark or :light
      def self.current
        Lich.respond_to?(:track_dark_mode) && Lich.track_dark_mode ? :dark : :light
      end
    end
  end
end
