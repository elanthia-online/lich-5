# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'rspec'

LIB_DIR = File.join(File.expand_path('../../../..', __dir__), 'lib') unless defined?(LIB_DIR)

require File.join(LIB_DIR, 'dragonrealms', 'commons', 'common-money-data.rb')
require File.join(LIB_DIR, 'dragonrealms', 'commons', 'common-money.rb')

# Mock Lich::Messaging for warning tests
module Lich
  module Messaging
    @messages = []

    class << self
      def msg(type, message, **_opts)
        @messages << { type: type, message: message }
      end

      def messages
        @messages
      end

      def clear_messages!
        @messages = []
      end
    end
  end
end unless defined?(Lich::Messaging)

# Mock DRC module
module DRC
  def self.bput(*_args)
    ''
  end

  def self.release_invisibility(*_args); end
end unless defined?(DRC)

# Mock DRCT module
module DRCT
  def self.walk_to(*_args); end
end unless defined?(DRCT)

# Mock DRRoom module
module DRRoom
  def self.pcs
    []
  end
end unless defined?(DRRoom)

DRCM = Lich::DragonRealms::DRCM unless defined?(DRCM)

RSpec.describe Lich::DragonRealms::DRCM do
  # ─── Data constants ──────────────────────────────────────────────────

  describe 'data constants' do
    describe 'DENOMINATIONS' do
      it 'is frozen' do
        expect(described_class::DENOMINATIONS).to be_frozen
      end

      it 'lists 5 denominations in descending value order' do
        expect(described_class::DENOMINATIONS.length).to eq(5)
        expect(described_class::DENOMINATIONS.first).to eq([10_000, 'platinum'])
        expect(described_class::DENOMINATIONS.last).to eq([1, 'copper'])
      end
    end

    describe 'DENOMINATION_VALUES' do
      it 'is frozen' do
        expect(described_class::DENOMINATION_VALUES).to be_frozen
      end

      it 'maps all 5 denominations to copper multipliers' do
        expect(described_class::DENOMINATION_VALUES['platinum']).to eq(10_000)
        expect(described_class::DENOMINATION_VALUES['gold']).to eq(1000)
        expect(described_class::DENOMINATION_VALUES['silver']).to eq(100)
        expect(described_class::DENOMINATION_VALUES['bronze']).to eq(10)
        expect(described_class::DENOMINATION_VALUES['copper']).to eq(1)
      end
    end

    describe 'DENOMINATION_REGEX_MAP' do
      it 'is frozen' do
        expect(described_class::DENOMINATION_REGEX_MAP).to be_frozen
      end

      it 'matches full denomination names' do
        expect('platinum').to match(described_class::DENOMINATION_REGEX_MAP['platinum'])
        expect('gold').to match(described_class::DENOMINATION_REGEX_MAP['gold'])
        expect('silver').to match(described_class::DENOMINATION_REGEX_MAP['silver'])
        expect('bronze').to match(described_class::DENOMINATION_REGEX_MAP['bronze'])
        expect('copper').to match(described_class::DENOMINATION_REGEX_MAP['copper'])
      end

      it 'matches abbreviations' do
        expect('p').to match(described_class::DENOMINATION_REGEX_MAP['platinum'])
        expect('plat').to match(described_class::DENOMINATION_REGEX_MAP['platinum'])
        expect('g').to match(described_class::DENOMINATION_REGEX_MAP['gold'])
        expect('s').to match(described_class::DENOMINATION_REGEX_MAP['silver'])
        expect('b').to match(described_class::DENOMINATION_REGEX_MAP['bronze'])
        expect('c').to match(described_class::DENOMINATION_REGEX_MAP['copper'])
      end
    end

    describe 'CURRENCY_REGEX_MAP' do
      it 'is frozen' do
        expect(described_class::CURRENCY_REGEX_MAP).to be_frozen
      end

      it 'matches full currency names' do
        expect('kronars').to match(described_class::CURRENCY_REGEX_MAP['kronars'])
        expect('lirums').to match(described_class::CURRENCY_REGEX_MAP['lirums'])
        expect('dokoras').to match(described_class::CURRENCY_REGEX_MAP['dokoras'])
      end

      it 'matches abbreviations' do
        expect('k').to match(described_class::CURRENCY_REGEX_MAP['kronars'])
        expect('kron').to match(described_class::CURRENCY_REGEX_MAP['kronars'])
        expect('l').to match(described_class::CURRENCY_REGEX_MAP['lirums'])
        expect('d').to match(described_class::CURRENCY_REGEX_MAP['dokoras'])
      end
    end

    describe 'CURRENCIES' do
      it 'is frozen' do
        expect(described_class::CURRENCIES).to be_frozen
      end

      it 'lists all three DR currencies' do
        expect(described_class::CURRENCIES).to eq(%w[kronars lirums dokoras])
      end
    end

    describe 'EXCHANGE_RATES' do
      it 'is frozen (outer and inner hashes)' do
        expect(described_class::EXCHANGE_RATES).to be_frozen
        described_class::EXCHANGE_RATES.each_value do |inner|
          expect(inner).to be_frozen
        end
      end

      it 'has rates for all currency pairs' do
        %w[kronars lirums dokoras].each do |from|
          %w[kronars lirums dokoras].each do |to|
            expect(described_class::EXCHANGE_RATES[from][to]).to be_a(Numeric)
          end
        end
      end

      it 'has identity rate of 1 for same-currency' do
        %w[kronars lirums dokoras].each do |currency|
          expect(described_class::EXCHANGE_RATES[currency][currency]).to eq(1)
        end
      end
    end

    describe 'WEALTH_COPPER_REGEX' do
      it 'is frozen' do
        expect(described_class::WEALTH_COPPER_REGEX).to be_frozen
      end

      it 'matches wealth output with named captures' do
        line = '1 gold, 6 silver, and 9 copper Kronars (1609 copper Kronars).'
        match = line.match(described_class::WEALTH_COPPER_REGEX)
        expect(match).not_to be_nil
        expect(match[:coppers]).to eq('1609')
        expect(match[:currency]).to eq('Kronars')
      end

      it 'matches all three currencies' do
        expect('(500 copper Kronars)').to match(described_class::WEALTH_COPPER_REGEX)
        expect('(200 copper Lirums)').to match(described_class::WEALTH_COPPER_REGEX)
        expect('(13181 copper Dokoras)').to match(described_class::WEALTH_COPPER_REGEX)
      end

      it 'is case insensitive' do
        match = '(100 copper kronars)'.match(described_class::WEALTH_COPPER_REGEX)
        expect(match).not_to be_nil
        expect(match[:currency]).to eq('kronars')
      end
    end

    describe 'backward compatibility globals' do
      it '$DENOMINATION_REGEX_MAP points to module constant' do
        expect($DENOMINATION_REGEX_MAP).to equal(described_class::DENOMINATION_REGEX_MAP)
      end

      it '$CURRENCY_REGEX_MAP points to module constant' do
        expect($CURRENCY_REGEX_MAP).to equal(described_class::CURRENCY_REGEX_MAP)
      end
    end
  end

  # ─── strip_xml ───────────────────────────────────────────────────────

  describe '.strip_xml' do
    it 'removes XML tags from lines' do
      lines = ['<output class="">Wealth:</output>']
      expect(described_class.strip_xml(lines)).to eq(['Wealth:'])
    end

    it 'decodes HTML entities' do
      lines = ['5 &gt; 3 &lt; 10']
      expect(described_class.strip_xml(lines)).to eq(['5 > 3 < 10'])
    end

    it 'strips whitespace and rejects empty lines' do
      lines = ['  hello  ', '', '  ', '<tag></tag>']
      expect(described_class.strip_xml(lines)).to eq(['hello'])
    end

    it 'handles mixed XML and plain text' do
      lines = [
        'Wealth:',
        '  1 gold, 6 silver, and 9 copper Kronars (1609 copper Kronars).',
        '<output class=""/>'
      ]
      result = described_class.strip_xml(lines)
      expect(result.length).to eq(2)
      expect(result[0]).to eq('Wealth:')
      expect(result[1]).to eq('1 gold, 6 silver, and 9 copper Kronars (1609 copper Kronars).')
    end
  end

  # ─── minimize_coins ──────────────────────────────────────────────────

  describe '.minimize_coins' do
    it 'converts 0 copper to an empty array' do
      expect(described_class.minimize_coins(0)).to eq([])
    end

    it 'converts exact platinum amount' do
      expect(described_class.minimize_coins(10_000)).to eq(['1 platinum'])
    end

    it 'converts exact gold amount' do
      expect(described_class.minimize_coins(1000)).to eq(['1 gold'])
    end

    it 'converts a mixed amount' do
      # 12345 = 1 plat + 2 gold + 3 silver + 4 bronze + 5 copper
      expect(described_class.minimize_coins(12_345)).to eq(
        ['1 platinum', '2 gold', '3 silver', '4 bronze', '5 copper']
      )
    end

    it 'converts copper-only amounts' do
      expect(described_class.minimize_coins(7)).to eq(['7 copper'])
    end

    it 'skips zero-quantity denominations' do
      # 10_100 = 1 plat + 1 silver
      expect(described_class.minimize_coins(10_100)).to eq(['1 platinum', '1 silver'])
    end

    it 'handles large amounts' do
      # 50,000 = 5 platinum
      expect(described_class.minimize_coins(50_000)).to eq(['5 platinum'])
    end
  end

  # ─── convert_to_copper ───────────────────────────────────────────────

  describe '.convert_to_copper' do
    before { Lich::Messaging.clear_messages! }

    it 'converts platinum to copper' do
      expect(described_class.convert_to_copper('1', 'platinum')).to eq(10_000)
    end

    it 'converts gold to copper' do
      expect(described_class.convert_to_copper('2', 'gold')).to eq(2000)
    end

    it 'converts silver to copper' do
      expect(described_class.convert_to_copper('3', 'silver')).to eq(300)
    end

    it 'converts bronze to copper' do
      expect(described_class.convert_to_copper('4', 'bronze')).to eq(40)
    end

    it 'converts copper to copper' do
      expect(described_class.convert_to_copper('5', 'copper')).to eq(5)
    end

    it 'accepts abbreviations' do
      expect(described_class.convert_to_copper('1', 'plat')).to eq(10_000)
      expect(described_class.convert_to_copper('1', 'p')).to eq(10_000)
      expect(described_class.convert_to_copper('1', 'g')).to eq(1000)
      expect(described_class.convert_to_copper('1', 's')).to eq(100)
      expect(described_class.convert_to_copper('1', 'b')).to eq(10)
      expect(described_class.convert_to_copper('1', 'c')).to eq(1)
    end

    it 'is case insensitive' do
      expect(described_class.convert_to_copper('1', 'PLATINUM')).to eq(10_000)
      expect(described_class.convert_to_copper('1', 'Gold')).to eq(1000)
    end

    it 'supports fractional amounts' do
      expect(described_class.convert_to_copper('1.5', 'platinum')).to eq(15_000)
      expect(described_class.convert_to_copper('2.5', 'gold')).to eq(2500)
    end

    it 'handles nil denomination safely with .to_s' do
      result = described_class.convert_to_copper('100', nil)
      expect(result).to eq(100)
      expect(Lich::Messaging.messages.last[:type]).to eq('bold')
    end

    it 'handles empty denomination with warning' do
      result = described_class.convert_to_copper('50', '')
      expect(result).to eq(50)
      expect(Lich::Messaging.messages.last[:message]).to include('Unknown denomination')
    end

    it 'handles unknown denomination with warning' do
      result = described_class.convert_to_copper('50', 'zorkmids')
      expect(result).to eq(50)
      expect(Lich::Messaging.messages.last[:message]).to include('zorkmids')
    end

    it 'includes DRCM prefix in warning messages' do
      described_class.convert_to_copper('50', 'zorkmids')
      expect(Lich::Messaging.messages.last[:message]).to start_with('DRCM:')
    end

    it 'strips whitespace from denomination' do
      expect(described_class.convert_to_copper('1', '  gold  ')).to eq(1000)
    end
  end

  # ─── get_canonical_currency ──────────────────────────────────────────

  describe '.get_canonical_currency' do
    it 'returns kronars for full name' do
      expect(described_class.get_canonical_currency('kronars')).to eq('kronars')
    end

    it 'returns lirums for full name' do
      expect(described_class.get_canonical_currency('lirums')).to eq('lirums')
    end

    it 'returns dokoras for full name' do
      expect(described_class.get_canonical_currency('dokoras')).to eq('dokoras')
    end

    it 'resolves abbreviations' do
      expect(described_class.get_canonical_currency('k')).to eq('kronars')
      expect(described_class.get_canonical_currency('kron')).to eq('kronars')
      expect(described_class.get_canonical_currency('l')).to eq('lirums')
      expect(described_class.get_canonical_currency('li')).to eq('lirums')
      expect(described_class.get_canonical_currency('d')).to eq('dokoras')
      expect(described_class.get_canonical_currency('dok')).to eq('dokoras')
    end

    it 'returns nil for unrecognized currency' do
      expect(described_class.get_canonical_currency('zorkmids')).to be_nil
    end
  end

  # ─── convert_currency ───────────────────────────────────────────────

  describe '.convert_currency' do
    it 'returns the same amount for same-currency conversion with no fee' do
      expect(described_class.convert_currency(1000, 'kronars', 'kronars', 0)).to eq(1000)
    end

    it 'converts kronars to lirums with positive fee' do
      # 1000 kronars * 0.8 = 800 lirums, ceil = 800, * (1 - 0.05) = 760
      result = described_class.convert_currency(1000, 'kronars', 'lirums', 0.05)
      expect(result).to eq(760)
    end

    it 'calculates needed kronars for target lirums with negative fee' do
      # Negative fee = how much needed to receive X
      result = described_class.convert_currency(1000, 'kronars', 'lirums', -0.05)
      expect(result).to be > 1000
    end

    it 'converts lirums to kronars with no fee' do
      # 1000 lirums * 1.25 = 1250 kronars
      result = described_class.convert_currency(1000, 'lirums', 'kronars', 0)
      expect(result).to eq(1250)
    end

    it 'converts dokoras to kronars with positive fee' do
      result = described_class.convert_currency(1000, 'dokoras', 'kronars', 0.05)
      expect(result).to be > 0
      expect(result).to be < 1386 # rate is ~1.386
    end
  end

  # ─── get_total_wealth ────────────────────────────────────────────────

  describe '.get_total_wealth' do
    before do
      stub_const('Lich::Util', double('Lich::Util'))
    end

    it 'parses all three currencies from wealth output' do
      raw_lines = [
        'Wealth:',
        '  1 gold, 6 silver, and 9 copper Kronars (1609 copper Kronars).',
        '  2 gold and 1 silver Lirums (2100 copper Lirums).',
        '  1 platinum, 2 gold, 10 silver, 17 bronze, and 11 copper Dokoras (13181 copper Dokoras).',
        '<output class=""/>'
      ]
      allow(Lich::Util).to receive(:issue_command).and_return(raw_lines)

      result = described_class.get_total_wealth
      expect(result).to eq({
        'kronars' => 1609,
        'lirums'  => 2100,
        'dokoras' => 13181
      })
    end

    it 'returns zeros when character has no money' do
      raw_lines = [
        'Wealth:',
        '  You have no Kronars.',
        '  You have no Lirums.',
        '  You have no Dokoras.'
      ]
      allow(Lich::Util).to receive(:issue_command).and_return(raw_lines)

      result = described_class.get_total_wealth
      expect(result).to eq({ 'kronars' => 0, 'lirums' => 0, 'dokoras' => 0 })
    end

    it 'returns zeros on timeout (nil from issue_command)' do
      allow(Lich::Util).to receive(:issue_command).and_return(nil)

      result = described_class.get_total_wealth
      expect(result).to eq({ 'kronars' => 0, 'lirums' => 0, 'dokoras' => 0 })
    end

    it 'handles partial currency (some currencies with no money)' do
      raw_lines = [
        'Wealth:',
        '  5 gold Kronars (5000 copper Kronars).',
        '  You have no Lirums.',
        '  You have no Dokoras.'
      ]
      allow(Lich::Util).to receive(:issue_command).and_return(raw_lines)

      result = described_class.get_total_wealth
      expect(result).to eq({ 'kronars' => 5000, 'lirums' => 0, 'dokoras' => 0 })
    end

    it 'calls issue_command with correct parameters' do
      allow(Lich::Util).to receive(:issue_command).and_return(nil)

      described_class.get_total_wealth

      expect(Lich::Util).to have_received(:issue_command).with(
        'wealth',
        /^Wealth:/,
        /<prompt/,
        usexml: true,
        quiet: true,
        include_end: false,
        timeout: 5
      )
    end
  end

  # ─── town_currency / hometown_currency ───────────────────────────────

  describe '.town_currency' do
    before do
      allow(described_class).to receive(:get_data).with('town').and_return({
        'Crossing'   => { 'currency' => 'kronars' },
        'Shard'      => { 'currency' => 'dokoras' },
        'Riverhaven' => { 'currency' => 'lirums' }
      })
    end

    it 'returns currency for Crossing' do
      expect(described_class.town_currency('Crossing')).to eq('kronars')
    end

    it 'returns currency for Shard' do
      expect(described_class.town_currency('Shard')).to eq('dokoras')
    end

    it 'is an alias for hometown_currency' do
      expect(described_class.town_currency('Riverhaven')).to eq(described_class.hometown_currency('Riverhaven'))
    end
  end

  # ─── check_wealth ───────────────────────────────────────────────────

  describe '.check_wealth' do
    it 'parses copper amount from wealth response' do
      allow(DRC).to receive(:bput).and_return('(5000 copper kronars)')
      expect(described_class.check_wealth('kronars')).to eq(5000)
    end

    it 'returns 0 when no currency found' do
      allow(DRC).to receive(:bput).and_return('No kronars')
      expect(described_class.check_wealth('kronars')).to eq(0)
    end
  end

  # ─── wealth ─────────────────────────────────────────────────────────

  describe '.wealth' do
    it 'delegates to check_wealth with hometown currency' do
      allow(described_class).to receive(:get_data).with('town').and_return({
        'Crossing' => { 'currency' => 'kronars' }
      })
      allow(DRC).to receive(:bput).and_return('(3000 copper kronars)')

      expect(described_class.wealth('Crossing')).to eq(3000)
    end
  end

  # ─── debt ───────────────────────────────────────────────────────────

  describe '.debt' do
    it 'parses debt amount from wealth response' do
      allow(described_class).to receive(:get_data).with('town').and_return({
        'Crossing' => { 'currency' => 'kronars' }
      })
      allow(DRC).to receive(:bput).and_return('(1500 copper kronars)')

      expect(described_class.debt('Crossing')).to eq(1500)
    end

    it 'returns 0 when wealth line has no numbers' do
      allow(described_class).to receive(:get_data).with('town').and_return({
        'Crossing' => { 'currency' => 'kronars' }
      })
      allow(DRC).to receive(:bput).and_return('Wealth:')

      expect(described_class.debt('Crossing')).to eq(0)
    end
  end

  # ─── ensure_copper_on_hand ──────────────────────────────────────────

  describe '.ensure_copper_on_hand' do
    let(:settings) do
      double('settings', hometown: 'Crossing', bankbot_enabled: false)
    end

    before do
      allow(described_class).to receive(:get_data).with('town').and_return({
        'Crossing' => { 'currency' => 'kronars', 'deposit' => { 'id' => 1 } }
      })
    end

    it 'returns true when already have enough' do
      allow(DRC).to receive(:bput).and_return('(5000 copper kronars)')

      expect(described_class.ensure_copper_on_hand(3000, settings)).to be true
    end

    it 'attempts withdrawal when not enough on hand' do
      allow(DRC).to receive(:bput).and_return('(100 copper kronars)')
      allow(DRCT).to receive(:walk_to)
      allow(DRC).to receive(:release_invisibility)

      # Need 900 more copper = 9 silver
      allow(DRC).to receive(:bput)
        .with(/withdraw/, any_args)
        .and_return('The clerk counts')

      result = described_class.ensure_copper_on_hand(1000, settings)
      expect(result).to be true
    end

    it 'uses provided hometown over settings' do
      allow(described_class).to receive(:get_data).with('town').and_return({
        'Crossing' => { 'currency' => 'kronars', 'deposit' => { 'id' => 1 } },
        'Shard'    => { 'currency' => 'dokoras', 'deposit' => { 'id' => 2 } }
      })
      allow(DRC).to receive(:bput).and_return('(50000 copper dokoras)')

      expect(described_class.ensure_copper_on_hand(100, settings, 'Shard')).to be true
    end
  end

  # ─── get_money_from_bank ────────────────────────────────────────────

  describe '.get_money_from_bank' do
    let(:settings) { double('settings', hometown: 'Crossing') }

    before do
      allow(described_class).to receive(:get_data).with('town').and_return({
        'Crossing' => { 'deposit' => { 'id' => 1 } }
      })
      allow(DRCT).to receive(:walk_to)
      allow(DRC).to receive(:release_invisibility)
    end

    it 'returns true on successful withdrawal (clerk counts)' do
      allow(DRC).to receive(:bput).and_return('The clerk counts')

      expect(described_class.get_money_from_bank('5 gold', settings)).to be true
    end

    it 'returns true on successful withdrawal (you count out)' do
      allow(DRC).to receive(:bput).and_return('You count out')

      expect(described_class.get_money_from_bank('5 gold', settings)).to be true
    end

    it 'returns false when not enough money' do
      allow(DRC).to receive(:bput).and_return("You don't have that much money")

      expect(described_class.get_money_from_bank('99 platinum', settings)).to be false
    end

    it 'returns false when no account' do
      allow(DRC).to receive(:bput).and_return('have an account')

      expect(described_class.get_money_from_bank('5 gold', settings)).to be false
    end

    it 'returns false when not at teller window' do
      allow(DRC).to receive(:bput).and_return("You must be at a bank teller's window to withdraw money")

      expect(described_class.get_money_from_bank('5 gold', settings)).to be false
    end

    it 'retries when clerk glares then succeeds' do
      allow(described_class).to receive(:pause)
      allow(DRC).to receive(:bput)
        .and_return('The clerk glares at you.', 'The clerk counts')

      expect(described_class.get_money_from_bank('5 gold', settings)).to be true
    end

    it 'uses provided hometown' do
      allow(described_class).to receive(:get_data).with('town').and_return({
        'Crossing' => { 'deposit' => { 'id' => 1 } },
        'Shard'    => { 'deposit' => { 'id' => 99 } }
      })
      allow(DRC).to receive(:bput).and_return('The clerk counts')

      described_class.get_money_from_bank('5 gold', settings, 'Shard')
      expect(DRCT).to have_received(:walk_to).with(99)
    end
  end

  # ─── withdraw_exact_amount? ─────────────────────────────────────────

  describe '.withdraw_exact_amount?' do
    let(:base_settings) do
      double('settings',
             hometown: 'Crossing',
             bankbot_enabled: false)
    end

    before do
      allow(described_class).to receive(:get_data).with('town').and_return({
        'Crossing' => { 'currency' => 'kronars', 'deposit' => { 'id' => 1 } }
      })
      allow(DRCT).to receive(:walk_to)
      allow(DRC).to receive(:release_invisibility)
    end

    it 'goes to bank when bankbot is disabled' do
      allow(DRC).to receive(:bput).and_return('The clerk counts')

      described_class.withdraw_exact_amount?('5 gold', base_settings)
      expect(DRCT).to have_received(:walk_to).with(1)
    end

    context 'with bankbot enabled' do
      let(:bankbot_settings) do
        double('settings',
               hometown: 'Crossing',
               bankbot_enabled: true,
               bankbot_room_id: 42,
               bankbot_name: 'TestBot')
      end

      it 'uses bankbot when present in room' do
        allow(DRRoom).to receive(:pcs).and_return(['TestBot'])
        allow(DRC).to receive(:bput)
          .with(/whisper TestBot/, any_args)
          .and_return('offers you')
        allow(DRC).to receive(:bput)
          .with('accept tip', any_args)
          .and_return('Your current balance is')

        described_class.withdraw_exact_amount?('5 gold', bankbot_settings)
        expect(DRCT).to have_received(:walk_to).with(42)
      end

      it 'falls back to bank when bankbot not in room' do
        allow(DRRoom).to receive(:pcs).and_return([])
        allow(DRC).to receive(:bput).and_return('The clerk counts')

        described_class.withdraw_exact_amount?('5 gold', bankbot_settings)
      end
    end
  end

  # ─── deposit_coins ──────────────────────────────────────────────────

  describe '.deposit_coins' do
    let(:settings) do
      double('settings',
             skip_bank: false,
             hometown: 'Crossing',
             bankbot_enabled: false)
    end

    before do
      Lich::Messaging.clear_messages!
      allow(described_class).to receive(:get_data).with('town').and_return({
        'Crossing' => { 'currency' => 'kronars', 'deposit' => { 'id' => 1 } }
      })
      allow(DRCT).to receive(:walk_to)
      allow(DRC).to receive(:release_invisibility)
    end

    it 'returns nil when skip_bank is true' do
      skip_settings = double('settings', skip_bank: true, hometown: 'Crossing')

      expect(described_class.deposit_coins(0, skip_settings)).to be_nil
    end

    it 'returns nil with messaging when no teller found' do
      allow(DRC).to receive(:bput)
        .with('wealth', 'Wealth:')
        .and_return('Wealth:')
      allow(DRC).to receive(:bput)
        .with('deposit all', any_args)
        .and_return('There is no teller here')

      result = described_class.deposit_coins(0, settings)
      expect(result).to be_nil
      expect(Lich::Messaging.messages.last[:message]).to include('DRCM:')
      expect(Lich::Messaging.messages.last[:message]).to include('No teller')
    end

    it 'parses balance from check balance response' do
      allow(DRC).to receive(:bput)
        .with('wealth', 'Wealth:')
        .and_return('Wealth:')
      allow(DRC).to receive(:bput)
        .with('deposit all', any_args)
        .and_return('You hand the clerk some coins')
      allow(DRC).to receive(:bput)
        .with('check balance', any_args)
        .and_return('current balance is 5 gold Kronars."')

      balance, currency = described_class.deposit_coins(0, settings)
      expect(balance).to eq(5000)
      expect(currency).to eq('Kronars')
    end

    it 'parses balance with mixed denominations' do
      allow(DRC).to receive(:bput)
        .with('wealth', 'Wealth:')
        .and_return('Wealth:')
      allow(DRC).to receive(:bput)
        .with('deposit all', any_args)
        .and_return('You hand the clerk some coins')
      allow(DRC).to receive(:bput)
        .with('check balance', any_args)
        .and_return('current balance is 1 platinum, 2 gold, and 5 silver Kronars."')

      balance, currency = described_class.deposit_coins(0, settings)
      expect(balance).to eq(12_500)
      expect(currency).to eq('Kronars')
    end

    it 'returns zero balance when no account' do
      allow(DRC).to receive(:bput)
        .with('wealth', 'Wealth:')
        .and_return('Wealth:')
      allow(DRC).to receive(:bput)
        .with('deposit all', any_args)
        .and_return('You hand the clerk some coins')
      allow(DRC).to receive(:bput)
        .with('check balance', any_args)
        .and_return('If you would like to open one, you need only deposit a few Kronars."')

      balance, currency = described_class.deposit_coins(0, settings)
      expect(balance).to eq(0)
      expect(currency).to eq('Kronars')
    end

    it 'returns zero balance for deposit jar message' do
      allow(DRC).to receive(:bput)
        .with('wealth', 'Wealth:')
        .and_return('Wealth:')
      allow(DRC).to receive(:bput)
        .with('deposit all', any_args)
        .and_return('You hand the clerk some coins')
      allow(DRC).to receive(:bput)
        .with('check balance', any_args)
        .and_return('Perhaps you should find a new deposit jar for your financial needs.  Be sure to mark it with your name')

      balance, currency = described_class.deposit_coins(0, settings)
      expect(balance).to eq(0)
      expect(currency).to eq('Dokoras')
    end

    it 'parses As expected balance response' do
      allow(DRC).to receive(:bput)
        .with('wealth', 'Wealth:')
        .and_return('Wealth:')
      allow(DRC).to receive(:bput)
        .with('deposit all', any_args)
        .and_return('You hand the clerk some coins')
      allow(DRC).to receive(:bput)
        .with('check balance', any_args)
        .and_return('As expected, there are 3 gold Dokoras.')

      balance, currency = described_class.deposit_coins(0, settings)
      expect(balance).to eq(3000)
      expect(currency).to eq('Dokoras')
    end

    it 'withdraws keep_copper when in hometown' do
      allow(DRC).to receive(:bput)
        .with('wealth', 'Wealth:')
        .and_return('Wealth:')
      allow(DRC).to receive(:bput)
        .with('deposit all', any_args)
        .and_return('You hand the clerk some coins')
      allow(DRC).to receive(:bput)
        .with('check balance', any_args)
        .and_return('current balance is 10 gold Kronars."')
      allow(DRC).to receive(:bput)
        .with(/withdraw/, any_args)
        .and_return('The clerk counts')

      described_class.deposit_coins(500, settings)
      # Should have attempted to withdraw 5 silver
    end
  end
end
