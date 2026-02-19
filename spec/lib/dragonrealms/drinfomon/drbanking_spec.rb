# frozen_string_literal: true

require 'rspec'

# Mock XMLData module
module XMLData
  class << self
    attr_accessor :name, :room_title, :game
  end
end unless defined?(XMLData)

# Mock GameSettings module
module GameSettings
  @data = {}

  def self.[](key)
    @data[key]
  end

  def self.[]=(key, value)
    @data[key] = value
  end

  def self.clear_test_data!
    @data = {}
  end
end unless defined?(GameSettings)

# Mock Lich::Messaging
module Lich
  module Messaging
    @messages = []

    def self.msg(_style, message)
      @messages << message
    end

    def self.messages
      @messages
    end

    def self.clear_messages!
      @messages = []
    end
  end
end unless defined?(Lich::Messaging)

# Load dependencies
require_relative '../../../../lib/dragonrealms/drinfomon/drvariables'
require_relative '../../../../lib/dragonrealms/drinfomon/drbanking'

RSpec.describe Lich::DragonRealms::DRBanking do
  let(:described_module) { Lich::DragonRealms::DRBanking }

  before(:each) do
    # Reset test state
    GameSettings.clear_test_data!
    Lich::Messaging.clear_messages!

    # Set up default XMLData values
    XMLData.name = 'TestChar'
    XMLData.room_title = ''
    XMLData.game = 'DRF'
  end

  describe 'Pattern constants' do
    describe 'DEPOSIT_PORTION' do
      let(:pattern) { described_module::Pattern::DEPOSIT_PORTION }

      it 'matches deposit with platinum Kronars' do
        line = 'The clerk slides a small metal box across the counter into which you drop 5 platinum Kronars'
        match = pattern.match(line)
        expect(match).not_to be_nil
        expect(match[:amount]).to eq('5')
        expect(match[:denomination]).to eq('platinum')
        expect(match[:currency]).to eq('Kronars')
      end

      it 'matches deposit with gold Lirums' do
        line = 'The clerk slides a small metal box across the counter into which you drop 100 gold Lirums'
        match = pattern.match(line)
        expect(match).not_to be_nil
        expect(match[:amount]).to eq('100')
        expect(match[:denomination]).to eq('gold')
        expect(match[:currency]).to eq('Lirums')
      end

      it 'matches deposit with copper Dokoras' do
        line = 'The clerk slides a small metal box across the counter into which you drop 50 copper Dokoras'
        match = pattern.match(line)
        expect(match).not_to be_nil
        expect(match[:amount]).to eq('50')
        expect(match[:denomination]).to eq('copper')
        expect(match[:currency]).to eq('Dokoras')
      end

      it 'does not match unrelated text' do
        line = 'You give the clerk some coins.'
        expect(pattern.match(line)).to be_nil
      end
    end

    describe 'DEPOSIT_ALL_TELLER' do
      let(:pattern) { described_module::Pattern::DEPOSIT_ALL_TELLER }

      it 'matches deposit all Kronars' do
        line = 'The clerk slides a small metal box across the counter into which you drop all your Kronars.  She counts them carefully and records the deposit in her ledger'
        expect(pattern.match(line)).not_to be_nil
      end

      it 'matches deposit all Lirums' do
        line = 'The clerk slides a small metal box across the counter into which you drop all your Lirums.  She counts them carefully and records the deposit in her ledger'
        expect(pattern.match(line)).not_to be_nil
      end

      it 'matches deposit all Dokoras' do
        line = 'The clerk slides a small metal box across the counter into which you drop all your Dokoras.  She counts them carefully and records the deposit in her ledger'
        expect(pattern.match(line)).not_to be_nil
      end
    end

    describe 'DEPOSIT_ALL_JAR' do
      let(:pattern) { described_module::Pattern::DEPOSIT_ALL_JAR }

      it 'matches jar bank deposit' do
        line = 'You cross through the old balance on the label and update it to reflect your new balance'
        expect(pattern.match(line)).not_to be_nil
      end
    end

    describe 'WITHDRAW_PORTION' do
      let(:pattern) { described_module::Pattern::WITHDRAW_PORTION }

      it 'matches clerk withdraw' do
        line = 'The clerk counts out 5 gold Kronars and hands them over, making a notation in her ledger'
        match = pattern.match(line)
        expect(match).not_to be_nil
        expect(match[:amount]).to eq('5')
        expect(match[:denomination]).to eq('gold')
        expect(match[:currency]).to eq('Kronars')
      end

      it 'matches jar withdraw' do
        line = 'You count out 10 silver Dokoras and quickly pocket them, updating the notation on your jar'
        match = pattern.match(line)
        expect(match).not_to be_nil
        expect(match[:amount]).to eq('10')
        expect(match[:denomination]).to eq('silver')
        expect(match[:currency]).to eq('Dokoras')
      end
    end

    describe 'WITHDRAW_ALL' do
      let(:pattern) { described_module::Pattern::WITHDRAW_ALL }

      it 'matches clerk withdraw all' do
        line = 'The clerk counts out all your Kronars and hands them over'
        expect(pattern.match(line)).not_to be_nil
      end

      it 'matches jar withdraw all' do
        line = 'You count out all of your Dokoras and quickly pocket them'
        expect(pattern.match(line)).not_to be_nil
      end
    end

    describe 'BALANCE_CHECK' do
      let(:pattern) { described_module::Pattern::BALANCE_CHECK }

      it 'matches "it looks like" balance check' do
        line = 'it looks like your current balance is 5 platinum Kronars'
        match = pattern.match(line)
        expect(match).not_to be_nil
      end

      it 'matches "Here we are" balance check' do
        line = '"Here we are. Your current balance is 10 gold, 5 silver Lirums'
        match = pattern.match(line)
        expect(match).not_to be_nil
      end

      it 'matches "As expected" balance check' do
        line = 'As expected, there are 100 copper Dokoras'
        match = pattern.match(line)
        expect(match).not_to be_nil
      end
    end

    describe 'NO_ACCOUNT' do
      let(:pattern) { described_module::Pattern::NO_ACCOUNT }

      it 'matches no account at teller bank' do
        line = 'you do not seem to have an account with us'
        expect(pattern.match(line)).not_to be_nil
      end

      it 'matches no account at jar bank' do
        line = 'you should find a new deposit jar for your financial needs'
        expect(pattern.match(line)).not_to be_nil
      end
    end
  end

  describe 'DENOMINATION_VALUES constant' do
    it 'is frozen' do
      expect(described_module::DENOMINATION_VALUES).to be_frozen
    end

    it 'has correct values for platinum' do
      expect(described_module::DENOMINATION_VALUES['platinum']).to eq(10_000)
    end

    it 'has correct values for gold' do
      expect(described_module::DENOMINATION_VALUES['gold']).to eq(1_000)
    end

    it 'has correct values for silver' do
      expect(described_module::DENOMINATION_VALUES['silver']).to eq(100)
    end

    it 'has correct values for bronze' do
      expect(described_module::DENOMINATION_VALUES['bronze']).to eq(10)
    end

    it 'has correct values for copper' do
      expect(described_module::DENOMINATION_VALUES['copper']).to eq(1)
    end
  end

  describe '.to_copper' do
    it 'converts platinum correctly' do
      expect(described_module.to_copper(5, 'platinum')).to eq(50_000)
    end

    it 'converts gold correctly' do
      expect(described_module.to_copper(10, 'gold')).to eq(10_000)
    end

    it 'converts silver correctly' do
      expect(described_module.to_copper(25, 'silver')).to eq(2_500)
    end

    it 'converts bronze correctly' do
      expect(described_module.to_copper(50, 'bronze')).to eq(500)
    end

    it 'converts copper correctly' do
      expect(described_module.to_copper(100, 'copper')).to eq(100)
    end

    it 'handles string amounts' do
      expect(described_module.to_copper('5', 'platinum')).to eq(50_000)
    end

    it 'is case insensitive' do
      expect(described_module.to_copper(5, 'PLATINUM')).to eq(50_000)
      expect(described_module.to_copper(5, 'Platinum')).to eq(50_000)
    end

    it 'returns amount as-is for unknown denomination' do
      expect(described_module.to_copper(100, 'unknown')).to eq(100)
    end
  end

  describe '.parse_balance_string' do
    it 'parses single denomination' do
      expect(described_module.parse_balance_string('5 platinum')).to eq(50_000)
    end

    it 'parses multiple denominations' do
      expect(described_module.parse_balance_string('5 platinum, 3 gold, 2 silver')).to eq(53_200)
    end

    it 'parses complex balance string' do
      expect(described_module.parse_balance_string('1 platinum, 2 gold, 3 silver, 4 bronze, 5 copper')).to eq(12_345)
    end

    it 'returns 0 for nil input' do
      expect(described_module.parse_balance_string(nil)).to eq(0)
    end

    it 'returns 0 for empty string' do
      expect(described_module.parse_balance_string('')).to eq(0)
    end

    it 'handles extra text around denominations' do
      expect(described_module.parse_balance_string('You have 5 gold coins')).to eq(5_000)
    end
  end

  describe '.format_currency' do
    it 'formats platinum only' do
      expect(described_module.format_currency(50_000)).to eq('5 platinum')
    end

    it 'formats gold only' do
      expect(described_module.format_currency(5_000)).to eq('5 gold')
    end

    it 'formats mixed denominations' do
      expect(described_module.format_currency(12_345)).to eq('1 platinum, 2 gold, 3 silver, 4 bronze, 5 copper')
    end

    it 'returns none for zero' do
      expect(described_module.format_currency(0)).to eq('none')
    end

    it 'returns none for nil' do
      expect(described_module.format_currency(nil)).to eq('none')
    end

    it 'returns none for negative values' do
      expect(described_module.format_currency(-100)).to eq('none')
    end

    it 'handles exact platinum amounts' do
      expect(described_module.format_currency(10_000)).to eq('1 platinum')
    end

    it 'handles copper only' do
      expect(described_module.format_currency(5)).to eq('5 copper')
    end
  end

  describe '.all_accounts' do
    it 'returns empty hash when no accounts exist' do
      expect(described_module.all_accounts).to eq({})
    end

    it 'returns all characters accounts' do
      GameSettings['drbanking_accounts'] = {
        'Mahtra'     => { 'Crossings' => 10_000 },
        'Quilsilgas' => { 'Shard' => 20_000 }
      }
      expect(described_module.all_accounts).to have_key('Mahtra')
      expect(described_module.all_accounts).to have_key('Quilsilgas')
    end
  end

  describe '.my_accounts' do
    it 'returns empty hash for new character' do
      expect(described_module.my_accounts).to eq({})
    end

    it 'returns current characters accounts' do
      XMLData.name = 'Mahtra'
      GameSettings['drbanking_accounts'] = {
        'Mahtra'    => { 'Crossings' => 10_000, 'Shard' => 5_000 },
        'OtherChar' => { 'Riverhaven' => 20_000 }
      }
      accounts = described_module.my_accounts
      expect(accounts['Crossings']).to eq(10_000)
      expect(accounts['Shard']).to eq(5_000)
      expect(accounts).not_to have_key('Riverhaven')
    end
  end

  describe '.update_balance' do
    it 'updates balance for current character' do
      XMLData.name = 'TestChar'
      described_module.update_balance('Crossings', 15_000)
      expect(described_module.my_accounts['Crossings']).to eq(15_000)
    end

    it 'converts string amounts to integer' do
      described_module.update_balance('Crossings', '20000')
      expect(described_module.my_accounts['Crossings']).to eq(20_000)
    end

    it 'overwrites existing balance' do
      described_module.update_balance('Crossings', 10_000)
      described_module.update_balance('Crossings', 25_000)
      expect(described_module.my_accounts['Crossings']).to eq(25_000)
    end

    it 'logs the update' do
      described_module.update_balance('Crossings', 10_000)
      expect(Lich::Messaging.messages.last).to include('Updated Crossings balance')
    end
  end

  describe '.clear_balance' do
    it 'sets balance to zero' do
      described_module.update_balance('Crossings', 10_000)
      described_module.clear_balance('Crossings')
      expect(described_module.my_accounts['Crossings']).to eq(0)
    end
  end

  describe '.total_wealth' do
    it 'returns 0 when no accounts' do
      expect(described_module.total_wealth).to eq(0)
    end

    it 'sums all bank balances for current character' do
      XMLData.name = 'TestChar'
      described_module.update_balance('Crossings', 10_000)
      described_module.update_balance('Shard', 5_000)
      described_module.update_balance('Riverhaven', 3_000)
      expect(described_module.total_wealth).to eq(18_000)
    end
  end

  describe '.total_wealth_all' do
    it 'returns 0 when no accounts' do
      expect(described_module.total_wealth_all).to eq(0)
    end

    it 'sums all bank balances across all characters' do
      GameSettings['drbanking_accounts'] = {
        'Char1' => { 'Crossings' => 10_000, 'Shard' => 5_000 },
        'Char2' => { 'Riverhaven' => 20_000 }
      }
      expect(described_module.total_wealth_all).to eq(35_000)
    end
  end

  describe '.current_bank_town' do
    it 'returns nil when room title is empty' do
      XMLData.room_title = ''
      expect(described_module.current_bank_town).to be_nil
    end

    it 'returns nil when room title is nil' do
      XMLData.room_title = nil
      expect(described_module.current_bank_town).to be_nil
    end

    it 'returns nil when not in a bank' do
      XMLData.room_title = '[Town Green, Center]'
      expect(described_module.current_bank_town).to be_nil
    end

    it 'identifies Crossings bank' do
      XMLData.room_title = '[Provincial Bank, Teller]'
      expect(described_module.current_bank_town).to eq('Crossings')
    end

    it 'identifies Shard bank' do
      XMLData.room_title = "[First Bank of Ilithi, Teller's Windows]"
      expect(described_module.current_bank_town).to eq('Shard')
    end

    it 'identifies Riverhaven bank' do
      XMLData.room_title = '[Bank of Riverhaven, Teller]'
      expect(described_module.current_bank_town).to eq('Riverhaven')
    end

    it 'identifies Hibarnhvidar bank' do
      XMLData.room_title = '[Second Provincial Bank of Hibarnhvidar, Teller]'
      expect(described_module.current_bank_town).to eq('Hibarnhvidar')
    end
  end

  describe '.parse' do
    context 'when not in a bank' do
      before { XMLData.room_title = '[Town Green, Center]' }

      it 'does nothing for deposit messages' do
        line = 'The clerk slides a small metal box across the counter into which you drop 5 platinum Kronars'
        expect { described_module.parse(line) }.not_to(change { described_module.my_accounts })
      end
    end

    context 'when in Crossings bank' do
      before { XMLData.room_title = '[Provincial Bank, Teller]' }

      it 'handles partial deposit' do
        line = 'The clerk slides a small metal box across the counter into which you drop 5 gold Kronars'
        described_module.parse(line)
        expect(described_module.my_accounts['Crossings']).to eq(5_000)
      end

      it 'handles cumulative deposits' do
        described_module.update_balance('Crossings', 10_000)
        line = 'The clerk slides a small metal box across the counter into which you drop 5 gold Kronars'
        described_module.parse(line)
        expect(described_module.my_accounts['Crossings']).to eq(15_000)
      end

      it 'handles partial withdrawal' do
        described_module.update_balance('Crossings', 10_000)
        line = 'The clerk counts out 3 gold Kronars and hands them over, making a notation in her ledger'
        described_module.parse(line)
        expect(described_module.my_accounts['Crossings']).to eq(7_000)
      end

      it 'handles withdraw all' do
        described_module.update_balance('Crossings', 10_000)
        line = 'The clerk counts out all your Kronars and hands them over'
        described_module.parse(line)
        expect(described_module.my_accounts['Crossings']).to eq(0)
      end

      it 'handles no account' do
        line = 'you do not seem to have an account with us'
        described_module.parse(line)
        expect(described_module.my_accounts['Crossings']).to eq(0)
      end
    end

    context 'when in Shard bank' do
      before { XMLData.room_title = "[First Bank of Ilithi, Teller's Windows]" }

      it 'handles balance check' do
        line = 'it looks like your current balance is 5 platinum, 2 gold Dokoras'
        described_module.parse(line)
        expect(described_module.my_accounts['Shard']).to eq(52_000)
      end
    end

    it 'handles nil input gracefully' do
      expect { described_module.parse(nil) }.not_to raise_error
    end

    it 'handles non-string input gracefully' do
      expect { described_module.parse(123) }.not_to raise_error
    end
  end

  describe '.display_banks' do
    it 'shows message when no accounts recorded' do
      described_module.display_banks
      expect(Lich::Messaging.messages).to include('DRBanking: No bank account info recorded.')
    end

    it 'displays bank balances when accounts exist' do
      described_module.update_balance('Crossings', 10_000)
      Lich::Messaging.clear_messages!
      described_module.display_banks
      messages = Lich::Messaging.messages.join("\n")
      expect(messages).to include('Crossings')
      expect(messages).to include('1 platinum')
    end
  end

  describe '.display_banks_all' do
    it 'shows message when no accounts recorded' do
      described_module.display_banks_all
      expect(Lich::Messaging.messages).to include('DRBanking: No bank account info recorded for any character.')
    end

    it 'displays all characters bank balances' do
      GameSettings['drbanking_accounts'] = {
        'Mahtra'     => { 'Crossings' => 10_000 },
        'Quilsilgas' => { 'Shard' => 20_000 }
      }
      described_module.display_banks_all
      messages = Lich::Messaging.messages.join("\n")
      expect(messages).to include('Mahtra')
      expect(messages).to include('Quilsilgas')
      expect(messages).to include('Grand Total')
    end
  end
end
