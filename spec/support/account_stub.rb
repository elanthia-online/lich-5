# frozen_string_literal: true

# The one stand-in for Lich::Common::Account (lib/common/account.rb).
#
# Several specs need Account state but not the real module, whose
# subscription= setter ignores nil and so cannot be reset between examples.
# They used to each define their own stub behind `unless defined?`, with
# different accessors, so whichever file loaded first decided what every
# later spec in the process got. Keep the accessor list a superset of what
# any spec or the code under test uses.

module Lich
  module Common
    module Account
      class << self
        attr_accessor :name, :game_code, :character, :subscription, :members
      end
    end
  end
end unless defined?(Lich::Common::Account)
