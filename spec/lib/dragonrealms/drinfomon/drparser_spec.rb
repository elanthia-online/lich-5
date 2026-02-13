# frozen_string_literal: true

require 'rspec'

# Mock dependencies
module Lich
  module DragonRealms
    DR_BALANCE_VALUES = %w[
      completely hopelessly extremely very\ badly badly somewhat\ off
      off slightly\ off solidly nimbly adeptly incredibly
    ].freeze unless defined?(DR_BALANCE_VALUES)

    DR_LEARNING_RATES = %w[
      clear dabbling perusing learning thoughtful thinking considering
      pondering ruminating concentrating attentive deliberative interested
      examining understanding absorbing intrigued scrutinizing analyzing
      studious focused very\ focused engaged very\ engaged cogitating
      fascinated captivated engrossed riveted very\ riveted rapt
      very\ rapt enthralled nearly\ locked mind\ lock
    ].freeze unless defined?(DR_LEARNING_RATES)

    module DRStats
      @gender = nil
      @age = 0
      @circle = 0
      @race = nil
      @guild = nil
      @encumbrance = nil
      @luck = 0
      @tdps = 0
      @favors = 0
      @balance = 8

      class << self
        attr_accessor :gender, :age, :circle, :race, :guild, :encumbrance, :luck, :tdps, :favors, :balance

        def strength=(val); end

        def agility=(val); end

        def discipline=(val); end

        def intelligence=(val); end

        def reflex=(val); end

        def charisma=(val); end

        def wisdom=(val); end

        def stamina=(val); end
      end
    end unless defined?(Lich::DragonRealms::DRStats)

    module DRSpells
      @grabbing_known_spells = false
      @grabbing_known_khri = false
      @check_known_barbarian_abilities = false
      @known_spells = {}
      @known_feats = {}
      @spellbook_format = nil

      class << self
        attr_accessor :grabbing_known_spells, :grabbing_known_khri, :check_known_barbarian_abilities, :spellbook_format

        def known_spells
          @known_spells
        end

        def known_feats
          @known_feats
        end
      end
    end unless defined?(Lich::DragonRealms::DRSpells)

    class DRRoom
      @@pcs = []
      @@pcs_prone = []
      @@pcs_sitting = []
      @@npcs = []
      @@dead_npcs = []
      @@room_objs = []
      @@group_members = []

      class << self
        def pcs; @@pcs; end

        def pcs=(val); @@pcs = val; end

        def pcs_prone; @@pcs_prone; end

        def pcs_prone=(val); @@pcs_prone = val; end

        def pcs_sitting; @@pcs_sitting; end

        def pcs_sitting=(val); @@pcs_sitting = val; end

        def npcs; @@npcs; end

        def npcs=(val); @@npcs = val; end

        def dead_npcs; @@dead_npcs; end

        def dead_npcs=(val); @@dead_npcs = val; end

        def room_objs; @@room_objs; end

        def room_objs=(val); @@room_objs = val; end

        def group_members; @@group_members; end

        def group_members=(val); @@group_members = val; end
      end
    end unless defined?(Lich::DragonRealms::DRRoom)

    class DRSkill
      @@exp_modifiers = {}

      class << self
        def update(name, rank, exp, percent); end

        def clear_mind(skill); end

        def exp_modifiers
          @@exp_modifiers
        end

        def update_mods(name, value)
          @@exp_modifiers[name] = value
        end

        def update_rested_exp(stored, usable, refresh); end
      end
    end unless defined?(Lich::DragonRealms::DRSkill)

    module DRExpMonitor
      def self.inline_display?
        false
      end

      def self.format_briefexp_on(line, _skill)
        line
      end

      def self.format_briefexp_off(line, _skill, _rate)
        line
      end
    end unless defined?(Lich::DragonRealms::DRExpMonitor)

    class Flags
      @@flags = {}
      @@matchers = {}

      class << self
        def flags
          @@flags
        end

        def matchers
          @@matchers
        end
      end
    end unless defined?(Lich::DragonRealms::Flags)
  end

  # Mock Messaging module for specs
  module Messaging
    def self.msg(type, message)
      # Capture messages for test assertions
      @messages ||= []
      @messages << { type: type, message: message }
    end

    def self.messages
      @messages ||= []
    end

    def self.clear_messages!
      @messages = []
    end
  end unless defined?(Lich::Messaging)
end

# NOTE: Do NOT define GameObj at top level here - it would block qstrike_spec's own GameObj setup.
# The tests in this file don't trigger GameObj code paths, so no mock is needed.
# If future tests need GameObj, stub it in a before(:each) block instead.

# Mock UserVars
module UserVars
  @npcs = []
  @account_type = nil
  @premium = false

  class << self
    attr_accessor :npcs, :account_type, :premium
  end
end unless defined?(UserVars)

# Mock Account
module Account
  @name = nil
  @subscription = nil

  class << self
    attr_accessor :name, :subscription
  end
end unless defined?(Account)

# Mock XMLData
module XMLData
  def self.game
    'DR'
  end
end unless defined?(XMLData)

# Mock global methods
def put(cmd); end

def find_pcs(_players)
  []
end

def find_pcs_prone(_players)
  []
end

def find_pcs_sitting(_players)
  []
end

def find_npcs(_objs)
  []
end

def find_dead_npcs(_objs)
  []
end

def find_objects(_objs)
  []
end

# Load the module under test
require_relative '../../../../lib/dragonrealms/drinfomon/drparser'

# Create aliases
DRParser = Lich::DragonRealms::DRParser unless defined?(DRParser)
DRStats = Lich::DragonRealms::DRStats unless defined?(DRStats)
DRSpells = Lich::DragonRealms::DRSpells unless defined?(DRSpells)
DRRoom = Lich::DragonRealms::DRRoom unless defined?(DRRoom)
DRSkill = Lich::DragonRealms::DRSkill unless defined?(DRSkill)
DRExpMonitor = Lich::DragonRealms::DRExpMonitor unless defined?(DRExpMonitor)
Flags = Lich::DragonRealms::Flags unless defined?(Flags)

RSpec.describe Lich::DragonRealms::DRParser do
  before(:each) do
    DRParser.instance_variable_set(:@parsing_exp_mods_output, false)
    DRParser.instance_variable_set(:@parsing_inventory_get, false)
    DRStats.gender = nil
    DRStats.age = 0
    DRStats.circle = 0
    DRStats.race = nil
    DRStats.guild = nil
    DRStats.encumbrance = nil
    DRStats.luck = 0
    DRStats.tdps = 0
    DRStats.favors = 0
    DRSpells.grabbing_known_spells = false
    DRSpells.grabbing_known_khri = false
    DRSpells.check_known_barbarian_abilities = false
    Account.name = nil
    Account.subscription = nil
    DRSkill.exp_modifiers.clear
  end

  describe 'Pattern constants' do
    describe 'GenderAgeCircle' do
      it 'matches gender/age/circle line from INFO' do
        line = "Gender:  Male         Age:  42              Circle:  150"
        match = line.match(DRParser::Pattern::GenderAgeCircle)
        expect(match).not_to be_nil
        expect(match[:gender].strip).to eq('Male')
        expect(match[:age].to_i).to eq(42)
        expect(match[:circle].to_i).to eq(150)
      end
    end

    describe 'NameRaceGuild' do
      it 'matches name/race/guild line from INFO' do
        line = "Name:  Mahtra Lansen             Race:  Elothean         Guild:  Moon Mage  "
        match = line.match(DRParser::Pattern::NameRaceGuild)
        expect(match).not_to be_nil
        expect(match[:race].strip).to eq('Elothean')
        expect(match[:guild].strip).to eq('Moon Mage')
      end
    end

    describe 'TDPValue' do
      it 'matches TDP line using named capture' do
        line = "You have 1234 TDPs."
        match = line.match(DRParser::Pattern::TDPValue)
        expect(match).not_to be_nil
        expect(match[:tdp].to_i).to eq(1234)
      end
    end

    describe 'RoomPlayers' do
      it 'matches room players with named capture' do
        line = "'room players'>Also here: Mahtra and Quilsilgas.</component>"
        match = line.match(DRParser::Pattern::RoomPlayers)
        expect(match).not_to be_nil
        expect(match[:players]).to eq('Mahtra and Quilsilgas')
      end
    end

    describe 'RoomObjs' do
      it 'matches room objects with named capture' do
        line = "'room objs'>You also see a <pushBold/>goblin<popBold/>.</component>"
        match = line.match(DRParser::Pattern::RoomObjs)
        expect(match).not_to be_nil
        expect(match[:objs]).to include('goblin')
      end
    end

    describe 'GroupMembers' do
      it 'matches group member with named capture' do
        line = '<pushStream id="group"/>  Mahtra:'
        match = line.match(DRParser::Pattern::GroupMembers)
        expect(match).not_to be_nil
        expect(match[:member]).to eq('Mahtra')
      end
    end

    describe 'ExpModLine' do
      it 'matches positive modifier' do
        line = '<preset id="speech">+79 Attunement</preset>'
        match = line.strip.match(DRParser::Pattern::ExpModLine)
        expect(match).not_to be_nil
        expect(match[:sign]).to eq('+')
        expect(match[:value]).to eq('79')
        expect(match[:skill].strip).to eq('Attunement')
      end

      it 'matches negative modifier' do
        line = '-10 Evasion'
        match = line.strip.match(DRParser::Pattern::ExpModLine)
        expect(match).not_to be_nil
        expect(match[:sign]).to eq('-')
        expect(match[:value]).to eq('10')
        expect(match[:skill].strip).to eq('Evasion')
      end
    end

    describe 'PlayedSubscription' do
      it 'matches subscription types' do
        %w[F2P Basic Premium Platinum].each do |sub|
          line = "Current Account Status: #{sub}"
          match = line.match(DRParser::Pattern::PlayedSubscription)
          expect(match).not_to be_nil
          expect(match[:subscription]).to eq(sub)
        end
      end
    end

    describe 'LastLogoff' do
      it 'matches logoff timestamp' do
        line = "   Logoff :  Mon Feb 10 15:30:45 ET 2026"
        match = line.match(DRParser::Pattern::LastLogoff)
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
        match = line.match(DRParser::Pattern::Rested_EXP)
        expect(match).not_to be_nil
        expect(match[:stored].strip).to eq('4:38 hours')
        expect(match[:usable].strip).to eq('38 minutes')
        expect(match[:refresh].strip).to eq('2 hours')
      end
    end

    describe 'BriefExpOn' do
      it 'matches BRIEFEXP ON format' do
        line = "<component id='exp Evasion'><d cmd='skill Evasion'>     Eva:  565 39%  [ 2/34]</d></component>"
        match = line.match(DRParser::Pattern::BriefExpOn)
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
        match = line.match(DRParser::Pattern::BriefExpOff)
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
        line = "Gender:  Female       Age:  25              Circle:  100"
        DRParser.parse(line)

        expect(DRStats.gender.strip).to eq('Female')
        expect(DRStats.age).to eq(25)
        expect(DRStats.circle).to eq(100)
      end
    end

    describe 'name/race/guild parsing' do
      it 'sets DRStats values from INFO output' do
        line = "Name:  Mahtra Lansen             Race:  Elothean         Guild:  Moon Mage  "
        DRParser.parse(line)

        expect(DRStats.race.strip).to eq('Elothean')
        expect(DRStats.guild.strip).to eq('Moon Mage')
      end
    end

    describe 'encumbrance parsing' do
      it 'sets encumbrance from INFO output' do
        line = "   Encumbrance    :  Light Burden"
        DRParser.parse(line)

        expect(DRStats.encumbrance.strip).to eq('Light Burden')
      end
    end

    describe 'luck parsing' do
      it 'sets luck from INFO output' do
        line = "   Luck           :  Average (2/3)"
        DRParser.parse(line)

        expect(DRStats.luck).to eq(2)
      end

      it 'handles negative luck' do
        line = "   Luck           :  Bad (-1/3)"
        DRParser.parse(line)

        expect(DRStats.luck).to eq(-1)
      end
    end

    describe 'TDP parsing' do
      it 'sets TDPs from INFO output' do
        line = "You have 5000 TDPs."
        DRParser.parse(line)

        expect(DRStats.tdps).to eq(5000)
      end

      it 'sets TDPs from exp window' do
        line = "<component id='exp tdp'>  TDPs:  1234</component>"
        DRParser.parse(line)

        expect(DRStats.tdps).to eq(1234)
      end
    end

    describe 'favor parsing' do
      it 'sets favors from exp window' do
        line = "<component id='exp favor'>  Favors:  7</component>"
        DRParser.parse(line)

        expect(DRStats.favors).to eq(7)
      end
    end

    describe 'room players parsing' do
      it 'clears PCs on empty room' do
        DRRoom.pcs = ['OldPlayer']
        line = "'room players'></component>"
        DRParser.parse(line)

        expect(DRRoom.pcs).to eq([])
      end
    end

    describe 'room objects parsing' do
      it 'clears room data on empty room' do
        DRRoom.npcs = ['goblin']
        DRRoom.dead_npcs = ['dead goblin']
        DRRoom.room_objs = ['sword']
        line = "'room objs'></component>"
        DRParser.parse(line)

        expect(DRRoom.npcs).to eq([])
        expect(DRRoom.dead_npcs).to eq([])
        expect(DRRoom.room_objs).to eq([])
      end
    end

    describe 'group members parsing' do
      it 'clears group on empty group' do
        DRRoom.group_members = ['OldMember']
        line = '<pushStream id="group"/>Members of your group:'
        DRParser.parse(line)

        expect(DRRoom.group_members).to eq([])
      end

      it 'adds group member' do
        DRRoom.group_members = []
        line = '<pushStream id="group"/>  Mahtra:'
        DRParser.parse(line)

        expect(DRRoom.group_members).to include('Mahtra')
      end
    end

    describe 'account parsing' do
      it 'sets account name' do
        Account.name = nil
        line = "Account Info for TESTACCOUNT:"
        DRParser.parse(line)

        expect(Account.name).to eq('TESTACCOUNT')
      end

      it 'sets subscription type' do
        Account.subscription = nil
        line = "Current Account Status: Premium"
        DRParser.parse(line)

        expect(Account.subscription).to eq('PREMIUM')
      end

      it 'normalizes Basic to Normal' do
        Account.subscription = nil
        line = "Current Account Status: Basic"
        DRParser.parse(line)

        expect(Account.subscription).to eq('NORMAL')
      end

      it 'normalizes F2P to Free' do
        Account.subscription = nil
        line = "Current Account Status: F2P"
        DRParser.parse(line)

        expect(Account.subscription).to eq('FREE')
      end
    end

    describe 'rested exp parsing' do
      it 'calls update_rested_exp with parsed values' do
        expect(DRSkill).to receive(:update_rested_exp).with('4:38 hours', '38 minutes', '2 hours')
        line = "<component id='exp rexp'>Rested EXP Stored:  4:38 hours  Usable This Cycle:  38 minutes  Cycle Refreshes:  2 hours</component>"
        DRParser.parse(line)
      end

      it 'handles F2P rested exp' do
        expect(DRSkill).to receive(:update_rested_exp).with('none', 'none', 'none')
        line = "<component id='exp rexp'>[Unlock Rested Experience"
        DRParser.parse(line)
      end
    end

    describe 'RoomID warning' do
      it 'sends warning message when RoomID is turned off' do
        expect(Lich::Messaging).to receive(:msg).with("bold", /DRParser:.*ShowRoomID/)
        expect(Lich::Messaging).to receive(:msg).with("plain", /DRParser:.*flaguid/)
        line = "You will no longer see room IDs when LOOKing in the game and room windows."
        DRParser.parse(line)
      end
    end

    describe 'error handling' do
      it 'catches and logs errors without crashing' do
        allow(DRStats).to receive(:gender=).and_raise(StandardError.new("Test error"))
        expect(Lich::Messaging).to receive(:msg).with("bold", /DRParser:.*error/)
        expect(Lich::Messaging).to receive(:msg).with("bold", /DRParser:.*line/)
        expect(Lich).to receive(:log).at_least(:once)

        line = "Gender:  Male         Age:  42              Circle:  150"
        expect { DRParser.parse(line) }.not_to raise_error
      end
    end
  end

  describe '.check_exp_mods' do
    before(:each) do
      DRParser.instance_variable_set(:@parsing_exp_mods_output, true)
    end

    it 'parses positive modifier' do
      line = '<preset id="speech">+79 Attunement</preset>'
      DRParser.check_exp_mods(line)

      expect(DRSkill.exp_modifiers['Attunement']).to eq(79)
    end

    it 'parses negative modifier' do
      line = '-10 Evasion'
      DRParser.check_exp_mods(line)

      expect(DRSkill.exp_modifiers['Evasion']).to eq(-10)
    end

    it 'stops parsing on output class end tag' do
      DRParser.check_exp_mods('<output class=""/>')

      expect(DRParser.instance_variable_get(:@parsing_exp_mods_output)).to be false
    end
  end

  describe '.check_events' do
    it 'matches flags and sets values' do
      Flags.matchers[:test_flag] = [/test pattern/]
      Flags.flags[:test_flag] = false

      DRParser.check_events('this is a test pattern here')

      expect(Flags.flags[:test_flag]).to be_truthy
    end
  end
end
