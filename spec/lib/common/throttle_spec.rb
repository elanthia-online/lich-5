# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/common/throttle'

RSpec.describe Lich::Common::Throttle do
  subject(:throttle) { described_class.new(60.0) }

  it 'runs the block on the first call (gate open from 0.0)' do
    ran = false
    expect(throttle.run { ran = true }).to be true
    expect(ran).to be true
  end

  it 'skips a call that arrives within the interval' do
    throttle.run { :first }
    ran = false
    expect(throttle.run { ran = true }).to be false
    expect(ran).to be false
  end

  it 'runs again once the interval has elapsed' do
    throttle.run { :first }
    throttle.last_run_at = 0.0 # force the window open

    ran = false
    expect(throttle.run { ran = true }).to be true
    expect(ran).to be true
  end

  it 'stamps the attempt time even when the block raises' do
    throttle.last_run_at = 0.0
    expect { throttle.run { raise 'boom' } }.to raise_error('boom')
    expect(throttle.last_run_at).to be > 0.0
  end
end
