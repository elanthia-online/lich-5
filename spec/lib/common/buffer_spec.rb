# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/common/buffer'

# Covers the dead-thread cleanup of Buffer's thread-id-keyed @@index/@@streams,
# which previously grew without bound (one entry per thread that ever read).
RSpec.describe Lich::Common::Buffer do
  let(:index)   { described_class.class_variable_get(:@@index) }
  let(:streams) { described_class.class_variable_get(:@@streams) }

  before do
    described_class.class_variable_set(:@@index, {})
    described_class.class_variable_set(:@@streams, {})
    described_class.class_variable_set(:@@buffer, [])
    described_class.class_variable_set(:@@offset, 0)
    described_class.class_variable_set(:@@last_cleanup_at, 0.0)
  end

  # Registers each id in @@index by reading from a thread that then dies.
  def register_dead_threads(count)
    ids = []
    count.times do
      Thread.new { ids << Thread.current.object_id; described_class.gets? }.join
    end
    ids
  end

  describe '.cleanup' do
    it 'removes entries for threads that are no longer alive, keeping live ones' do
      dead_ids = register_dead_threads(3)
      described_class.gets? # current (live) thread registers
      live_id = Thread.current.object_id

      described_class.cleanup

      expect(index).to have_key(live_id)
      expect(streams.keys).to contain_exactly(live_id)
      dead_ids.each { |id| expect(index).not_to have_key(id) }
    end
  end

  describe 'automatic cleanup on registration' do
    it 'sweeps dead-thread entries once the interval has elapsed' do
      # Hold the throttle closed while the dead threads accumulate entries...
      described_class.class_variable_set(:@@last_cleanup_at, Process.clock_gettime(Process::CLOCK_MONOTONIC))
      register_dead_threads(3)
      expect(index.size).to eq(3)

      # ...then force the interval open; the next new registration sweeps them.
      described_class.class_variable_set(:@@last_cleanup_at, 0.0)
      described_class.gets?

      expect(index.keys).to contain_exactly(Thread.current.object_id)
    end

    it 'does not sweep again within the throttle interval' do
      described_class.class_variable_set(:@@last_cleanup_at, Process.clock_gettime(Process::CLOCK_MONOTONIC))
      dead_ids = register_dead_threads(3)

      Thread.new { described_class.gets? }.join # new registration, still within interval

      dead_ids.each { |id| expect(index).to have_key(id) }
    end
  end
end
