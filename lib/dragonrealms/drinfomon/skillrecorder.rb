module Lich
  module DragonRealms
    module DRSkillRecorder
      Thread.new {
        loop do
          unless UserVars.athletics == DRSkill.getmodrank('Athletics')
            UserVars.athletics = DRSkill.getmodrank('Athletics')
          end

          if DRSpells.active_spells['Athleticism'] || DRSpells.active_spells['Khri Flight'] || DRSpells.active_spells['Unyielding']
            # If these buffs are active but we don't see a change in `exp mods`
            # then assume the minimum modifier amount of 10%
            if DRSkill.getrank('Athletics') == DRSkill.getmodrank('Athletics')
              UserVars.athletics = UserVars.athletics * 1.1
            end
          end

          if DRStats.guild == 'Ranger'
            UserVars.scouting = nil unless UserVars.scouting.nil?
            UserVars.instinct = DRSkill.getmodrank('Instinct')
          else
            UserVars.scouting = nil unless UserVars.scouting.nil?
            UserVars.instinct = nil unless UserVars.instinct.nil?
          end

          if DRStats.guild == 'Thief'
            UserVars.thief_tunnels = {} unless UserVars.thief_tunnels.is_a?(Hash)

            if DRStats.circle > 5
              UserVars.thief_tunnels['crossing_passages'] = true unless UserVars.thief_tunnels['crossing_passages']
              UserVars.thief_tunnels['shard_passages'] = true unless UserVars.thief_tunnels['shard_passages']
              if UserVars.athletics >= 25
                UserVars.thief_tunnels['crossing_leth'] = true unless UserVars.thief_tunnels['crossing_leth']
              end
            end
          else
            UserVars.thief_tunnels = nil unless UserVars.thief_tunnels.nil?
          end

          if DRStats.guild == 'Cleric'
            UserVars.know_rezz = DRSpells.known_spells['Resurrection'] unless UserVars.know_rezz
          else
            UserVars.know_rezz = nil unless UserVars.know_rezz.nil?
          end
          pause 60
        end
      }
    end
  end
end
