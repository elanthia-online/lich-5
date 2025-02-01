module Lich
  module Common
    class Spell
      OLD_KNOWN_METHOD ||= Spell.instance_method(:known?)
      OLD_TIME_PER_METHOD ||= Spell.instance_method(:time_per)
      def known?
        SK.known?(self) or OLD_KNOWN_METHOD.bind(self).call()
      end

      def time_per(arg = nil)
        # dumb time per of 10m because lots of things break otherwise
        return 10.0 if SK.known?(self) && (OLD_TIME_PER_METHOD.bind(self).call(arg).nil? || OLD_TIME_PER_METHOD.bind(self).call(arg) < 10)
        return OLD_TIME_PER_METHOD.bind(self).call(arg)
      end
    end
  end
end

module Lich
  module Gemstone
    module SK
      @sks_known ||= []

      def self.known?(spell)
        @sks_known.include?(spell.num.to_s)
      end

      def self.list
        respond "Current SK Spells: #{@sks_known.inspect}"
      end

      def self.help
        respond "   Script to add SK spells to be known and used with Spell API calls."
        respond ""
        respond "   ;sk add <SPELL_NUMBER>  - Add spell number to saved list"
        respond "   ;sk rm <SPELL_NUMBER>   - Remove spell number from saved list"
        respond "   ;sk list                - Show all currently saved SK spell numbers"
        respond "   ;sk help                - Show this menu"
        respond ""
      end

      def self.add(*numbers)
        @sks_known = (@sks_known + numbers).uniq
      end

      def self.remove(*numbers)
        @sks_known = (@sks_known - numbers).uniq
      end

      def self.main(action, spells)
        action = action.to_sym
        case action
        when :add
          self.add(*spells)
        when :rm
          self.remove(*spells)
        when :list
          self.list
        when :help
          self.help
        else
          fail "unknown action #{action}"
        end
      end
    end
  end
end
