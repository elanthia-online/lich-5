# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'gemstone/combat/parser'
require 'gemstone/combat/processor'

# elanthia-online/lich-5#2415 (case 3): the game sends Earthen Fury's eruption
# lines with the target as plain text, no link. The parser filed every one as
# a foreign target (a third party), so none of the spell's damage or kills
# reached the caster's ledger. Lines are from GS4 logs.
RSpec.describe 'unlinked creature targets' do
  let(:eruption) { 'Fiery debris explodes from the ground beneath a triton brawler!' }

  describe Lich::Gemstone::Combat::Parser do
    it 'does not file an unlinked creature as a foreign target, and keeps its name' do
      result = described_class.parse_attack(eruption)
      expect(result[:name]).to eq(:earthen_fury)
      expect(result[:foreign_target]).to be_nil
      expect(result[:target_name]).to eq('triton brawler')
      expect(result[:target]).to eq({})
    end

    it 'keeps the possessive form unlinked creature name' do
      result = described_class.parse_attack('The earth cracks beneath a triton warden, releasing a column of frigid air!')
      expect(result[:target_name]).to eq('triton warden')
    end

    it 'still files a capitalized bare name (a player) as a foreign target' do
      result = described_class.parse_attack('Onkel shivers as the cold settles into his flesh.')
      expect(result[:foreign_target]).to be(true)
      expect(result[:target_name]).to be_nil
    end
  end

  describe Lich::Gemstone::Combat::Processor do
    # crtr_flag?(:dead) is the server's death flag, which the lookup reads.
    # dead? (Lich's HP model) stays false: a GS corpse keeps nonzero health.
    let(:brawler) do
      Struct.new(:id, :noun, :name, :flag_dead) do
        def crtr_flag?(flag) = flag == :dead && flag_dead == true
        def dead? = false
      end
    end

    before do
      stub_const('Lich::Gemstone::Combat::Tracker', Module.new)
      allow(Lich::Gemstone::Combat::Tracker).to receive(:settings).and_return(
        track_statuses: false, track_ucs: false, emit_attacks: true, track_damage: true, track_wounds: false
      )
      allow(Lich::Gemstone::Combat::Tracker).to receive(:debug?).and_return(false)
      stub_const('Lich::Common::Events', Module.new)
      allow(Lich::Common::Events).to receive(:emit)
      allow(Lich::Common::Events).to receive(:any_for?).with('combat.attack').and_return(false)
      %i[@death_watch @death_announced @held_cast @held_pre_flares @deferred_emits @running_spells @spell_victims_dead].each do |iv|
        described_class.instance_variable_set(iv, nil)
      end
    end

    def room(*creatures)
      registry = Class.new do
        define_singleton_method(:in_room) { |*_filters| creatures }
        define_singleton_method(:[]) { |id| creatures.find { |c| c.id == id } }
      end
      stub_const('Lich::Gemstone::Combat::Creature', registry)
    end

    def bolded(id, noun, name) = %(<pushBold/><a exist="#{id}" noun="#{noun}">#{name}</a><popBold/>)

    let(:chunk) { [eruption, '[SMR result: 132 (Open d100: 39, Bonus: 50)]', '   ... 25 points of damage!'] }

    it 'binds the eruption to the one creature in the room with that name' do
      room(brawler.new(190_214_719, 'brawler', 'triton brawler'), brawler.new(5, 'warden', 'triton warden'))
      events = described_class.parse_events(chunk)
      expect(events.map { |e| [e[:name], e[:target][:id], e[:hits].map { |h| h[:damage] }] }).to eq([[:earthen_fury, 190_214_719, [25]]])
      expect(events.first[:foreign_target]).to be_nil
    end

    it 'leaves same-named creatures unbound and does not adopt a different creature' do
      room(brawler.new(1, 'brawler', 'triton brawler'), brawler.new(2, 'brawler', 'triton brawler'))
      events = described_class.parse_events(chunk + ["   The #{bolded(5, 'warden', 'triton warden')} is stunned!"])
      expect(events.first[:name]).to eq(:earthen_fury)
      expect(events.first[:target][:id]).to be_nil
      expect(events.first[:foreign_target]).to be_nil
    end

    it 'skips a same-named corpse from an earlier kill and binds the live creature' do
      room(brawler.new(1, 'brawler', 'triton brawler', true), brawler.new(2, 'brawler', 'triton brawler'))
      expect(described_class.parse_events(chunk).first[:target][:id]).to eq(2)
    end

    it 'still skips the corpse when the room listing repeats its dead flag in this chunk' do
      room(brawler.new(1, 'brawler', 'triton brawler', true), brawler.new(2, 'brawler', 'triton brawler'))
      listing = %(<component id='room objs'>  You also see<crtrStatus exist="1" health="177" maxhealth="300" hostile="1" dead="1"/><b> #{bolded(1, 'brawler', 'a triton brawler')}</b> that appears dead.</component>)
      expect(described_class.parse_events([listing] + chunk).first[:target][:id]).to eq(2)
    end

    it 'keeps the creature this chunk killed as a candidate, so it never binds to a live namesake' do
      # this chunk's eruption kills brawler 1: its crtrStatus arrives in the
      # chunk and was applied before processing, so it is already flagged dead
      room(brawler.new(1, 'brawler', 'triton brawler', true), brawler.new(2, 'brawler', 'triton brawler'))
      killed = chunk + ['<crtrStatus exist="1" health="-12" maxhealth="300" hostile="1" dead="1"/>']
      expect(described_class.parse_events(killed).first[:target][:id]).not_to eq(2)
    end

    it 'binds the chunk\'s victim when it is the only one with that name' do
      room(brawler.new(1, 'brawler', 'triton brawler', true))
      killed = chunk + ['<crtrStatus exist="1" health="-12" maxhealth="300" hostile="1" dead="1"/>']
      expect(described_class.parse_events(killed).first[:target][:id]).to eq(1)
    end

    it 'adopts a later link to a creature with the same name' do
      room(brawler.new(1, 'brawler', 'triton brawler'), brawler.new(2, 'brawler', 'triton brawler'))
      events = described_class.parse_events(chunk + ["   The #{bolded(2, 'brawler', 'triton brawler')} is knocked to the ground!"])
      expect(events.first[:target][:id]).to eq(2)
    end

    it "adopts a crit line's short-name link to the same creature (real lines)" do
      room(brawler.new(1, 'warg', 'niveous giant warg'), brawler.new(2, 'warg', 'niveous giant warg'))
      warg_chunk = ['Craggy debris explodes from the ground beneath a niveous giant warg!',
                    '[SMR result: 195 (Open d100: 87, Bonus: 57)]', '   ... 35 points of damage!',
                    %(   Massive blow removes <pushBold/>the <a exist="2" noun="warg">giant warg</a><popBold/>'s right foot!)]
      expect(described_class.parse_events(warg_chunk).first[:target][:id]).to eq(2)
    end

    it "adopts a short-name link the registry doesn't know, by the tail of the printed name" do
      room(brawler.new(1, 'warg', 'niveous giant warg'), brawler.new(2, 'warg', 'niveous giant warg'))
      warg_chunk = ['Craggy debris explodes from the ground beneath a niveous giant warg!',
                    '[SMR result: 195 (Open d100: 87, Bonus: 57)]', '   ... 35 points of damage!',
                    %(   Massive blow removes <pushBold/>the <a exist="9" noun="warg">giant warg</a><popBold/>'s right foot!)]
      expect(described_class.parse_events(warg_chunk).first[:target][:id]).to eq(9)
    end

    context 'with a creature whose whole name is the tail of the printed one' do
      before do
        room(brawler.new(1, 'reiver', 'burly reiver'), brawler.new(2, 'reiver', 'burly reiver'), brawler.new(5, 'reiver', 'reiver'))
      end

      let(:reiver_chunk) do
        ['Craggy debris explodes from the ground beneath a burly reiver!', '[SMR result: 195 (Open d100: 87, Bonus: 57)]', '   ... 35 points of damage!']
      end

      it 'does not adopt that different creature' do
        events = described_class.parse_events(reiver_chunk + ['   The <pushBold/><a exist="5" noun="reiver">reiver</a><popBold/> is stunned!'])
        expect(events.first[:target][:id]).to be_nil
      end

      it "still adopts a crit line's short-name link to a burly reiver" do
        crit = %(   Massive blow removes <pushBold/>the <a exist="2" noun="reiver">reiver</a><popBold/>'s right foot!)
        expect(described_class.parse_events(reiver_chunk + [crit]).first[:target][:id]).to eq(2)
      end
    end
  end
end
