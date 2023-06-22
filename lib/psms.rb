require "ostruct"

require_relative('./psms/armor.rb')
require_relative('./psms/cman.rb')
require_relative('./psms/feat.rb')
require_relative('./psms/shield.rb')
require_relative('./psms/weapon.rb')
require_relative('./psms/warcry.rb')

module PSMS
  def self.name_normal(name)
    # there are four cases to normalize
    # "vault_kick", "vault kick", :vault_kick, :vaultkick
    # if present, convert spaces to underscore; convert all to downcase string
    name.gsub!(' ', '_') if name =~ (/\s/)
    name.to_s.downcase
  end

  def self.assess(name, type, costcheck = false)
    name = self.name_normal(name)
    seek_psm = Object.const_get("#{type}").method("#{type.downcase}_lookups").call
                     .find { |h| h[:long_name].eql?(name) || h[:short_name].eql?(name) }
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
      Infomon.get("psm.#{seek_psm[:short_name]}")
    end
  end
end
