# frozen_string_literal: true

require_relative '../../spec_helper'
require 'common/room_description_filter'

# DragonRealms' FLAG DESCRIPTION OFF: the legacy stream drops the room
# description from the room view, the Saga-identity stream's <room> block
# keeps it (a game bug). The filter follows the game's replies to the flag and
# empties the description of a block for the character's own room.
# Shapes are real lines (spec/fixtures/streams/dr_saga_group_bank.xml and a
# 2026-10-16 Locate capture), names pseudonymized, descriptions shortened.
RSpec.describe Lich::Common::RoomDescriptionFilter do
  off_reply = "You will no longer see room descriptions.\r\n"
  on_reply = "You will now see room descriptions.\r\n"
  shacks = %(<resource picture="0"/><room><name>[Bosque Deriel, Hermit's Shacks] (230008)</name><description>Here on the route ) +
           %(between the sacred sites of the Observatory and the Faery Ring is a semi-circular clearing.</description><exists></exists>) +
           %(<players>Also here: Paintress <a exist="-10614513" noun="Brenna">Brenna</a>, <a exist="-10623441" noun="Delphine">Delphine</a> ) +
           %(and Druid <a exist="-10614301" noun="Corwin">Corwin</a>.</players><exits>Obvious paths: <d>north</d>, <d>south</d>.</exits>) +
           %(<extra></extra></room>\r\n)
  shacks_without = shacks.sub(%r{<description>.*?</description>}, '<description></description>')
  burial_ground = %(<resource picture="0"/><room><name>[Bosque Deriel, Burial Ground] (230007)</name><description>You come upon an ) +
                  %(Elven burial ground in the shade of sacred groves.</description><exists></exists><players></players>) +
                  %(<exits>Obvious paths: <d>north</d>, <d>southeast</d>.</exits><extra></extra></room>\r\n)

  around do |example|
    saved = described_class.descriptions_off?
    described_class.reset
    example.run
  ensure
    described_class.instance_variable_set(:@descriptions_off, saved)
  end

  describe '.observe' do
    it 'shows descriptions until the game has answered the flag' do
      expect(described_class.descriptions_off?).to be(false)
    end

    it 'follows the OFF reply, then the ON reply' do
      described_class.observe(+off_reply)
      expect(described_class.descriptions_off?).to be(true)
      described_class.observe(+on_reply)
      expect(described_class.descriptions_off?).to be(false)
    end

    it 'reads a reply sent without a line ending' do
      described_class.observe(+off_reply.chomp)
      expect(described_class.descriptions_off?).to be(true)
    end

    it 'keeps the state across lines that are not replies' do
      described_class.observe(+off_reply)
      ["<prompt time=\"1\">&gt;</prompt>\r\n", shacks, "You also see a deed register.\r\n"].each { |line| described_class.observe(+line) }
      expect(described_class.descriptions_off?).to be(true)
    end

    it 'goes by the later reply when one string holds both' do
      described_class.observe(+"#{off_reply}#{on_reply}")
      expect(described_class.descriptions_off?).to be(false)
      described_class.observe(+"#{on_reply}#{off_reply}")
      expect(described_class.descriptions_off?).to be(true)
    end

    [
      %(Brenna says, "You will no longer see room descriptions."\r\n),
      %(<preset id='speech'>You say</preset>, "You will no longer see room descriptions."\r\n),
      "You will no longer see room descriptions in the Crossing.\r\n"
    ].each do |line|
      it "ignores #{line.chomp.inspect}" do
        described_class.observe(+line)
        expect(described_class.descriptions_off?).to be(false)
      end
    end
  end

  describe '.apply' do
    it 'leaves every string alone while descriptions are on' do
      line = +shacks
      expect(described_class.apply(line, room_id: 230_008, room_exits: [])).to equal(line)
    end

    it "empties the description of the character's room while they are off" do
      described_class.observe(+off_reply)
      expect(described_class.apply(+shacks, room_id: 230_008, room_exits: [])).to eq(shacks_without)
    end

    it 'shows it again after the ON reply' do
      described_class.observe(+off_reply)
      described_class.observe(+on_reply)
      expect(described_class.apply(+shacks, room_id: 230_008, room_exits: [])).to eq(shacks)
    end

    # A Moon Mage's Locate shows the target's room as the same bare <room>
    # block, description included, while descriptions are off.
    it "keeps the description of a room the character is not in (Locate)" do
      described_class.observe(+off_reply)
      expect(described_class.apply(+shacks, room_id: 230_007, room_exits: %w[north southeast])).to eq(shacks)
    end

    it 'keeps it before the character has a room number' do
      described_class.observe(+off_reply)
      expect(described_class.apply(+shacks, room_id: 0, room_exits: [])).to eq(shacks)
    end

    context 'with a room name that has no room number (ShowRoomID off)' do
      no_uid = shacks.sub(' (230008)', '')

      it "empties it when the block's exits are the current room's" do
        described_class.observe(+off_reply)
        expect(described_class.apply(+no_uid, room_id: 230_008, room_exits: %w[north south])).to eq(no_uid.sub(%r{<description>.*?</description>}, '<description></description>'))
      end

      it 'keeps it when they differ' do
        described_class.observe(+off_reply)
        expect(described_class.apply(+no_uid, room_id: 230_008, room_exits: %w[north southeast])).to eq(no_uid)
      end
    end

    it 'decides for each block of a multi-block string' do
      described_class.observe(+off_reply)
      out = described_class.apply(+"#{burial_ground}#{shacks}", room_id: 230_007, room_exits: [])
      expect(out).to eq("#{burial_ground.sub(%r{<description>.*?</description>}, '<description></description>')}#{shacks}")
    end

    it 'keeps every other part of the block, markup included' do
      described_class.observe(+off_reply)
      out = described_class.apply(+shacks, room_id: 230_008, room_exits: [])
      expect(out.sub('<description></description>', '')).to eq(shacks.sub(%r{<description>.*?</description>}, ''))
    end

    it 'returns a string without a complete block unchanged, as the same object' do
      described_class.observe(+off_reply)
      ["<component id='room desc'>Here on the route.</component>\r\n",
       %(<resource picture="0"/><room><name>[Cut, Short] (5)</name><description>Half of a\r\n)].each do |line|
        line = +line
        expect(described_class.apply(line, room_id: 5, room_exits: [])).to equal(line)
      end
    end
  end
end
