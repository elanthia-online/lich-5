# frozen_string_literal: true

require_relative '../../../spec_helper'

# Load dependencies
require_relative '../../../../lib/dragonrealms/drinfomon/drvariables'
require_relative '../../../../lib/dragonrealms/drinfomon/drskill'

# Load the module under test
require_relative '../../../../lib/dragonrealms/drinfomon/drparser'

RSpec.describe Lich::DragonRealms::DRParser do
  # Reference production classes for stubs
  let(:drstats_class) { Lich::DragonRealms::DRStats }
  let(:drspells_class) { Lich::DragonRealms::DRSpells }
  let(:drroom_class) { Lich::DragonRealms::DRRoom }
  let(:drskill_class) { Lich::DragonRealms::DRSkill }
  let(:drexpmonitor_class) { Lich::DragonRealms::DRExpMonitor }

  before(:each) do
    described_class.instance_variable_set(:@parsing_exp_mods_output, false)
    described_class.instance_variable_set(:@parsing_inventory_get, false)

    # Stub DRStats setters
    allow(drstats_class).to receive(:gender=)
    allow(drstats_class).to receive(:age=)
    allow(drstats_class).to receive(:circle=)
    allow(drstats_class).to receive(:race=)
    allow(drstats_class).to receive(:guild=)
    allow(drstats_class).to receive(:encumbrance=)
    allow(drstats_class).to receive(:luck=)
    allow(drstats_class).to receive(:tdps=)
    allow(drstats_class).to receive(:favors=)
    allow(drstats_class).to receive(:balance=)
    allow(drstats_class).to receive(:strength=)
    allow(drstats_class).to receive(:agility=)
    allow(drstats_class).to receive(:discipline=)
    allow(drstats_class).to receive(:intelligence=)
    allow(drstats_class).to receive(:reflex=)
    allow(drstats_class).to receive(:charisma=)
    allow(drstats_class).to receive(:wisdom=)
    allow(drstats_class).to receive(:stamina=)

    # Stub DRSpells
    allow(drspells_class).to receive(:grabbing_known_spells).and_return(false)
    allow(drspells_class).to receive(:grabbing_known_spells=)
    allow(drspells_class).to receive(:grabbing_known_khri).and_return(false)
    allow(drspells_class).to receive(:grabbing_known_khri=)
    allow(drspells_class).to receive(:check_known_barbarian_abilities).and_return(false)
    allow(drspells_class).to receive(:check_known_barbarian_abilities=)

    # Stub DRRoom
    allow(drroom_class).to receive(:pcs).and_return([])
    allow(drroom_class).to receive(:pcs=)
    allow(drroom_class).to receive(:pcs_prone).and_return([])
    allow(drroom_class).to receive(:pcs_prone=)
    allow(drroom_class).to receive(:pcs_sitting).and_return([])
    allow(drroom_class).to receive(:pcs_sitting=)
    allow(drroom_class).to receive(:npcs).and_return([])
    allow(drroom_class).to receive(:npcs=)
    allow(drroom_class).to receive(:dead_npcs).and_return([])
    allow(drroom_class).to receive(:dead_npcs=)
    allow(drroom_class).to receive(:room_objs).and_return([])
    allow(drroom_class).to receive(:room_objs=)
    allow(drroom_class).to receive(:group_members).and_return([])
    allow(drroom_class).to receive(:group_members=)

    # Stub DRSkill
    allow(drskill_class).to receive(:update)
    allow(drskill_class).to receive(:clear_mind)
    allow(drskill_class).to receive(:update_mods)
    allow(drskill_class).to receive(:update_rested_exp)
    allow(drskill_class).to receive(:exp_modifiers).and_return({})

    # Stub DRExpMonitor
    allow(drexpmonitor_class).to receive(:inline_display?).and_return(false)
    allow(drexpmonitor_class).to receive(:format_briefexp_on) { |line, _skill| line }
    allow(drexpmonitor_class).to receive(:format_briefexp_off) { |line, _skill, _rate| line }

    # Stub Lich::Common::Account
    allow(Lich::Common::Account).to receive(:name=) if defined?(Lich::Common::Account)
    allow(Lich::Common::Account).to receive(:subscription=) if defined?(Lich::Common::Account)

    # Stub Flags
    allow(Flags).to receive(:flags).and_return({})
    allow(Flags).to receive(:matchers).and_return({})

    # Stub XMLData
    allow(XMLData).to receive(:game).and_return('DR')
  end

  describe 'Pattern constants' do
    describe 'GenderAgeCircle' do
      it 'matches gender/age/circle line from INFO' do
        line = "Gender:  Male         Age:  42              Circle:  150"
        match = line.match(described_class::Pattern::GenderAgeCircle)
        expect(match).not_to be_nil
        expect(match[:gender].strip).to eq('Male')
        expect(match[:age].to_i).to eq(42)
        expect(match[:circle].to_i).to eq(150)
      end
    end

    describe 'NameRaceGuild' do
      it 'matches name/race/guild line from INFO' do
        line = "Name:  Mahtra Lansen             Race:  Elothean         Guild:  Moon Mage  "
        match = line.match(described_class::Pattern::NameRaceGuild)
        expect(match).not_to be_nil
        expect(match[:race].strip).to eq('Elothean')
        expect(match[:guild].strip).to eq('Moon Mage')
      end
    end

    describe 'TDPValue' do
      it 'matches TDP line using named capture' do
        line = "You have 1234 TDPs."
        match = line.match(described_class::Pattern::TDPValue)
        expect(match).not_to be_nil
        expect(match[:tdp].to_i).to eq(1234)
      end
    end

    describe 'RoomPlayers' do
      it 'matches room players with named capture' do
        line = "'room players'>Also here: Mahtra and Quilsilgas.</component>"
        match = line.match(described_class::Pattern::RoomPlayers)
        expect(match).not_to be_nil
        expect(match[:players]).to eq('Mahtra and Quilsilgas')
      end
    end

    describe 'RoomObjs' do
      it 'matches room objects with named capture' do
        line = "'room objs'>You also see a <pushBold/>goblin<popBold/>.</component>"
        match = line.match(described_class::Pattern::RoomObjs)
        expect(match).not_to be_nil
        expect(match[:objs]).to include('goblin')
      end
    end

    describe 'GroupMembers' do
      it 'matches group member with named capture' do
        line = '<pushStream id="group"/>  Mahtra:'
        match = line.match(described_class::Pattern::GroupMembers)
        expect(match).not_to be_nil
        expect(match[:member]).to eq('Mahtra')
      end
    end

    describe 'ExpModLine' do
      it 'matches positive modifier' do
        line = '<preset id="speech">+79 Attunement</preset>'
        match = line.strip.match(described_class::Pattern::ExpModLine)
        expect(match).not_to be_nil
        expect(match[:sign]).to eq('+')
        expect(match[:value]).to eq('79')
        expect(match[:skill].strip).to eq('Attunement')
      end

      it 'matches negative modifier' do
        line = '<preset id="thought">--10 Evasion</preset>'
        match = line.strip.match(described_class::Pattern::ExpModLine)
        expect(match).not_to be_nil
        expect(match[:sign]).to eq('--')
        expect(match[:value]).to eq('10')
        expect(match[:skill].strip).to eq('Evasion')
      end
    end

    describe 'PlayedSubscription' do
      it 'matches subscription types' do
        %w[F2P Basic Premium Platinum].each do |sub|
          line = "Current Account Status: #{sub}"
          match = line.match(described_class::Pattern::PlayedSubscription)
          expect(match).not_to be_nil
          expect(match[:subscription]).to eq(sub)
        end
      end
    end

    describe 'LastLogoff' do
      it 'matches logoff timestamp' do
        line = "   Logoff :  Mon Feb 10 15:30:45 ET 2026"
        match = line.match(described_class::Pattern::LastLogoff)
        expect(match).not_to be_nil
        expect(match[:weekday]).to eq('Mon')
        expect(match[:month]).to eq('Feb')
        expect(match[:day].strip).to eq('10')
        expect(match[:hour]).to eq('15')
        expect(match[:minute]).to eq('30')
        expect(match[:second]).to eq('45')
        expect(match[:year]).to eq('2026')
      end
    end

    describe 'Rested_EXP' do
      it 'matches rested exp display' do
        line = "<component id='exp rexp'>Rested EXP Stored:  4:38 hours  Usable This Cycle:  38 minutes  Cycle Refreshes:  2 hours</component>"
        match = line.match(described_class::Pattern::Rested_EXP)
        expect(match).not_to be_nil
        expect(match[:stored].strip).to eq('4:38 hours')
        expect(match[:usable].strip).to eq('38 minutes')
        expect(match[:refresh].strip).to eq('2 hours')
      end
    end

    describe 'BriefExpOn' do
      it 'matches BRIEFEXP ON format' do
        line = "<component id='exp Evasion'><d cmd='skill Evasion'>     Eva:  565 39%  [ 2/34]</d></component>"
        match = line.match(described_class::Pattern::BriefExpOn)
        expect(match).not_to be_nil
        expect(match[:skill]).to eq('Evasion')
        expect(match[:rank]).to eq('565')
        expect(match[:percent]).to eq('39')
        expect(match[:rate]).to eq('2')
      end
    end

    describe 'BriefExpOff' do
      it 'matches BRIEFEXP OFF format' do
        line = "<component id='exp Evasion'>    Evasion:  565 39% learning     </component>"
        match = line.match(described_class::Pattern::BriefExpOff)
        expect(match).not_to be_nil
        expect(match[:skill].strip).to eq('Evasion')
        expect(match[:rank]).to eq('565')
        expect(match[:percent]).to eq('39')
        expect(match[:rate].strip).to eq('learning')
      end
    end
  end

  describe '.parse' do
    describe 'gender/age/circle parsing' do
      it 'sets DRStats values from INFO output' do
        # Real code strips whitespace
        expect(drstats_class).to receive(:gender=).with('Female')
        expect(drstats_class).to receive(:age=).with(25)
        expect(drstats_class).to receive(:circle=).with(100)

        line = "Gender:  Female       Age:  25              Circle:  100"
        described_class.parse(line)
      end
    end

    describe 'name/race/guild parsing' do
      it 'sets DRStats values from INFO output' do
        # Real code strips whitespace
        expect(drstats_class).to receive(:race=).with('Elothean')
        expect(drstats_class).to receive(:guild=).with('Moon Mage')

        line = "Name:  Mahtra Lansen             Race:  Elothean         Guild:  Moon Mage  "
        described_class.parse(line)
      end
    end

    describe 'TDP parsing' do
      it 'sets TDPs from INFO output' do
        expect(drstats_class).to receive(:tdps=).with(5000)

        line = "You have 5000 TDPs."
        described_class.parse(line)
      end

      it 'sets TDPs from exp window' do
        expect(drstats_class).to receive(:tdps=).with(1234)

        line = "<component id='exp tdp'>  TDPs:  1234</component>"
        described_class.parse(line)
      end
    end

    describe 'favor parsing' do
      it 'sets favors from exp window' do
        expect(drstats_class).to receive(:favors=).with(7)

        line = "<component id='exp favor'>  Favors:  7</component>"
        described_class.parse(line)
      end
    end

    describe 'room players parsing' do
      it 'parses empty room without error' do
        line = "'room players'></component>"
        expect { described_class.parse(line) }.not_to raise_error
      end
    end

    describe 'room objects parsing' do
      it 'parses empty room without error' do
        line = "'room objs'></component>"
        expect { described_class.parse(line) }.not_to raise_error
      end
    end

    describe 'group members parsing' do
      it 'parses group header without error' do
        line = '<pushStream id="group"/>Members of your group:'
        expect { described_class.parse(line) }.not_to raise_error
      end

      it 'parses group member without error' do
        line = '<pushStream id="group"/>  Mahtra:'
        expect { described_class.parse(line) }.not_to raise_error
      end
    end

    describe 'rested exp parsing' do
      it 'calls update_rested_exp with parsed values' do
        expect(drskill_class).to receive(:update_rested_exp).with('4:38 hours', '38 minutes', '2 hours')

        line = "<component id='exp rexp'>Rested EXP Stored:  4:38 hours  Usable This Cycle:  38 minutes  Cycle Refreshes:  2 hours</component>"
        described_class.parse(line)
      end

      it 'handles F2P rested exp' do
        expect(drskill_class).to receive(:update_rested_exp).with('none', 'none', 'none')

        line = "<component id='exp rexp'>[Unlock Rested Experience"
        described_class.parse(line)
      end
    end

    describe 'RoomID warning' do
      it 'sends warning message when RoomID is turned off' do
        expect(Lich::Messaging).to receive(:msg).with("bold", /DRParser:.*ShowRoomID/)
        expect(Lich::Messaging).to receive(:msg).with("plain", /DRParser:.*flaguid/)

        line = "You will no longer see room IDs when LOOKing in the game and room windows."
        described_class.parse(line)
      end
    end

    describe 'error handling' do
      it 'catches and logs errors without crashing' do
        allow(drstats_class).to receive(:gender=).and_raise(StandardError.new("Test error"))
        expect(Lich::Messaging).to receive(:msg).with("bold", /DRParser:.*error/)
        expect(Lich::Messaging).to receive(:msg).with("bold", /DRParser:.*line/)
        expect(Lich).to receive(:log).at_least(:once)

        line = "Gender:  Male         Age:  42              Circle:  150"
        expect { described_class.parse(line) }.not_to raise_error
      end
    end
  end

  describe '.check_exp_mods' do
    before(:each) do
      described_class.instance_variable_set(:@parsing_exp_mods_output, true)
      allow(drskill_class).to receive(:exp_modifiers).and_return({})
    end

    it 'parses positive modifier' do
      expect(drskill_class).to receive(:update_mods).with('Attunement', 79)

      line = '<preset id="speech">+79 Attunement</preset>'
      described_class.check_exp_mods(line)
    end

    it 'parses negative modifier' do
      expect(drskill_class).to receive(:update_mods).with('Evasion', -10)

      line = '<preset id="thought">--10 Evasion</preset>'
      described_class.check_exp_mods(line)
    end

    it 'stops parsing on output class end tag' do
      described_class.check_exp_mods('<output class=""/>')

      expect(described_class.instance_variable_get(:@parsing_exp_mods_output)).to be false
    end
  end

  describe '.check_events' do
    it 'processes events without error' do
      # The check_events method iterates over Flags.matchers and sets matching flags
      # This test verifies the method can be called without error
      expect { described_class.check_events('this is a test pattern here') }.not_to raise_error
    end
  end

  describe 'inventory search parsing' do
    before(:each) do
      allow(GameObj).to receive(:clear_inv)
      allow(GameObj).to receive(:clear_all_containers)
    end

    describe 'when InventoryGetStart pattern matches' do
      let(:inv_search_line) { 'You rummage about your person, looking for' }

      it 'calls GameObj.clear_inv' do
        expect(GameObj).to receive(:clear_inv)

        described_class.parse(inv_search_line)
      end

      it 'calls GameObj.clear_all_containers' do
        expect(GameObj).to receive(:clear_all_containers)

        described_class.parse(inv_search_line)
      end

      it 'sets @parsing_inventory_get to true' do
        described_class.parse(inv_search_line)

        expect(described_class.instance_variable_get(:@parsing_inventory_get)).to be true
      end
    end

    describe 'InventoryGetStart pattern' do
      it 'matches inv search command output' do
        line = 'You rummage about your person, looking for'
        expect(line).to match(described_class::Pattern::InventoryGetStart)
      end

      it 'matches partial inv search output' do
        line = 'You rummage about your person, looking for all items'
        expect(line).to match(described_class::Pattern::InventoryGetStart)
      end
    end
  end
end
