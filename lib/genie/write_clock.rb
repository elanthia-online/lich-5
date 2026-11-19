# frozen_string_literal: true

module Lich
  module Genie
    # A process-wide, strictly increasing write counter shared by the two writers of a
    # Genie global: a script's `#var` (GlobalStore#set) and a game update (GameState).
    #
    # Remix keeps ONE variable list: a `#var invisible 0` and the next
    # `<indicator id='IconINVISIBLE'>` both Add() the same key, so the later write wins
    # (Globals.cs:604-617 R; Game.cs:2093-2099 R). Ours keeps the two in different
    # places (the store and the game-state capture), so each write takes a stamp from
    # this clock and Variables#global_get returns whichever was written last.
    # The two writers run on different threads (script threads, Lich's parser thread),
    # hence the mutex.
    class WriteClock
      def initialize
        @mutex = Mutex.new
        @last = 0
      end

      # @return [Integer] a stamp greater than every stamp handed out before
      def tick
        @mutex.synchronize { @last += 1 }
      end

      # The clock every store and game state shares unless a spec injects its own.
      SHARED = new
    end
  end
end
