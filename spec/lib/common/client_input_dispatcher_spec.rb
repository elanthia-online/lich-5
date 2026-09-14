# frozen_string_literal: true

require_relative '../../spec_helper'
require 'common/client_input_dispatcher'

RSpec.describe Lich::Common::ClientInputDispatcher do
  it 'serializes handlers dispatched concurrently' do
    active = 0
    max_active = 0
    state_mutex = Mutex.new
    start = Queue.new

    threads = 12.times.map do |index|
      Thread.new do
        start.pop
        described_class.dispatch(index) do
          state_mutex.synchronize do
            active += 1
            max_active = [max_active, active].max
          end
          sleep 0.005
          state_mutex.synchronize { active -= 1 }
        end
      end
    end
    threads.length.times { start << true }
    threads.each(&:join)

    expect(max_active).to eq(1)
  end

  it 'returns the handler result' do
    expect(described_class.dispatch('look') { |command| command.upcase }).to eq('LOOK')
  end
end
