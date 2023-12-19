require "ostruct"

require_relative('./psms/armor.rb')
require_relative('./psms/cman.rb')
require_relative('./psms/feat.rb')
require_relative('./psms/shield.rb')
require_relative('./psms/weapon.rb')
require_relative('./psms/warcry.rb')
require_relative('./psms/ascension.rb')

module PSMS
  def self.name_normal(name)
    # there are five cases to normalize
    # "vault_kick", "vault kick", "vault-kick", :vault_kick, :vaultkick
    # "predator's eye"
    # if present, convert spaces to underscore; convert all to downcase string
    normal_name = name.to_s.downcase
    normal_name.gsub!(' ', '_') if name =~ (/\s/)
    normal_name.gsub!('-', '_') if name =~ (/-/)
    normal_name.gsub!("'", '') if name =~ (/'/)
    normal_name
  end

  def self.find_name(name, type)
    Object.const_get("#{type}").method("#{type.downcase}_lookups").call
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
      if type =~ /Ascension/
        Infomon.get("ascension.#{seek_psm[:short_name]}")
      else
        Infomon.get("psm.#{seek_psm[:short_name]}")
      end
    end
  end
end
