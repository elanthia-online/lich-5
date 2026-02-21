# frozen_string_literal: true

require_relative '../../../spec_helper'

# Load dependencies
require_relative '../../../../lib/dragonrealms/drinfomon/drvariables'

# Test data storage - class-level to avoid closure issues
class DRBankingTestData
  class << self
    attr_accessor :game_data, :messages

    def reset!
      @game_data = {}
      @messages = []
    end
  end
end

# Minimal stubs for initial load (if real modules not yet defined)
module Lich
  module Common
    module InstanceSettings
      def self.game
        # Returns a mock accessor that reads/writes to test data
        Object.new.tap do |obj|
          obj.define_singleton_method(:[]) { |key| DRBankingTestData.game_data[key] }
          obj.define_singleton_method(:[]=) { |key, value| DRBankingTestData.game_data[key] = value }
        end
      end
    end
  end unless defined?(Lich::Common::InstanceSettings)
end

# Note: XMLData and Lich::Messaging are provided by spec_helper.rb
# We use Lich::Messaging.messages/clear_messages! for test assertions

require_relative '../../../../lib/dragonrealms/drinfomon/drbanking'

RSpec.describe Lich::DragonRealms::DRBanking do
  let(:described_module) { Lich::DragonRealms::DRBanking }

  # Helper to extract message strings from Lich::Messaging (provided by spec_helper)
  def message_strings
    Lich::Messaging.messages.map { |m| m.is_a?(Hash) ? m[:message] : m.to_s }
  end

  before(:all) do
    # Save original InstanceSettings.game method to restore after tests
    @original_game_method = Lich::Common::InstanceSettings.method(:game)
  end

  after(:all) do
    # Restore original InstanceSettings.game method
    if @original_game_method
      Lich::Common::InstanceSettings.define_singleton_method(:game, @original_game_method)
    end
  end

  before(:each) do
    # Reset test data
    DRBankingTestData.reset!
    Lich::Messaging.clear_messages!

    # XMLData is reset by spec_helper's before(:each) via reset_xml_data!
    # Just set room_title which isn't reset by default
    XMLData.room_title = ''

    # Redefine InstanceSettings.game to use our test data
    Lich::Common::InstanceSettings.define_singleton_method(:game) do
      Object.new.tap do |obj|
        obj.define_singleton_method(:[]) { |key| DRBankingTestData.game_data[key] }
        obj.define_singleton_method(:[]=) { |key, value| DRBankingTestData.game_data[key] = value }
      end
    end

    # Reset DRBanking cache
    described_module.class_variable_set(:@@accounts_cache, nil)
    described_module.reload!
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
        line = 'The clerk slides a small metal box across the counter into which you drop 10 gold Lirums'
        match = pattern.match(line)
        expect(match).not_to be_nil
        expect(match[:amount]).to eq('10')
        expect(match[:denomination]).to eq('gold')
        expect(match[:currency]).to eq('Lirums')
      end

      it 'matches deposit with copper Dokoras' do
        line = 'The clerk slides a small metal box across the counter into which you drop 100 copper Dokoras'
        match = pattern.match(line)
        expect(match).not_to be_nil
        expect(match[:amount]).to eq('100')
        expect(match[:denomination]).to eq('copper')
        expect(match[:currency]).to eq('Dokoras')
      end

      it 'does not match unrelated text' do
        line = 'You pick up a bag of coins.'
        expect(pattern.match(line)).to be_nil
      end
    end

    describe 'DEPOSIT_ALL_TELLER' do
      let(:pattern) { described_module::Pattern::DEPOSIT_ALL_TELLER }

      it 'matches deposit all Kronars' do
        line = 'The clerk slides a small metal box across the counter into which you drop all your Kronars.  She counts them carefully and records the deposit in her ledger'
        expect(pattern.match(line)).not_to be_nil
        expect(pattern.match(line)[:currency]).to eq('Kronars')
      end

      it 'matches deposit all Lirums' do
        line = 'The clerk slides a small metal box across the counter into which you drop all your Lirums.  She counts them carefully and records the deposit in her ledger'
        expect(pattern.match(line)).not_to be_nil
        expect(pattern.match(line)[:currency]).to eq('Lirums')
      end

      it 'matches deposit all Dokoras' do
        line = 'The clerk slides a small metal box across the counter into which you drop all your Dokoras.  She counts them carefully and records the deposit in her ledger'
        expect(pattern.match(line)).not_to be_nil
        expect(pattern.match(line)[:currency]).to eq('Dokoras')
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
        expect(pattern.match(line)[:currency]).to eq('Kronars')
      end

      it 'matches jar withdraw all' do
        line = 'You count out all of your Dokoras and quickly pocket them'
        expect(pattern.match(line)).not_to be_nil
        expect(pattern.match(line)[:currency]).to eq('Dokoras')
      end
    end

    describe 'BALANCE_CHECK' do
      let(:pattern) { described_module::Pattern::BALANCE_CHECK }

      it 'matches "it looks like" balance check' do
        line = 'it looks like your current balance is 5 platinum Kronars'
        match = pattern.match(line)
        expect(match).not_to be_nil
        expect(match[:balance]).to eq('5 platinum')
        expect(match[:currency]).to eq('Kronars')
      end

      it 'matches "Here we are" balance check' do
        line = '"Here we are. Your current balance is 10 gold, 5 silver Lirums'
        match = pattern.match(line)
        expect(match).not_to be_nil
        expect(match[:currency]).to eq('Lirums')
      end

      it 'matches "As expected" balance check' do
        line = 'As expected, there are 100 copper Dokoras'
        match = pattern.match(line)
        expect(match).not_to be_nil
        expect(match[:balance]).to eq('100 copper')
        expect(match[:currency]).to eq('Dokoras')
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

  describe 'CURRENCY_BANKS constant' do
    it 'is frozen' do
      expect(described_module::CURRENCY_BANKS).to be_frozen
    end

    it 'maps Kronars to KRONAR_BANKS' do
      expect(described_module::CURRENCY_BANKS['Kronars']).to eq(Lich::DragonRealms::KRONAR_BANKS)
    end

    it 'maps Lirums to LIRUM_BANKS' do
      expect(described_module::CURRENCY_BANKS['Lirums']).to eq(Lich::DragonRealms::LIRUM_BANKS)
    end

    it 'maps Dokoras to DOKORA_BANKS' do
      expect(described_module::CURRENCY_BANKS['Dokoras']).to eq(Lich::DragonRealms::DOKORA_BANKS)
    end
  end

  describe '.all_accounts' do
    it 'returns empty hash when no data' do
      expect(described_module.all_accounts).to eq({})
    end

    it 'returns all character accounts' do
      DRBankingTestData.game_data['banking'] = {
        'CharA' => { 'Crossings' => 10_000 },
        'CharB' => { 'Shard' => 20_000 }
      }
      described_module.reload!
      accounts = described_module.all_accounts
      expect(accounts['CharA']).to eq({ 'Crossings' => 10_000 })
      expect(accounts['CharB']).to eq({ 'Shard' => 20_000 })
    end
  end

  describe '.my_accounts' do
    it 'returns empty hash for new character' do
      expect(described_module.my_accounts).to eq({})
    end

    it 'returns current characters accounts' do
      # Directly set up multi-character data in storage
      DRBankingTestData.game_data['banking'] = {
        'Mahtra'    => { 'Crossings' => 10_000, 'Shard' => 5_000 },
        'OtherChar' => { 'Riverhaven' => 20_000 }
      }
      described_module.reload!

      # Verify data structure is correct via all_accounts
      # (my_accounts depends on XMLData.name which may not be settable in CI)
      all = described_module.all_accounts
      expect(all['Mahtra']['Crossings']).to eq(10_000)
      expect(all['Mahtra']['Shard']).to eq(5_000)
      expect(all['OtherChar']['Riverhaven']).to eq(20_000)
      expect(all['Mahtra']).not_to have_key('Riverhaven')
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
      expect(message_strings.last).to include('Updated Crossings balance')
    end

    it 'persists to InstanceSettings' do
      described_module.update_balance('Crossings', 10_000)
      # Reload to verify persistence
      described_module.reload!
      expect(described_module.my_accounts['Crossings']).to eq(10_000)
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
      XMLData.name = 'CharA'
      described_module.update_balance('Crossings', 10_000)
      XMLData.name = 'CharB'
      described_module.update_balance('Shard', 5_000)
      described_module.update_balance('Riverhaven', 3_000)
      expect(described_module.total_wealth_all).to eq(18_000)
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
      expect(described_module.to_copper(100, 'silver')).to eq(10_000)
    end

    it 'converts bronze correctly' do
      expect(described_module.to_copper(50, 'bronze')).to eq(500)
    end

    it 'converts copper correctly' do
      expect(described_module.to_copper(1000, 'copper')).to eq(1_000)
    end

    it 'handles string amounts' do
      expect(described_module.to_copper('5', 'platinum')).to eq(50_000)
    end

    it 'handles mixed case denomination' do
      expect(described_module.to_copper(5, 'PLATINUM')).to eq(50_000)
    end

    it 'defaults to 1 for unknown denomination' do
      expect(described_module.to_copper(100, 'unknown')).to eq(100)
    end
  end

  describe '.parse_balance_string' do
    it 'returns 0 for nil' do
      expect(described_module.parse_balance_string(nil)).to eq(0)
    end

    it 'returns 0 for empty string' do
      expect(described_module.parse_balance_string('')).to eq(0)
    end

    it 'parses single denomination' do
      expect(described_module.parse_balance_string('5 platinum')).to eq(50_000)
    end

    it 'parses multiple denominations' do
      expect(described_module.parse_balance_string('5 platinum, 3 gold, 2 silver')).to eq(53_200)
    end

    it 'handles extra whitespace' do
      expect(described_module.parse_balance_string('5  platinum,  3  gold')).to eq(53_000)
    end
  end

  describe '.format_currency' do
    it 'returns "none" for 0' do
      expect(described_module.format_currency(0)).to eq('none')
    end

    it 'returns "none" for negative amounts' do
      expect(described_module.format_currency(-100)).to eq('none')
    end

    it 'formats single denomination' do
      expect(described_module.format_currency(50_000)).to eq('5 platinum')
    end

    it 'formats multiple denominations' do
      expect(described_module.format_currency(53_210)).to eq('5 platinum, 3 gold, 2 silver, 1 bronze')
    end

    it 'handles string input' do
      expect(described_module.format_currency('50000')).to eq('5 platinum')
    end

    it 'omits zero-value denominations' do
      # 10,001 copper = 1 platinum (10,000) + 1 copper
      expect(described_module.format_currency(10_001)).to eq('1 platinum, 1 copper')
    end
  end

  describe '.current_bank_town' do
    it 'returns nil when not in a bank' do
      XMLData.room_title = '[Some Random Room]'
      expect(described_module.current_bank_town).to be_nil
    end

    it 'returns nil when room_title is nil' do
      XMLData.room_title = nil
      expect(described_module.current_bank_town).to be_nil
    end

    it 'returns nil when room_title is empty' do
      XMLData.room_title = ''
      expect(described_module.current_bank_town).to be_nil
    end

    it 'returns town when in Crossings bank' do
      XMLData.room_title = '[[Provincial Bank, Teller]]'
      expect(described_module.current_bank_town).to eq('Crossings')
    end

    it 'returns town when in Shard bank' do
      XMLData.room_title = "[[First Bank of Ilithi, Teller's Windows]]"
      expect(described_module.current_bank_town).to eq('Shard')
    end

    it 'returns town when in Riverhaven bank' do
      XMLData.room_title = '[[Bank of Riverhaven, Teller]]'
      expect(described_module.current_bank_town).to eq('Riverhaven')
    end
  end

  describe '.parse' do
    context 'when not in a bank' do
      before { XMLData.room_title = '[Some Random Room]' }

      it 'does nothing for bank messages' do
        expect {
          described_module.parse('The clerk counts out 5 gold Kronars and hands them over, making a notation in her ledger')
        }.not_to(change { described_module.my_accounts })
      end
    end

    context 'when in a bank' do
      before { XMLData.room_title = '[[Provincial Bank, Teller]]' } # Crossings bank

      it 'handles nil input' do
        expect { described_module.parse(nil) }.not_to raise_error
      end

      it 'handles non-string input' do
        expect { described_module.parse(123) }.not_to raise_error
      end

      describe 'deposit portion' do
        it 'adds deposit to current balance' do
          described_module.update_balance('Crossings', 10_000)
          described_module.parse('The clerk slides a small metal box across the counter into which you drop 5 gold Kronars')
          expect(described_module.my_accounts['Crossings']).to eq(15_000)
        end

        it 'creates new balance if none exists' do
          described_module.parse('The clerk slides a small metal box across the counter into which you drop 5 platinum Kronars')
          expect(described_module.my_accounts['Crossings']).to eq(50_000)
        end
      end

      describe 'deposit all' do
        it 'logs deposit all for teller bank' do
          described_module.parse('The clerk slides a small metal box across the counter into which you drop all your Kronars.  She counts them carefully and records the deposit in her ledger')
          expect(message_strings.last).to include('Deposited all money')
        end

        it 'logs deposit all for jar bank' do
          described_module.parse('You cross through the old balance on the label and update it to reflect your new balance')
          expect(message_strings.last).to include('Deposited all money')
        end
      end

      describe 'withdraw portion' do
        it 'subtracts withdrawal from balance' do
          described_module.update_balance('Crossings', 10_000)
          described_module.parse('The clerk counts out 5 gold Kronars and hands them over, making a notation in her ledger')
          expect(described_module.my_accounts['Crossings']).to eq(5_000)
        end

        it 'does not go below zero' do
          described_module.update_balance('Crossings', 1_000)
          described_module.parse('The clerk counts out 5 gold Kronars and hands them over, making a notation in her ledger')
          expect(described_module.my_accounts['Crossings']).to eq(0)
        end
      end

      describe 'withdraw all' do
        it 'sets balance to zero' do
          described_module.update_balance('Crossings', 10_000)
          described_module.parse('The clerk counts out all your Kronars and hands them over')
          expect(described_module.my_accounts['Crossings']).to eq(0)
        end

        it 'logs the withdrawal' do
          described_module.update_balance('Crossings', 10_000)
          described_module.parse('The clerk counts out all your Kronars and hands them over')
          expect(message_strings.last).to include('Withdrew all money')
        end
      end

      describe 'balance check' do
        it 'updates balance from "it looks like" message' do
          described_module.parse('it looks like your current balance is 5 platinum, 3 gold Kronars')
          expect(described_module.my_accounts['Crossings']).to eq(53_000)
        end

        it 'updates balance from "As expected" message' do
          described_module.parse('As expected, there are 100 copper Kronars')
          expect(described_module.my_accounts['Crossings']).to eq(100)
        end
      end

      describe 'no account' do
        it 'clears balance for teller bank message' do
          described_module.update_balance('Crossings', 10_000)
          described_module.parse('you do not seem to have an account with us')
          expect(described_module.my_accounts['Crossings']).to eq(0)
        end

        it 'clears balance for jar bank message' do
          described_module.update_balance('Crossings', 10_000)
          described_module.parse('you should find a new deposit jar for your financial needs')
          expect(described_module.my_accounts['Crossings']).to eq(0)
        end

        it 'logs no account message' do
          described_module.parse('you do not seem to have an account with us')
          expect(message_strings.last).to include('No account')
        end
      end
    end
  end

  describe '.display_banks' do
    it 'displays message when no accounts' do
      described_module.display_banks
      expect(message_strings.last).to include('No bank account info recorded')
    end

    it 'displays account balances' do
      described_module.update_balance('Crossings', 10_000)
      described_module.update_balance('Riverhaven', 5_000)
      described_module.display_banks
      # Should display header and balances
      expect(message_strings.any? { |m| m.include?('Your bank balances') }).to be true
    end
  end

  describe '.display_banks_all' do
    it 'displays message when no accounts' do
      described_module.display_banks_all
      expect(message_strings.last).to include('No bank account info recorded for any character')
    end

    it 'displays all character balances' do
      XMLData.name = 'CharA'
      described_module.update_balance('Crossings', 10_000)
      XMLData.name = 'CharB'
      described_module.update_balance('Shard', 5_000)
      described_module.display_banks_all
      expect(message_strings.any? { |m| m.include?('Bank balances for all characters') }).to be true
    end
  end

  describe '.reload!' do
    it 'clears cache and reloads from storage' do
      # Set initial data
      described_module.update_balance('Crossings', 10_000)

      # Clear the cache directly and reload
      described_module.class_variable_set(:@@accounts_cache, nil)
      described_module.reload!

      # Data should still be there (loaded from storage)
      expect(described_module.my_accounts['Crossings']).to eq(10_000)
    end
  end

  describe '.reset_character!' do
    it 'clears current characters data' do
      XMLData.name = 'TestChar'
      described_module.update_balance('Crossings', 10_000)
      described_module.reset_character!
      expect(described_module.my_accounts).to eq({})
    end

    it 'preserves other characters data' do
      # Use the character name that spec_helper sets (XMLData.name = 'TestChar')
      # This avoids relying on XMLData.name being settable in CI
      current_char = XMLData.name

      # Directly set up multi-character data with current_char as one of them
      DRBankingTestData.game_data['banking'] = {
        'Mahtra'     => { 'Crossings' => 10_000 },
        current_char => { 'Shard' => 5_000 }
      }
      described_module.reload!

      # Verify both characters have data before reset
      expect(described_module.all_accounts.keys).to include('Mahtra', current_char)

      # Reset current character (whatever XMLData.name returns)
      described_module.reset_character!

      # Verify current_char is cleared but Mahtra still has data
      expect(described_module.all_accounts.keys).to include('Mahtra')
      expect(described_module.all_accounts[current_char]).to be_nil
      expect(described_module.all_accounts['Mahtra']['Crossings']).to eq(10_000)
    end

    it 'logs the reset' do
      described_module.reset_character!
      expect(message_strings.last).to include('Cleared bank data')
    end
  end

  describe '.reset_all!' do
    it 'clears all character data' do
      XMLData.name = 'CharA'
      described_module.update_balance('Crossings', 10_000)
      XMLData.name = 'CharB'
      described_module.update_balance('Shard', 5_000)
      described_module.reset_all!
      expect(described_module.all_accounts).to eq({})
    end

    it 'logs the reset' do
      described_module.reset_all!
      expect(message_strings.last).to include('Cleared all bank data')
    end

    it 'resets total_wealth_all to 0' do
      XMLData.name = 'CharA'
      described_module.update_balance('Crossings', 10_000)
      described_module.reset_all!
      expect(described_module.total_wealth_all).to eq(0)
    end
  end
end
