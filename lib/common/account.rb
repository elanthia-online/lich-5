module Lich
  module Common
    module Account
      @@name ||= nil
      @@subscription ||= nil
      @@game_code ||= nil
      @@members ||= {}
      @@character ||= nil

      def self.name
        @@name
      end

      def self.name=(value)
        @@name = value
      end

      def self.character
        @@character
      end

      def self.character=(value)
        @@character = value
      end

      def self.subscription
        @@subscription
      end

      def self.type
        if XMLData.game.is_a?(String) && XMLData.game =~ /^GS/
          Infomon.get("account.type")
        end
      end

      def self.subscription=(value)
        if value =~ /(NORMAL|PREMIUM|TRIAL|INTERNAL|FREE)/
          @@subscription = Regexp.last_match(1)
        end
      end

      def self.game_code
        @@game_code
      end

      def self.game_code=(value)
        @@game_code = value
      end

      def self.members
        @@members
      end

      def self.members=(value)
        potential_members = {}
        for code_name in value.sub(/^C\t[0-9]+\t[0-9]+\t[0-9]+\t[0-9]+[\t\n]/, '').scan(/[^\t]+\t[^\t^\n]+/)
          char_code, char_name = code_name.split("\t")
          potential_members[char_code] = char_name
        end
        @@members = potential_members
      end

      def self.characters
        @@members.values
      end
    end
  end
end
