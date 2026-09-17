# frozen_string_literal: true

module Lich
  module Main
    # Resolves a detachable-client session's character name from launch data.
    #
    # A raw --sal launch (no --login) carries no character name in the fields
    # main.rb already reads (GAMECODE/GAMEPORT/GAMEHOST/GAME) -- the EAccess
    # response it comes from never includes one. Some launch data (a wrapper
    # tool around --sal) may still carry CHARACTER=/NAME=, the same keys
    # SessionLauncher#build_spawn_args already treats as authoritative
    # (case-insensitively, since it reads them from a parse_launch_data map
    # that upcases every key) -- so this is checked before falling back to
    # watching the game stream for XMLData.name.
    #
    # Pulled out as a pure function so the parsing/validation rules can be unit
    # tested without exercising the surrounding detachable-listener thread.
    module DetachableSessionName
      # @param launch_data [Array<String>, nil]
      # @return [String, nil] capitalized character name, or nil when absent or blank
      def self.from_launch_data(launch_data)
        raw = launch_data&.find { |line| line =~ /\A(?:CHARACTER|NAME)=/i }
                         &.split('=', 2)&.last&.strip
        return nil if raw.to_s.empty?

        raw.capitalize
      end
    end
  end
end
