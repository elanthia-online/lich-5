require "ostruct"

require_relative('./psms/armor.rb')
require_relative('./psms/cman.rb')
require_relative('./psms/feat.rb')
require_relative('./psms/shield.rb')
require_relative('./psms/weapon.rb')

module PSM
  def self._name_normal(name)
    # there are four cases to normalize
    # "vault_kick", "vault kick", :vault_kick, :vaultkick
    # if present, convert spaces to underscore; convert all to downcase string
    name.gsub!(' ', '_') if name =~ (/\s/)
    name.to_s.downcase
  end

  def self.method_missing(arg1, arg2)
    # todo: always returns one extra line?
    echo "#{arg1} is not a defined #{arg2}.  Was it moved to another Ability?"
  end

  def self.assess(name, type)
    name = self._name_normal(name)
    seek_psm = Object.const_get("#{type}")
                     .method("#{type.downcase}_lookups").call
                     .find { |h|
      h[:long_name].eql?(name) ||
        h[:short_name].eql?(name)
    }
    return Infomon.get("psm.#{seek_psm[:short_name]}") unless seek_psm.nil?
    return self.method_missing(name, type) if seek_psm[:short_name].nil?
  end

  def self.affordable?(name, type)
    name = self._name_normal(name)
    check = Object.const_get("#{type}")
                  .method("#{type.downcase}_lookups").call
                  .find { |h|
      h[:long_name].eql?(name.to_s) ||
        h[:short_name].eql?(name.to_s)
    }
    return self.method_missing(name, type) if check[:cost].nil?
    check[:cost] < XMLData.stamina
  end
end
