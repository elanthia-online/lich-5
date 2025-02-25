module Lich
  module Resources
    def self.weekly
      Lich::Gemstone::Infomon.get('resources.weekly')
    end

    def self.total
      Lich::Gemstone::Infomon.get('resources.total')
    end

    def self.suffused
      Lich::Gemstone::Infomon.get('resources.suffused')
    end

    def self.type
      Lich::Gemstone::Infomon.get('resources.type')
    end

    def self.voln_favor
      Lich::Gemstone::Infomon.get('resources.voln_favor')
    end

    def self.covert_arts_charges
      Lich::Gemstone::Infomon.get('resources.covert_arts_charges')
    end

    def self.check(quiet = false)
      Lich::Util.issue_command('resource', /^Health: \d+\/(?:<pushBold\/>)?\d+(?:<popBold\/>)?\s+Mana: \d+\/(?:<pushBold\/>)?\d+(?:<popBold\/>)?\s+Stamina: \d+\/(?:<pushBold\/>)?\d+(?:<popBold\/>)?\s+Spirit: \d+\/(?:<pushBold\/>)?\d+/, /<prompt/, silent: true, quiet: quiet)
      return [self.weekly, self.total, self.suffused]
    end
  end
end
