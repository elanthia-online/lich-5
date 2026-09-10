# frozen_string_literal: true

require_relative '../../spec_helper'
require 'gemstone/fog'

# A stand-in for Spell[n]: known, affordable, and a cast that the example
# can make move the room.
FogSpell = Struct.new(:num, :known, :affordable, keyword_init: true) do
  def known? = known
  def affordable? = affordable

  def cast(*_args)
    @casts = (@casts || 0) + 1
    @on_cast&.call
    'Cast Roundtime 3 Seconds.'
  end

  def casts = @casts || 0
  def on_cast(&block) = @on_cast = block
end

RSpec.describe Lich::Gemstone::Fog do
  let(:spells) { {} }
  let(:voln) { double('OrderOfVoln', known?: false, available?: false) }
  let(:sunfist) { double('GuardiansOfSunfist', known?: false, available?: false) }
  let(:sent) { [] }

  def spell(num, known: true, affordable: true)
    spells[num] = FogSpell.new(num: num, known: known, affordable: affordable)
  end

  def arrive(id)
    Room.current = Room.room_double(id: id)
  end

  before do
    stub_const('Spell', Class.new)
    allow(Spell).to receive(:[]) { |n| spells[n] }
    allow(described_class).to receive(:voln).and_return(voln)
    allow(described_class).to receive(:sunfist).and_return(sunfist)
    allow(described_class).to receive(:sleep)
    # the confirm wait polls the clock; answer at once from the room
    allow(described_class).to receive(:wait_for_move) { |start| described_class.moved_from?(start) }
    allow(described_class).to receive(:waitrt?)
    allow(described_class).to receive(:waitcastrt?)
    allow(described_class).to receive(:fput) { |cmd| sent << cmd }
    allow(described_class).to receive(:dothistimeout) { |cmd, *_| sent << cmd; 'An invigorating rush of mana pulses through you.' }
    arrive(100)
  end

  describe '.normalize' do
    it 'takes a name, a symbol or bigshot number' do
      expect(described_class.normalize(:spirit_guide)).to eq(:spirit_guide)
      expect(described_class.normalize('Symbol_of_Return')).to eq(:symbol_of_return)
      expect(described_class.normalize(3)).to eq(:travelers_song)
      expect(described_class.normalize('5')).to eq(:familiar_gate)
      expect(described_class.normalize(6)).to be_nil
      expect(described_class.normalize(:walk)).to be_nil
    end
  end

  describe '.known? and .available' do
    it 'reads the spells and the society readers' do
      spell(130)
      spell(1020, affordable: false)
      allow(voln).to receive(:known?).with('return').and_return(true)
      allow(voln).to receive(:available?).with('return').and_return(true)
      expect(described_class.known?(:spirit_guide)).to be true
      expect(described_class.known?(:travelers_song)).to be true
      expect(described_class.known?(:sigil_of_escape)).to be false
      expect(described_class.available).to eq(%i[spirit_guide symbol_of_return])
    end

    it 'is false for an unknown spell or a missing reader' do
      allow(described_class).to receive(:voln).and_return(nil)
      expect(described_class.known?(:spirit_guide)).to be false
      expect(described_class.known?(:symbol_of_return)).to be false
    end
  end

  describe '.return' do
    it 'casts Spirit Guide and answers on the room changing' do
      spell(130).on_cast { arrive(4) }
      expect(described_class.return(:spirit_guide)).to be true
      expect(spells[130].casts).to eq(1)
    end

    it 'answers false when nothing moved' do
      spell(130)
      expect(described_class.return(1)).to be false
    end

    it 'pulses mana before a known spell it cannot afford' do
      spell(1020, affordable: false)
      expect(described_class.return(:travelers_song)).to be false
      expect(sent).to eq(['mana pulse'])
      expect(spells[1020].casts).to eq(0)
    end

    it 'falls back from Spirit Guide to the Symbol of Return, once' do
      spell(130)
      allow(voln).to receive(:known?).with('return').and_return(true)
      allow(described_class).to receive(:fput) { |cmd| sent << cmd; arrive(4) if cmd == 'symbol of return' }
      expect(described_class.return(:spirit_guide)).to be true
      expect(spells[130].casts).to eq(1)
      expect(sent).to eq(['symbol of return'])
    end

    it 'falls back from the Symbol of Return to Spirit Guide, once' do
      spell(130).on_cast { arrive(4) }
      allow(voln).to receive(:known?).with('return').and_return(true)
      expect(described_class.return(:symbol_of_return)).to be true
      expect(sent).to eq(['symbol of return'])
      expect(spells[130].casts).to eq(1)
    end

    it 'casts a second time when the first lands in the Rift and the destination is elsewhere' do
      s = spell(130)
      s.on_cast { arrive(s.casts == 1 ? described_class::RIFT_ROOM : 4) }
      expect(described_class.return(:spirit_guide, rift: true, resting_room: 4)).to be true
      expect(s.casts).to eq(2)
    end

    it 'stays in the Rift when that is the destination' do
      s = spell(130)
      s.on_cast { arrive(described_class::RIFT_ROOM) }
      expect(described_class.return(:spirit_guide, rift: true, resting_room: described_class::RIFT_ROOM)).to be true
      expect(s.casts).to eq(1)
    end

    it 'sends the Sigil of Escape only when the reader allows it' do
      expect(described_class.return(:sigil_of_escape)).to be false
      expect(sent).to be_empty
      allow(sunfist).to receive(:available?).with('escape').and_return(true)
      allow(described_class).to receive(:fput) { |cmd| sent << cmd; arrive(4) }
      expect(described_class.return(4)).to be true
      expect(sent).to eq(['sigil of escape'])
    end

    it 'gates for Familiar Gate and walks through the portal' do
      spell(930)
      allow(described_class).to receive(:fput) { |cmd| sent << cmd; arrive(4) }
      expect(described_class.return(:familiar_gate)).to be true
      expect(spells[930].casts).to eq(1)
      expect(sent).to eq(['go portal'])
    end

    it 'refuses an unknown method without sending anything' do
      expect(described_class.return(:walk)).to be false
      expect(sent).to be_empty
    end
  end
end
