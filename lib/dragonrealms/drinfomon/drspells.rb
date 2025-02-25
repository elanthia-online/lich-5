module Lich
  module DragonRealms
    module DRSpells
      @@known_spells = {}
      @@known_feats = {}
      @@spellbook_format = nil # 'column-formatted' or 'non-column'

      @@grabbing_known_spells = false
      @@grabbing_known_barbarian_abilities = false
      @@grabbing_known_khri = false

      def self.active_spells
        XMLData.dr_active_spells
      end

      def self.known_spells
        @@known_spells
      end

      def self.known_feats
        @@known_feats
      end

      def self.slivers
        XMLData.dr_active_spells_slivers
      end

      def self.stellar_percentage
        XMLData.dr_active_spells_stellar_percentage
      end

      def self.grabbing_known_spells
        @@grabbing_known_spells
      end

      def self.grabbing_known_spells=(val)
        @@grabbing_known_spells = val
      end

      def self.check_known_barbarian_abilities
        @@grabbing_known_barbarian_abilities
      end

      def self.check_known_barbarian_abilities=(val)
        @@grabbing_known_barbarian_abilities = val
      end

      def self.grabbing_known_khri
        @@grabbing_known_khri
      end

      def self.grabbing_known_khri=(val)
        @@grabbing_known_khri = val
      end

      def self.spellbook_format
        @@spellbook_format
      end

      def self.spellbook_format=(val)
        @@spellbook_format = val
      end
    end
  end
end
