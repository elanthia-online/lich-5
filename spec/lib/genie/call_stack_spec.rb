# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative '../../../lib/genie'

RSpec.describe Lich::Genie::CallStack do
  subject(:stack) { described_class.new }

  describe 'initial state' do
    it 'starts with a single base frame at PC 0' do
      expect(stack.count).to eq(1)
      expect(stack.line_value).to eq(0)
    end
  end

  describe 'program counter' do
    it 'reads and writes the active frame PC' do
      stack.line_value = 7
      expect(stack.line_value).to eq(7)
    end
  end

  describe 'gosub / return' do
    it 'pushes a frame with the arg list ($0 = full string, $1.. = tokens)' do
      stack.line_value = 3
      stack.add_jump(3, 'kill orc')
      expect(stack.count).to eq(2)
      expect(stack.arg_list).to eq(['kill orc', 'kill', 'orc'])
    end

    it 'returns to the caller frame and never pops the base frame' do
      stack.line_value = 3
      stack.add_jump(3, 'sub')
      stack.line_value = 10
      expect(stack.remove_jump).to be(true)
      expect(stack.line_value).to eq(3) # back on the caller frame
      expect(stack.remove_jump).to be(false) # base frame stays
    end
  end

  describe 'block state (per active frame)' do
    it 'pushes, replaces, reads, and pops block states' do
      expect(stack.block_value).to eq(:noeval) # empty default
      stack.block_value = :evaltrue
      expect(stack.block_count).to eq(1)
      stack.add_block(:noeval)
      expect(stack.block_count).to eq(2)
      stack.block_value = :evalfalse # replaces the top
      expect(stack.block_value).to eq(:evalfalse)
      expect(stack.remove_block).to be(true)
      expect(stack.block_value).to eq(:evaltrue)
    end

    it 'clears only the active frame block stack' do
      stack.add_block(:evaltrue)
      stack.clear_blocks
      expect(stack.block_count).to eq(0)
    end

    it 'gives each gosub frame its own fresh block stack and args' do
      stack.add_block(:evaltrue)
      stack.add_jump(5, 'x')
      expect(stack.block_count).to eq(0)
      expect(stack.remove_jump).to be(true)
      expect(stack.block_count).to eq(1) # base frame block preserved
    end
  end

  describe 'skip flags' do
    it 'tracks skip_block, target_block_depth, and last_row_was_evaluation per frame' do
      stack.skip_block = true
      stack.target_block_depth = 2
      stack.last_row_was_evaluation = true
      expect(stack.skip_block).to be(true)
      expect(stack.target_block_depth).to eq(2)
      expect(stack.last_row_was_evaluation).to be(true)
    end
  end

  describe '#clear' do
    it 'resets to a single empty base frame' do
      stack.add_jump(5, 'x')
      stack.clear
      expect(stack.count).to eq(1)
      expect(stack.arg_list).to eq([])
    end
  end
end
