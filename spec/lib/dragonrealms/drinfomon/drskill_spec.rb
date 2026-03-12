# frozen_string_literal: true

require_relative '../../../spec_helper'

# Load dependencies in correct order
require_relative '../../../../lib/dragonrealms/drinfomon/drvariables'
require_relative '../../../../lib/dragonrealms/drinfomon/drexpmonitor'
require_relative '../../../../lib/dragonrealms/drinfomon/drskill'

RSpec.describe Lich::DragonRealms::DRSkill do
  before(:each) do
    # NOTE: class_variable_set used because DRSkill is a production class with no reset! method
    described_class.class_variable_set(:@@gained_skills, [])
    described_class.class_variable_set(:@@start_time, Time.now)
    described_class.class_variable_set(:@@list, [])
    described_class.class_variable_set(:@@exp_modifiers, {})
    described_class.class_variable_set(:@@rexp_stored, 0)
    described_class.class_variable_set(:@@rexp_usable, 0)
    described_class.class_variable_set(:@@rexp_refresh, 0)
    Lich.reset_display_expgains!
    # Default guild stub - can be overridden per test
    allow(Lich::DragonRealms::DRStats).to receive(:guild).and_return('Warrior Mage')
  end

  describe '.gained_skills' do
    it 'returns empty array initially' do
      expect(described_class.gained_skills).to eq([])
    end

    it 'accumulates skill gains' do
      described_class.gained_skills << { skill: 'Evasion', change: 2 }
      described_class.gained_skills << { skill: 'Parry Ability', change: 1 }

      expect(described_class.gained_skills.size).to eq(2)
    end
  end

  describe '.reset' do
    it 'clears gained_skills' do
      described_class.gained_skills << { skill: 'Evasion', change: 2 }

      described_class.reset

      expect(described_class.gained_skills).to eq([])
    end

    it 'resets start_time to the current time when reset is called' do
      old_time = described_class.start_time
      # Advance the mocked clock so the new start_time is guaranteed to differ.
      # Using allow(Time).to receive(:now) avoids a real sleep and makes the test deterministic.
      future = old_time + 1
      allow(Time).to receive(:now).and_return(future)

      described_class.reset

      expect(described_class.start_time).to eq(future)
    end
  end

  describe '.handle_exp_change' do
    before(:each) do
      # Initialize a skill so getxp works
      described_class.new('Evasion', 100, 10, 50)
    end

    context 'when display_expgains is enabled' do
      before do
        Lich.display_expgains = true
      end

      it 'tracks positive exp changes' do
        described_class.handle_exp_change('Evasion', 15)

        expect(described_class.gained_skills.size).to eq(1)
        expect(described_class.gained_skills.first[:skill]).to eq('Evasion')
        expect(described_class.gained_skills.first[:change]).to eq(5)
      end

      it 'does not track zero or negative changes' do
        described_class.handle_exp_change('Evasion', 10)  # same
        described_class.handle_exp_change('Evasion', 5)   # decrease

        expect(described_class.gained_skills).to be_empty
      end

      it 'tracks multiple skills' do
        described_class.new('Parry Ability', 200, 5, 25)

        described_class.handle_exp_change('Evasion', 15)
        described_class.handle_exp_change('Parry Ability', 10)

        expect(described_class.gained_skills.size).to eq(2)
      end
    end

    context 'when display_expgains is disabled' do
      before do
        Lich.display_expgains = false
      end

      it 'does not track exp changes' do
        described_class.handle_exp_change('Evasion', 15)

        expect(described_class.gained_skills).to be_empty
      end
    end

    context 'when display_expgains is nil' do
      before do
        Lich.reset_display_expgains!
      end

      it 'does not track exp changes' do
        described_class.handle_exp_change('Evasion', 15)

        expect(described_class.gained_skills).to be_empty
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
      described_class.update('Athletics', 150, 20, 75)

      expect(described_class.getrank('Athletics')).to eq(150)
      expect(described_class.getxp('Athletics')).to eq(20)
      expect(described_class.getpercent('Athletics')).to eq(75)
    end

    it 'updates existing skill' do
      described_class.new('Athletics', 150, 20, 75)
      described_class.update('Athletics', 151, 5, 10)

      expect(described_class.getrank('Athletics')).to eq(151)
      expect(described_class.getxp('Athletics')).to eq(5)
      expect(described_class.getpercent('Athletics')).to eq(10)
    end

    it 'triggers handle_exp_change' do
      described_class.new('Athletics', 150, 10, 75)

      described_class.update('Athletics', 150, 15, 75)

      expect(described_class.gained_skills.size).to eq(1)
      expect(described_class.gained_skills.first[:change]).to eq(5)
    end
  end

  describe '.gained_exp' do
    it 'returns difference between current and baseline' do
      skill = described_class.new('Evasion', 100, 10, 50)
      # Baseline is 100.50
      skill.current = 101.25

      result = described_class.gained_exp('Evasion')

      expect(result).to eq(0.75)
    end

    it 'returns 0.00 when no gain' do
      described_class.new('Evasion', 100, 10, 50)

      result = described_class.gained_exp('Evasion')

      expect(result).to eq(0.00)
    end

    it 'returns 0.00 for unknown skill (BUG FIX)' do
      # Previously returned nil, now returns 0.00 for consistency and safety
      result = described_class.gained_exp('UnknownSkill')

      expect(result).to eq(0.00)
    end
  end

  describe '.getxp' do
    it 'returns current mindstate' do
      described_class.new('Evasion', 100, 25, 50)

      expect(described_class.getxp('Evasion')).to eq(25)
    end

    it 'caps at 34 for mastered skills (rank >= 1750)' do
      described_class.new('Evasion', 1750, 10, 50)

      expect(described_class.getxp('Evasion')).to eq(34)
    end
  end

  describe '.getrank' do
    it 'returns current rank' do
      described_class.new('Evasion', 500, 10, 75)

      expect(described_class.getrank('Evasion')).to eq(500)
    end
  end

  describe '.getpercent' do
    it 'returns percent to next rank' do
      described_class.new('Evasion', 500, 10, 75)

      expect(described_class.getpercent('Evasion')).to eq(75)
    end
  end

  describe '.lookup_alias' do
    it 'returns skill name when no alias exists' do
      expect(described_class.lookup_alias('Evasion')).to eq('Evasion')
    end

    it 'returns aliased name for guild-specific skills' do
      allow(Lich::DragonRealms::DRStats).to receive(:guild).and_return('Barbarian')

      expect(described_class.lookup_alias('Primary Magic')).to eq('Inner Fire')
    end

    it 'returns skill unchanged when guild is nil (BUG FIX)' do
      allow(Lich::DragonRealms::DRStats).to receive(:guild).and_return(nil)
      # This would crash with NoMethodError before the .dig() fix
      expect(described_class.lookup_alias('Primary Magic')).to eq('Primary Magic')
    end

    it 'returns skill unchanged when guild not in aliases hash (BUG FIX)' do
      allow(Lich::DragonRealms::DRStats).to receive(:guild).and_return('Commoner')
      # Commoner has no alias entries - would crash before .dig() fix
      expect(described_class.lookup_alias('Primary Magic')).to eq('Primary Magic')
    end
  end

  describe '.getrank nil guard (BUG FIX)' do
    it 'returns 0 for non-existent skill instead of crashing' do
      expect(described_class.getrank('NonExistentSkill')).to eq(0)
    end
  end

  describe '.getpercent nil guard (BUG FIX)' do
    it 'returns 0 for non-existent skill instead of crashing' do
      expect(described_class.getpercent('NonExistentSkill')).to eq(0)
    end
  end

  describe '.getskillset nil guard (BUG FIX)' do
    it 'returns nil for non-existent skill instead of crashing' do
      expect(described_class.getskillset('NonExistentSkill')).to be_nil
    end
  end

  describe '.clear_mind nil guard (BUG FIX)' do
    it 'does not raise for non-existent skill' do
      expect { described_class.clear_mind('NonExistentSkill') }.not_to raise_error
    end
  end

  describe '#lookup_skillset nil guard (BUG FIX)' do
    it 'returns nil for unknown skill without crashing' do
      # Create a skill with an unknown name directly
      skill = described_class.allocate
      result = skill.lookup_skillset('CompletelyUnknownSkill')
      expect(result).to be_nil
    end
  end

  describe 'skill initialization' do
    it 'calculates baseline correctly' do
      skill = described_class.new('Evasion', 100, 10, 50)

      expect(skill.baseline).to eq(100.50)
      expect(skill.current).to eq(100.50)
    end

    it 'looks up and assigns the correct skillset category for the skill name' do
      skill = described_class.new('Evasion', 100, 10, 50)

      expect(skill.skillset).to eq('Survival')
    end

    it 'does not add duplicate skills to list' do
      described_class.new('Evasion', 100, 10, 50)
      described_class.new('Evasion', 100, 10, 50)

      expect(described_class.list.count { |s| s.name == 'Evasion' }).to eq(1)
    end
  end

  describe '.convert_rexp_str_to_seconds' do
    it 'returns 0 seconds when given nil input' do
      expect(described_class.convert_rexp_str_to_seconds(nil)).to eq(0)
    end

    it 'returns 0 seconds when given the string "none"' do
      expect(described_class.convert_rexp_str_to_seconds('none')).to eq(0)
    end

    it 'handles "less than a minute"' do
      expect(described_class.convert_rexp_str_to_seconds('less than a minute')).to eq(0)
    end

    it 'converts a minutes-only string like "38 minutes" to total seconds' do
      expect(described_class.convert_rexp_str_to_seconds('38 minutes')).to eq(38 * 60)
    end

    it 'parses hours with colon format' do
      expect(described_class.convert_rexp_str_to_seconds('4:38 hours')).to eq((4 * 60 + 38) * 60)
    end

    it 'parses hours without minutes' do
      expect(described_class.convert_rexp_str_to_seconds('6 hours')).to eq(6 * 60 * 60)
    end

    it 'parses hours and minutes separately' do
      expect(described_class.convert_rexp_str_to_seconds('2 hours 30 minutes')).to eq((2 * 60 + 30) * 60)
    end
  end
end
