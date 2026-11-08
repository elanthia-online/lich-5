# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'ox' # populate_inventory_get parses <d> fragments via Ox (loaded by lich.rbw in production)

# Load dependencies
require_relative '../../../../lib/dragonrealms/drinfomon/drdefs'
require_relative '../../../../lib/dragonrealms/drinfomon/drvariables'
require_relative '../../../../lib/dragonrealms/drinfomon/drskill'
# check_events writes through the real Flags (record_match checks its matchers).
require_relative '../../../../lib/dragonrealms/drinfomon/events'
# The inline exp examples run the real DRExpMonitor formatters.
require_relative '../../../../lib/dragonrealms/drinfomon/drexpmonitor'
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
require_relative '../../../support/account_stub'

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
    described_class.class_variable_set(:@@room_objs_cut, nil)
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

    describe 'player speech and ESP' do
      # Line shapes from real logs: ESP is `[Channel][Name] "text"`, speech is
      # `Name says, "text"` (one case adds leading tags). Anyone in the room or
      # on the channel controls the quoted text, so it must never write the
      # listener's state.
      {
        'an ESP stat'          => ['[General][Mallory] "Strength : 999"', :strength=],
        'a spoken TDPs stat'   => ['Mallory says, "TDPs : 0"', :tdps=],
        'a spoken favors stat' => ['<preset id="speech">Mallory says</preset>, "Favors : 0"', :favors=],
        'an ESP TDP sentence'  => ['[General][Mallory] "You have 0 TDPs."', :tdps=]
      }.each do |name, (line, setter)|
        it "ignores #{name}" do
          expect(drstats_class).not_to receive(setter)
          described_class.parse(line.dup)
        end
      end

      it 'ignores an ESP exp column' do
        expect(drskill_class).not_to receive(:update)
        described_class.parse('[General][Mallory] "Evasion: 1 0% mind lock"'.dup)
      end

      it 'ignores a whispered account status' do
        allow(Lich::Common::Account).to receive(:subscription).and_return(nil)
        expect(Lich::Common::Account).not_to receive(:subscription=)
        expect(UserVars).not_to receive(:account_type=)
        described_class.parse('Mallory whispers, "Current Account Status: F2P"'.dup)
      end

      # The anchors must still accept the real lines, which start with only
      # whitespace and/or tags.
      it 'still reads a buffed INFO stat line wrapped in speech presets' do
        expect(drstats_class).to receive(:agility=).with(100)
        expect(drstats_class).to receive(:charisma=).with(100)
        described_class.parse('<preset id="speech">      Agility : 100 +20</preset>   <preset id="speech">     Charisma : 100 +20</preset>'.dup)
      end

      it 'still reads both columns of an EXP line' do
        expect(drskill_class).to receive(:update).with('Light Armor', '0', 0, '77')
        expect(drskill_class).to receive(:update).with('Defending', '0', 0, '62')
        described_class.parse('     Light Armor:      0 77% clear          (0/34)       Defending:      0 62% clear          (0/34)'.dup)
      end

      it 'still reads an indented account status from PLAYED' do
        allow(Lich::Common::Account).to receive(:subscription).and_return(nil)
        expect(Lich::Common::Account).to receive(:subscription=).with('FREE')
        described_class.parse('  Current Account Status: F2P'.dup)
      end

      # The exp branch must take every column the ExpColumns scan can read,
      # even when the first column is garbled, and must not claim a line the
      # scan reads nothing from. Shapes from a real log line whose rate word
      # was cut off.
      it 'reads the intact column of an EXP line whose first column is cut off' do
        expect(drskill_class).to receive(:update).with('Evasion', '1610', 34, '24').once
        described_class.parse('   Parry Ability: 1610 24% mi550     Evasion: 1610 24% mind lock'.dup)
      end

      it 'updates nothing from an EXP line with no readable column' do
        expect(drskill_class).not_to receive(:update)
        described_class.parse('   Parry Ability: 1610 24% mi550 07% mind lock     0.14'.dup)
      end

      # All four anchors share one prefix, so either kind of lead-in works.
      it 'still reads an indented TDP sentence' do
        expect(drstats_class).to receive(:tdps=).with(12)
        described_class.parse('   You have 12 TDPs.'.dup)
      end

      it 'still reads an account status behind a tag' do
        allow(Lich::Common::Account).to receive(:subscription).and_return(nil)
        expect(Lich::Common::Account).to receive(:subscription=).with('PREMIUM')
        described_class.parse('<output class="mono"/>Current Account Status: Premium'.dup)
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

  # The 'DRParser stubs' context stubs Flags.flags and Flags.matchers to empty
  # hashes. Specs that need check_events to set a flag use the real ones.
  shared_context 'real Flags' do
    before do
      allow(Flags).to receive(:flags).and_call_original
      allow(Flags).to receive(:matchers).and_call_original
      Flags.class_variable_set(:@@flags, {})
      Flags.class_variable_set(:@@matchers, {}.freeze)
    end
  end

  describe '.check_events' do
    include_context 'real Flags'

    it 'matches flags and sets values' do
      Flags.add('test_flag', /test pattern/)

      described_class.check_events('this is a test pattern here')
      expect(Flags['test_flag']).to be_a(MatchData)
    end

    it 'leaves other flags alone' do
      Flags.add('test_flag', /test pattern/)
      Flags.add('other_flag', /something else/)

      described_class.check_events('this is a test pattern here')
      expect(Flags['other_flag']).to be false
    end

    # check_events walks a snapshot of Flags.matchers. Park it on the first
    # flag, change the flags from another thread, then let it reach the
    # pouch-full matcher with a line that matches it.
    def check_events_with_write_mid_iteration(line, &write)
      parked = Queue.new
      resume = Queue.new
      calls = 0
      server_string = +line
      server_string.define_singleton_method(:match) do |regex|
        calls += 1
        if calls == 1
          parked << true
          resume.pop
        end
        # &nil: a bare super would pass this method's block on to String#match.
        super(regex, &nil)
      end
      reader = Thread.new { described_class.check_events(server_string) }
      parked.pop(timeout: 5) || raise('check_events never started iterating')
      begin
        write.call
      ensure
        resume << true
      end
      reader.join
    end

    it 'does not bring back a flag deleted while it was iterating' do
      Flags.add('flag1', /never matches/)
      Flags.add('pouch-full', /is too full/)

      check_events_with_write_mid_iteration('Your gem pouch is too full.') { Flags.delete('pouch-full') }

      expect(Flags.flags).not_to have_key('pouch-full')
      expect(Flags['pouch-full']).to be_nil
    end

    it 'does not set a flag re-added while it was iterating from the matchers it replaced' do
      Flags.add('flag1', /never matches/)
      Flags.add('pouch-full', /is too full/)

      check_events_with_write_mid_iteration('Your gem pouch is too full.') do
        Flags.delete('pouch-full')
        Flags.add('pouch-full', /is too full/)
      end

      expect(Flags['pouch-full']).to be false
    end

    it 'still sets a flag whose matchers did not change while it was iterating' do
      Flags.add('flag1', /never matches/)
      Flags.add('pouch-full', /is too full/)

      check_events_with_write_mid_iteration('Your gem pouch is too full.') { Flags.add('unrelated', /x/) }

      expect(Flags['pouch-full']).to be_a(MatchData)
    end
  end

  # The Saga-identity stream wraps names in <a exist noun> links and (currently) doubles the
  # bold around linked creatures; the legacy stream does neither. Lines below are
  # verbatim Saga shapes (names pseudonymized) next to their legacy equivalents.
  describe 'Saga dialect object links' do
    saga_objs = "<component id='room objs'>You also see <pushBold/><pushBold/>a <a exist=\"195652828\" noun=\"moradu\">jeol moradu</a><popBold/><popBold/> (immobile), a <a exist=\"195649758\" noun=\"pouch\">pouch of lead pellets</a>, an <a exist=\"195634669\" noun=\"card\">Immortal Glythtide card</a>, <pushBold/><pushBold/>a <a exist=\"195652888\" noun=\"moradu\">jeol moradu</a><popBold/><popBold/> (dead) and some junk.</component>"
    legacy_objs = "<component id='room objs'>You also see <pushBold/>a jeol moradu<popBold/> (immobile), a pouch of lead pellets, an Immortal Glythtide card, <pushBold/>a jeol moradu<popBold/> (dead) and some junk.</component>"
    saga_players = "<component id='room players'>Also here: Monster <a exist=\"-10700002\" noun=\"Aldric\">Aldric</a>, Daydreamer <a exist=\"-10700003\" noun=\"Brenna\">Brenna</a> who is surrounded by a pale electrical sphere, <a exist=\"-10700004\" noun=\"Corwin\">Corwin</a> and Druid <a exist=\"-10700005\" noun=\"Delphine\">Delphine</a>.</component>"
    legacy_players = "<component id='room players'>Also here: Monster Aldric, Daydreamer Brenna who is surrounded by a pale electrical sphere, Corwin and Druid Delphine.</component>"

    # The shared 'DRParser stubs' context stubs DRRoom's setters, so capture what
    # parse assigns instead of reading DRRoom back.
    let(:assigned) { {} }

    before do
      %i[npcs dead_npcs room_objs pcs].each do |field|
        allow(drroom_class).to receive(:"#{field}=") { |value| assigned[field] = value }
      end
      # parse calls the drdefs room helpers unqualified; production reaches them
      # because main.rb includes Lich::DragonRealms into Object. Route them to the
      # real implementations here without including the module globally.
      drdefs = Object.new.extend(Lich::DragonRealms)
      %i[find_npcs find_dead_npcs find_objects find_pcs find_pcs_prone find_pcs_sitting].each do |helper|
        allow(described_class).to receive(helper) { |arg| drdefs.send(helper, arg) }
      end
    end

    def parse_room(line)
      assigned.clear
      described_class.parse(+line)
      assigned.dup
    end

    describe '.match_line' do
      it 'removes object links but keeps their text' do
        line = 'The clerk says, "<a exist="-10700006" noun="Edric">Edric</a>, it looks like your current balance is 5 platinum Kronars."'
        expect(described_class.match_line(line)).to eq('The clerk says, "Edric, it looks like your current balance is 5 platinum Kronars."')
      end

      it 'collapses doubled bold to the single bold the legacy stream sends' do
        line = '<pushBold/><pushBold/>a <a exist="1" noun="leopard">white-tailed leopard</a><popBold/><popBold/>'
        expect(described_class.match_line(line)).to eq('<pushBold/>a white-tailed leopard<popBold/>')
      end

      # The doubled bold is a current server quirk; a single-bold linked line
      # (the shape DR already sends in combat lines) must still lose its links
      # and keep its one bold.
      it 'strips links from a single-bold linked line and leaves the bold alone' do
        line = '<pushBold/>a <a exist="1" noun="leopard">white-tailed leopard</a><popBold/>'
        expect(described_class.match_line(line)).to eq('<pushBold/>a white-tailed leopard<popBold/>')
      end

      it 'returns a link-free line unchanged, as the same object' do
        line = +"<component id='room objs'>You also see <pushBold/>a jeol moradu<popBold/>.</component>"
        expect(described_class.match_line(line)).to equal(line)
      end

      it 'leaves <d cmd> links (INV LIST items, exits) alone' do
        line = "  <d cmd='remove #195648608'>a diacan lamellar helm</d>"
        expect(described_class.match_line(line)).to equal(line)
      end
    end

    describe '.parse room components' do
      it 'derives the same DRRoom npcs/dead_npcs/room_objs from a Saga room objs line as from its legacy equivalent' do
        legacy = parse_room(legacy_objs)
        saga = parse_room(saga_objs)

        expect(saga).to eq(legacy)
        expect(saga[:npcs]).to eq(['moradu'])
        expect(saga[:dead_npcs]).to eq(['moradu'])
        expect(saga[:room_objs]).to include('pouch of lead pellets', 'junk')
        expect(saga[:room_objs].join).not_to include('<a ')
      end

      it 'derives the same DRRoom fields from a single-bold Saga room objs line as from its legacy equivalent' do
        single_bold = saga_objs.gsub('<pushBold/><pushBold/>', '<pushBold/>').gsub('<popBold/><popBold/>', '<popBold/>')

        expect(parse_room(single_bold)).to eq(parse_room(legacy_objs))
        expect(parse_room(single_bold)[:dead_npcs]).to eq(['moradu'])
      end

      it 'does not report a doubled-bold dead creature as alive' do
        expect(parse_room(saga_objs)[:npcs]).to eq(['moradu'])
      end

      it 'derives the same DRRoom.pcs from a Saga room players line as from its legacy equivalent' do
        legacy = parse_room(legacy_players)
        saga = parse_room(saga_players)

        expect(saga).to eq(legacy)
        expect(saga[:pcs]).to eq(%w[Aldric Brenna Corwin Delphine])
      end
    end

    describe 'Flags on linked lines' do
      include_context 'real Flags'

      it 'fires a name-anchored Flag when the name is an object link' do
        Flags.add('drums', /^Brenna drums (?:his|her) fingers/)

        described_class.parse(+'<a exist="-10700003" noun="Brenna">Brenna</a> drums his fingers on his bucket rhythmically.')
        expect(Flags['drums']).to be_truthy
      end

      it 'fires a speech Flag when the speaker is linked inside the speech preset' do
        Flags.add('hello', /<preset id='speech'>Delphine politely says<\/preset>, "Hello\."/)

        described_class.parse(+%(<preset id='speech'><a exist="-10700005" noun="Delphine">Delphine</a> politely says</preset>, "Hello."))
        expect(Flags['hello']).to be_truthy
      end
    end

    describe 'parse error log' do
      let(:messages) { [] }
      let(:logs) { [] }

      before do
        allow(Lich::Messaging).to receive(:msg) { |_type, message| messages << message }
        allow(Lich).to receive(:log) { |message| logs << message }
        allow(described_class).to receive(:check_game_shutdown).and_raise(StandardError, 'boom')
      end

      it 'reports the line as the server sent it, links included, and the matched copy' do
        server_line = +'<a exist="-10700003" noun="Brenna">Brenna</a> drums his fingers.'
        described_class.parse(server_line)

        expect(messages).to include('DRParser: line: <a exist="-10700003" noun="Brenna">Brenna</a> drums his fingers.')
        expect(messages).to include('DRParser: matched as: Brenna drums his fingers.')
        expect(logs.join).to include('<a exist="-10700003" noun="Brenna">Brenna</a> drums his fingers.', 'matched as: Brenna drums his fingers.')
      end

      it 'reports a link-free (legacy) line once, as before' do
        described_class.parse(+'Brenna drums his fingers.')

        expect(messages).to eq(['DRParser: error in parse: boom', 'DRParser: line: Brenna drums his fingers.'])
        expect(logs.join).not_to include('matched as')
      end
    end

    describe 'inline exp display' do
      it 'still rewrites the server string the client receives' do
        allow(Lich::DragonRealms::DRExpMonitor).to receive(:inline_display?).and_return(true)
        allow(Lich::DragonRealms::DRExpMonitor).to receive(:format_briefexp_off).and_return('REWRITTEN')
        server_line = +"<component id='exp Athletics'>       Athletics: 1552 43% enthralled    0.00   </component>"

        described_class.parse(server_line)
        expect(server_line).to eq('REWRITTEN')
      end

      # The example above uses a link-free line, which match_line returns as the
      # same object, so it passes whether the rewrite targets server_line or the
      # normalized copy. Real exp components carry no links (none in the
      # captures, either dialect), so this input is synthetic: the link only
      # makes match_line return a new string, so that only a rewrite of the
      # client-bound server_line passes.
      it 'rewrites the server string, not the normalized copy (synthetic linked input)' do
        received = nil
        allow(Lich::DragonRealms::DRExpMonitor).to receive(:inline_display?).and_return(true)
        # Copy the argument at call time: the formatter is handed server_line
        # itself, which parse then replaces with the formatter's result.
        allow(Lich::DragonRealms::DRExpMonitor).to receive(:format_briefexp_off) do |line, skill, rate|
          received = [line.dup, skill, rate]
          'REWRITTEN'
        end
        server_line = +%(<component id='exp Athletics'>       <a exist="1" noun="x">Athletics</a>: 1552 43% enthralled    0.00   </component>)

        described_class.parse(server_line)
        expect(server_line).to eq('REWRITTEN')
        # The formatter edits the line as sent (links kept); skill and rate come
        # from the normalized copy.
        expect(received).to eq([%(<component id='exp Athletics'>       <a exist="1" noun="x">Athletics</a>: 1552 43% enthralled    0.00   </component>), 'Athletics', 'enthralled'])
      end

      # These run the real DRExpMonitor formatters. The linked and doubled-bold
      # lines are synthetic: no captured exp component carries a link or
      # doubled bold, in either dialect. They guard that the formatter edits
      # the client-bound string (server_line), so whatever markup it holds
      # survives the rewrite, and that only the skill and rate come from the
      # normalized copy.
      describe 'with the real formatters' do
        before do
          described_class.class_variable_set(:@@parsing_exp_mods_output, false)
          allow(drexpmonitor_class).to receive(:inline_display?).and_return(true)
          allow(drexpmonitor_class).to receive(:format_briefexp_on).and_call_original
          allow(drexpmonitor_class).to receive(:format_briefexp_off).and_call_original
          # The formatters read the class variable directly; spec_helper's
          # DRExpMonitor.reset! clears it after each example.
          drexpmonitor_class.class_variable_set(:@@inline_display, true)
          allow(drskill_class).to receive(:gained_exp).and_return(1.5)
        end

        it 'edits the client-bound string of a BRIEFEXP OFF line (synthetic links and doubled bold kept)' do
          server_line = +%(<component id='exp Athletics'><pushBold/><pushBold/>       <a exist="1" noun="Athletics">Athletics</a>: 1552 43% enthralled    0.00   <popBold/><popBold/></component>)
          normalized = described_class.match_line(server_line).dup

          described_class.parse(server_line)
          expect(server_line).to include('<a exist="1" noun="Athletics">Athletics</a>', '<pushBold/><pushBold/>', '<popBold/><popBold/>')
          expect(server_line).to include(' 1.50')
          expect(described_class.match_line(server_line)).to eq(drexpmonitor_class.format_briefexp_off(normalized, 'Athletics', 'enthralled'))
        end

        it 'edits the client-bound string of a BRIEFEXP ON line (synthetic links kept)' do
          server_line = +%(<component id='exp Athletics'><d cmd='skill Athletics'><a exist="1" noun="Athletics">Athletics</a></d>:  1552 43%  [ 2/34]</component>)
          normalized = described_class.match_line(server_line).dup

          described_class.parse(server_line)
          expect(server_line).to include('<a exist="1" noun="Athletics">Athletics</a>', '[ 2/34] 1.50')
          expect(described_class.match_line(server_line)).to eq(drexpmonitor_class.format_briefexp_on(normalized, 'Athletics'))
        end

        it 'rewrites a link-free (legacy) line exactly as before' do
          server_line = +"<component id='exp Athletics'>       Athletics: 1552 43% enthralled    0.00   </component>"
          expected = drexpmonitor_class.format_briefexp_off(server_line.dup, 'Athletics', 'enthralled')

          described_class.parse(server_line)
          expect(server_line).to eq(expected)
          expect(server_line).not_to eq("<component id='exp Athletics'>       Athletics: 1552 43% enthralled    0.00   </component>")
        end
      end
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

      it 'opens a staged container refresh (NOT a destructive clear), enters parsing, and is NOT partial' do
        # The full replacement is now staged so the live model stays visible until
        # a clean terminator commits it -- the header must not wipe anything.
        # The worn list belongs to the worn-items stream, so it is not staged.
        expect(GameObj).not_to receive(:clear_inv)
        expect(GameObj).not_to receive(:clear_all_containers)
        expect(GameObj).not_to receive(:begin_inv)
        expect(GameObj).to receive(:begin_all_containers)

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

    # Non-mocked, drives the REAL GameObj end-to-end to prove the COMPLETE INV
    # LIST path is atomic: the previous model stays visible until a clean
    # terminator commits the staged replacement, and an interrupted listing
    # keeps the old model instead of leaving it half-updated.
    describe 'atomic full INV LIST refresh (real GameObj)' do
      before do
        GameObj.class_variable_set(:@@inv, [])
        GameObj.class_variable_set(:@@contents, {})
        GameObj.class_variable_set(:@@staging_inv, nil)
        GameObj.class_variable_set(:@@staging_contents, {})
        GameObj.class_variable_set(:@@staging_all_containers, false)
        GameObj.class_variable_set(:@@index, {})
        described_class.class_variable_set(:@@parsing_inventory_get, false)
        described_class.class_variable_set(:@@inventory_partial, false)
        allow(Lich::Messaging).to receive(:msg)

        # Seed a known model: a worn cloak (#10) holding a gem (#11).
        GameObj.new_inv('10', nil, 'cloak', nil, 'remove #10')
        GameObj.new_inv('11', nil, 'gem', '10', 'get #11 in #10')
      end

      def ids(list) = Array(list).map(&:id)

      it 'leaves the previous model visible while the listing streams (no up-front wipe)' do
        described_class.parse('You take a moment and rummage about your person, taking stock of your possessions...')
        described_class.parse("  <d cmd='remove #20'>a backpack</d>")

        # Nothing committed yet: the old cloak+gem are still the published model.
        expect(ids(GameObj.inv)).to contain_exactly('10')
        expect(GameObj.containers).to have_key('10')
        expect(ids(GameObj.containers['10'])).to contain_exactly('11')
      end

      it 'atomically replaces the container contents on the clean terminator, dropping absent containers' do
        described_class.parse('You take a moment and rummage about your person, taking stock of your possessions...')
        described_class.parse("  <d cmd='remove #20'>a backpack</d>")
        described_class.parse("     -<d cmd='get #21 in #20'>a coin</d>")
        described_class.parse('<output class=""/>')

        # The worn list is the worn-items stream's: the listing leaves it alone.
        expect(ids(GameObj.inv)).to contain_exactly('10')
        expect(ids(GameObj.containers['20'])).to contain_exactly('21')
        # The cloak's contents were not in the new listing, so its entry is dropped.
        expect(GameObj.containers).not_to have_key('10')
      end

      it 'keeps the previous model and warns when the listing is interrupted by a prompt' do
        described_class.parse('You take a moment and rummage about your person, taking stock of your possessions...')
        described_class.parse("  <d cmd='remove #20'>a backpack</d>")

        expect(Lich::Messaging).to receive(:msg).with('warn', /inv list.*did not finish/i)
        # Interrupted: a prompt arrives with no closing <output class=""/>.
        described_class.parse('<prompt time="123">&gt;</prompt>')

        # Old model intact; the half-streamed backpack was discarded.
        expect(ids(GameObj.inv)).to contain_exactly('10')
        expect(ids(GameObj.containers['10'])).to contain_exactly('11')
      end

      # Regression: in production Game.process_xml_data runs XMLParser BEFORE
      # DRParser, so the interrupting <prompt> first fires
      # GameObj.commit_all_containers (the ordinary per-container publish) and
      # only afterwards does DRParser discard the refresh. commit_all_containers
      # must refuse to publish while a full refresh is open, or it commits the
      # partial listing before the discard can run -- corrupting the model while
      # still warning that the previous inventory was kept.
      it 'does not commit a partial full refresh when XMLParser commits at the prompt first' do
        described_class.parse('You take a moment and rummage about your person, taking stock of your possessions...')
        # Listing streams the cloak with a DIFFERENT child (#12) than published (#11).
        described_class.parse("  <d cmd='remove #10'>a cloak</d>")
        described_class.parse("     -<d cmd='get #12 in #10'>a coin</d>")

        expect(Lich::Messaging).to receive(:msg).with('warn', /inv list.*did not finish/i)
        # Production order at the prompt: XMLParser publishes containers first...
        GameObj.commit_all_containers
        # ...then DRParser sees the interrupted scrape and discards it.
        described_class.parse('<prompt time="123">&gt;</prompt>')

        # The premature commit must NOT have replaced #11 with #12.
        expect(ids(GameObj.containers['10'])).to contain_exactly('11')
        expect(ids(GameObj.inv)).to contain_exactly('10')
      end

      it 'does not resurrect an item picked into a hand mid-listing when the staged list commits' do
        described_class.parse('You take a moment and rummage about your person, taking stock of your possessions...')
        # The listing streams the gem (#11) as still inside the cloak...
        described_class.parse("  <d cmd='remove #10'>a cloak</d>")
        described_class.parse("     -<d cmd='get #11 in #10'>a gem</d>")
        # ...but it is then picked into a hand before the list commits.
        GameObj.remove_inv_item('11')
        described_class.parse('<output class=""/>')

        # The commit must not re-add the picked-up gem to the cloak.
        expect(ids(GameObj.containers['10'] || [])).not_to include('11')
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

  # When a room holds too much, DragonRealms cuts the room objs component short
  # ("... and some other stuff.</component>") while the main-stream room view
  # that follows the roomName line still lists everything.
  describe 'room objs component cut short' do
    # Lines 14-31, 40-54, 63-67, 91-105 and 129-143 of a 2026-11-07 Saga capture
    # (Andreshlew, Lithralia Street), timestamps stripped, player names and ids
    # pseudonymized. In order: entry with a cut component (Seamstress Zasele is
    # only in the main-stream view), an unrelated arrival, a second entry, a
    # LOOK with room descriptions on, a move east to a complete room, and the
    # return once the ground was partly cleared (Zasele back in the component).
    fixture = File.expand_path('../../../fixtures/room_objs/dr_saga_room_objs_cut.xml', __dir__)
    let(:capture) { File.readlines(fixture) }

    let(:assigned) { {} }
    # [line number, field, value] for every DRRoom/UserVars write, in order.
    let(:writes) { [] }
    let(:line_no) { [0] }

    before do
      %i[npcs dead_npcs room_objs].each do |field|
        allow(drroom_class).to receive(:"#{field}=") do |value|
          assigned[field] = value
          writes << [line_no[0], field, value]
        end
      end
      allow(drroom_class).to receive(:npcs) { assigned.fetch(:npcs, []) }
      # parse calls the drdefs room helpers unqualified; production reaches them
      # because main.rb includes Lich::DragonRealms into Object. Route them to
      # the real implementations here without including the module globally.
      drdefs = Object.new.extend(Lich::DragonRealms)
      %i[find_npcs find_dead_npcs find_objects find_pcs find_pcs_prone find_pcs_sitting].each do |helper|
        allow(described_class).to receive(helper) { |arg| drdefs.send(helper, arg) }
      end
      UserVars.npcs = []
    end

    def feed(*lines)
      lines.flatten.each do |line|
        line_no[0] += 1
        described_class.parse(+line)
      end
      assigned
    end

    # 1-based line number of the first capture line at or after +from+ that
    # contains every one of +needles+.
    def capture_line(*needles, from: 1)
      index = capture.each_index.find { |i| i + 1 >= from && needles.all? { |n| capture[i].include?(n) } }
      raise "no capture line has #{needles.inspect}" unless index

      index + 1
    end

    def writes_on(number) = writes.select { |n, _, _| n == number }

    cut_objs = "<component id='room objs'>You also see a rock, <pushBold/>a goblin<popBold/> and some other stuff.</component>"
    full_list = 'You also see a rock, <pushBold/>a goblin<popBold/>, a wooden chest, <pushBold/>a kobold<popBold/> which appears dead and <pushBold/>Seamstress Zasele<popBold/>.'
    full_view = "<style id=\"\"/>  #{full_list}\r\n"
    prompt = '<prompt time="1794026438">&gt;</prompt>'

    describe 'the real capture' do
      before { feed(capture) }

      it 'adds the NPC listed after the cut once the room view arrives' do
        component = capture_line("'room objs'", 'other stuff')
        view = capture_line('<style id=""/>  You also see', from: component)

        expect(writes_on(component).to_h { |_, field, value| [field, value] }[:npcs]).to eq([])
        expect(writes_on(view).to_h { |_, field, value| [field, value] }).to include(npcs: ['Zasele'], dead_npcs: [])
      end

      it 'replaces the cut list, "other stuff" entry included, with the full one' do
        component = capture_line("'room objs'", 'other stuff')
        view = capture_line('<style id=""/>  You also see', from: component)
        cut = writes_on(component).find { |_, field, _| field == :room_objs }.last
        full = writes_on(view).find { |_, field, _| field == :room_objs }.last

        # 25 objects + "other stuff"; then 32 objects, 33 entries because
        # find_objects splits "white and blue cozy shop" (existing behaviour).
        expect(cut.size).to eq(26)
        expect(cut.last).to eq('other stuff')
        expect(full.size).to eq(33)
        expect(full.first(25)).to eq(cut.first(25))
        expect(full).to include('sturdy shack', 'boxy structure')
        expect(full.last).to eq('boxy structure')
        expect(full.grep(/other stuff|Zasele|<|exist=/)).to be_empty
      end

      it 'leaves the repaired room alone through later lines up to the next move' do
        component = capture_line("'room objs'", 'other stuff')
        view = capture_line('<style id=""/>  You also see', from: component)
        next_move = capture_line('<nav/>', from: view)

        expect(writes.select { |n, _, _| n > view && n < next_move }).to be_empty
      end

      it 'repairs the second entry and the LOOK with room descriptions on' do
        second = capture_line("'room objs'", 'other stuff', from: capture_line('You wander north.'))
        view = capture_line('<style id=""/>  You also see', from: second)
        look = capture_line("<preset id='roomDesc'>", from: view)

        [view, look].each do |n|
          expect(writes_on(n).to_h { |_, field, value| [field, value] }[:npcs]).to eq(['Zasele'])
          expect(writes_on(n).to_h { |_, field, value| [field, value] }[:room_objs].size).to eq(33)
        end
      end

      it 'does not reparse the room view of a complete component' do
        %w[east west].each do |dir|
          component = capture_line("'room objs'", from: capture_line("You wander #{dir}."))
          view = capture_line('<style id=""/>  You also see', from: component)

          expect(writes_on(component).map { |_, field, _| field }).to contain_exactly(:npcs, :dead_npcs, :room_objs)
          expect(writes_on(view)).to be_empty
        end
      end

      it 'ends on the complete component that lists Zasele itself' do
        expect(assigned[:npcs]).to eq(['Zasele'])
        # find_objects splits "white and blue cozy shop" on " and " (existing
        # behaviour, unchanged here), hence "white" and "blue cozy shop".
        expect(assigned[:room_objs]).to eq(['sturdy shack', 'stone building', 'dragon-painted green stall', 'white', 'blue cozy shop', 'boxy structure'])
        expect(UserVars.npcs).to eq(['Zasele'])
      end
    end

    it 'repairs the legacy dialect too, sorting a dead NPC after the cut into dead_npcs' do
      feed(cut_objs, full_view)

      expect(assigned[:npcs]).to eq(%w[Zasele goblin])
      expect(assigned[:dead_npcs]).to eq(['kobold'])
      expect(assigned[:room_objs]).to eq(['rock', 'wooden chest'])
      expect(UserVars.npcs).to eq(%w[Zasele goblin])
    end

    it 'accepts the "and a lot of other stuff." form of the marker' do
      feed(cut_objs.sub('some other stuff', 'a lot of other stuff'), full_view)

      expect(assigned[:npcs]).to eq(%w[Zasele goblin])
    end

    it 'keeps a cut component as sent when no room view follows (still or refreshed)' do
      feed(cut_objs, prompt, 'You pick up a rock.')

      expect(assigned[:npcs]).to eq(['goblin'])
      expect(assigned[:room_objs]).to eq(['rock', 'other stuff'])
      expect(UserVars.npcs).to eq(['goblin'])
    end

    it 'repairs from a LOOK several prompts later in the same room' do
      feed(cut_objs, prompt, 'Brenna just arrived.', prompt)
      feed("<resource picture=\"0\"/><style id=\"roomName\" />[Room] (**)\r\n", full_view)

      expect(assigned[:npcs]).to eq(%w[Zasele goblin])
    end

    it 'finds the list after a room description that itself says "You also see"' do
      look = "<style id=\"\"/><preset id='roomDesc'>You also see a rock in the mist.</preset>  #{full_list}"
      feed(cut_objs, look)

      expect(assigned[:npcs]).to eq(%w[Zasele goblin])
      expect(assigned[:room_objs]).to eq(['rock', 'wooden chest'])
    end

    it "ignores another room's view and a container listing" do
      feed(cut_objs)
      writes.clear
      feed('<style id=""/>  You also see a rock, a stump and a goblin.',
           '<style id=""/>  You also see a rock.',
           'In the chest you see a rock, a goblin and some other stuff.',
           '<style id="">  You also see a boulder, a rock, <pushBold/>a goblin<popBold/>, a wooden chest.')

      expect(writes).to be_empty
    end

    it 'ignores a view that stops where the component was cut' do
      feed(cut_objs)
      writes.clear
      feed('<style id=""/>  You also see a rock, <pushBold/>a goblin<popBold/>.')

      expect(writes).to be_empty
    end

    it 'repairs when only one object follows the cut (" and " continuation)' do
      feed(cut_objs, '<style id=""/>  You also see a rock, <pushBold/>a goblin<popBold/> and a wooden chest.')

      expect(assigned[:room_objs]).to eq(['rock', 'wooden chest'])
    end

    {
      'a complete component' => "<component id='room objs'>You also see a rock.</component>",
      'an empty component'   => "<component id='room objs'></component>",
      'a move (<nav>)'       => "<nav rm='100029'/>"
    }.each do |boundary, line|
      it "forgets the cut after #{boundary}, so the old room view cannot overwrite the room" do
        feed(cut_objs, line)
        writes.clear
        feed(full_view)

        expect(writes).to be_empty
      end
    end

    it 'tracks the latest cut component: a newer cut replaces the older one' do
      newer = "<component id='room objs'>You also see a boulder and some other stuff.</component>"
      feed(cut_objs, newer)
      writes.clear
      feed(full_view)
      expect(writes).to be_empty

      feed('<style id=""/>  You also see a boulder, a rock and <pushBold/>a troll<popBold/>.')
      expect(assigned[:npcs]).to eq(['troll'])
    end

    it 'ignores a room view that arrives before the cut component' do
      feed(full_view, cut_objs)

      expect(assigned[:npcs]).to eq(['goblin'])
      expect(assigned[:room_objs]).to eq(['rock', 'other stuff'])
    end

    it 'does not treat "and some other stuff." before the end of the list as a cut' do
      objs = 'You also see a rock and some other stuff., <pushBold/>a goblin<popBold/>.'
      feed("<component id='room objs'>#{objs}</component>")

      expect(described_class.class_variable_get(:@@room_objs_cut)).to be_nil
    end

    # A status is worded differently in the component and the room view once
    # room descriptions are off (dr_legacy_hunt.xml:1561 "which appears dead",
    # :1608 "(dead)").
    describe 'creature status worded differently in the component and the view' do
      it 'repairs from a view that words a status before the cut differently' do
        feed("<component id='room objs'>You also see <pushBold/>a jeol moradu<popBold/> which appears dead, a rock and some other stuff.</component>",
             "<resource picture=\"0\"/><style id=\"roomName\" />[Room] (1)\r\n",
             '<style id=""/>  You also see <pushBold/>a jeol moradu<popBold/> (dead), a rock, a wooden chest and <pushBold/>a troll<popBold/>.')

        expect(assigned[:npcs]).to eq(['troll'])
        expect(assigned[:dead_npcs]).to eq(['moradu'])
        expect(assigned[:room_objs]).to eq(['rock', 'wooden chest'])
      end

      it 'repairs when the status is the last object before the cut, and the wordy form is in the view' do
        feed("<component id='room objs'>You also see a rock, <pushBold/>a goblin<popBold/> (stunned) and some other stuff.</component>",
             '<style id=""/>  You also see a rock, <pushBold/>a goblin<popBold/> that appears stunned and <pushBold/>Seamstress Zasele<popBold/>.')

        expect(assigned[:npcs]).to eq(%w[Zasele goblin])
      end

      it 'still rejects a view whose objects differ once statuses are set aside' do
        feed("<component id='room objs'>You also see <pushBold/>a goblin<popBold/> which appears dead, a rock and some other stuff.</component>")
        writes.clear
        feed('<style id=""/>  You also see <pushBold/>a kobold<popBold/> (dead), a rock, a wooden chest and <pushBold/>a troll<popBold/>.')

        expect(writes).to be_empty
      end

      it 'does not strip status-like words from an object that is not a creature' do
        feed("<component id='room objs'>You also see a rock which appears dead, a stick and some other stuff.</component>")
        writes.clear
        feed('<style id=""/>  You also see a rock (dead), a stick and <pushBold/>a troll<popBold/>.')

        expect(writes).to be_empty
      end
    end

    # The game resends the component, still cut, whenever something in the room
    # changes; no room view follows it. The change may be after the cut, where
    # the refresh cannot show it, so the refresh is applied as sent: an object
    # after the cut is missing until the next room view, never listed after it
    # has gone.
    describe 'a cut component resent in the same room' do
      # rock, goblin | wooden chest, kobold (dead), Zasele
      let(:refresh) { ->(text) { "<component id='room objs'>You also see #{text} and some other stuff.</component>" } }

      it 'applies a refresh as sent, "other stuff" entry included' do
        feed(cut_objs, full_view, refresh.call('a sack, a rock, <pushBold/>a goblin<popBold/>'), prompt)

        expect(assigned[:npcs]).to eq(['goblin'])
        expect(assigned[:dead_npcs]).to eq([])
        expect(assigned[:room_objs]).to eq(['sack', 'rock', 'other stuff'])
        expect(UserVars.npcs).to eq(['goblin'])
      end

      it 'drops a creature listed after the cut that left (unchanged refresh)' do
        feed(cut_objs, full_view, 'Seamstress Zasele just went east.', cut_objs, prompt)

        expect(assigned[:npcs]).to eq(['goblin'])
        expect(assigned[:dead_npcs]).to eq([])
        expect(assigned[:room_objs]).to eq(['rock', 'other stuff'])
      end

      it 'drops an object listed after the cut that was taken away (unchanged refresh)' do
        feed(cut_objs, full_view, 'Brenna picks up a wooden chest.', cut_objs)

        expect(assigned[:room_objs]).not_to include('wooden chest')
        expect(assigned[:room_objs].last).to eq('other stuff')
      end

      it 'repairs from a LOOK after a refresh, against the refresh it follows' do
        feed(cut_objs, full_view, refresh.call('a sack, a rock, <pushBold/>a goblin<popBold/>'))
        feed('<style id=""/>  You also see a sack, a rock, <pushBold/>a goblin<popBold/>, a wooden chest and <pushBold/>a troll<popBold/>.')

        expect(assigned[:npcs]).to eq(%w[goblin troll])
        expect(assigned[:room_objs]).to eq(['sack', 'rock', 'wooden chest'])
      end

      it 'does not repair from a view of the room as it was before the refresh' do
        feed(cut_objs, full_view, refresh.call('a sack, a rock, <pushBold/>a goblin<popBold/>'))
        writes.clear
        feed(full_view)

        expect(writes).to be_empty
      end

      # Review of #2287: the repaired list was merged with every later refresh,
      # so a creature after the cut stayed listed after it left.
      it 'drops Zasele from the real capture when she leaves and the component is resent' do
        component = capture_line("'room objs'", 'other stuff')
        view = capture_line('<style id=""/>  You also see', from: component)
        feed(capture.first(view))
        expect(assigned[:npcs]).to eq(['Zasele'])

        feed('Seamstress Zasele just went east.', capture[component - 1], prompt)

        expect(assigned[:npcs]).to eq([])
        expect(assigned[:room_objs].last).to eq('other stuff')
      end

      it 'drops her until a LOOK when she stays and the component is resent' do
        component = capture_line("'room objs'", 'other stuff')
        view = capture_line('<style id=""/>  You also see', from: component)
        feed(capture.first(view), capture[component - 1], prompt)
        expect(assigned[:npcs]).to eq([])

        feed(capture[view - 1])

        expect(assigned[:npcs]).to eq(['Zasele'])
      end
    end

    it 'never reparses main-stream views after a complete component' do
      feed("<component id='room objs'>You also see a rock and <pushBold/>a goblin<popBold/>.</component>")
      writes.clear
      feed('<style id=""/>  You also see a rock and <pushBold/>a goblin<popBold/>.', full_view)

      expect(writes).to be_empty
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

    it 'parses a nested item, stripping a leading article' do
      expect(GameObj).to receive(:new_inv).with('12345', nil, 'small pouch', '9', 'get #12345 in #9', nil)
      described_class.populate_inventory_get("<d cmd='get #12345 in #9'>a small pouch</d>")
    end

    it 'strips a capitalized leading article (e.g. from INV SEARCH output)' do
      expect(GameObj).to receive(:new_inv).with('12345', nil, 'soft gem pouch', '9', 'get #12345 in #9', nil)
      described_class.populate_inventory_get("<d cmd='get #12345 in #9'>A soft gem pouch</d>")
    end

    # The worn list belongs to the worn-items stream. A line with no container
    # stored here replaced the stream's entries with noun-less copies until the
    # next hand change (at every login, the game's own INV LIST did this).
    it 'does not store a top-level item (no container)' do
      expect(GameObj).not_to receive(:new_inv)
      expect(GameObj).not_to receive(:upsert_inv)
      described_class.populate_inventory_get("<d cmd='get #12345'>a small pouch</d>")
    end

    it 'parses a nested item with its container' do
      expect(GameObj).to receive(:new_inv).with('1', nil, 'sack', '2', 'get #1 in #2', nil)
      described_class.populate_inventory_get("<d cmd='get #1 in #2'>a sack</d>")
    end

    it 'parses an item line with trailing location prose after the </d> element' do
      expect(GameObj).to receive(:new_inv).with('8286821', nil, 'papyrus parchment', '8286816', 'get #8286821 in #8286816', nil)
      described_class.populate_inventory_get("<d cmd='get #8286821 in #8286816'>a papyrus parchment</d> is in a black winter cloak.")
    end

    it 'does NOT store a held item ("... is in your right hand") as worn inventory' do
      # The item is in a hand, tracked by the <right> stream -- storing it here
      # (cmd has no container -> worn inv) would recreate the held/worn duplicate.
      expect(GameObj).not_to receive(:new_inv)
      expect(GameObj).not_to receive(:upsert_inv)
      expect(GameObj).to receive(:remove_inv_item).with('8761784')
      described_class.populate_inventory_get("<d cmd='get #8761784'>a seagull feather quill</d> is in your right hand.")
    end

    it 'also skips the worn store for a left-hand item' do
      expect(GameObj).not_to receive(:new_inv)
      expect(GameObj).to receive(:remove_inv_item).with('8761784')
      described_class.populate_inventory_get("<d cmd='get #8761784'>a seagull feather quill</d> is in your left hand.")
    end

    it 'does not store an inv list worn item (remove link): the worn-items stream owns it' do
      expect(GameObj).not_to receive(:new_inv)
      expect(GameObj).not_to receive(:remove_inv_item)
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

      it 'does not upsert a matched worn item (remove link): the worn-items stream owns it' do
        expect(GameObj).not_to receive(:upsert_inv)
        expect(GameObj).not_to receive(:new_inv)
        described_class.populate_inventory_get("  <d cmd='remove #11404268'>A red pouch embroidered with a pork chop</d> is being worn.")
      end

      it 'does not file an item lying at your feet anywhere (it is not carried)' do
        expect(GameObj).not_to receive(:upsert_inv)
        expect(GameObj).not_to receive(:new_inv)
        expect(GameObj).not_to receive(:remove_inv_item)
        described_class.populate_inventory_get("<d cmd='get #8761784'>A seagull feather quill with dyed snowy white barbs</d> is lying at your feet.")
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

  # The worn list belongs to the worn-items stream (pushStream id='inv'); the
  # INV LIST and INV SEARCH scrapes write container contents only. Every line
  # goes through the real XMLParser, then DRParser.parse, in the order
  # Game.process_xml_data and process_game_specific_data run them. Lines and
  # ids are verbatim from Quilsilgas' 2026-11-08 09:26 login, where the game
  # sent the worn list first and its own INV LIST about 180 lines later.
  describe 'worn-items stream and the INV LIST scrape together (real XMLParser + GameObj)' do
    let(:xml) { Lich::Common::XMLParser.new }

    worn_push = [
      '<clearStream id=\'inv\' ifClosed=\'\'/><pushStream id=\'inv\'/>Your worn items are:',
      '  a <a exist="15705096" noun="crystal">sanowret crystal</a>',
      '  <a exist="15705095" noun="zills">some polished thin-edged zills with silvered esoteric filigree</a>',
      '  a <a exist="15705078" noun="pack">spidersilk traveler\'s pack dyed with shifting hues of red and black</a>',
      '  a <a exist="15705077" noun="bag">heartname leather thigh bag edged in cloud turquoise beading</a>',
      '  a <a exist="15705076" noun="charm">divine charm</a>',
      '  a <a exist="15705070" noun="pack">canvas scribe\'s pack</a>',
      '  a <a exist="15705069" noun="jerkin">leather jerkin</a>',
      '  <a exist="15705068" noun="vambraces">some buckled leather vambraces</a>',
      '  a <a exist="15705067" noun="skirt">flowing blue skirt</a>',
      '<popStream/>'
    ].freeze

    inv_list = [
      'You take a moment and rummage about your person, taking stock of your possessions...',
      'You have:',
      '  <d cmd=\'remove #15705096\'>sanowret crystal</d>',
      '  <d cmd=\'remove #15705095\'>thin-edged zills</d>',
      '  <d cmd=\'remove #15705078\'>traveler\'s pack</d>',
      '     -<d cmd=\'get #15705079 in #15705078\'>duffel bag</d>',
      '        -<d cmd=\'get #15705094 in #15705079 in #15705078\'>traveler\'s pack</d>',
      '        -<d cmd=\'get #15705093 in #15705079 in #15705078\'>traveler\'s pack</d>',
      '        -<d cmd=\'get #15705092 in #15705079 in #15705078\'>traveler\'s pack</d>',
      '        -<d cmd=\'get #15705091 in #15705079 in #15705078\'>traveler\'s pack</d>',
      '        -<d cmd=\'get #15705090 in #15705079 in #15705078\'>traveler\'s pack</d>',
      '        -<d cmd=\'get #15705089 in #15705079 in #15705078\'>traveler\'s pack</d>',
      '        -<d cmd=\'get #15705088 in #15705079 in #15705078\'>traveler\'s pack</d>',
      '        -<d cmd=\'get #15705087 in #15705079 in #15705078\'>traveler\'s pack</d>',
      '        -<d cmd=\'get #15705086 in #15705079 in #15705078\'>traveler\'s pack</d>',
      '        -<d cmd=\'get #15705082 in #15705079 in #15705078\'>traveler\'s pack</d>',
      '           -<d cmd=\'get #15705085 in #15705082 in #15705079 in #15705078\'>traveler\'s pack</d>',
      '           -<d cmd=\'get #15705084 in #15705082 in #15705079 in #15705078\'>traveler\'s pack</d>',
      '           -<d cmd=\'get #15705083 in #15705082 in #15705079 in #15705078\'>traveler\'s pack</d>',
      '        -<d cmd=\'get #15705080 in #15705079 in #15705078\'>traveler\'s pack</d>',
      '           -<d cmd=\'get #15705081 in #15705080 in #15705079 in #15705078\'>traveler\'s pack</d>',
      '  <d cmd=\'remove #15705077\'>thigh bag</d>',
      '  <d cmd=\'remove #15705076\'>divine charm</d>',
      '  <d cmd=\'remove #15705070\'>scribe\'s pack</d>',
      '     -<d cmd=\'get #15705075 in #15705070\'>faience necklace</d>',
      '     -<d cmd=\'get #15705074 in #15705070\'>bronze rapier</d>',
      '     -<d cmd=\'get #15705073 in #15705070\'>ice skates</d>',
      '     -<d cmd=\'get #15705072 in #15705070\'>jade bowl</d>',
      '     -<d cmd=\'get #15705071 in #15705070\'>Albreda lollipop</d>',
      '  <d cmd=\'remove #15705069\'>leather jerkin</d>',
      '  <d cmd=\'remove #15705068\'>leather vambraces</d>',
      '  <d cmd=\'remove #15705067\'>blue skirt</d>',
      '<output class=""/>'
    ].freeze

    def feed(*lines)
      lines.flatten.each do |line|
        Ox.sax_parse(xml, line, convert_special: false, symbolize: false, skip: :skip_none)
        described_class.parse(line.dup)
      end
    end

    def worn_by_id
      Array(GameObj.inv).to_h { |o| [o.id, [o.noun, o.name]] }
    end

    def contents_ids(id) = Array(GameObj.containers[id]).map(&:id)

    before(:each) do
      require_relative '../../../../lib/common/xmlparser'
      allow(XMLData).to receive(:game).and_return('DR')
      # In production XMLData is this parser: DRParser asks it whether the
      # stream is linked.
      allow(XMLData).to receive(:stream_feature?) { |feature| xml.stream_feature?(feature) }
      xml.instance_variable_set(:@game, 'DR')
      GameObj.clear_inv
      GameObj.clear_all_containers
      GameObj.discard_staged_refreshes
      described_class.class_variable_set(:@@parsing_inventory_get, false)
      described_class.class_variable_set(:@@inventory_partial, false)
    end

    it 'keeps the stream\'s nouns and long names after the login INV LIST, and fills the containers' do
      feed(worn_push)
      before_listing = worn_by_id
      expect(before_listing['15705095']).to eq(['zills', 'some polished thin-edged zills with silvered esoteric filigree'])

      feed(inv_list)

      expect(worn_by_id).to eq(before_listing)
      expect(Array(GameObj.inv).map(&:id)).to eq(%w[15705096 15705095 15705078 15705077 15705076 15705070 15705069 15705068 15705067])
      expect(contents_ids('15705078')).to eq(['15705079'])
      expect(contents_ids('15705079').size).to eq(11)
      expect(contents_ids('15705082')).to eq(%w[15705085 15705084 15705083])
      expect(contents_ids('15705080')).to eq(['15705081'])
      expect(contents_ids('15705070')).to eq(%w[15705075 15705074 15705073 15705072 15705071])
      expect(GameObj.containers['15705070'].map(&:name)).to include('ice skates', 'Albreda lollipop')
    end

    it 'never creates worn entries from an INV LIST that arrives before any worn list' do
      # Any linked element marks the stream as linked (the login burst has many).
      feed('<component id=\'room objs\'>You also see a <a exist="96365" noun="bucket">large waste bucket</a>.</component>')
      feed(inv_list)
      expect(GameObj.inv).to be_nil
      expect(contents_ids('15705070').size).to eq(5)

      feed(worn_push)
      expect(worn_by_id['15705095']&.first).to eq('zills')
      expect(contents_ids('15705070').size).to eq(5)
    end

    it 'does not merge a worn list that arrives in the middle of an INV LIST into the listing' do
      # A Saga session has sent linked items long before any listing (room
      # objects, the login worn list); only a legacy session has none.
      feed('<component id=\'room objs\'>You also see a <a exist="96365" noun="bucket">large waste bucket</a>.</component>')
      feed(inv_list[0..5])
      feed(worn_push)
      feed(inv_list[6..])

      ids = Array(GameObj.inv).map(&:id)
      expect(ids.size).to eq(9)
      expect(ids.uniq).to eq(ids)
      expect(Array(GameObj.inv).map(&:noun)).to all(be_a(String))
      expect(contents_ids('15705079').size).to eq(11)
    end

    it 'leaves a worn item alone when INV SEARCH reports it as worn' do
      feed(worn_push)
      before_search = Array(GameObj.inv).map { |o| [o.id, o.noun, o.name] }

      feed("<roundTime value='1794083168'/>You rummage about your person, looking for zills...",
           "  <d cmd='remove #15705095'>Some thin-edged zills</d> is being worn.",
           '<output class=""/>')

      expect(Array(GameObj.inv).map { |o| [o.id, o.noun, o.name] }).to eq(before_search)
    end

    # A front end handshake kept with --keep-fe-string gets the legacy stream:
    # its worn list is plain text, so the scrapes stay its only worn source.
    context 'on the legacy stream (no linked items seen)' do
      legacy_worn_push = [
        "<clearStream id='inv' ifClosed=''/><pushStream id='inv'/>Your worn items are:",
        "  a canvas scribe's pack",
        '  a leather jerkin',
        '<popStream/>'
      ].freeze

      it 'still fills the worn list from INV LIST, and from INV SEARCH' do
        feed(legacy_worn_push)
        expect(xml.stream_feature?(:links)).to be false

        feed(inv_list)
        expect(Array(GameObj.inv).map(&:id)).to eq(%w[15705096 15705095 15705078 15705077 15705076 15705070 15705069 15705068 15705067])
        expect(contents_ids('15705070').size).to eq(5)

        GameObj.clear_inv
        feed("<roundTime value='1794083168'/>You rummage about your person, looking for jerkin...",
             "  <d cmd='remove #15705069'>A leather jerkin</d> is being worn.",
             '<output class=""/>')
        expect(Array(GameObj.inv).map { |o| [o.id, o.name] }).to eq([['15705069', 'leather jerkin']])
      end

      it 'discards the staged worn list too when the INV LIST is cut off' do
        feed(legacy_worn_push, inv_list)
        before_cut = Array(GameObj.inv).map(&:id)
        expect(Lich::Messaging).to receive(:msg).with('warn', /inv list.*did not finish/i)

        feed(inv_list[0..2], '<prompt time="1794083170">&gt;</prompt>')

        expect(Array(GameObj.inv).map(&:id)).to eq(before_cut)
        expect(GameObj.inv_refresh_open?).to be false
      end
    end

    it 'keeps the worn list and the previous contents when the INV LIST is cut off by a prompt' do
      feed(worn_push, inv_list)
      before_cut = [worn_by_id, contents_ids('15705070')]
      expect(Lich::Messaging).to receive(:msg).with('warn', /inv list.*did not finish/i)

      feed(inv_list[0..2], '<prompt time="1794083170">&gt;</prompt>')

      expect([worn_by_id, contents_ids('15705070')]).to eq(before_cut)
    end
  end
end
