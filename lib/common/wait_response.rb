# frozen_string_literal: true

module Lich
  module Common
    # The game's roundtime refusal ("...wait 3 seconds.", "Wait 1 second.").
    # Shared by fput, dothis, dothistimeout, move and DR's bput. Anchored at
    # the end of the line: the game sometimes appends "...wait N seconds." to
    # the previous line, and player speech containing "Wait N" ends in a quote.
    WAIT_RESPONSE_PATTERN = /(?:\.\.\. ?wait|\AWait) (?<seconds>[0-9]+) sec(?:onds?)?\.(?:<[^>]+>)*\s*\z/.freeze
  end
end
