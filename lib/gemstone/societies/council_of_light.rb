module Lich
  module Gemstone
    module Society
      class CouncilOfLight
        @@col_signs = {
          "sign_of_recognition" => {
            :rank              => 1,
            :short_name        => "recognition",
            :type              => :utility,
            :regex             => nil,
            :cost              => nil, # no cost
            :duration          => nil,
            :cooldown_duration => nil,
            :summary           => "Detect other members of the Order and any undead creatures present in the room.",
            :spell_number      => 9901,
          },
        }
      end
    end
  end
end
