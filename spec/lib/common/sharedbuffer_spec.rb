# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/common/sharedbuffer'

# Covers the dead-thread cleanup of SharedBuffer's thread-id-keyed
# @buffer_index, which previously grew without bound.
RSpec.describe Lich::Common::SharedBuffer do
  subject(:buffer) { described_class.new }

  let(:index)    { buffer.instance_variable_get(:@buffer_index) }
  let(:throttle) { buffer.instance_variable_get(:@cleanup_throttle) }

  # Registers each id in @buffer_index by reading from a thread that then dies.
  def register_dead_threads(count)
    ids = []
    count.times do
      Thread.new { ids << Thread.current.object_id; buffer.gets? }.join
    end
    ids
  end

  describe '#cleanup_threads' do
    it 'removes entries for dead threads, keeping live ones' do
      dead_ids = register_dead_threads(3)
      buffer.gets? # current (live) thread registers
      live_id = Thread.current.object_id

      buffer.cleanup_threads

      expect(index).to have_key(live_id)
      dead_ids.each { |id| expect(index).not_to have_key(id) }
    end
  end

  describe 'automatic cleanup on registration' do
    it 'sweeps dead-thread entries once the interval has elapsed' do
      throttle.last_run_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      register_dead_threads(3)
      expect(index.size).to eq(3)

      throttle.last_run_at = 0.0
      buffer.gets?

      expect(index.keys).to contain_exactly(Thread.current.object_id)
    end
  end
end
