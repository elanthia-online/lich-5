require 'rspec'

LIB_DIR = File.join(File.expand_path('../../../..', __dir__), 'lib') unless defined?(LIB_DIR)

require File.join(LIB_DIR, 'dragonrealms', 'commons', 'common-money-data.rb')
require File.join(LIB_DIR, 'dragonrealms', 'commons', 'common-money.rb')

# Mock Lich::Messaging for warning tests
module Lich
  module Messaging
    @messages = []

    class << self
      def msg(type, message)
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

DRCM = Lich::DragonRealms::DRCM

RSpec.describe DRCM do
  # ─── Data constants ──────────────────────────────────────────────────

  describe 'data constants' do
    describe 'DENOMINATIONS' do
      it 'is frozen' do
        expect(DRCM::DENOMINATIONS).to be_frozen
      end

      it 'lists 5 denominations in descending value order' do
        expect(DRCM::DENOMINATIONS.length).to eq(5)
        expect(DRCM::DENOMINATIONS.first).to eq([10_000, 'platinum'])
        expect(DRCM::DENOMINATIONS.last).to eq([1, 'copper'])
      end
    end

    describe 'DENOMINATION_VALUES' do
      it 'is frozen' do
        expect(DRCM::DENOMINATION_VALUES).to be_frozen
      end

      it 'maps all 5 denominations to copper multipliers' do
        expect(DRCM::DENOMINATION_VALUES['platinum']).to eq(10_000)
        expect(DRCM::DENOMINATION_VALUES['gold']).to eq(1000)
        expect(DRCM::DENOMINATION_VALUES['silver']).to eq(100)
        expect(DRCM::DENOMINATION_VALUES['bronze']).to eq(10)
        expect(DRCM::DENOMINATION_VALUES['copper']).to eq(1)
      end
    end

    describe 'DENOMINATION_REGEX_MAP' do
      it 'is frozen' do
        expect(DRCM::DENOMINATION_REGEX_MAP).to be_frozen
      end

      it 'matches full denomination names' do
        expect('platinum').to match(DRCM::DENOMINATION_REGEX_MAP['platinum'])
        expect('gold').to match(DRCM::DENOMINATION_REGEX_MAP['gold'])
        expect('silver').to match(DRCM::DENOMINATION_REGEX_MAP['silver'])
        expect('bronze').to match(DRCM::DENOMINATION_REGEX_MAP['bronze'])
        expect('copper').to match(DRCM::DENOMINATION_REGEX_MAP['copper'])
      end

      it 'matches abbreviations' do
        expect('p').to match(DRCM::DENOMINATION_REGEX_MAP['platinum'])
        expect('plat').to match(DRCM::DENOMINATION_REGEX_MAP['platinum'])
        expect('g').to match(DRCM::DENOMINATION_REGEX_MAP['gold'])
        expect('s').to match(DRCM::DENOMINATION_REGEX_MAP['silver'])
        expect('b').to match(DRCM::DENOMINATION_REGEX_MAP['bronze'])
        expect('c').to match(DRCM::DENOMINATION_REGEX_MAP['copper'])
      end
    end

    describe 'CURRENCY_REGEX_MAP' do
      it 'is frozen' do
        expect(DRCM::CURRENCY_REGEX_MAP).to be_frozen
      end

      it 'matches full currency names' do
        expect('kronars').to match(DRCM::CURRENCY_REGEX_MAP['kronars'])
        expect('lirums').to match(DRCM::CURRENCY_REGEX_MAP['lirums'])
        expect('dokoras').to match(DRCM::CURRENCY_REGEX_MAP['dokoras'])
      end

      it 'matches abbreviations' do
        expect('k').to match(DRCM::CURRENCY_REGEX_MAP['kronars'])
        expect('kron').to match(DRCM::CURRENCY_REGEX_MAP['kronars'])
        expect('l').to match(DRCM::CURRENCY_REGEX_MAP['lirums'])
        expect('d').to match(DRCM::CURRENCY_REGEX_MAP['dokoras'])
      end
    end

    describe 'CURRENCIES' do
      it 'is frozen' do
        expect(DRCM::CURRENCIES).to be_frozen
      end

      it 'lists all three DR currencies' do
        expect(DRCM::CURRENCIES).to eq(%w[kronars lirums dokoras])
      end
    end

    describe 'EXCHANGE_RATES' do
      it 'is frozen (outer and inner hashes)' do
        expect(DRCM::EXCHANGE_RATES).to be_frozen
        DRCM::EXCHANGE_RATES.each_value do |inner|
          expect(inner).to be_frozen
        end
      end

      it 'has rates for all currency pairs' do
        %w[kronars lirums dokoras].each do |from|
          %w[kronars lirums dokoras].each do |to|
            expect(DRCM::EXCHANGE_RATES[from][to]).to be_a(Numeric)
          end
        end
      end

      it 'has identity rate of 1 for same-currency' do
        %w[kronars lirums dokoras].each do |currency|
          expect(DRCM::EXCHANGE_RATES[currency][currency]).to eq(1)
        end
      end
    end

    describe 'WEALTH_COPPER_REGEX' do
      it 'is frozen' do
        expect(DRCM::WEALTH_COPPER_REGEX).to be_frozen
      end

      it 'matches wealth output with named captures' do
        line = '1 gold, 6 silver, and 9 copper Kronars (1609 copper Kronars).'
        match = line.match(DRCM::WEALTH_COPPER_REGEX)
        expect(match).not_to be_nil
        expect(match[:coppers]).to eq('1609')
        expect(match[:currency]).to eq('Kronars')
      end

      it 'matches all three currencies' do
        expect('(500 copper Kronars)').to match(DRCM::WEALTH_COPPER_REGEX)
        expect('(200 copper Lirums)').to match(DRCM::WEALTH_COPPER_REGEX)
        expect('(13181 copper Dokoras)').to match(DRCM::WEALTH_COPPER_REGEX)
      end

      it 'is case insensitive' do
        match = '(100 copper kronars)'.match(DRCM::WEALTH_COPPER_REGEX)
        expect(match).not_to be_nil
        expect(match[:currency]).to eq('kronars')
      end
    end

    describe 'backward compatibility globals' do
      it '$DENOMINATION_REGEX_MAP points to module constant' do
        expect($DENOMINATION_REGEX_MAP).to equal(DRCM::DENOMINATION_REGEX_MAP)
      end

      it '$CURRENCY_REGEX_MAP points to module constant' do
        expect($CURRENCY_REGEX_MAP).to equal(DRCM::CURRENCY_REGEX_MAP)
      end
    end
  end

  # ─── strip_xml ───────────────────────────────────────────────────────

  describe '.strip_xml' do
    it 'removes XML tags from lines' do
      lines = ['<output class="">Wealth:</output>']
      expect(DRCM.strip_xml(lines)).to eq(['Wealth:'])
    end

    it 'decodes HTML entities' do
      lines = ['5 &gt; 3 &lt; 10']
      expect(DRCM.strip_xml(lines)).to eq(['5 > 3 < 10'])
    end

    it 'strips whitespace and rejects empty lines' do
      lines = ['  hello  ', '', '  ', '<tag></tag>']
      expect(DRCM.strip_xml(lines)).to eq(['hello'])
    end

    it 'handles mixed XML and plain text' do
      lines = [
        'Wealth:',
        '  1 gold, 6 silver, and 9 copper Kronars (1609 copper Kronars).',
        '<output class=""/>'
      ]
      result = DRCM.strip_xml(lines)
      expect(result.length).to eq(2)
      expect(result[0]).to eq('Wealth:')
      expect(result[1]).to eq('1 gold, 6 silver, and 9 copper Kronars (1609 copper Kronars).')
    end
  end

  # ─── minimize_coins ──────────────────────────────────────────────────

  describe '.minimize_coins' do
    it 'converts 0 copper to an empty array' do
      expect(DRCM.minimize_coins(0)).to eq([])
    end

    it 'converts exact platinum amount' do
      expect(DRCM.minimize_coins(10_000)).to eq(['1 platinum'])
    end

    it 'converts exact gold amount' do
      expect(DRCM.minimize_coins(1000)).to eq(['1 gold'])
    end

    it 'converts a mixed amount' do
      # 12345 = 1 plat + 2 gold + 3 silver + 4 bronze + 5 copper
      expect(DRCM.minimize_coins(12_345)).to eq(['1 platinum', '2 gold', '3 silver', '4 bronze', '5 copper'])
    end

    it 'converts copper-only amounts' do
      expect(DRCM.minimize_coins(7)).to eq(['7 copper'])
    end

    it 'skips zero-quantity denominations' do
      # 10_100 = 1 plat + 1 silver
      expect(DRCM.minimize_coins(10_100)).to eq(['1 platinum', '1 silver'])
    end

    it 'handles large amounts' do
      # 50,000 = 5 platinum
      expect(DRCM.minimize_coins(50_000)).to eq(['5 platinum'])
    end
  end

  # ─── convert_to_copper ───────────────────────────────────────────────

  describe '.convert_to_copper' do
    before { Lich::Messaging.clear_messages! }

    it 'converts platinum to copper' do
      expect(DRCM.convert_to_copper('1', 'platinum')).to eq(10_000)
    end

    it 'converts gold to copper' do
      expect(DRCM.convert_to_copper('2', 'gold')).to eq(2000)
    end

    it 'converts silver to copper' do
      expect(DRCM.convert_to_copper('3', 'silver')).to eq(300)
    end

    it 'converts bronze to copper' do
      expect(DRCM.convert_to_copper('4', 'bronze')).to eq(40)
    end

    it 'converts copper to copper' do
      expect(DRCM.convert_to_copper('5', 'copper')).to eq(5)
    end

    it 'accepts abbreviations' do
      expect(DRCM.convert_to_copper('1', 'plat')).to eq(10_000)
      expect(DRCM.convert_to_copper('1', 'p')).to eq(10_000)
      expect(DRCM.convert_to_copper('1', 'g')).to eq(1000)
      expect(DRCM.convert_to_copper('1', 's')).to eq(100)
      expect(DRCM.convert_to_copper('1', 'b')).to eq(10)
      expect(DRCM.convert_to_copper('1', 'c')).to eq(1)
    end

    it 'is case insensitive' do
      expect(DRCM.convert_to_copper('1', 'PLATINUM')).to eq(10_000)
      expect(DRCM.convert_to_copper('1', 'Gold')).to eq(1000)
    end

    it 'supports fractional amounts' do
      expect(DRCM.convert_to_copper('1.5', 'platinum')).to eq(15_000)
      expect(DRCM.convert_to_copper('2.5', 'gold')).to eq(2500)
    end

    it 'handles nil denomination safely with .to_s' do
      result = DRCM.convert_to_copper('100', nil)
      expect(result).to eq(100)
      expect(Lich::Messaging.messages.last[:type]).to eq('bold')
    end

    it 'handles empty denomination with warning' do
      result = DRCM.convert_to_copper('50', '')
      expect(result).to eq(50)
      expect(Lich::Messaging.messages.last[:message]).to include('Unknown denomination')
    end

    it 'handles unknown denomination with warning' do
      result = DRCM.convert_to_copper('50', 'zorkmids')
      expect(result).to eq(50)
      expect(Lich::Messaging.messages.last[:message]).to include('zorkmids')
    end

    it 'strips whitespace from denomination' do
      expect(DRCM.convert_to_copper('1', '  gold  ')).to eq(1000)
    end
  end

  # ─── get_canonical_currency ──────────────────────────────────────────

  describe '.get_canonical_currency' do
    it 'returns kronars for full name' do
      expect(DRCM.get_canonical_currency('kronars')).to eq('kronars')
    end

    it 'returns lirums for full name' do
      expect(DRCM.get_canonical_currency('lirums')).to eq('lirums')
    end

    it 'returns dokoras for full name' do
      expect(DRCM.get_canonical_currency('dokoras')).to eq('dokoras')
    end

    it 'resolves abbreviations' do
      expect(DRCM.get_canonical_currency('k')).to eq('kronars')
      expect(DRCM.get_canonical_currency('kron')).to eq('kronars')
      expect(DRCM.get_canonical_currency('l')).to eq('lirums')
      expect(DRCM.get_canonical_currency('li')).to eq('lirums')
      expect(DRCM.get_canonical_currency('d')).to eq('dokoras')
      expect(DRCM.get_canonical_currency('dok')).to eq('dokoras')
    end

    it 'returns nil for unrecognized currency' do
      expect(DRCM.get_canonical_currency('zorkmids')).to be_nil
    end
  end

  # ─── convert_currency ───────────────────────────────────────────────

  describe '.convert_currency' do
    it 'returns the same amount for same-currency conversion with no fee' do
      expect(DRCM.convert_currency(1000, 'kronars', 'kronars', 0)).to eq(1000)
    end

    it 'converts kronars to lirums with positive fee' do
      # 1000 kronars * 0.8 = 800 lirums, ceil = 800, * (1 - 0.05) = 760
      result = DRCM.convert_currency(1000, 'kronars', 'lirums', 0.05)
      expect(result).to eq(760)
    end

    it 'calculates needed kronars for target lirums with negative fee' do
      # Negative fee = how much needed to receive X
      result = DRCM.convert_currency(1000, 'kronars', 'lirums', -0.05)
      expect(result).to be > 1000
    end

    it 'converts lirums to kronars with no fee' do
      # 1000 lirums * 1.25 = 1250 kronars
      result = DRCM.convert_currency(1000, 'lirums', 'kronars', 0)
      expect(result).to eq(1250)
    end

    it 'converts dokoras to kronars with positive fee' do
      result = DRCM.convert_currency(1000, 'dokoras', 'kronars', 0.05)
      expect(result).to be > 0
      expect(result).to be < 1386 # rate is ~1.386
    end
  end

  # ─── get_total_wealth ────────────────────────────────────────────────

  describe '.get_total_wealth' do
    # Mock Lich::Util for issue_command
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

      result = DRCM.get_total_wealth
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

      result = DRCM.get_total_wealth
      expect(result).to eq({ 'kronars' => 0, 'lirums' => 0, 'dokoras' => 0 })
    end

    it 'returns zeros on timeout (nil from issue_command)' do
      allow(Lich::Util).to receive(:issue_command).and_return(nil)

      result = DRCM.get_total_wealth
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

      result = DRCM.get_total_wealth
      expect(result).to eq({ 'kronars' => 5000, 'lirums' => 0, 'dokoras' => 0 })
    end

    it 'calls issue_command with correct parameters' do
      allow(Lich::Util).to receive(:issue_command).and_return(nil)

      DRCM.get_total_wealth

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
      # Mock get_data to return town data
      allow(DRCM).to receive(:get_data).with('town').and_return({
        'Crossing'   => { 'currency' => 'kronars' },
        'Shard'      => { 'currency' => 'dokoras' },
        'Riverhaven' => { 'currency' => 'lirums' }
      })
    end

    it 'returns currency for Crossing' do
      expect(DRCM.town_currency('Crossing')).to eq('kronars')
    end

    it 'returns currency for Shard' do
      expect(DRCM.town_currency('Shard')).to eq('dokoras')
    end

    it 'is an alias for hometown_currency' do
      expect(DRCM.town_currency('Riverhaven')).to eq(DRCM.hometown_currency('Riverhaven'))
    end
  end
end
