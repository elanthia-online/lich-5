# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative '../../../lib/genie'

# WriteClock: the one strictly increasing counter the store's `#var` writes and the game
# state's updates take their stamps from (last writer wins, Globals.cs:604-617 R).
RSpec.describe Lich::Genie::WriteClock do
  subject(:clock) { described_class.new }

  it 'starts above zero and hands out strictly increasing stamps' do
    stamps = Array.new(5) { clock.tick }
    expect(stamps).to eq([1, 2, 3, 4, 5])
  end

  it 'never hands the same stamp to two threads' do
    stamps = Array.new(8) { Thread.new { Array.new(500) { clock.tick } } }.flat_map(&:value)
    expect(stamps.size).to eq(4000)
    expect(stamps.uniq.size).to eq(4000)
    expect(stamps.max).to eq(4000)
  end

  it 'keeps separate clocks independent' do
    other = described_class.new
    3.times { clock.tick }
    expect(other.tick).to eq(1)
  end

  it 'shares one process-wide clock between the store and the game state by default' do
    store = Lich::Genie::GlobalStore.new
    state = Lich::Genie::GameState.new
    store.set('x', '1')
    state.feed("<indicator id='IconHIDDEN' visible='y'/>\r\n")
    expect(state.stamp('hidden')).to be > store.stamp('x')
    expect(described_class::SHARED).to be_a(described_class)
  end
end
