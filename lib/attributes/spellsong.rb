module Games
  module Gemstone
    class Spellsong
      @@renewed ||= 0.to_f

      def self.sync
        timed_spell = Effects::Spells.to_h.keys.find { |k| k.to_s.match(/10[0-9][0-9]/) }
        return 'No active bard spells' if timed_spell.nil?
        @@renewed = Time.at(Time.now.to_f - self.duration.to_f + (Effects::Spells.time_left(timed_spell) * 60.to_f))
      end

      def self.renewed
        @@renewed = Time.now
      end

      def self.renewed=(val)
        @@renewed = val
      end

      def self.renewed_at
        @@renewed
      end

      def self.timeleft
        return 0.0 if Char.prof != 'Bard'
        (self.duration - ((Time.now.to_f - @@renewed.to_f) % self.duration)) / 60.to_f
      end

      def self.serialize
        self.timeleft
      end

      def self.duration
        total = 135
        1.upto(Stats.level.to_i) { |n|
          if n < 26
            total += 4
          elsif n < 51
            total += 3
          elsif n < 76
            total += 2
          else
            total += 1
          end
        }
        # echo  total + Stats.log[1].to_i + (Stats.inf[1].to_i * 3) + (Skills.mltelepathy.to_i * 2)
        total + Stats.log[1].to_i + (Stats.inf[1].to_i * 3) + (Skills.mltelepathy.to_i * 2)
      end

      def self.renew_cost
        # fixme: multi-spell penalty?
        total = num_active = 0
        [1003, 1006, 1009, 1010, 1012, 1014, 1018, 1019, 1025].each { |song_num|
          if (song = Spell[song_num])
            if song.active?
              total += song.renew_cost
              num_active += 1
            end
          else
            echo "self.renew_cost: warning: can't find song number #{song_num}"
          end
        }
        return total
      end

      def self.sonicarmordurability
        210 + (Stats.level / 2).round + Skills.to_bonus(Skills.elair)
      end

      def self.sonicbladedurability
        160 + (Stats.level / 2).round + Skills.to_bonus(Skills.elair)
      end

      def self.sonicweapondurability
        self.sonicbladedurability
      end

      def self.sonicshielddurability
        125 + (Stats.level / 2).round + Skills.to_bonus(Skills.elair)
      end

      def self.tonishastebonus
        bonus = -1
        thresholds = [30, 75]
        thresholds.each { |val| if Skills.elair >= val then bonus -= 1 end }
        bonus
      end

      def self.depressionpushdown
        20 + Skills.mltelepathy
      end

      def self.depressionslow
        thresholds = [10, 25, 45, 70, 100]
        bonus = -2
        thresholds.each { |val| if Skills.mltelepathy >= val then bonus -= 1 end }
        bonus
      end

      def self.holdingtargets
        1 + ((Spells.bard - 1) / 7).truncate
      end

      def self.cost
        self.renew_cost
      end

      def self.tonisdodgebonus
        thresholds = [1, 2, 3, 5, 8, 10, 14, 17, 21, 26, 31, 36, 42, 49, 55, 63, 70, 78, 87, 96]
        bonus = 20
        thresholds.each { |val| if Skills.elair >= val then bonus += 1 end }
        bonus
      end

      def self.mirrorsdodgebonus
        20 + ((Spells.bard - 19) / 2).round
      end

      def self.mirrorscost
        [19 + ((Spells.bard - 19) / 5).truncate, 8 + ((Spells.bard - 19) / 10).truncate]
      end

      def self.sonicbonus
        (Spells.bard / 2).round
      end

      def self.sonicarmorbonus
        self.sonicbonus + 15
      end

      def self.sonicbladebonus
        self.sonicbonus + 10
      end

      def self.sonicweaponbonus
        self.sonicbladebonus
      end

      def self.sonicshieldbonus
        self.sonicbonus + 10
      end

      def self.valorbonus
        10 + (([Spells.bard, Stats.level].min - 10) / 2).round
      end

      def self.valorcost
        [10 + (self.valorbonus / 2), 3 + (self.valorbonus / 5)]
      end

      def self.luckcost
        [6 + ((Spells.bard - 6) / 4), (6 + ((Spells.bard - 6) / 4) / 2).round]
      end

      def self.manacost
        [18, 15]
      end

      def self.fortcost
        [3, 1]
      end

      def self.shieldcost
        [9, 4]
      end

      def self.weaponcost
        [12, 4]
      end

      def self.armorcost
        [14, 5]
      end

      def self.swordcost
        [25, 15]
      end
    end
  end
end
