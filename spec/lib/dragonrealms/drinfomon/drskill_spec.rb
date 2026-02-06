# frozen_string_literal: true

require_relative '../../../spec_helper'

# Mock DRStats for guild lookups
module Lich
  module DragonRealms
    module DRStats
      def self.guild
        @guild || 'Warrior Mage'
      end

      def self.guild=(val)
        @guild = val
      end
    end
  end
end

# Load the real DRExpMonitor (needed for DRSkill.handle_exp_change)
require_relative '../../../../lib/dragonrealms/drinfomon/drexpmonitor'

# Load the module under test
require_relative '../../../../lib/dragonrealms/drinfomon/drskill'

# Force aliases to point to real classes — mock modules from other specs
# (e.g., common_arcana_spec) may have defined these as top-level modules,
# shadowing the real Lich::DragonRealms classes.
%i[DRSkill DRStats DRExpMonitor].each do |name|
  real = Lich::DragonRealms.const_get(name)
  if Object.const_defined?(name) && Object.const_get(name) != real
    Object.send(:remove_const, name)
  end
  Object.const_set(name, real) unless Object.const_defined?(name)
end

RSpec.describe Lich::DragonRealms::DRSkill do
  before(:each) do
    # Reset class state
    DRSkill.class_variable_set(:@@gained_skills, [])
    DRSkill.class_variable_set(:@@list, [])
    DRSkill.class_variable_set(:@@start_time, Time.now)
    Lich.reset_display_expgains!
  end

  describe '.gained_skills' do
    it 'returns empty array initially' do
      expect(DRSkill.gained_skills).to eq([])
    end

    it 'accumulates skill gains' do
      DRSkill.gained_skills << { skill: 'Evasion', change: 2 }
      DRSkill.gained_skills << { skill: 'Parry Ability', change: 1 }

      expect(DRSkill.gained_skills.size).to eq(2)
    end
  end

  describe '.reset' do
    it 'clears gained_skills' do
      DRSkill.gained_skills << { skill: 'Evasion', change: 2 }

      DRSkill.reset

      expect(DRSkill.gained_skills).to eq([])
    end

    it 'resets start_time' do
      old_time = DRSkill.start_time
      sleep 0.01

      DRSkill.reset

      expect(DRSkill.start_time).to be > old_time
    end
  end

  describe '.handle_exp_change' do
    before(:each) do
      # Initialize a skill so getxp works
      DRSkill.new('Evasion', 100, 10, 50)
    end

    context 'when display_expgains is enabled' do
      before do
        Lich.display_expgains = true
      end

      it 'tracks positive exp changes' do
        DRSkill.handle_exp_change('Evasion', 15)

        expect(DRSkill.gained_skills.size).to eq(1)
        expect(DRSkill.gained_skills.first[:skill]).to eq('Evasion')
        expect(DRSkill.gained_skills.first[:change]).to eq(5)
      end

      it 'does not track zero or negative changes' do
        DRSkill.handle_exp_change('Evasion', 10)  # same
        DRSkill.handle_exp_change('Evasion', 5)   # decrease

        expect(DRSkill.gained_skills).to be_empty
      end

      it 'tracks multiple skills' do
        DRSkill.new('Parry Ability', 200, 5, 25)

        DRSkill.handle_exp_change('Evasion', 15)
        DRSkill.handle_exp_change('Parry Ability', 10)

        expect(DRSkill.gained_skills.size).to eq(2)
      end
    end

    context 'when display_expgains is disabled' do
      before do
        Lich.display_expgains = false
      end

      it 'does not track exp changes' do
        DRSkill.handle_exp_change('Evasion', 15)

        expect(DRSkill.gained_skills).to be_empty
      end
    end

    context 'when display_expgains is nil' do
      before do
        Lich.reset_display_expgains!
      end

      it 'does not track exp changes' do
        DRSkill.handle_exp_change('Evasion', 15)

        expect(DRSkill.gained_skills).to be_empty
      end
    end
  end

  describe '.update' do
    before(:each) do
      Lich.display_expgains = true
    end

    it 'creates new skill if not exists' do
      # Disable expgains for this test - tracking gains for a brand new skill
      # doesn't make sense (no baseline to compare against)
      Lich.display_expgains = false
      DRSkill.update('Athletics', 150, 20, 75)

      expect(DRSkill.getrank('Athletics')).to eq(150)
      expect(DRSkill.getxp('Athletics')).to eq(20)
      expect(DRSkill.getpercent('Athletics')).to eq(75)
    end

    it 'updates existing skill' do
      DRSkill.new('Athletics', 150, 20, 75)
      DRSkill.update('Athletics', 151, 5, 10)

      expect(DRSkill.getrank('Athletics')).to eq(151)
      expect(DRSkill.getxp('Athletics')).to eq(5)
      expect(DRSkill.getpercent('Athletics')).to eq(10)
    end

    it 'triggers handle_exp_change' do
      DRSkill.new('Athletics', 150, 10, 75)

      DRSkill.update('Athletics', 150, 15, 75)

      expect(DRSkill.gained_skills.size).to eq(1)
      expect(DRSkill.gained_skills.first[:change]).to eq(5)
    end
  end

  describe '.gained_exp' do
    it 'returns difference between current and baseline' do
      skill = DRSkill.new('Evasion', 100, 10, 50)
      # Baseline is 100.50
      skill.current = 101.25

      result = DRSkill.gained_exp('Evasion')

      expect(result).to eq(0.75)
    end

    it 'returns 0.00 when no gain' do
      DRSkill.new('Evasion', 100, 10, 50)

      result = DRSkill.gained_exp('Evasion')

      expect(result).to eq(0.00)
    end

    it 'returns nil for unknown skill' do
      result = DRSkill.gained_exp('UnknownSkill')

      expect(result).to be_nil
    end
  end

  describe '.getxp' do
    it 'returns current mindstate' do
      DRSkill.new('Evasion', 100, 25, 50)

      expect(DRSkill.getxp('Evasion')).to eq(25)
    end

    it 'caps at 34 for mastered skills (rank >= 1750)' do
      DRSkill.new('Evasion', 1750, 10, 50)

      expect(DRSkill.getxp('Evasion')).to eq(34)
    end
  end

  describe '.getrank' do
    it 'returns current rank' do
      DRSkill.new('Evasion', 500, 10, 75)

      expect(DRSkill.getrank('Evasion')).to eq(500)
    end
  end

  describe '.getpercent' do
    it 'returns percent to next rank' do
      DRSkill.new('Evasion', 500, 10, 75)

      expect(DRSkill.getpercent('Evasion')).to eq(75)
    end
  end

  describe '.lookup_alias' do
    it 'returns skill name when no alias exists' do
      expect(DRSkill.lookup_alias('Evasion')).to eq('Evasion')
    end

    it 'returns aliased name for guild-specific skills' do
      DRStats.guild = 'Barbarian'

      expect(DRSkill.lookup_alias('Primary Magic')).to eq('Inner Fire')
    end
  end

  describe 'skill initialization' do
    it 'calculates baseline correctly' do
      skill = DRSkill.new('Evasion', 100, 10, 50)

      expect(skill.baseline).to eq(100.50)
      expect(skill.current).to eq(100.50)
    end

    it 'looks up skillset' do
      skill = DRSkill.new('Evasion', 100, 10, 50)

      expect(skill.skillset).to eq('Survival')
    end

    it 'does not add duplicate skills to list' do
      DRSkill.new('Evasion', 100, 10, 50)
      DRSkill.new('Evasion', 100, 10, 50)

      expect(DRSkill.list.count { |s| s.name == 'Evasion' }).to eq(1)
    end
  end

  describe '.convert_rexp_str_to_seconds' do
    it 'handles nil' do
      expect(DRSkill.convert_rexp_str_to_seconds(nil)).to eq(0)
    end

    it 'handles "none"' do
      expect(DRSkill.convert_rexp_str_to_seconds('none')).to eq(0)
    end

    it 'handles "less than a minute"' do
      expect(DRSkill.convert_rexp_str_to_seconds('less than a minute')).to eq(0)
    end

    it 'parses minutes' do
      expect(DRSkill.convert_rexp_str_to_seconds('38 minutes')).to eq(38 * 60)
    end

    it 'parses hours with colon format' do
      expect(DRSkill.convert_rexp_str_to_seconds('4:38 hours')).to eq((4 * 60 + 38) * 60)
    end

    it 'parses hours without minutes' do
      expect(DRSkill.convert_rexp_str_to_seconds('6 hours')).to eq(6 * 60 * 60)
    end

    it 'parses hours and minutes separately' do
      expect(DRSkill.convert_rexp_str_to_seconds('2 hours 30 minutes')).to eq((2 * 60 + 30) * 60)
    end
  end
end
