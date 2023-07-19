module Lich
  module Resources
    def self.weekly
      Infomon.get('resources.weekly')
    end

    def self.total
      Infomon.get('resources.total')
    end

    def self.suffused
      Infomon.get('resources.suffused')
    end

    def self.type
      Infomon.get('resources.type')
    end

    def self.check(quiet = false)
      Lich::Util.issue_command('resource', /^Health: \d+\/(?:<pushBold\/>)?\d+\s+Mana: \d+\/(?:<pushBold\/>)?\d+\s+Stamina: \d+\/(?:<pushBold\/>)?\d+\s+Spirit: \d+\/(?:<pushBold\/>)?\d+/, /<prompt/, silent: true, quiet: quiet)
      return [self.weekly, self.total, self.suffused]
    end
  end
end
