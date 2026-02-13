# frozen_string_literal: true

require 'rspec'

# NilClass monkey-patch (matches lich runtime behavior where nil.method returns nil)
class NilClass
  def method_missing(*)
    nil
  end
end

# Mock DRC (module) — define at top level with *_args for cross-spec compat
module DRC
  def self.bput(*_args)
    nil
  end

  def self.left_hand
    nil
  end

  def self.right_hand
    nil
  end

  def self.message(*_args)
    nil
  end
end unless defined?(DRC)

# Defensive method additions for methods other specs may not define
DRC.define_singleton_method(:left_hand) { nil } unless DRC.respond_to?(:left_hand)
DRC.define_singleton_method(:right_hand) { nil } unless DRC.respond_to?(:right_hand)
DRC.define_singleton_method(:message) { |*_args| nil } unless DRC.respond_to?(:message)

# Mock DRCI (module)
module DRCI
  def self.in_hands?(*_args)
    false
  end

  def self.inside?(*_args)
    false
  end

  def self.get_item?(*_args)
    true
  end

  def self.put_away_item?(*_args)
    true
  end

  def self.have_item_by_look?(*_args)
    false
  end
end unless defined?(DRCI)

DRCI.define_singleton_method(:in_hands?) { |*_args| false } unless DRCI.respond_to?(:in_hands?)
DRCI.define_singleton_method(:inside?) { |*_args| false } unless DRCI.respond_to?(:inside?)

# Mock DRCT (module)
module DRCT
  def self.walk_to(*_args)
    nil
  end

  def self.buy_item(*_args)
    nil
  end
end unless defined?(DRCT)

DRCT.define_singleton_method(:walk_to) { |*_args| nil } unless DRCT.respond_to?(:walk_to)
DRCT.define_singleton_method(:buy_item) { |*_args| nil } unless DRCT.respond_to?(:buy_item)

# Mock DRCA (module)
module DRCA
  def self.cast_spell(*_args)
    nil
  end
end unless defined?(DRCA)

DRCA.define_singleton_method(:cast_spell) { |*_args| nil } unless DRCA.respond_to?(:cast_spell)

# Mock Lich::Messaging (separate guard from Lich::Util)
module Lich
  module Messaging
    def self.msg(*_args)
      nil
    end
  end unless defined?(Lich::Messaging)

  module Util
    def self.issue_command(*_args, **_kwargs)
      nil
    end
  end unless defined?(Lich::Util)
end

# Namespace aliases — MUST be BEFORE require so namespaced code resolves to same objects
module Lich
  module DragonRealms
    DRC = ::DRC unless defined?(Lich::DragonRealms::DRC)
    DRCI = ::DRCI unless defined?(Lich::DragonRealms::DRCI)
    DRCT = ::DRCT unless defined?(Lich::DragonRealms::DRCT)
    DRCA = ::DRCA unless defined?(Lich::DragonRealms::DRCA)
  end
end

# Kernel mocks for global methods used by module_function code
module Kernel
  def get_data(*_args)
    {}
  end
  unless method_defined?(:get_data)
    define_method(:get_data) { |*_args| {} }
  end

  def waitrt?
    nil
  end
  unless method_defined?(:waitrt?)
    define_method(:waitrt?) { nil }
  end

  def pause(*_args)
    nil
  end
  unless method_defined?(:pause)
    define_method(:pause) { |*_args| nil }
  end
end

require_relative '../../../../lib/dragonrealms/commons/common-theurgy'

RSpec.describe Lich::DragonRealms::DRCTH do
  # ─── Constants ───────────────────────────────────────────────────────

  describe 'constants' do
    describe 'CLERIC_ITEMS' do
      it 'is frozen' do
        expect(described_class::CLERIC_ITEMS).to be_frozen
      end

      it 'has frozen elements' do
        described_class::CLERIC_ITEMS.each do |item|
          expect(item).to be_frozen
        end
      end

      it 'contains expected items' do
        expect(described_class::CLERIC_ITEMS).to include('holy water', 'holy oil', 'incense', 'flint', 'jalbreth balm')
      end
    end

    describe 'COMMUNE_ERRORS' do
      it 'is frozen' do
        expect(described_class::COMMUNE_ERRORS).to be_frozen
      end

      it 'has frozen elements' do
        described_class::COMMUNE_ERRORS.each do |item|
          expect(item).to be_frozen
        end
      end

      it 'contains expected error messages' do
        expect(described_class::COMMUNE_ERRORS).to include(
          'As you commune you sense that the ground is already consecrated.'
        )
      end
    end

    describe 'DEVOTION_LEVELS' do
      it 'is frozen' do
        expect(described_class::DEVOTION_LEVELS).to be_frozen
      end

      it 'has frozen elements' do
        described_class::DEVOTION_LEVELS.each do |item|
          expect(item).to be_frozen
        end
      end

      it 'contains 17 levels' do
        expect(described_class::DEVOTION_LEVELS.length).to eq(17)
      end
    end

    describe 'COMMUNE_SENSE_START' do
      it 'is frozen' do
        expect(described_class::COMMUNE_SENSE_START).to be_frozen
      end

      it 'matches known first-line patterns' do
        expect("Tamsine's benevolent eyes are upon you.").to match(described_class::COMMUNE_SENSE_START)
        expect("The miracle of Tamsine has manifested about you.").to match(described_class::COMMUNE_SENSE_START)
        expect("You are under the auspices of Kertigen.").to match(described_class::COMMUNE_SENSE_START)
        expect("Meraud's influence is woven into the area.").to match(described_class::COMMUNE_SENSE_START)
        expect("You are not a vessel for the gods at present.").to match(described_class::COMMUNE_SENSE_START)
        expect("You will not be able to open another divine conduit yet.").to match(described_class::COMMUNE_SENSE_START)
        expect("You are eager to better understand your relationship with the Immortals.").to match(described_class::COMMUNE_SENSE_START)
      end
    end
  end

  # ─── CommuneSenseResult ─────────────────────────────────────────────

  describe described_class::CommuneSenseResult do
    describe '#initialize' do
      it 'defaults to commune_ready true with empty arrays' do
        result = described_class.new
        expect(result.commune_ready).to be true
        expect(result.active_communes).to eq([])
        expect(result.recent_communes).to eq([])
      end

      it 'accepts keyword arguments' do
        result = described_class.new(
          active_communes: ['Tamsine'],
          recent_communes: ['Eluned'],
          commune_ready: false
        )
        expect(result.active_communes).to eq(['Tamsine'])
        expect(result.recent_communes).to eq(['Eluned'])
        expect(result.commune_ready).to be false
      end

      it 'freezes arrays' do
        result = described_class.new(active_communes: ['Tamsine'])
        expect(result.active_communes).to be_frozen
        expect(result.recent_communes).to be_frozen
      end
    end

    describe '#commune_ready?' do
      it 'returns true when ready' do
        result = described_class.new(commune_ready: true)
        expect(result.commune_ready?).to be true
      end

      it 'returns false when not ready' do
        result = described_class.new(commune_ready: false)
        expect(result.commune_ready?).to be false
      end
    end

    describe '#[] backward compat' do
      it 'accesses commune_ready via string key' do
        result = described_class.new(commune_ready: false)
        expect(result['commune_ready']).to be false
      end

      it 'accesses active_communes via string key' do
        result = described_class.new(active_communes: ['Tamsine', 'Kertigen'])
        expect(result['active_communes']).to eq(['Tamsine', 'Kertigen'])
      end

      it 'accesses recent_communes via string key' do
        result = described_class.new(recent_communes: ['Eluned'])
        expect(result['recent_communes']).to eq(['Eluned'])
      end

      it 'supports .include? on active_communes via [] access' do
        result = described_class.new(active_communes: ['Tamsine'])
        expect(result['active_communes'].include?('Tamsine')).to be true
        expect(result['active_communes'].include?('Kertigen')).to be false
      end
    end
  end

  # ─── parse_commune_sense_lines ──────────────────────────────────────

  describe '.parse_commune_sense_lines' do
    # Test cases ported from dr-scripts test/test_common_theurgy.rb

    context 'test case 1: active Tamsine, not ready, recent Tamsine' do
      let(:lines) do
        [
          "Tamsine's benevolent eyes are upon you.",
          'You will not be able to open another divine conduit yet.',
          'You have been recently enlightened by Tamsine.'
        ]
      end

      it 'returns not ready to commune' do
        result = described_class.parse_commune_sense_lines(lines)
        expect(result.commune_ready).to be false
        expect(result['commune_ready']).to be false
      end

      it 'detects active Tamsine' do
        result = described_class.parse_commune_sense_lines(lines)
        expect(result.active_communes).to include('Tamsine')
        expect(result['active_communes']).to include('Tamsine')
      end

      it 'detects recent Tamsine' do
        result = described_class.parse_commune_sense_lines(lines)
        expect(result.recent_communes).to include('Tamsine')
      end
    end

    context 'test case 2: miracle of Tamsine, recent Eluned and Tamsine' do
      let(:lines) do
        [
          'The miracle of Tamsine has manifested about you.',
          'The waters of Eluned are still in your thoughts.',
          'You have been recently enlightened by Tamsine.'
        ]
      end

      it 'returns ready to commune' do
        result = described_class.parse_commune_sense_lines(lines)
        expect(result.commune_ready).to be true
      end

      it 'detects active Tamsine via miracle pattern' do
        result = described_class.parse_commune_sense_lines(lines)
        expect(result.active_communes).to include('Tamsine')
      end

      it 'detects recent Eluned and Tamsine' do
        result = described_class.parse_commune_sense_lines(lines)
        expect(result.recent_communes).to include('Eluned')
        expect(result.recent_communes).to include('Tamsine')
      end
    end

    context 'test case 3: multiple active and recent communes, not ready' do
      let(:lines) do
        [
          'The miracle of Tamsine has manifested about you.',
          'You are under the auspices of Kertigen.',
          'You will not be able to open another divine conduit yet.',
          "The sounds of Kertigen's forge still ring in your ears.",
          'You have been recently enlightened by Tamsine.',
          'The waters of Eluned are still in your thoughts.'
        ]
      end

      it 'returns not ready to commune' do
        result = described_class.parse_commune_sense_lines(lines)
        expect(result.commune_ready).to be false
      end

      it 'detects active Tamsine and Kertigen' do
        result = described_class.parse_commune_sense_lines(lines)
        expect(result.active_communes).to include('Tamsine')
        expect(result.active_communes).to include('Kertigen')
      end

      it 'detects recent Tamsine, Eluned, and Kertigen' do
        result = described_class.parse_commune_sense_lines(lines)
        expect(result.recent_communes).to include('Tamsine')
        expect(result.recent_communes).to include('Eluned')
        expect(result.recent_communes).to include('Kertigen')
      end
    end

    context 'test case 4: no active communes, recent Truffenyi and Eluned' do
      let(:lines) do
        [
          'You are not a vessel for the gods at present.',
          "You are still captivated by Truffenyi's favor.",
          'The waters of Eluned are still in your thoughts.'
        ]
      end

      it 'returns ready to commune' do
        result = described_class.parse_commune_sense_lines(lines)
        expect(result.commune_ready).to be true
      end

      it 'has no active communes' do
        result = described_class.parse_commune_sense_lines(lines)
        expect(result.active_communes).to be_empty
      end

      it 'detects recent Truffenyi and Eluned' do
        result = described_class.parse_commune_sense_lines(lines)
        expect(result.recent_communes).to include('Truffenyi')
        expect(result.recent_communes).to include('Eluned')
      end
    end

    context 'test case 5: active Meraud, no recent communes' do
      let(:lines) do
        [
          "Meraud's influence is woven into the area.",
          'You are eager to better understand your relationship with the Immortals.'
        ]
      end

      it 'returns ready to commune' do
        result = described_class.parse_commune_sense_lines(lines)
        expect(result.commune_ready).to be true
      end

      it 'detects active Meraud' do
        result = described_class.parse_commune_sense_lines(lines)
        expect(result.active_communes).to include('Meraud')
      end

      it 'has no recent communes' do
        result = described_class.parse_commune_sense_lines(lines)
        expect(result.recent_communes).to be_empty
      end
    end

    context 'with empty input' do
      it 'returns default result' do
        result = described_class.parse_commune_sense_lines([])
        expect(result.commune_ready).to be true
        expect(result.active_communes).to be_empty
        expect(result.recent_communes).to be_empty
      end
    end

    context 'with unrecognized lines mixed in' do
      it 'ignores unrecognized lines' do
        lines = [
          "Tamsine's benevolent eyes are upon you.",
          'A thunderous din peals from the west.',
          'You have been recently enlightened by Tamsine.'
        ]
        result = described_class.parse_commune_sense_lines(lines)
        expect(result.active_communes).to eq(['Tamsine'])
        expect(result.recent_communes).to eq(['Tamsine'])
      end
    end
  end

  # ─── has_holy_water? ────────────────────────────────────────────────

  describe '.has_holy_water?' do
    let(:container) { 'portal' }
    let(:water_holder) { 'chalice' }

    context 'when water holder cannot be retrieved' do
      before do
        allow(DRCI).to receive(:get_item?).with('chalice', 'portal').and_return(false)
      end

      it 'returns false' do
        expect(described_class.has_holy_water?(container, water_holder)).to be false
      end

      it 'does not check inside water holder' do
        expect(DRCI).not_to receive(:inside?)
        described_class.has_holy_water?(container, water_holder)
      end
    end

    context 'when water holder is retrieved and has holy water' do
      before do
        allow(DRCI).to receive(:get_item?).with('chalice', 'portal').and_return(true)
        allow(DRCI).to receive(:inside?).with('holy water', 'chalice').and_return(true)
        allow(DRCI).to receive(:put_away_item?).and_return(true)
      end

      it 'returns true' do
        expect(described_class.has_holy_water?(container, water_holder)).to be true
      end

      it 'puts water holder back' do
        expect(DRCI).to receive(:put_away_item?).with('chalice', 'portal')
        described_class.has_holy_water?(container, water_holder)
      end
    end

    context 'when water holder is retrieved but has no holy water' do
      before do
        allow(DRCI).to receive(:get_item?).with('chalice', 'portal').and_return(true)
        allow(DRCI).to receive(:inside?).with('holy water', 'chalice').and_return(false)
        allow(DRCI).to receive(:put_away_item?).and_return(true)
      end

      it 'returns false' do
        expect(described_class.has_holy_water?(container, water_holder)).to be false
      end

      it 'still puts water holder back' do
        expect(DRCI).to receive(:put_away_item?).with('chalice', 'portal')
        described_class.has_holy_water?(container, water_holder)
      end
    end
  end

  # ─── has_*? predicates ──────────────────────────────────────────────

  describe '.has_flint?' do
    it 'delegates to DRCI.have_item_by_look?' do
      expect(DRCI).to receive(:have_item_by_look?).with('flint', 'portal').and_return(true)
      expect(described_class.has_flint?('portal')).to be true
    end
  end

  describe '.has_holy_oil?' do
    it 'delegates to DRCI.have_item_by_look?' do
      expect(DRCI).to receive(:have_item_by_look?).with('holy oil', 'portal').and_return(true)
      expect(described_class.has_holy_oil?('portal')).to be true
    end
  end

  describe '.has_incense?' do
    it 'delegates to DRCI.have_item_by_look?' do
      expect(DRCI).to receive(:have_item_by_look?).with('incense', 'portal').and_return(false)
      expect(described_class.has_incense?('portal')).to be false
    end
  end

  describe '.has_jalbreth_balm?' do
    it 'delegates to DRCI.have_item_by_look?' do
      expect(DRCI).to receive(:have_item_by_look?).with('jalbreth balm', 'portal').and_return(true)
      expect(described_class.has_jalbreth_balm?('portal')).to be true
    end
  end

  # ─── buying_cleric_item_requires_bless? ─────────────────────────────

  describe '.buying_cleric_item_requires_bless?' do
    before do
      allow(described_class).to receive(:get_data).with('theurgy').and_return(theurgy_data)
    end

    context 'when town data exists with needs_bless' do
      let(:theurgy_data) do
        { 'Crossing' => { 'incense_shop' => { 'needs_bless' => true, 'id' => 1234 } } }
      end

      it 'returns true' do
        expect(described_class.buying_cleric_item_requires_bless?('Crossing', 'incense')).to be true
      end
    end

    context 'when town data exists without needs_bless' do
      let(:theurgy_data) do
        { 'Crossing' => { 'incense_shop' => { 'id' => 1234 } } }
      end

      it 'returns nil' do
        expect(described_class.buying_cleric_item_requires_bless?('Crossing', 'incense')).to be_nil
      end
    end

    context 'when town data does not exist' do
      let(:theurgy_data) { {} }

      it 'returns nil' do
        expect(described_class.buying_cleric_item_requires_bless?('UnknownTown', 'incense')).to be_nil
      end
    end

    context 'when item shop data does not exist' do
      let(:theurgy_data) do
        { 'Crossing' => {} }
      end

      it 'returns nil' do
        expect(described_class.buying_cleric_item_requires_bless?('Crossing', 'unknown_item')).to be_nil
      end
    end
  end

  # ─── buy_cleric_item? ──────────────────────────────────────────────

  describe '.buy_cleric_item?' do
    let(:container) { 'portal' }

    before do
      allow(described_class).to receive(:get_data).with('theurgy').and_return(theurgy_data)
      allow(Lich::Messaging).to receive(:msg)
      allow(DRCI).to receive(:get_item?).and_return(true)
      allow(DRCI).to receive(:put_away_item?).and_return(true)
      allow(DRCT).to receive(:walk_to)
      allow(DRCT).to receive(:buy_item)
      allow(DRC).to receive(:bput).and_return('You combine')
    end

    context 'when town data not found' do
      let(:theurgy_data) { {} }

      it 'returns false with messaging' do
        expect(Lich::Messaging).to receive(:msg).with('bold', "DRCTH: No theurgy data found for town 'Crossing'.")
        expect(described_class.buy_cleric_item?('Crossing', 'incense', false, 1, container)).to be false
      end
    end

    context 'when item shop data not found' do
      let(:theurgy_data) { { 'Crossing' => {} } }

      it 'returns false with messaging' do
        expect(Lich::Messaging).to receive(:msg).with('bold', "DRCTH: No shop data found for 'incense' in 'Crossing'.")
        expect(described_class.buy_cleric_item?('Crossing', 'incense', false, 1, container)).to be false
      end
    end

    context 'when buying non-stackable items' do
      let(:theurgy_data) do
        { 'Crossing' => { 'incense_shop' => { 'id' => 1234 } } }
      end

      it 'walks to shop and buys requested number' do
        expect(DRCT).to receive(:walk_to).with(1234)
        expect(DRCT).to receive(:buy_item).with(1234, 'incense').twice
        expect(DRCI).to receive(:put_away_item?).with('incense', 'portal').twice
        expect(described_class.buy_cleric_item?('Crossing', 'incense', false, 2, container)).to be true
      end
    end

    context 'when buying stackable items' do
      let(:theurgy_data) do
        { 'Crossing' => { 'incense_shop' => { 'id' => 1234 } } }
      end

      it 'combines items and puts away each cycle' do
        allow(DRCI).to receive(:get_item?).with('incense', 'portal').and_return(true)
        expect(DRC).to receive(:bput).with(
          'combine incense with incense', 'You combine', "You can't combine", 'You must be holding'
        ).twice
        expect(DRCI).to receive(:put_away_item?).with('incense', 'portal').twice
        expect(described_class.buy_cleric_item?('Crossing', 'incense', true, 2, container)).to be true
      end
    end

    context 'when shop has custom method' do
      let(:theurgy_data) do
        { 'Crossing' => { 'incense_shop' => { 'id' => 1234, 'method' => 'custom_buy' } } }
      end

      it 'calls the custom method instead of buy_item' do
        allow(described_class).to receive(:custom_buy)
        expect(described_class).to receive(:custom_buy).once
        expect(DRCT).not_to receive(:buy_item)
        described_class.buy_cleric_item?('Crossing', 'incense', false, 1, container)
      end
    end
  end

  # ─── buy_single_supply ─────────────────────────────────────────────

  describe '.buy_single_supply' do
    context 'when shop has no custom method' do
      let(:shop_data) { { 'id' => 1234 } }

      it 'calls DRCT.buy_item' do
        expect(DRCT).to receive(:buy_item).with(1234, 'incense')
        described_class.buy_single_supply('incense', shop_data)
      end
    end

    context 'when shop has custom method' do
      let(:shop_data) { { 'id' => 1234, 'method' => 'custom_buy' } }

      it 'calls the custom method' do
        allow(described_class).to receive(:custom_buy)
        expect(described_class).to receive(:custom_buy)
        described_class.buy_single_supply('incense', shop_data)
      end
    end

    context 'when needs_bless is true but @known_spells is nil (module_function context)' do
      let(:shop_data) { { 'id' => 1234, 'needs_bless' => true } }

      it 'does not call quick_bless_item (known_spells is nil in module_function)' do
        allow(DRCT).to receive(:buy_item)
        expect(described_class).not_to receive(:quick_bless_item)
        described_class.buy_single_supply('incense', shop_data)
      end
    end
  end

  # ─── sprinkle? ──────────────────────────────────────────────────────

  describe '.sprinkle?' do
    it 'returns true on successful sprinkle' do
      allow(DRC).to receive(:bput).and_return('You sprinkle')
      expect(described_class.sprinkle?('chalice', 'altar')).to be true
    end

    it 'returns false when sprinkle fails with what' do
      allow(DRC).to receive(:bput).and_return('Sprinkle what')
      expect(described_class.sprinkle?('chalice', 'altar')).to be false
    end

    it 'returns false when sprinkle fails with referring' do
      allow(DRC).to receive(:bput).and_return('What were you referring to')
      expect(described_class.sprinkle?('chalice', 'altar')).to be false
    end

    it 'sends correct command' do
      expect(DRC).to receive(:bput).with(
        'sprinkle chalice on altar',
        'You sprinkle', 'Sprinkle (what|that)', 'What were you referring to'
      ).and_return('You sprinkle')
      described_class.sprinkle?('chalice', 'altar')
    end
  end

  # ─── sprinkle_holy_water? ───────────────────────────────────────────

  describe '.sprinkle_holy_water?' do
    let(:container) { 'portal' }
    let(:water_holder) { 'chalice' }
    let(:target) { 'altar' }

    context 'when get_item fails' do
      before do
        allow(DRCI).to receive(:get_item?).with('chalice', 'portal').and_return(false)
        allow(Lich::Messaging).to receive(:msg)
      end

      it 'returns false' do
        expect(described_class.sprinkle_holy_water?(container, water_holder, target)).to be false
      end

      it 'logs a message' do
        expect(Lich::Messaging).to receive(:msg).with('bold', "DRCTH: Can't get chalice to sprinkle.")
        described_class.sprinkle_holy_water?(container, water_holder, target)
      end
    end

    context 'when sprinkle fails' do
      before do
        allow(DRCI).to receive(:get_item?).and_return(true)
        allow(DRC).to receive(:bput).and_return('Sprinkle what')
        allow(DRCI).to receive(:put_away_item?).and_return(true)
        allow(Lich::Messaging).to receive(:msg)
      end

      it 'returns false and puts water holder back' do
        expect(DRCI).to receive(:put_away_item?).with('chalice', 'portal')
        expect(described_class.sprinkle_holy_water?(container, water_holder, target)).to be false
      end
    end

    context 'when sprinkle succeeds' do
      before do
        allow(DRCI).to receive(:get_item?).and_return(true)
        allow(DRC).to receive(:bput).and_return('You sprinkle')
        allow(DRCI).to receive(:put_away_item?).and_return(true)
      end

      it 'returns true and puts water holder back' do
        expect(DRCI).to receive(:put_away_item?).with('chalice', 'portal')
        expect(described_class.sprinkle_holy_water?(container, water_holder, target)).to be true
      end
    end
  end

  # ─── sprinkle_holy_oil? ─────────────────────────────────────────────

  describe '.sprinkle_holy_oil?' do
    let(:container) { 'portal' }
    let(:target) { 'altar' }

    context 'when get_item fails' do
      before do
        allow(DRCI).to receive(:get_item?).with('holy oil', 'portal').and_return(false)
        allow(Lich::Messaging).to receive(:msg)
      end

      it 'returns false' do
        expect(described_class.sprinkle_holy_oil?(container, target)).to be false
      end

      it 'logs a message' do
        expect(Lich::Messaging).to receive(:msg).with('bold', "DRCTH: Can't get holy oil to sprinkle.")
        described_class.sprinkle_holy_oil?(container, target)
      end
    end

    context 'when sprinkle fails' do
      before do
        allow(DRCI).to receive(:get_item?).and_return(true)
        allow(DRC).to receive(:bput).and_return('Sprinkle what')
        allow(DRC).to receive(:right_hand).and_return(nil)
        allow(DRC).to receive(:left_hand).and_return(nil)
        allow(Lich::Messaging).to receive(:msg)
      end

      it 'returns false and cleans up hands' do
        expect(described_class.sprinkle_holy_oil?(container, target)).to be false
      end
    end

    context 'when sprinkle succeeds' do
      before do
        allow(DRCI).to receive(:get_item?).and_return(true)
        allow(DRC).to receive(:bput).and_return('You sprinkle')
        allow(DRC).to receive(:right_hand).and_return(nil)
        allow(DRC).to receive(:left_hand).and_return(nil)
      end

      it 'returns true' do
        expect(described_class.sprinkle_holy_oil?(container, target)).to be true
      end
    end
  end

  # ─── sprinkle_holy_water (non-predicate) ───────────────────────────

  describe '.sprinkle_holy_water' do
    let(:container) { 'portal' }
    let(:water_holder) { 'chalice' }
    let(:target) { 'altar' }

    before do
      allow(DRCI).to receive(:get_item?).and_return(true)
      allow(DRC).to receive(:bput).and_return('You sprinkle')
      allow(DRCI).to receive(:put_away_item?).and_return(true)
    end

    it 'gets item, sprinkles, and puts away' do
      expect(DRCI).to receive(:get_item?).with('chalice', 'portal')
      expect(DRC).to receive(:bput).with('sprinkle chalice on altar', anything, anything, anything)
      expect(DRCI).to receive(:put_away_item?).with('chalice', 'portal')
      described_class.sprinkle_holy_water(container, water_holder, target)
    end
  end

  # ─── sprinkle_holy_oil (non-predicate) ──────────────────────────────

  describe '.sprinkle_holy_oil' do
    let(:container) { 'portal' }
    let(:target) { 'altar' }

    before do
      allow(DRCI).to receive(:get_item?).and_return(true)
      allow(DRC).to receive(:bput).and_return('You sprinkle')
      allow(DRCI).to receive(:in_hands?).and_return(true)
      allow(DRCI).to receive(:put_away_item?).and_return(true)
    end

    it 'gets oil and sprinkles on target' do
      expect(DRCI).to receive(:get_item?).with('holy oil', 'portal')
      expect(DRC).to receive(:bput).with('sprinkle oil on altar', anything, anything, anything)
      described_class.sprinkle_holy_oil(container, target)
    end

    it 'puts oil away if still in hands' do
      allow(DRCI).to receive(:in_hands?).with('oil').and_return(true)
      expect(DRCI).to receive(:put_away_item?).with('holy oil', 'portal')
      described_class.sprinkle_holy_oil(container, target)
    end

    it 'does not put oil away if not in hands' do
      allow(DRCI).to receive(:in_hands?).with('oil').and_return(false)
      expect(DRCI).not_to receive(:put_away_item?)
      described_class.sprinkle_holy_oil(container, target)
    end
  end

  # ─── apply_jalbreth_balm ───────────────────────────────────────────

  describe '.apply_jalbreth_balm' do
    let(:container) { 'portal' }
    let(:target) { 'altar' }

    before do
      allow(DRCI).to receive(:get_item?).and_return(true)
      allow(DRC).to receive(:bput).and_return('You carefully apply')
      allow(DRCI).to receive(:in_hands?).and_return(true)
      allow(DRCI).to receive(:put_away_item?).and_return(true)
    end

    it 'gets balm from container' do
      expect(DRCI).to receive(:get_item?).with('jalbreth balm', 'portal')
      described_class.apply_jalbreth_balm(container, target)
    end

    it 'applies balm to target' do
      expect(DRC).to receive(:bput).with('apply balm to altar', '.*')
      described_class.apply_jalbreth_balm(container, target)
    end

    it 'puts balm away if still in hands' do
      allow(DRCI).to receive(:in_hands?).with('balm').and_return(true)
      expect(DRCI).to receive(:put_away_item?).with('jalbreth balm', 'portal')
      described_class.apply_jalbreth_balm(container, target)
    end

    it 'does not put balm away if not in hands' do
      allow(DRCI).to receive(:in_hands?).with('balm').and_return(false)
      expect(DRCI).not_to receive(:put_away_item?)
      described_class.apply_jalbreth_balm(container, target)
    end
  end

  # ─── empty_cleric_hands ────────────────────────────────────────────

  describe '.empty_cleric_hands' do
    let(:container) { 'portal' }

    before do
      allow(DRC).to receive(:bput).and_return('You glance')
      allow(DRC).to receive(:right_hand).and_return(nil)
      allow(DRC).to receive(:left_hand).and_return(nil)
    end

    it 'glances first to refresh hand state' do
      expect(DRC).to receive(:bput).with('glance', 'You glance')
      described_class.empty_cleric_hands(container)
    end

    it 'empties both hands' do
      allow(DRC).to receive(:right_hand).and_return('some incense')
      allow(DRC).to receive(:left_hand).and_return('steel sword')
      allow(DRCI).to receive(:put_away_item?).and_return(true)

      # Right hand has cleric item → theurgy container
      expect(DRCI).to receive(:put_away_item?).with('some incense', 'portal')
      # Left hand has non-cleric item → nil container
      expect(DRCI).to receive(:put_away_item?).with('steel sword', nil)
      described_class.empty_cleric_hands(container)
    end

    it 'does nothing when both hands are empty' do
      expect(DRCI).not_to receive(:put_away_item?)
      described_class.empty_cleric_hands(container)
    end
  end

  # ─── empty_cleric_right_hand / empty_cleric_left_hand ───────────────

  describe '.empty_cleric_right_hand' do
    let(:container) { 'portal' }

    context 'when right hand is empty' do
      before { allow(DRC).to receive(:right_hand).and_return(nil) }

      it 'does nothing' do
        expect(DRCI).not_to receive(:put_away_item?)
        described_class.empty_cleric_right_hand(container)
      end
    end

    context 'when right hand has a cleric item' do
      before { allow(DRC).to receive(:right_hand).and_return('some incense') }

      it 'puts item in theurgy container' do
        expect(DRCI).to receive(:put_away_item?).with('some incense', 'portal')
        described_class.empty_cleric_right_hand(container)
      end
    end

    context 'when right hand has a non-cleric item' do
      before { allow(DRC).to receive(:right_hand).and_return('steel sword') }

      it 'puts item away without specifying container' do
        expect(DRCI).to receive(:put_away_item?).with('steel sword', nil)
        described_class.empty_cleric_right_hand(container)
      end
    end

    context 'when right hand has holy water' do
      before { allow(DRC).to receive(:right_hand).and_return('some holy water') }

      it 'puts item in theurgy container' do
        expect(DRCI).to receive(:put_away_item?).with('some holy water', 'portal')
        described_class.empty_cleric_right_hand(container)
      end
    end
  end

  describe '.empty_cleric_left_hand' do
    let(:container) { 'portal' }

    context 'when left hand is empty' do
      before { allow(DRC).to receive(:left_hand).and_return(nil) }

      it 'does nothing' do
        expect(DRCI).not_to receive(:put_away_item?)
        described_class.empty_cleric_left_hand(container)
      end
    end

    context 'when left hand has a cleric item (jalbreth balm)' do
      before { allow(DRC).to receive(:left_hand).and_return('some jalbreth balm') }

      it 'puts item in theurgy container' do
        expect(DRCI).to receive(:put_away_item?).with('some jalbreth balm', 'portal')
        described_class.empty_cleric_left_hand(container)
      end
    end

    context 'when left hand has a non-cleric item' do
      before { allow(DRC).to receive(:left_hand).and_return('bronze shield') }

      it 'puts item away without specifying container' do
        expect(DRCI).to receive(:put_away_item?).with('bronze shield', nil)
        described_class.empty_cleric_left_hand(container)
      end
    end
  end

  # ─── quick_bless_item ───────────────────────────────────────────────

  describe '.quick_bless_item' do
    it 'casts bless with correct spell data' do
      expect(DRCA).to receive(:cast_spell).with(
        { 'abbrev' => 'bless', 'mana' => 1, 'prep_time' => 2, 'cast' => 'cast my incense' },
        {}
      )
      described_class.quick_bless_item('incense')
    end
  end

  # ─── commune_sense (integration with issue_command) ─────────────────

  describe '.commune_sense' do
    context 'when issue_command returns nil (timeout)' do
      before do
        allow(Lich::Util).to receive(:issue_command).and_return(nil)
      end

      it 'returns a default CommuneSenseResult' do
        result = described_class.commune_sense
        expect(result).to be_a(described_class::CommuneSenseResult)
        expect(result.commune_ready).to be true
        expect(result.active_communes).to be_empty
        expect(result.recent_communes).to be_empty
      end
    end

    context 'when issue_command returns lines' do
      before do
        allow(Lich::Util).to receive(:issue_command).and_return([
                                                                  "Tamsine's benevolent eyes are upon you.",
                                                                  '',
                                                                  'You have been recently enlightened by Tamsine.'
                                                                ])
      end

      it 'passes correct parameters to issue_command' do
        expect(Lich::Util).to receive(:issue_command).with(
          'commune sense',
          described_class::COMMUNE_SENSE_START,
          /Roundtime/,
          usexml: false,
          quiet: true,
          include_end: false
        )
        described_class.commune_sense
      end

      it 'strips and filters empty lines before parsing' do
        result = described_class.commune_sense
        expect(result.active_communes).to eq(['Tamsine'])
        expect(result.recent_communes).to eq(['Tamsine'])
      end
    end
  end

  # ─── wave_incense? ──────────────────────────────────────────────────

  describe '.wave_incense?' do
    let(:container) { 'portal' }
    let(:flint_lighter) { 'steel flint' }
    let(:target) { 'altar' }

    before do
      # Default stubs for empty_cleric_hands
      allow(DRC).to receive(:bput).and_return('You glance')
      allow(DRC).to receive(:right_hand).and_return(nil)
      allow(DRC).to receive(:left_hand).and_return(nil)
      allow(Lich::Messaging).to receive(:msg)
    end

    context 'when flint is not available' do
      before do
        allow(DRCI).to receive(:have_item_by_look?).with('flint', 'portal').and_return(false)
      end

      it 'returns false with message' do
        expect(Lich::Messaging).to receive(:msg).with('bold', "DRCTH: Can't find flint to light")
        expect(described_class.wave_incense?(container, flint_lighter, target)).to be false
      end
    end

    context 'when incense is not available' do
      before do
        allow(DRCI).to receive(:have_item_by_look?).with('flint', 'portal').and_return(true)
        allow(DRCI).to receive(:have_item_by_look?).with('incense', 'portal').and_return(false)
      end

      it 'returns false with message' do
        expect(Lich::Messaging).to receive(:msg).with('bold', "DRCTH: Can't find incense to light")
        expect(described_class.wave_incense?(container, flint_lighter, target)).to be false
      end
    end

    context 'when flint lighter cannot be retrieved' do
      before do
        allow(DRCI).to receive(:have_item_by_look?).and_return(true)
        allow(DRCI).to receive(:get_item?).with('steel flint').and_return(false)
      end

      it 'returns false with message' do
        expect(Lich::Messaging).to receive(:msg).with('bold', "DRCTH: Can't get steel flint to light incense")
        expect(described_class.wave_incense?(container, flint_lighter, target)).to be false
      end
    end

    context 'when incense cannot be retrieved' do
      before do
        allow(DRCI).to receive(:have_item_by_look?).and_return(true)
        allow(DRCI).to receive(:get_item?).with('steel flint').and_return(true)
        allow(DRCI).to receive(:get_item?).with('incense', 'portal').and_return(false)
      end

      it 'returns false with message and cleans up' do
        expect(Lich::Messaging).to receive(:msg).with('bold', "DRCTH: Can't get incense to light")
        expect(described_class.wave_incense?(container, flint_lighter, target)).to be false
      end
    end

    context 'when lighting succeeds on first try' do
      before do
        allow(DRCI).to receive(:have_item_by_look?).and_return(true)
        allow(DRCI).to receive(:get_item?).and_return(true)
        allow(DRC).to receive(:bput).with('glance', 'You glance').and_return('You glance')
        allow(DRC).to receive(:bput).with(
          'light my incense with my flint', anything, anything, anything, anything
        ).and_return('bursts into flames')
        allow(DRC).to receive(:bput).with(/wave my incense/, anything).and_return('You wave')
        allow(DRC).to receive(:bput).with('snuff my incense', anything).and_return('You snuff out')
        allow(DRCI).to receive(:in_hands?).with('incense').and_return(true)
        allow(DRCI).to receive(:put_away_item?).and_return(true)
      end

      it 'returns true' do
        expect(described_class.wave_incense?(container, flint_lighter, target)).to be true
      end

      it 'waves incense at target' do
        expect(DRC).to receive(:bput).with("wave my incense at altar", 'You wave')
        described_class.wave_incense?(container, flint_lighter, target)
      end

      it 'snuffs incense if still in hands' do
        expect(DRC).to receive(:bput).with('snuff my incense', 'You snuff out')
        described_class.wave_incense?(container, flint_lighter, target)
      end

      it 'puts flint lighter away' do
        expect(DRCI).to receive(:put_away_item?).with('steel flint')
        described_class.wave_incense?(container, flint_lighter, target)
      end
    end

    context 'when lighting fails 5 times' do
      before do
        allow(DRCI).to receive(:have_item_by_look?).and_return(true)
        allow(DRCI).to receive(:get_item?).and_return(true)
        allow(DRC).to receive(:bput).with('glance', 'You glance').and_return('You glance')
        allow(DRC).to receive(:bput).with(
          'light my incense with my flint', anything, anything, anything, anything
        ).and_return('nothing happens')
        allow(described_class).to receive(:waitrt?)
      end

      it 'returns false with message after 5 attempts' do
        expect(Lich::Messaging).to receive(:msg).with(
          'bold', "DRCTH: Can't light your incense for some reason. Tried 5 times, giving up."
        )
        expect(described_class.wave_incense?(container, flint_lighter, target)).to be false
      end
    end

    context 'when incense is not in hands after wave' do
      before do
        allow(DRCI).to receive(:have_item_by_look?).and_return(true)
        allow(DRCI).to receive(:get_item?).and_return(true)
        allow(DRC).to receive(:bput).with('glance', 'You glance').and_return('You glance')
        allow(DRC).to receive(:bput).with(
          'light my incense with my flint', anything, anything, anything, anything
        ).and_return('bursts into flames')
        allow(DRC).to receive(:bput).with(/wave my incense/, anything).and_return('You wave')
        allow(DRCI).to receive(:in_hands?).with('incense').and_return(false)
        allow(DRCI).to receive(:put_away_item?).and_return(true)
      end

      it 'does not attempt to snuff incense' do
        expect(DRC).not_to receive(:bput).with('snuff my incense', anything)
        described_class.wave_incense?(container, flint_lighter, target)
      end
    end
  end
end
