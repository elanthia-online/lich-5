module Lich
  module Gemstone
    module SK
      # NAMESPACE = "sk/known"
      # Vars[NAMESPACE] ||= []
      @sk_known = nil
      
      def self.sk_known
        if @sk_known.nil?
          val = DB_Store.read("#{XMLData.game}:#{XMLData.name}", "sk_known")
          val = [] if val.nil? || (val.class == Hash && val.empty?)
          @sk_known = val if !val.nil?;
        end
        return @sk_known
      end

      def self.sk_known=(val)
        @sk_known = val
        DB_Store.save("#{XMLData.game}:#{XMLData.name}", "sk_known", @sk_known)
        return @sk_known
      end

      def self.known?(spell)
        self.sk_known if @sk_known.nil?
        @sk_known.include?(spell.num.to_s)
      end

      def self.list
        respond "Current SK Spells: #{@sk_known.inspect}"
        respond ""
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
        self.sk_known = (@sk_known + numbers).uniq
        self.list
      end

      def self.remove(*numbers)
        self.sk_known = (@sk_known - numbers).uniq
        self.list
      end

      def self.main(action = help, spells = nil)
        action = action.to_sym
        spells = spells.split(" ").uniq
        case action
        when :add
          self.add(*spells) unless spells.empty?
          self.help if spells.empty?
        when :rm
          self.remove(*spells) unless spells.empty?
          self.help if spells.empty?
        when :list
          self.list
        else
          self.help
        end
      end
    end
  end
end
