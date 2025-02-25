module Lich
  module DragonRealms
    class DRSkill
      @@skills_data ||= DR_SKILLS_DATA
      @@gained_skills ||= []
      @@start_time ||= Time.now
      @@list ||= []
      @@exp_modifiers ||= {}

      attr_reader :name, :skillset
      attr_accessor :rank, :exp, :percent, :current, :baseline

      def initialize(name, rank, exp, percent)
        @name = name # skill name like 'Evasion'
        @rank = rank.to_i # earned ranks in the skill
        # Skill mindstate x/34
        # Hardcode caped skills to 34/34
        @exp = rank.to_i >= 1750 ? 34 : exp.to_i
        @percent = percent.to_i # percent to next rank from 0 to 100
        @baseline = rank.to_i + (percent.to_i / 100.0)
        @current = rank.to_i + (percent.to_i / 100.0)
        @skillset = lookup_skillset(@name)
        @@list.push(self) unless @@list.find { |skill| skill.name == @name }
      end

      def self.reset
        @@gained_skills = []
        @@start_time = Time.now
        @@list.each { |skill| skill.baseline = skill.current }
      end

      # Primarily used by `learned` script to track how long it's
      # been tracking your experience gains this session.
      def self.start_time
        @@start_time
      end

      # List of skills that have increased their learning rates.
      # Primarily used by `exp-monitor` script to echo which skills
      # gained experience after you performed an action.
      def self.gained_skills
        @@gained_skills
      end

      # Returns the amount of ranks that have been gained since
      # the baseline was last reset. This allows you to track
      # rank gain for a given play session.
      #
      # Note, don't confuse the 'exp' in this method name with DRSkill.getxp(..)
      # which returns the current learning rate of the skill.
      def self.gained_exp(val)
        skill = self.find_skill(val)
        if skill
          return skill.current ? (skill.current - skill.baseline).round(2) : 0.00
        end
      end

      # Updates DRStats.gained_skills if the learning rate increased.
      # The original consumer of this data is the `exp-monitor` script.
      def self.handle_exp_change(name, new_exp)
        return unless UserVars.echo_exp

        old_exp = DRSkill.getxp(name)
        change = new_exp.to_i - old_exp.to_i
        if change > 0
          DRSkill.gained_skills << { skill: name, change: change }
        end
      end

      def self.include?(val)
        !self.find_skill(val).nil?
      end

      def self.update(name, rank, exp, percent)
        self.handle_exp_change(name, exp)
        skill = self.find_skill(name)
        if skill
          skill.rank = rank.to_i
          skill.exp = skill.rank.to_i >= 1750 ? 34 : exp.to_i
          skill.percent = percent.to_i
          skill.current = rank.to_i + (percent.to_i / 100.0)
        else
          DRSkill.new(name, rank, exp, percent)
        end
      end

      def self.update_mods(name, rank)
        self.exp_modifiers[self.lookup_alias(name)] = rank.to_i
      end

      def self.exp_modifiers
        @@exp_modifiers
      end

      def self.clear_mind(val)
        self.find_skill(val).exp = 0
      end

      def self.getrank(val)
        self.find_skill(val).rank.to_i
      end

      def self.getmodrank(val)
        skill = self.find_skill(val)
        if skill
          rank = skill.rank.to_i
          modifier = self.exp_modifiers[skill.name].to_i
          rank + modifier
        end
      end

      def self.getxp(val)
        skill = self.find_skill(val)
        skill.exp.to_i
      end

      def self.getpercent(val)
        self.find_skill(val).percent.to_i
      end

      def self.getskillset(val)
        self.find_skill(val).skillset
      end

      def self.listall
        @@list.each do |i|
          echo "#{i.name}: #{i.rank}.#{i.percent}% [#{i.exp}/34]"
        end
      end

      def self.list
        @@list
      end

      def self.find_skill(val)
        @@list.find { |data| data.name == self.lookup_alias(val) }
      end

      # Some guilds rename skills, like Barbarians call "Primary Magic" as "Inner Fire".
      # Given the canonical or colloquial name, this method returns the value
      # that's usable with the other methods like `getxp(skill)` and `getrank(skill)`.
      def self.lookup_alias(skill)
        @@skills_data[:guild_skill_aliases][DRStats.guild][skill] || skill
      end

      # This is an instance method, do not prefix with `self`.
      # It is called from the initialize method (constructor).
      # When it was defined as a class method then the initialize method
      # complained that this method didn't yet exist.
      def lookup_skillset(skill)
        @@skills_data[:skillsets].find { |_skillset, skills| skills.include?(skill) }.first
      end
    end
  end
end
