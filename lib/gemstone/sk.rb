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
      NAMESPACE = "sk/known"
      Vars[NAMESPACE] ||= []

      def self.known?(spell)
        Vars[NAMESPACE].include?(spell.num.to_s)
      end

      def self.list
        respond "Current SK Spells: #{Vars[NAMESPACE].inspect}"
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
        Vars[NAMESPACE] = (Vars[NAMESPACE] + numbers).uniq
      end

      def self.remove(*numbers)
        Vars[NAMESPACE] = (Vars[NAMESPACE] - numbers).uniq
      end

      def self.main()
        action = Script.current.vars[1].to_sym
        spells = Script.current.vars[2..-1]
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

      #self.main() if Script.current.vars.size > 1
    end
  end
end
