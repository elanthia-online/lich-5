require 'rspec'

# NilClass monkey-patch (matches lich runtime behavior where nil.method returns nil)
class NilClass
  def method_missing(*)
    nil
  end
end

# Mock DRC (module)
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

# Mock DRCT (module)
module DRCT
  def self.walk_to(*_args)
    nil
  end

  def self.buy_item(*_args)
    nil
  end
end unless defined?(DRCT)

# Mock DRCA (module)
module DRCA
  def self.cast_spell(*_args)
    nil
  end
end unless defined?(DRCA)

# Mock Lich::Messaging
module Lich
  module Messaging
    def self.msg(_type, _message)
      nil
    end
  end

  module Util
    def self.issue_command(*_args, **_kwargs)
      nil
    end
  end
end unless defined?(Lich::Messaging)

require_relative '../../../../lib/dragonrealms/commons/common-theurgy'

DRCTH = Lich::DragonRealms::DRCTH unless defined?(DRCTH)
CommuneSenseResult = Lich::DragonRealms::DRCTH::CommuneSenseResult unless defined?(CommuneSenseResult)

RSpec.describe DRCTH do
  # ─── Constants ───────────────────────────────────────────────────────

  describe 'constants' do
    describe 'CLERIC_ITEMS' do
      it 'is frozen' do
        expect(DRCTH::CLERIC_ITEMS).to be_frozen
      end

      it 'has frozen elements' do
        DRCTH::CLERIC_ITEMS.each do |item|
          expect(item).to be_frozen
        end
      end

      it 'contains expected items' do
        expect(DRCTH::CLERIC_ITEMS).to include('holy water', 'holy oil', 'incense', 'flint', 'jalbreth balm')
      end
    end

    describe 'COMMUNE_ERRORS' do
      it 'is frozen' do
        expect(DRCTH::COMMUNE_ERRORS).to be_frozen
      end

      it 'has frozen elements' do
        DRCTH::COMMUNE_ERRORS.each do |item|
          expect(item).to be_frozen
        end
      end

      it 'contains expected error messages' do
        expect(DRCTH::COMMUNE_ERRORS).to include(
          'As you commune you sense that the ground is already consecrated.'
        )
      end
    end

    describe 'DEVOTION_LEVELS' do
      it 'is frozen' do
        expect(DRCTH::DEVOTION_LEVELS).to be_frozen
      end

      it 'has frozen elements' do
        DRCTH::DEVOTION_LEVELS.each do |item|
          expect(item).to be_frozen
        end
      end

      it 'contains 17 levels' do
        expect(DRCTH::DEVOTION_LEVELS.length).to eq(17)
      end
    end

    describe 'COMMUNE_SENSE_START' do
      it 'is frozen' do
        expect(DRCTH::COMMUNE_SENSE_START).to be_frozen
      end

      it 'matches known first-line patterns' do
        expect("Tamsine's benevolent eyes are upon you.").to match(DRCTH::COMMUNE_SENSE_START)
        expect("The miracle of Tamsine has manifested about you.").to match(DRCTH::COMMUNE_SENSE_START)
        expect("You are under the auspices of Kertigen.").to match(DRCTH::COMMUNE_SENSE_START)
        expect("Meraud's influence is woven into the area.").to match(DRCTH::COMMUNE_SENSE_START)
        expect("You are not a vessel for the gods at present.").to match(DRCTH::COMMUNE_SENSE_START)
        expect("You will not be able to open another divine conduit yet.").to match(DRCTH::COMMUNE_SENSE_START)
        expect("You are eager to better understand your relationship with the Immortals.").to match(DRCTH::COMMUNE_SENSE_START)
      end
    end
  end

  # ─── CommuneSenseResult ─────────────────────────────────────────────

  describe CommuneSenseResult do
    describe '#initialize' do
      it 'defaults to commune_ready true with empty arrays' do
        result = CommuneSenseResult.new
        expect(result.commune_ready).to be true
        expect(result.active_communes).to eq([])
        expect(result.recent_communes).to eq([])
      end

      it 'accepts keyword arguments' do
        result = CommuneSenseResult.new(
          active_communes: ['Tamsine'],
          recent_communes: ['Eluned'],
          commune_ready: false
        )
        expect(result.active_communes).to eq(['Tamsine'])
        expect(result.recent_communes).to eq(['Eluned'])
        expect(result.commune_ready).to be false
      end

      it 'freezes arrays' do
        result = CommuneSenseResult.new(active_communes: ['Tamsine'])
        expect(result.active_communes).to be_frozen
        expect(result.recent_communes).to be_frozen
      end
    end

    describe '#commune_ready?' do
      it 'returns true when ready' do
        result = CommuneSenseResult.new(commune_ready: true)
        expect(result.commune_ready?).to be true
      end

      it 'returns false when not ready' do
        result = CommuneSenseResult.new(commune_ready: false)
        expect(result.commune_ready?).to be false
      end
    end

    describe '#[] backward compat' do
      it 'accesses commune_ready via string key' do
        result = CommuneSenseResult.new(commune_ready: false)
        expect(result['commune_ready']).to be false
      end

      it 'accesses active_communes via string key' do
        result = CommuneSenseResult.new(active_communes: ['Tamsine', 'Kertigen'])
        expect(result['active_communes']).to eq(['Tamsine', 'Kertigen'])
      end

      it 'accesses recent_communes via string key' do
        result = CommuneSenseResult.new(recent_communes: ['Eluned'])
        expect(result['recent_communes']).to eq(['Eluned'])
      end

      it 'supports .include? on active_communes via [] access' do
        result = CommuneSenseResult.new(active_communes: ['Tamsine'])
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
        result = DRCTH.parse_commune_sense_lines(lines)
        expect(result.commune_ready).to be false
        expect(result['commune_ready']).to be false
      end

      it 'detects active Tamsine' do
        result = DRCTH.parse_commune_sense_lines(lines)
        expect(result.active_communes).to include('Tamsine')
        expect(result['active_communes']).to include('Tamsine')
      end

      it 'detects recent Tamsine' do
        result = DRCTH.parse_commune_sense_lines(lines)
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
        result = DRCTH.parse_commune_sense_lines(lines)
        expect(result.commune_ready).to be true
      end

      it 'detects active Tamsine via miracle pattern' do
        result = DRCTH.parse_commune_sense_lines(lines)
        expect(result.active_communes).to include('Tamsine')
      end

      it 'detects recent Eluned and Tamsine' do
        result = DRCTH.parse_commune_sense_lines(lines)
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
        result = DRCTH.parse_commune_sense_lines(lines)
        expect(result.commune_ready).to be false
      end

      it 'detects active Tamsine and Kertigen' do
        result = DRCTH.parse_commune_sense_lines(lines)
        expect(result.active_communes).to include('Tamsine')
        expect(result.active_communes).to include('Kertigen')
      end

      it 'detects recent Tamsine, Eluned, and Kertigen' do
        result = DRCTH.parse_commune_sense_lines(lines)
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
        result = DRCTH.parse_commune_sense_lines(lines)
        expect(result.commune_ready).to be true
      end

      it 'has no active communes' do
        result = DRCTH.parse_commune_sense_lines(lines)
        expect(result.active_communes).to be_empty
      end

      it 'detects recent Truffenyi and Eluned' do
        result = DRCTH.parse_commune_sense_lines(lines)
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
        result = DRCTH.parse_commune_sense_lines(lines)
        expect(result.commune_ready).to be true
      end

      it 'detects active Meraud' do
        result = DRCTH.parse_commune_sense_lines(lines)
        expect(result.active_communes).to include('Meraud')
      end

      it 'has no recent communes' do
        result = DRCTH.parse_commune_sense_lines(lines)
        expect(result.recent_communes).to be_empty
      end
    end

    context 'with empty lines filtered out' do
      it 'handles empty input' do
        result = DRCTH.parse_commune_sense_lines([])
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
        result = DRCTH.parse_commune_sense_lines(lines)
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
        expect(DRCTH.has_holy_water?(container, water_holder)).to be false
      end

      it 'does not check inside water holder' do
        expect(DRCI).not_to receive(:inside?)
        DRCTH.has_holy_water?(container, water_holder)
      end
    end

    context 'when water holder is retrieved and has holy water' do
      before do
        allow(DRCI).to receive(:get_item?).with('chalice', 'portal').and_return(true)
        allow(DRCI).to receive(:inside?).with('holy water', 'chalice').and_return(true)
        allow(DRCI).to receive(:put_away_item?).and_return(true)
      end

      it 'returns true' do
        expect(DRCTH.has_holy_water?(container, water_holder)).to be true
      end

      it 'puts water holder back' do
        expect(DRCI).to receive(:put_away_item?).with('chalice', 'portal')
        DRCTH.has_holy_water?(container, water_holder)
      end
    end

    context 'when water holder is retrieved but has no holy water' do
      before do
        allow(DRCI).to receive(:get_item?).with('chalice', 'portal').and_return(true)
        allow(DRCI).to receive(:inside?).with('holy water', 'chalice').and_return(false)
        allow(DRCI).to receive(:put_away_item?).and_return(true)
      end

      it 'returns false' do
        expect(DRCTH.has_holy_water?(container, water_holder)).to be false
      end

      it 'still puts water holder back' do
        expect(DRCI).to receive(:put_away_item?).with('chalice', 'portal')
        DRCTH.has_holy_water?(container, water_holder)
      end
    end
  end

  # ─── has_*? predicates ──────────────────────────────────────────────

  describe '.has_flint?' do
    it 'delegates to DRCI.have_item_by_look?' do
      expect(DRCI).to receive(:have_item_by_look?).with('flint', 'portal').and_return(true)
      expect(DRCTH.has_flint?('portal')).to be true
    end
  end

  describe '.has_holy_oil?' do
    it 'delegates to DRCI.have_item_by_look?' do
      expect(DRCI).to receive(:have_item_by_look?).with('holy oil', 'portal').and_return(true)
      expect(DRCTH.has_holy_oil?('portal')).to be true
    end
  end

  describe '.has_incense?' do
    it 'delegates to DRCI.have_item_by_look?' do
      expect(DRCI).to receive(:have_item_by_look?).with('incense', 'portal').and_return(false)
      expect(DRCTH.has_incense?('portal')).to be false
    end
  end

  describe '.has_jalbreth_balm?' do
    it 'delegates to DRCI.have_item_by_look?' do
      expect(DRCI).to receive(:have_item_by_look?).with('jalbreth balm', 'portal').and_return(true)
      expect(DRCTH.has_jalbreth_balm?('portal')).to be true
    end
  end

  # ─── sprinkle? ──────────────────────────────────────────────────────

  describe '.sprinkle?' do
    it 'returns true on successful sprinkle' do
      allow(DRC).to receive(:bput).and_return('You sprinkle')
      expect(DRCTH.sprinkle?('chalice', 'altar')).to be true
    end

    it 'returns false when sprinkle fails with what' do
      allow(DRC).to receive(:bput).and_return('Sprinkle what')
      expect(DRCTH.sprinkle?('chalice', 'altar')).to be false
    end

    it 'returns false when sprinkle fails with referring' do
      allow(DRC).to receive(:bput).and_return('What were you referring to')
      expect(DRCTH.sprinkle?('chalice', 'altar')).to be false
    end

    it 'sends correct command' do
      expect(DRC).to receive(:bput).with(
        'sprinkle chalice on altar',
        'You sprinkle', 'Sprinkle (what|that)', 'What were you referring to'
      ).and_return('You sprinkle')
      DRCTH.sprinkle?('chalice', 'altar')
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
        expect(DRCTH.sprinkle_holy_water?(container, water_holder, target)).to be false
      end

      it 'logs a message' do
        expect(Lich::Messaging).to receive(:msg).with('bold', "DRCTH: Can't get chalice to sprinkle.")
        DRCTH.sprinkle_holy_water?(container, water_holder, target)
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
        expect(DRCTH.sprinkle_holy_water?(container, water_holder, target)).to be false
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
        expect(DRCTH.sprinkle_holy_water?(container, water_holder, target)).to be true
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
        expect(DRCTH.sprinkle_holy_oil?(container, target)).to be false
      end

      it 'logs a message' do
        expect(Lich::Messaging).to receive(:msg).with('bold', "DRCTH: Can't get holy oil to sprinkle.")
        DRCTH.sprinkle_holy_oil?(container, target)
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
        expect(DRCTH.sprinkle_holy_oil?(container, target)).to be false
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
        expect(DRCTH.sprinkle_holy_oil?(container, target)).to be true
      end
    end
  end

  # ─── empty_cleric_right_hand / empty_cleric_left_hand ───────────────

  describe '.empty_cleric_right_hand' do
    let(:container) { 'portal' }

    context 'when right hand is empty' do
      before { allow(DRC).to receive(:right_hand).and_return(nil) }

      it 'does nothing' do
        expect(DRCI).not_to receive(:put_away_item?)
        DRCTH.empty_cleric_right_hand(container)
      end
    end

    context 'when right hand has a cleric item' do
      before { allow(DRC).to receive(:right_hand).and_return('some incense') }

      it 'puts item in theurgy container' do
        expect(DRCI).to receive(:put_away_item?).with('some incense', 'portal')
        DRCTH.empty_cleric_right_hand(container)
      end
    end

    context 'when right hand has a non-cleric item' do
      before { allow(DRC).to receive(:right_hand).and_return('steel sword') }

      it 'puts item away without specifying container' do
        expect(DRCI).to receive(:put_away_item?).with('steel sword', nil)
        DRCTH.empty_cleric_right_hand(container)
      end
    end

    context 'when right hand has holy water' do
      before { allow(DRC).to receive(:right_hand).and_return('some holy water') }

      it 'puts item in theurgy container' do
        expect(DRCI).to receive(:put_away_item?).with('some holy water', 'portal')
        DRCTH.empty_cleric_right_hand(container)
      end
    end
  end

  describe '.empty_cleric_left_hand' do
    let(:container) { 'portal' }

    context 'when left hand is empty' do
      before { allow(DRC).to receive(:left_hand).and_return(nil) }

      it 'does nothing' do
        expect(DRCI).not_to receive(:put_away_item?)
        DRCTH.empty_cleric_left_hand(container)
      end
    end

    context 'when left hand has a cleric item (jalbreth balm)' do
      before { allow(DRC).to receive(:left_hand).and_return('some jalbreth balm') }

      it 'puts item in theurgy container' do
        expect(DRCI).to receive(:put_away_item?).with('some jalbreth balm', 'portal')
        DRCTH.empty_cleric_left_hand(container)
      end
    end

    context 'when left hand has a non-cleric item' do
      before { allow(DRC).to receive(:left_hand).and_return('bronze shield') }

      it 'puts item away without specifying container' do
        expect(DRCI).to receive(:put_away_item?).with('bronze shield', nil)
        DRCTH.empty_cleric_left_hand(container)
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
      DRCTH.quick_bless_item('incense')
    end
  end

  # ─── commune_sense (integration with issue_command) ─────────────────

  describe '.commune_sense' do
    context 'when issue_command returns nil (timeout)' do
      before do
        allow(Lich::Util).to receive(:issue_command).and_return(nil)
      end

      it 'returns a default CommuneSenseResult' do
        result = DRCTH.commune_sense
        expect(result).to be_a(CommuneSenseResult)
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
          DRCTH::COMMUNE_SENSE_START,
          /Roundtime/,
          usexml: false,
          quiet: true,
          include_end: false
        )
        DRCTH.commune_sense
      end

      it 'strips and filters empty lines before parsing' do
        result = DRCTH.commune_sense
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
        expect(DRCTH.wave_incense?(container, flint_lighter, target)).to be false
      end
    end

    context 'when incense is not available' do
      before do
        allow(DRCI).to receive(:have_item_by_look?).with('flint', 'portal').and_return(true)
        allow(DRCI).to receive(:have_item_by_look?).with('incense', 'portal').and_return(false)
      end

      it 'returns false with message' do
        expect(Lich::Messaging).to receive(:msg).with('bold', "DRCTH: Can't find incense to light")
        expect(DRCTH.wave_incense?(container, flint_lighter, target)).to be false
      end
    end

    context 'when flint lighter cannot be retrieved' do
      before do
        allow(DRCI).to receive(:have_item_by_look?).and_return(true)
        allow(DRCI).to receive(:get_item?).with('steel flint').and_return(false)
      end

      it 'returns false with message' do
        expect(Lich::Messaging).to receive(:msg).with('bold', "DRCTH: Can't get steel flint to light incense")
        expect(DRCTH.wave_incense?(container, flint_lighter, target)).to be false
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
        expect(DRCTH.wave_incense?(container, flint_lighter, target)).to be false
      end
    end
  end
end
