# frozen_string_literal: true

require_relative '../../../spec_helper'

# Load dependencies
require_relative '../../../../lib/dragonrealms/drinfomon/drvariables'
require_relative '../../../../lib/dragonrealms/drinfomon/drskill'

# Stub DRBanking to avoid loading its dependencies
module Lich
  module DragonRealms
    module DRBanking
      def self.parse(_line)
        # No-op stub for testing
      end
    end
  end
end unless defined?(Lich::DragonRealms::DRBanking)

# Stub Account for subscription/account name parsing tests
module Lich
  module Common
    module Account
      @name = nil
      @subscription = nil

      class << self
        attr_accessor :name, :subscription
      end
    end
  end
end unless defined?(Lich::Common::Account)

# Stub UserVars for room parsing (npcs assignment)
module UserVars
  @npcs = []

  class << self
    attr_accessor :npcs
  end
end unless defined?(UserVars)

# Stub top-level helper methods called by DRParser.parse for room parsing.
# These are defined in drdefs.rb and made available at parse-time.
unless respond_to?(:find_pcs, true)
  def find_pcs(_players) = []
  def find_pcs_prone(_players) = []
  def find_pcs_sitting(_players) = []
  def find_npcs(_objs)       = []
  def find_dead_npcs(_objs)  = []
  def find_objects(_objs)    = []
end

# Load the module under test
require_relative '../../../../lib/dragonrealms/drinfomon/drparser'

# Top-level aliases for tests that use unqualified constant names
DRParser = Lich::DragonRealms::DRParser unless defined?(DRParser)
DRRoom = Lich::DragonRealms::DRRoom unless defined?(DRRoom)

RSpec.describe Lich::DragonRealms::DRParser do
  # Use shared context from spec_helper for common DRParser test setup.
  # This extracts ~70 lines of stub setup into a reusable shared context (DRY).
  include_context 'DRParser stubs'

  before(:each) do
    # NOTE: class_variable_set used because DRParser is a production module with no reset! method
    described_class.class_variable_set(:@@parsing_exp_mods_output, false)
    described_class.class_variable_set(:@@parsing_inventory_get, false)
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
        line = "Name: Emerald Knight Mahtra Rotschreck   Race: Elf   Guild: Ranger  "
        match = line.match(described_class::Pattern::NameRaceGuild)
        expect(match).not_to be_nil
        expect(match[:race].strip).to eq('Elf')
        expect(match[:guild].strip).to eq('Ranger')
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
        expect(drstats_class).to receive(:race=).with('Elf')
        expect(drstats_class).to receive(:guild=).with('Ranger')

        line = "Name: Emerald Knight Mahtra Rotschreck   Race: Elf   Guild: Ranger  "
        described_class.parse(line)
      end
    end

    describe 'encumbrance parsing' do
      it 'sets encumbrance from INFO output' do
        expect(drstats_class).to receive(:encumbrance=).with('Light Burden')

        line = "   Encumbrance    :  Light Burden"
        described_class.parse(line)
      end
    end

    describe 'luck parsing' do
      it 'sets luck from INFO output' do
        expect(drstats_class).to receive(:luck=).with(2)

        line = "   Luck           :  Average (2/3)"
        described_class.parse(line)
      end

      it 'handles negative luck' do
        expect(drstats_class).to receive(:luck=).with(-1)

        line = "   Luck           :  Bad (-1/3)"
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
      it 'clears PCs on empty room' do
        line = "'room players'></component>"
        expect(drroom_class).to receive(:pcs=).with([])
        described_class.parse(line)
      end
    end

    describe 'room objects parsing' do
      it 'clears room data on empty room' do
        # RoomObjs pattern matches before RoomObjsEmpty, calling find_* helpers
        # which return [] for empty input, effectively clearing all room data.
        line = "'room objs'></component>"
        expect(drroom_class).to receive(:npcs=)
        expect(drroom_class).to receive(:dead_npcs=)
        expect(drroom_class).to receive(:room_objs=)
        described_class.parse(line)
      end
    end

    describe 'group members parsing' do
      it 'clears group on group header' do
        line = '<pushStream id="group"/>Members of your group:'
        expect(drroom_class).to receive(:group_members=).with([])
        described_class.parse(line)
      end

      it 'adds group member from group stream' do
        # Override the default stub to return a mutable array we can track
        members = []
        allow(drroom_class).to receive(:group_members).and_return(members)

        line = '<pushStream id="group"/>  Mahtra:'
        described_class.parse(line)
        expect(members).to include('Mahtra')
      end
    end

    describe 'account parsing' do
      before do
        # Override shared context stubs FIRST to allow real state changes
        allow(Lich::Common::Account).to receive(:name).and_call_original
        allow(Lich::Common::Account).to receive(:name=).and_call_original
        allow(Lich::Common::Account).to receive(:subscription).and_call_original
        allow(Lich::Common::Account).to receive(:subscription=).and_call_original
        # THEN reset state (must happen after stubs are restored)
        Lich::Common::Account.name = nil
        Lich::Common::Account.subscription = nil
      end

      it 'sets account name' do
        line = "Account Info for TESTACCOUNT:"
        described_class.parse(line)
        expect(Lich::Common::Account.name).to eq('TESTACCOUNT')
      end

      it 'sets subscription type' do
        line = "Current Account Status: Premium"
        described_class.parse(line)
        expect(Lich::Common::Account.subscription).to eq('PREMIUM')
      end

      it 'normalizes Basic to Normal' do
        line = "Current Account Status: Basic"
        described_class.parse(line)
        expect(Lich::Common::Account.subscription).to eq('NORMAL')
      end

      it 'normalizes F2P to Free' do
        line = "Current Account Status: F2P"
        described_class.parse(line)
        expect(Lich::Common::Account.subscription).to eq('FREE')
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

    describe 'nil guards' do
      it 'handles nil players capture group gracefully' do
        # Simulates a malformed room players line where capture fails
        line = "'room players'>Also here: </component>"
        expect { DRParser.parse(line) }.not_to raise_error
      end

      it 'handles nil objs capture group gracefully' do
        # Simulates a malformed room objs line where capture fails
        line = "'room objs'></component>"
        expect { DRParser.parse(line) }.not_to raise_error
        expect(DRRoom.npcs).to eq([])
      end

      it 'skips unrecognized weekday in LastLogoff parsing' do
        # Invalid weekday "Xyz" should not crash
        line = "   Logoff :  Xyz Feb 10 15:30:45 ET 2026"
        expect { DRParser.parse(line) }.not_to raise_error
        # $last_logoff should not be updated for invalid weekday
      end

      it 'handles valid weekday in LastLogoff parsing' do
        line = "   Logoff :  Mon Feb 10 15:30:45 ET 2026"
        expect { DRParser.parse(line) }.not_to raise_error
        expect($last_logoff).to be_a(Time)
        expect($last_logoff.mon).to eq(2)
        # Day may be 10 or 11 depending on timezone conversion to local time
        expect($last_logoff.day).to be_between(9, 11)
      end
    end
  end

  describe '.check_exp_mods' do
    # NOTE: class_variable_set/get is acceptable here because we're testing
    # internal state transitions of the parser. These tests verify the state
    # machine behavior, which requires setting up specific internal states.
    before(:each) do
      described_class.class_variable_set(:@@parsing_exp_mods_output, true)
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

      expect(described_class.class_variable_get(:@@parsing_exp_mods_output)).to be false
    end
  end

  describe '.check_events' do
    it 'matches flags and sets values' do
      flags = {}
      matchers = { test_flag: [/test pattern/] }
      allow(Flags).to receive(:flags).and_return(flags)
      allow(Flags).to receive(:matchers).and_return(matchers)

      described_class.check_events('this is a test pattern here')
      expect(flags[:test_flag]).to be_truthy
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

      it 'sets @@parsing_inventory_get to true' do
        described_class.parse(inv_search_line)

        # NOTE: class_variable_get is acceptable here - we're verifying the parser
        # correctly transitions to inventory parsing state after matching the trigger line.
        expect(described_class.class_variable_get(:@@parsing_inventory_get)).to be true
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
