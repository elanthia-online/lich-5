# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'ox' # populate_inventory_get parses <d> fragments via Ox (loaded by lich.rbw in production)

# Load dependencies
require_relative '../../../../lib/dragonrealms/drinfomon/drvariables'
require_relative '../../../../lib/dragonrealms/drinfomon/drskill'
# The doubly-nested regression below drives the REAL GameObj (no new_inv mock)
# so it observes the actual container contents. spec_helper installs a
# lightweight GameObj double; requiring the production file reopens it with the
# real implementation. This is idempotent -- in the combined suite gameobj_spec
# has already loaded it -- and mirrors how gameobj_spec obtains the real class.
require_relative '../../../../lib/common/gameobj'

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
    described_class.class_variable_set(:@@shutdown_at, nil)
  end

  describe 'game shutdown tracking' do
    it 'reports no shutdown initially' do
      expect(described_class.shutting_down?).to be false
      expect(described_class.shutdown_minutes).to be_nil
    end

    it 'records a pending shutdown from a notice line' do
      described_class.check_game_shutdown('DragonRealms will be shutting down in 15 minutes for routine maintenance.')
      expect(described_class.shutting_down?).to be true
      expect(described_class.shutdown_minutes).to eq(15)
    end

    it 'recomputes the estimate as the warnings count down' do
      described_class.check_game_shutdown('DragonRealms will be shutting down in 15 minutes for routine maintenance.')
      described_class.check_game_shutdown('DragonRealms will be shutting down in 1 minute for routine maintenance.')
      expect(described_class.shutdown_minutes).to eq(1)
    end

    it 'ignores lines that are not shutdown notices' do
      described_class.check_game_shutdown('You glance around the room.')
      expect(described_class.shutting_down?).to be false
    end

    it 'never reports negative minutes once the target time passes' do
      described_class.class_variable_set(:@@shutdown_at, Time.now - 120)
      expect(described_class.shutdown_minutes).to eq(0)
    end
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

    describe 'GameShutdown' do
      # Real announcement lines captured from a routine maintenance shutdown.
      {
        15 => 'DragonRealms will be shutting down in 15 minutes for routine maintenance.  Please be sure to gather your things and be prepared to exit the game at that time.',
        10 => 'DragonRealms will be shutting down in 10 minutes for routine maintenance.  Please be sure to gather your things and be prepared to exit the game at that time.',
        5  => 'DragonRealms will be shutting down in 5 minutes for routine maintenance.  Please gather your things and exit the game as soon as possible.',
        2  => 'DragonRealms will be shutting down in 2 minutes for routine maintenance.  Please gather your things and exit the game as soon as possible.',
        1  => 'DragonRealms will be shutting down in 1 minute for routine maintenance.  Please gather your things and exit the game as soon as possible.'
      }.each do |minutes, line|
        it "captures #{minutes} from the #{minutes}-minute notice" do
          match = line.match(described_class::Pattern::GameShutdown)
          expect(match).not_to be_nil
          expect(match[:minutes].to_i).to eq(minutes)
        end
      end

      it 'matches even with an Announcement prefix' do
        line = 'Announcement: DragonRealms will be shutting down in 1 minute for routine maintenance.'
        match = line.match(described_class::Pattern::GameShutdown)
        expect(match[:minutes].to_i).to eq(1)
      end

      it 'does not match unrelated lines' do
        expect('You glance around the room.'.match(described_class::Pattern::GameShutdown)).to be_nil
      end

      it 'does not match the phrase quoted mid-line (chat/speech)' do
        line = 'Someone says, "DragonRealms will be shutting down in 5 minutes, lol."'
        expect(line.match(described_class::Pattern::GameShutdown)).to be_nil
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

    describe 'BalanceValue' do
      it 'matches a standalone balance line' do
        line = "You are solidly balanced."
        match = line.match(described_class::Pattern::BalanceValue)
        expect(match).not_to be_nil
        expect(match[:balance]).to eq('solidly')
      end

      it 'matches a bracketed balance line' do
        line = "[You're adeptly balanced]"
        match = line.match(described_class::Pattern::BalanceValue)
        expect(match).not_to be_nil
        expect(match[:balance]).to eq('adeptly')
      end

      it 'matches a balance line preceded by wound and condition status' do
        line = "[You're battered (71%), winded (100%), mighty (100%), incredibly balanced and in dominating position.]"
        match = line.match(described_class::Pattern::BalanceValue)
        expect(match).not_to be_nil
        expect(match[:balance]).to eq('incredibly')
      end

      it 'matches the "off balance" form without a trailing d' do
        line = "[You're battered (73%), winded (100%), off balance with opponent dominating.]"
        match = line.match(described_class::Pattern::BalanceValue)
        expect(match).not_to be_nil
        expect(match[:balance]).to eq('off')
      end

      it 'captures the full multi-word balance value rather than a substring' do
        # "slightly off" must not be truncated to "off"; "somewhat off" likewise.
        {
          "[You're battered (70%), winded (97%), slightly off balance and in strong position.]" => 'slightly off',
          "[You're somewhat off balance.]"                                                      => 'somewhat off',
          "[You're very badly balanced with opponent overwhelming you.]"                        => 'very badly'
        }.each do |line, expected|
          match = line.match(described_class::Pattern::BalanceValue)
          expect(match).not_to be_nil, "expected #{line.inspect} to match"
          expect(match[:balance]).to eq(expected)
        end
      end
    end

    describe 'PositionValue' do
      it 'captures the "and" position clause' do
        line = "[You're solidly balanced and in good position.]"
        match = line.match(described_class::Pattern::PositionValue)
        expect(match).not_to be_nil
        expect(match[:position]).to eq('in good position')
      end

      it 'captures the "with" position clause' do
        line = "[You're badly balanced with opponent dominating.]"
        match = line.match(described_class::Pattern::PositionValue)
        expect(match).not_to be_nil
        expect(match[:position]).to eq('opponent dominating')
      end

      it 'captures the neutral "no advantage" clause' do
        line = "[You're nimbly balanced with no advantage.]"
        match = line.match(described_class::Pattern::PositionValue)
        expect(match).not_to be_nil
        expect(match[:position]).to eq('no advantage')
      end

      it 'captures both "overwhelming opponent" phrasings' do
        {
          "[You're incredibly balanced and overwhelming opponent.]"      => 'overwhelming opponent',
          "[You're incredibly balanced and overwhelming your opponent.]" => 'overwhelming your opponent'
        }.each do |line, expected|
          match = line.match(described_class::Pattern::PositionValue)
          expect(match).not_to be_nil, "expected #{line.inspect} to match"
          expect(match[:position]).to eq(expected)
        end
      end

      it 'captures the full multi-word position rather than a substring' do
        line = "[You're solidly balanced and in very strong position.]"
        match = line.match(described_class::Pattern::PositionValue)
        expect(match).not_to be_nil
        expect(match[:position]).to eq('in very strong position')
      end
    end
  end

  describe '.parse' do
    describe 'balance parsing' do
      it 'sets balance index from a combat-status line' do
        # 'incredibly' is the last entry in DR_BALANCE_VALUES
        expected_index = Lich::DragonRealms::DR_BALANCE_VALUES.index('incredibly')
        expect(drstats_class).to receive(:balance=).with(expected_index)

        line = "[You're battered (71%), winded (100%), mighty (100%), incredibly balanced and in dominating position.]"
        described_class.parse(line)
      end

      it 'sets both balance and position from a combat-status line' do
        expect(drstats_class).to receive(:balance=).with(Lich::DragonRealms::DR_BALANCE_VALUES.index('solidly'))
        expect(drstats_class).to receive(:position=).with(-1)

        line = "[You're bruised, solidly balanced and opponent has slight advantage.]"
        described_class.parse(line)
      end

      it 'sets a positive position when winning' do
        expect(drstats_class).to receive(:position=).with(8)

        line = "[You're incredibly balanced and in dominating position.]"
        described_class.parse(line)
      end

      it 'maps "overwhelming your opponent" to the maximum position' do
        expect(drstats_class).to receive(:position=).with(9)

        line = "[You're incredibly balanced and overwhelming your opponent.]"
        described_class.parse(line)
      end

      it 'sets a neutral position for "no advantage"' do
        expect(drstats_class).to receive(:position=).with(0)

        line = "[You're nimbly balanced with no advantage.]"
        described_class.parse(line)
      end

      it 'does not set position for a bare balance line' do
        expect(drstats_class).not_to receive(:position=)

        line = "You are solidly balanced."
        described_class.parse(line)
      end
    end

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

    describe 'RoomID toggle (no longer enforced)' do
      it 'ignores the "no longer see room IDs" line without warning or re-enabling the flag' do
        # Room UIDs now come from the <nav> tag regardless of the ShowRoomID flag, so turning
        # it off is a valid player choice: Lich must neither nag nor send a command to force
        # the flag back on (the old handler ran put("flag showroomid on")).
        expect(Lich::Messaging).not_to receive(:msg)
        expect(described_class).not_to receive(:put)

        line = "You will no longer see room IDs when LOOKing in the game and room windows."
        expect { described_class.parse(line) }.not_to raise_error
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

  describe 'inventory scrape parsing' do
    before(:each) do
      allow(GameObj).to receive(:clear_inv)
      allow(GameObj).to receive(:clear_all_containers)
      described_class.class_variable_set(:@@parsing_inventory_get, false)
      described_class.class_variable_set(:@@inventory_partial, false)
    end

    describe 'headers' do
      it 'InventoryListStart matches the INV LIST header only' do
        expect('You take a moment and rummage about your person, taking stock of your possessions...')
          .to match(described_class::Pattern::InventoryListStart)
        expect('You rummage about your person, looking for pouch...')
          .not_to match(described_class::Pattern::InventoryListStart)
      end

      it 'InventorySearchStart matches the INV SEARCH / category header' do
        expect('You rummage about your person, looking for pouch...')
          .to match(described_class::Pattern::InventorySearchStart)
        expect('You rummage about your person, looking for armor and shields...')
          .to match(described_class::Pattern::InventorySearchStart)
      end

      it 'InventorySearchStart matches the real <roundTime/>-prefixed header' do
        expect("<roundTime value='1788496743'/>You rummage about your person, looking for pouch...")
          .to match(described_class::Pattern::InventorySearchStart)
      end

      # Adversarial: a header quoted mid-line (speech/thought/book) must NOT open
      # a scrape -- for the SEARCH header this would open a *mutating* upsert.
      # This is why both patterns are anchored to the stream-line start.
      it 'neither header matches the phrase quoted mid-line in speech' do
        line = %(Someone says, "You rummage about your person, looking for trouble.")
        expect(line).not_to match(described_class::Pattern::InventorySearchStart)
        expect(line).not_to match(described_class::Pattern::InventoryListStart)
      end

      it 'neither header matches the phrase embedded after prose' do
        line = 'She watched as you take a moment and rummage about your person, taking stock of your possessions.'
        expect(line).not_to match(described_class::Pattern::InventoryListStart)
      end

      it 'does NOT match an arbitrary non-roundTime tag glued before the search header' do
        expect("<pushStream id='thought'/>You rummage about your person, looking for pouch...")
          .not_to match(described_class::Pattern::InventorySearchStart)
      end
    end

    describe 'when the INV LIST (complete) header matches' do
      let(:inv_list_line) { 'You take a moment and rummage about your person, taking stock of your possessions...' }

      it 'clears inv and containers, enters parsing, and is NOT partial' do
        expect(GameObj).to receive(:clear_inv)
        expect(GameObj).to receive(:clear_all_containers)

        described_class.parse(inv_list_line)

        # NOTE: class_variable_get is acceptable here - we're verifying the parser
        # correctly transitions to inventory parsing state after the trigger line.
        expect(described_class.class_variable_get(:@@parsing_inventory_get)).to be true
        expect(described_class.class_variable_get(:@@inventory_partial)).to be false
      end
    end

    describe 'when the INV SEARCH (partial) header matches' do
      let(:inv_search_line) { 'You rummage about your person, looking for pouch...' }

      it 'enters parsing in partial mode WITHOUT clearing the model' do
        expect(GameObj).not_to receive(:clear_inv)
        expect(GameObj).not_to receive(:clear_all_containers)

        described_class.parse(inv_search_line)

        expect(described_class.class_variable_get(:@@parsing_inventory_get)).to be true
        expect(described_class.class_variable_get(:@@inventory_partial)).to be true
      end
    end

    describe 'scrape safety valve (interrupted stream)' do
      it 'resets an unclosed scrape on the next <prompt> so later <d cmd> links are not hijacked' do
        described_class.parse('You take a moment and rummage about your person, taking stock of your possessions...')
        expect(described_class.class_variable_get(:@@parsing_inventory_get)).to be true

        # Stream is interrupted -- no <output class=""/> arrives, just a prompt.
        described_class.parse('<prompt time="123">&gt;</prompt>')

        expect(described_class.class_variable_get(:@@parsing_inventory_get)).to be false

        # A later stray get-link in ordinary output must NOT be parsed as inventory.
        expect(GameObj).not_to receive(:new_inv)
        described_class.parse("<d cmd='get #999'>a random link</d>")
      end

      it 'also clears PARTIAL mode when a prompt ends an interrupted search scrape' do
        described_class.parse("<roundTime value='1'/>You rummage about your person, looking for pouch...")
        expect(described_class.class_variable_get(:@@inventory_partial)).to be true

        described_class.parse('<prompt time="123">&gt;</prompt>')

        expect(described_class.class_variable_get(:@@parsing_inventory_get)).to be false
        expect(described_class.class_variable_get(:@@inventory_partial)).to be false

        # A stray get-link afterward must NOT be upserted into the live model.
        expect(GameObj).not_to receive(:upsert_inv)
        described_class.parse("<d cmd='get #999'>a random link</d>")
      end
    end
  end

  describe '.parse additional state' do
    describe 'stat values' do
      it 'sets multiple stats scanned from a single INFO line' do
        expect(drstats_class).to receive(:intelligence=).with(80)
        expect(drstats_class).to receive(:wisdom=).with(90)
        described_class.parse('Intelligence    :   80   Wisdom          :   90')
      end
    end

    describe 'balance' do
      it 'sets the balance index from a balance line' do
        expect(drstats_class).to receive(:balance=).with(0)
        described_class.parse('You are completely balanced.')
      end
    end

    describe 'mindstate clear' do
      it 'clears the mind for a skill on an empty exp component' do
        expect(drskill_class).to receive(:clear_mind).with('Evasion')
        described_class.parse("<component id='exp Evasion'></component>")
      end
    end

    describe 'exp columns' do
      it 'updates a skill from a plain-text exp column line' do
        expect(drskill_class).to receive(:update).with(a_string_matching(/Evasion/), '565', anything, '39')
        described_class.parse('         Evasion:  565 39% thoughtful')
      end
    end

    describe 'brief exp' do
      it 'updates skill and rate from BRIEFEXP ON output' do
        expect(drskill_class).to receive(:update).with('Evasion', 565, '2', '39')
        described_class.parse("<component id='exp Evasion'><d cmd='skill Evasion'>     Eva:  565 39%  [ 2/34]</d></component>")
      end
    end

    describe 'spellbook format toggle' do
      it 'sets the spellbook format from the SPELLS verb toggle' do
        drspells_class.reset!
        described_class.parse('You will see column-formatted output for the SPELLS verb.')
        expect(drspells_class.spellbook_format).to eq('column-formatted')
      end
    end

    describe 'spell-list capture triggers' do
      it 'starts grabbing known spells' do
        expect(drspells_class).to receive(:grabbing_known_spells=).with(true)
        described_class.parse('You recall the spells you have learned from your training.')
      end

      it 'starts grabbing barbarian abilities' do
        expect(drspells_class).to receive(:check_known_barbarian_abilities=).with(true)
        described_class.parse('You know the Berserks: Avalanche, Drought.')
      end

      it 'starts grabbing thief khri' do
        expect(drspells_class).to receive(:grabbing_known_khri=).with(true)
        described_class.parse('From the Subtlety tree, you know the following khri: Darken (Aug)')
      end
    end

    describe 'subscription premium normalization' do
      before do
        allow(Lich::Common::Account).to receive(:subscription).and_call_original
        allow(Lich::Common::Account).to receive(:subscription=).and_call_original
        Lich::Common::Account.subscription = nil
      end

      it 'normalizes Platinum to Premium' do
        described_class.parse('Current Account Status: Platinum')
        expect(Lich::Common::Account.subscription).to eq('PREMIUM')
      end
    end
  end

  describe '.check_known_spells' do
    before do
      drspells_class.reset!
      allow(drspells_class).to receive(:grabbing_known_spells).and_return(true)
    end

    it 'detects column-formatted output from the mono tag' do
      described_class.check_known_spells('<output class="mono"/>')
      expect(drspells_class.spellbook_format).to eq('column-formatted')
    end

    it 'parses a spell name from column-formatted slot info' do
      drspells_class.spellbook_format = 'column-formatted'
      line = '<popBold/>     maf  Manifest Force                  Slot(s): 1   Min Prep: 1     Max Prep: 100'
      described_class.check_known_spells(line)
      expect(drspells_class.known_spells).to include('Manifest Force' => true)
    end

    it 'parses spells from a non-column chapter line' do
      line = 'In the chapter entitled "Analogous Patterns", you have notes on the Manifest Force [maf] and Gauge Flow [gaf] spells.'
      described_class.check_known_spells(line)
      expect(drspells_class.known_spells).to include('Manifest Force' => true, 'Gauge Flow' => true)
    end

    it 'parses magic feats, splitting the non-Oxford "and"' do
      line = 'You recall proficiency with the magic feats of Sorcerous Patterns, Alternate Preparation and Augmentation Mastery.'
      described_class.check_known_spells(line)
      expect(drspells_class.known_feats).to include('Sorcerous Patterns' => true, 'Alternate Preparation' => true, 'Augmentation Mastery' => true)
    end

    it 'stops grabbing on the spells-end line' do
      expect(drspells_class).to receive(:grabbing_known_spells=).with(false)
      described_class.check_known_spells('You can use SPELL STANCE [HELP] to view or modify your spellcasting preferences.')
    end
  end

  describe '.check_known_barbarian_abilities' do
    before do
      drspells_class.reset!
      allow(drspells_class).to receive(:check_known_barbarian_abilities).and_return(true)
    end

    it 'parses known berserks into known_spells' do
      described_class.check_known_barbarian_abilities('You know the Berserks:<pushBold/> Avalanche, Drought.')
      expect(drspells_class.known_spells).to include('Avalanche' => true, 'Drought' => true)
    end

    it 'parses known masteries into known_feats' do
      described_class.check_known_barbarian_abilities('<popBold/>You know the Masteries:<pushBold/> Juggernaut, Duelist.')
      expect(drspells_class.known_feats).to include('Juggernaut' => true, 'Duelist' => true)
    end

    it 'stops on the training-remaining line' do
      expect(drspells_class).to receive(:check_known_barbarian_abilities=).with(false)
      described_class.check_known_barbarian_abilities('You recall that you have 0 training sessions remaining with the Guild.')
    end
  end

  describe '.check_known_thief_khri' do
    before do
      drspells_class.reset!
      allow(drspells_class).to receive(:grabbing_known_khri).and_return(true)
    end

    it 'parses khri names, stripping the type annotations' do
      line = 'From the Subtlety tree, you know the following khri: Darken (Aug), Dampen (Util/Ward), Strike (Aug)'
      described_class.check_known_thief_khri(line)
      expect(drspells_class.known_spells).to include('Darken' => true, 'Dampen' => true, 'Strike' => true)
    end

    it 'stops on the available-slots line' do
      expect(drspells_class).to receive(:grabbing_known_khri=).with(false)
      described_class.check_known_thief_khri('You have 7 available slots.')
    end
  end

  describe '.populate_inventory_get' do
    before(:each) do
      allow(GameObj).to receive(:new_inv)
      allow(GameObj).to receive(:upsert_inv)
      described_class.class_variable_set(:@@parsing_inventory_get, true)
      # Default to COMPLETE (INV LIST) mode for the existing add cases.
      described_class.class_variable_set(:@@inventory_partial, false)
    end

    it 'parses a top-level item, stripping a leading article' do
      expect(GameObj).to receive(:new_inv).with('12345', nil, 'small pouch', nil, 'get #12345', nil)
      described_class.populate_inventory_get("<d cmd='get #12345'>a small pouch</d>")
    end

    it 'strips a capitalized leading article (e.g. from INV SEARCH output)' do
      expect(GameObj).to receive(:new_inv).with('12345', nil, 'soft gem pouch', nil, 'get #12345', nil)
      described_class.populate_inventory_get("<d cmd='get #12345'>A soft gem pouch</d>")
    end

    it 'parses a nested item with its container' do
      expect(GameObj).to receive(:new_inv).with('1', nil, 'sack', '2', 'get #1 in #2', nil)
      described_class.populate_inventory_get("<d cmd='get #1 in #2'>a sack</d>")
    end

    it 'parses an item line with trailing location prose' do
      expect(GameObj).to receive(:new_inv).with('8761784', nil, 'seagull feather quill', nil, 'get #8761784', nil)
      described_class.populate_inventory_get("<d cmd='get #8761784'>a seagull feather quill</d> is in your right hand.")
    end

    it 'parses an inv list worn item linked with a remove command into inv' do
      expect(GameObj).to receive(:new_inv).with('10859433', nil, 'hooded electroweave cloak', nil, 'remove #10859433', nil)
      described_class.populate_inventory_get("  <d cmd='remove #10859433'>a hooded electroweave cloak</d>")
    end

    it 'parses an inv list nested item despite the leading dash and indentation' do
      expect(GameObj).to receive(:new_inv).with('10859466', nil, 'dirty inkpot', '10859433', 'get #10859466 in #10859433', nil)
      described_class.populate_inventory_get("     -<d cmd='get #10859466 in #10859433'>a dirty inkpot</d>")
    end

    # A doubly-nested line establishes ONLY the item -> immediate parent
    # (#10956107) edge. It must NOT also synthesize the middle-container ->
    # grandparent ('a watery portal') edge with a nil name: INV LIST lists
    # #10956107 on its own line with its real name, so a second nil-name
    # placement would be a phantom duplicate (find_or_create dedups on
    # "id|noun|name", so the nil-name copy never collides). See the non-mocked
    # regression below for the duplicate itself.
    it 'parses a doubly-nested inv list item without re-registering the middle container' do
      expect(GameObj).to receive(:new_inv).with('10956111', nil, 'rosemary-dusted pumpkin and apple tart drizzled with an amber glaze', '10956107', 'get #10956111 in #10956107 in a watery portal', nil)
      # The middle container (#10956107) is never re-added from this child line.
      expect(GameObj).not_to receive(:new_inv).with('10956107', anything, anything, anything, anything, anything)
      described_class.populate_inventory_get("        -<d cmd='get #10956111 in #10956107 in a watery portal'>a rosemary-dusted pumpkin and apple tart drizzled with an amber glaze</d>")
    end

    it 'stops parsing and clears partial mode on the output-class-empty tag' do
      described_class.class_variable_set(:@@inventory_partial, true)
      described_class.populate_inventory_get('<output class=""/>')
      expect(described_class.class_variable_get(:@@parsing_inventory_get)).to be false
      expect(described_class.class_variable_get(:@@inventory_partial)).to be false
    end

    context 'in PARTIAL (INV SEARCH / category) mode' do
      before(:each) { described_class.class_variable_set(:@@inventory_partial, true) }

      it 'upserts a matched item instead of a plain add' do
        expect(GameObj).to receive(:upsert_inv).with('11404650', nil, 'soft gem pouch', '11404639', 'get #11404650 in #11404639', nil)
        expect(GameObj).not_to receive(:new_inv)
        described_class.populate_inventory_get("  <d cmd='get #11404650 in #11404639'>A soft gem pouch</d> is in a sky blue thigh quiver.")
      end

      it 'upserts a matched worn item (remove link) into inv' do
        expect(GameObj).to receive(:upsert_inv).with('11404268', nil, 'red pouch embroidered with a pork chop', nil, 'remove #11404268', nil)
        described_class.populate_inventory_get("  <d cmd='remove #11404268'>A red pouch embroidered with a pork chop</d> is being worn.")
      end

      # Adversarial (#5): a filtered scrape of a deeply-nested item must NOT touch
      # the intermediate container. Routing it through upsert_inv with name=nil
      # would blank that container's real name and pull a worn parent out of
      # GameObj.inv. So the middle container is left alone in partial mode.
      it 'does NOT upsert the intermediate container for a doubly-nested match' do
        # Only the matched item itself is upserted...
        expect(GameObj).to receive(:upsert_inv).with('10956111', nil, 'rosemary-dusted pumpkin and apple tart drizzled with an amber glaze', '10956107', 'get #10956111 in #10956107 in a watery portal', nil)
        # ...never the middle container (#10956107) with a nil name.
        expect(GameObj).not_to receive(:upsert_inv).with('10956107', anything, anything, anything, anything, anything)
        expect(GameObj).not_to receive(:new_inv)
        described_class.populate_inventory_get("        -<d cmd='get #10956111 in #10956107 in a watery portal'>a rosemary-dusted pumpkin and apple tart drizzled with an amber glaze</d>")
      end
    end
  end

  # Regression (NON-MOCKED): drives the real GameObj model end-to-end. Kept in
  # its own describe -- OUTSIDE '.populate_inventory_get', whose before(:each)
  # stubs new_inv -- precisely so new_inv is NOT stubbed here. This is the case
  # the mocked tests cannot see: they stub new_inv, so they never observe the
  # resulting duplicate in GameObj.containers. We feed a real doubly-nested
  # INV LIST fragment (middle container listed on its own line AND as the parent
  # of nested items, exactly as DR emits it) and assert each id lands in its
  # parent container exactly once, with its real name and no nil phantom.
  describe 'doubly-nested INV LIST against the real GameObj (duplicate regression)' do
    before(:each) do
      # GameObj has no reset! -- clear the production registries and identity
      # index this test touches so it is isolated from earlier examples.
      %i[@@inv @@contents @@index].each do |cv|
        GameObj.class_variable_get(cv).clear if GameObj.class_variable_defined?(cv)
      end
      described_class.class_variable_set(:@@parsing_inventory_get, true)
      # COMPLETE (INV LIST) mode. Harmless where the flag is not yet read; keeps
      # the scrape in replace-not-upsert mode once partial scrapes are added.
      described_class.class_variable_set(:@@inventory_partial, false)
    end

    # Raw INV LIST lines: a single leading dash + indentation at every depth.
    # #10783170 is the middle container -- it appears on its own line and as the
    # parent of the two nested items.
    let(:inv_list_lines) do
      [
        "      -<d cmd='get #10783170 in a watery portal'>a deep-green square tin (closed)</d>",
        "         -<d cmd='get #10783174 in #10783170 in a watery portal'>a sheet of red parchment</d>",
        "         -<d cmd='get #10783173 in #10783170 in a watery portal'>a tart</d>"
      ]
    end

    it 'registers the middle container in its parent exactly once (no nil-name phantom)' do
      inv_list_lines.each { |line| described_class.populate_inventory_get(line) }

      portal = GameObj.containers['a watery portal'] || []
      mids = portal.select { |o| o.id == '10783170' }

      # Before the fix this was 2: the real 'deep-green square tin (closed)' plus
      # a nil-name phantom synthesized from the nested item lines.
      expect(mids.size).to eq(1)
      expect(mids.first.name).to eq('deep-green square tin (closed)')
      expect(portal.map(&:name)).not_to include(nil)
    end

    it 'places the nested contents under the middle container once each' do
      inv_list_lines.each { |line| described_class.populate_inventory_get(line) }

      contents = GameObj.containers['10783170'] || []
      expect(contents.map(&:id)).to contain_exactly('10783174', '10783173')
      expect(contents.map(&:name)).to contain_exactly('sheet of red parchment', 'tart')
    end
  end
end
