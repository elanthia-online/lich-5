# frozen_string_literal: true

# Top-level ::Frontend stand-in for game code outside Lich::Common (games.rb,
# DR/GS modules), which resolves Frontend to ::Frontend.
#
# lib/common/frontend.rb ends with `Frontend = Lich::Common::Frontend unless
# defined?(Frontend)`, so whichever file loads first decides what ::Frontend
# is for the rest of the process. .rspec and .rspec_parallel require this file
# before any spec file loads (spec_helper and login_spec_helper also require
# it), so ::Frontend is always this mock, whichever spec a worker loads first.
# Code inside Lich::Common still finds the real Lich::Common::Frontend by
# lexical lookup.
module Frontend
  class << self
    def wizard?
      false
    end

    def stormfront?
      true
    end

    def supports_gsl?
      false
    end

    def supports_mono?(_fe = nil)
      false
    end

    def supports_room_window?(_fe = nil)
      %w[wrayth stormfront saga].include?(client)
    end

    def client
      'profanity'
    end
  end
end unless defined?(Frontend)
