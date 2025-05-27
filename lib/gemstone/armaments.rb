require_relative "armaments/armor_stats.rb"
require_relative "armaments/weapon_stats.rb"
require_relative "armaments/shield_stats.rb"

module Lich
  module Gemstone
    module Armaments
      def self.find_by_alt_name(name, type) # type is "armor", "weapon", or "shield"
        case type
        when "armor"
          Lich::Gemstone::ArmorStats.find_type_by_name(name: name, category: nil)
        when "weapon"
          Lich::Gemstone::WeaponStats.find_type_by_name(name: name, category: nil)
        when "shield"
          Lich::Gemstone::ShieldStats.find_type_by_name(name: name, category: nil)
        else
          raise ArgumentError, "Unknown armament type: #{type}"
        end
      end
    end
  end
end
