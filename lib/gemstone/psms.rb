require "ostruct"

require_relative('./psms/armor.rb')
require_relative('./psms/cman.rb')
require_relative('./psms/feat.rb')
require_relative('./psms/shield.rb')
require_relative('./psms/weapon.rb')
require_relative('./psms/warcry.rb')
require_relative('./psms/ascension.rb')

module Lich
  module Gemstone
    module PSMS
      def self.name_normal(name)
        Lich::Util.name_normal(name)
      end

      def self.find_name(name, type)
        Object.const_get("Lich::Gemstone::#{type}").method("#{type.downcase}_lookups").call
              .find { |h| h[:long_name].eql?(name) || h[:short_name].eql?(name) }
      end

      def self.assess(name, type, costcheck = false)
        name = self.name_normal(name)
        seek_psm = self.find_name(name, type)
        # this logs then raises an exception to stop (kill) the offending script
        if seek_psm.nil?
          Lich.log("error: PSMS request: #{$!}\n\t")
          raise StandardError.new "Aborting script - The referenced #{type} skill #{name} is invalid.\r\nCheck your PSM category (Armor, CMan, Feat, Shield, Warcry, Weapon) and your spelling of #{name}."
        end
        # otherwise process request
        case costcheck
        when true
          seek_psm[:cost] < XMLData.stamina
        else
          Infomon.get("#{type.downcase}.#{seek_psm[:short_name]}")
        end
      end
    end
  end
end
