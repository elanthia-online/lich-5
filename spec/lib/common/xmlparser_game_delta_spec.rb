# frozen_string_literal: true

require_relative '../../spec_helper'
require 'ox'
require 'common/gameobj'
require 'common/xmlparser'
require 'gemstone/xml_delta'
require 'dragonrealms/xml_delta'

RSpec.describe Lich::Common::XMLParserDelta do
  describe '.for' do
    it 'resolves each game code to its registered delta' do
      expect(described_class.for('DR')).to be(Lich::DragonRealms::XMLDelta)
      expect(described_class.for('DRF')).to be(Lich::DragonRealms::XMLDelta)
      expect(described_class.for('GSIV')).to be(Lich::Gemstone::XMLDelta)
      expect(described_class.for('GSPlat')).to be(Lich::Gemstone::XMLDelta)
    end

    it 'falls back to Default for an unknown or not-yet-known game' do
      expect(described_class.for('unknown')).to be(described_class::Default)
      expect(described_class.for(nil)).to be(described_class::Default)
      expect(described_class.for('')).to be(described_class::Default)
    end

    # ";hmr xmlparser" greps $LOADED_FEATURES and load()s every match, and
    # lib/common/xmlparser/game_delta.rb matches. Re-running the file must not
    # drop the deltas the game files registered when GameLoader required them.
    it 'keeps every registered delta when game_delta.rb is reloaded (;hmr xmlparser)' do
      registry = described_class.instance_variable_get(:@registry)
      saved = registry.dup
      begin
        load $LOADED_FEATURES.grep(%r{/xmlparser/game_delta\.rb\z}).first
        expect(described_class.for('DR')).to be(Lich::DragonRealms::XMLDelta)
        expect(described_class.for('GSIV')).to be(Lich::Gemstone::XMLDelta)
      ensure
        registry.replace(saved)
        described_class.instance_variable_set(:@registry, registry)
      end
    end
  end

  describe 'Default#main_subtitle' do
    it 'clears the room title, as the parser did for an unknown game' do
      expect(described_class::Default.main_subtitle(' - [Somewhere]', nav_uid_pending: false)).to eq(room_title: '')
    end
  end

  describe 'Gemstone::XMLDelta#main_subtitle' do
    let(:delta) { Lich::Gemstone::XMLDelta }

    it 'strips the room number from the (double-bracketed) title' do
      allow(Lich).to receive(:display_uid).and_return(true)
      expect(delta.main_subtitle(' - [Town Square, Central] - 228', nav_uid_pending: false))
        .to eq(room_title: '[[Town Square, Central]]')
    end

    it 'turns on display_uid when the game shows a room number and it was off' do
      allow(Lich).to receive(:display_uid).and_return(false)
      expect(Lich).to receive(:display_uid=).with(true)
      delta.main_subtitle(' - [Town Square, Central] - 228', nav_uid_pending: false)
    end

    it 'leaves display_uid alone for a subtitle without a room number' do
      allow(Lich).to receive(:display_uid).and_return(false)
      expect(Lich).not_to receive(:display_uid=)
      expect(delta.main_subtitle(' - [Town Square, Central]', nav_uid_pending: false))
        .to eq(room_title: '[[Town Square, Central]]')
    end
  end

  describe 'DragonRealms::XMLDelta#main_subtitle' do
    let(:delta) { Lich::DragonRealms::XMLDelta }

    it 'double-brackets the title and takes the uid when nav did not supply one' do
      expect(delta.main_subtitle(" - [Bosque Deriel, Hermit's Shacks] (230008)", nav_uid_pending: false))
        .to eq(room_title: "[[Bosque Deriel, Hermit's Shacks]]", room_id: 230_008, nav_uid_pending: false, show_room_id: true)
    end

    it 'never overrides a nav-supplied uid' do
      expect(delta.main_subtitle(' - [Catacombs, Labyrinth] (54209)', nav_uid_pending: true)).not_to have_key(:room_id)
    end

    it 'maps the "(**)" no-uid marker to room id 0' do
      expect(delta.main_subtitle(' - [Somewhere] (**)', nav_uid_pending: false)).to include(room_id: 0, show_room_id: true)
    end

    it 'leaves room_id untouched when ShowRoomID is off (no marker)' do
      update = delta.main_subtitle(' - [Somewhere]', nav_uid_pending: false)
      expect(update).not_to have_key(:room_id)
      expect(update).to include(show_room_id: false)
    end

    it 'updates nothing for an identity-less subtitle' do
      expect(delta.main_subtitle(' - ', nav_uid_pending: false)).to eq({})
    end
  end

  describe '#apply_crtr_status' do
    it 'defers (stashes) by default and on GemStone, whose room-objs <crtrStatus> precedes the creature link' do
      expect(described_class::Default.apply_crtr_status('1', { 'hostile' => '1' })).to be false
      expect(Lich::Gemstone::XMLDelta.apply_crtr_status('1', { 'hostile' => '1' })).to be false
    end

    it 'applies id-first on DragonRealms' do
      require 'dragonrealms/creature'
      Lich::DragonRealms::Creature.clear
      expect(Lich::DragonRealms::XMLDelta.apply_crtr_status('4001', { 'hostile' => '1', 'immobile' => '1' })).to be true
      expect(Lich::DragonRealms::Creature[4001].crtr_flag?(:hostile)).to be true
    end
  end

  describe 'XMLParser integration' do
    subject(:parser) { Lich::Common::XMLParser.new }

    def feed(fragment)
      Ox.sax_parse(parser, fragment, convert_special: false, symbolize: false, skip: :skip_none)
    end

    it 'applies the GemStone delta to the main subtitle' do
      allow(XMLData).to receive(:game).and_return('GSIV')
      allow(Lich).to receive(:display_uid).and_return(true)
      feed(%(<streamWindow id='main' title='Story' subtitle=" - [Town Square, Central] - 228" location='center' target='drop'/>))
      expect(parser.room_title).to eq('[[Town Square, Central]]')
    end

    it 'applies the Default delta before the game is known' do
      allow(XMLData).to receive(:game).and_return(nil)
      feed(%(<streamWindow id='main' title='Story' subtitle=" - [Town Square, Central]" location='center' target='drop'/>))
      expect(parser.room_title).to eq('')
    end
  end
end
