# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'timeout'

require File.join(LIB_DIR, 'dragonrealms', 'commons', 'common-travel.rb')

DRCT = Lich::DragonRealms::DRCT unless defined?(DRCT)

RSpec.describe DRCT, '.walk_to retry depth limiting' do
  before(:each) do
    Lich::Messaging.clear_messages!
    allow(DRC).to receive(:fix_standing)
    allow(Script).to receive(:running).and_return([])
    allow(Script).to receive(:running?).and_return(false)
  end

  # -- Constant ------------------------------------------------------------

  describe 'MAX_WALK_TO_RETRIES' do
    it 'is defined' do
      expect(DRCT::MAX_WALK_TO_RETRIES).to be_a(Integer)
    end

    it 'is a small positive number' do
      expect(DRCT::MAX_WALK_TO_RETRIES).to be_between(1, 10)
    end
  end

  # -- Retry exhaustion (the bug that caused SystemStackError) -------------

  describe 'when go2 always fails' do
    before(:each) do
      # go2 always "runs" and exits immediately, room never changes
      allow(Room).to receive(:current).and_return(OpenStruct.new(id: 100))
      allow(DRCT).to receive(:start_script).and_return(:go2_handle)
      allow(XMLData).to receive(:room_description).and_return('A room')
      allow(XMLData).to receive(:room_title).and_return('[Room]')
    end

    it 'does not raise SystemStackError' do
      expect { DRCT.walk_to(999) }.not_to raise_error
    end

    it 'returns false after exhausting retries' do
      expect(DRCT.walk_to(999)).to eq(false)
    end

    it 'retries exactly MAX_WALK_TO_RETRIES times' do
      DRCT.walk_to(999)

      retry_msgs = Lich::Messaging.messages.select { |m| m[:message].include?('attempting again') }
      expect(retry_msgs.size).to eq(DRCT::MAX_WALK_TO_RETRIES)
    end

    it 'logs a give-up message on the final failure' do
      DRCT.walk_to(999)

      last_bold = Lich::Messaging.messages.select { |m| m[:type] == 'bold' }.last
      expect(last_bold[:message]).to include('giving up')
    end

    it 'includes retry counter in each retry message' do
      DRCT.walk_to(999)

      retry_msgs = Lich::Messaging.messages.select { |m| m[:message].include?('attempting again') }
      retry_msgs.each_with_index do |msg, i|
        expect(msg[:message]).to include("#{i + 1}/#{DRCT::MAX_WALK_TO_RETRIES}")
      end
    end
  end

  # -- Successful retry (go2 fails once, then succeeds) --------------------

  describe 'when go2 succeeds on a retry' do
    it 'returns true and stops retrying' do
      call_count = 0
      allow(DRCT).to receive(:start_script).and_return(:go2_handle)
      allow(XMLData).to receive(:room_description).and_return('A room')
      allow(XMLData).to receive(:room_title).and_return('[Room]')
      allow(Room).to receive(:current) do
        call_count += 1
        # First 4 calls: still in room 100 (walk_to entry + retry checks)
        # After that: arrived at room 200
        OpenStruct.new(id: call_count <= 4 ? 100 : 200)
      end

      expect(DRCT.walk_to(200)).to eq(true)
    end
  end

  # -- No retry when restart_on_fail is false ------------------------------

  describe 'when restart_on_fail is false' do
    before(:each) do
      allow(Room).to receive(:current).and_return(OpenStruct.new(id: 100))
      allow(DRCT).to receive(:start_script).and_return(:go2_handle)
      allow(XMLData).to receive(:room_description).and_return('A room')
      allow(XMLData).to receive(:room_title).and_return('[Room]')
    end

    it 'does not retry' do
      DRCT.walk_to(999, false)

      retry_msgs = Lich::Messaging.messages.select { |m| m[:message].include?('attempting again') }
      expect(retry_msgs).to be_empty
    end

    it 'returns false' do
      expect(DRCT.walk_to(999, false)).to eq(false)
    end
  end

  # -- Already at destination (no retry needed) ----------------------------

  describe 'when already at destination' do
    it 'returns true immediately without starting go2' do
      allow(Room).to receive(:current).and_return(OpenStruct.new(id: 200))

      expect(DRCT).not_to receive(:start_script)
      expect(DRCT.walk_to(200)).to eq(true)
    end
  end

  # -- Stack depth safety (adversarial) ------------------------------------

  describe 'stack safety under adversarial conditions' do
    before(:each) do
      allow(Room).to receive(:current).and_return(OpenStruct.new(id: 100))
      allow(DRCT).to receive(:start_script).and_return(:go2_handle)
      allow(XMLData).to receive(:room_description).and_return('A room')
      allow(XMLData).to receive(:room_title).and_return('[Room]')
    end

    it 'never exceeds MAX_WALK_TO_RETRIES + 1 recursive frames' do
      max_depth = 0
      original_walk_to = DRCT.method(:walk_to)

      allow(DRCT).to receive(:walk_to).and_wrap_original do |_method, *args, **kwargs|
        depth = kwargs[:_retry_depth] || 0
        max_depth = [max_depth, depth].max
        original_walk_to.call(*args, **kwargs)
      end

      DRCT.walk_to(999)

      expect(max_depth).to be <= DRCT::MAX_WALK_TO_RETRIES
    end

    it 'completes in bounded time even with instant go2 failures' do
      result = Timeout.timeout(5) { DRCT.walk_to(999) }
      expect(result).to eq(false)
    end
  end

  # -- Backward compatibility: _retry_depth not required from callers ------

  describe 'backward compatibility' do
    before(:each) do
      allow(Room).to receive(:current).and_return(OpenStruct.new(id: 100))
      allow(DRCT).to receive(:start_script).and_return(:go2_handle)
      allow(XMLData).to receive(:room_description).and_return('A room')
      allow(XMLData).to receive(:room_title).and_return('[Room]')
    end

    it 'works with positional args only (walk_to(room))' do
      expect { DRCT.walk_to(999) }.not_to raise_error
    end

    it 'works with two positional args (walk_to(room, true))' do
      expect { DRCT.walk_to(999, true) }.not_to raise_error
    end

    it 'works with two positional args (walk_to(room, false))' do
      expect { DRCT.walk_to(999, false) }.not_to raise_error
    end
  end

  # -- Flags cleanup on exhausted retries ----------------------------------

  describe 'flag cleanup' do
    before(:each) do
      allow(Room).to receive(:current).and_return(OpenStruct.new(id: 100))
      allow(DRCT).to receive(:start_script).and_return(:go2_handle)
      allow(XMLData).to receive(:room_description).and_return('A room')
      allow(XMLData).to receive(:room_title).and_return('[Room]')
    end

    it 'deletes travel flags even when retries are exhausted' do
      expect(Flags).to receive(:delete).with('travel-closed-shop').at_least(:once)
      expect(Flags).to receive(:delete).with('travel-engaged').at_least(:once)

      DRCT.walk_to(999)
    end
  end

  # -- Error propagation (non-navigation errors still raise) ---------------

  describe 'non-navigation errors' do
    it 'propagates unexpected exceptions from start_script' do
      allow(Room).to receive(:current).and_return(OpenStruct.new(id: 100))
      allow(DRCT).to receive(:start_script).and_raise(RuntimeError, 'something broke')

      expect { DRCT.walk_to(999) }.to raise_error(RuntimeError, 'something broke')
    end
  end
end
