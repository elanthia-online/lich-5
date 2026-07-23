# frozen_string_literal: true

require_relative '../../spec_helper'
require 'common/socket_read_hook'

RSpec.describe Lich::Common::SocketReadHook do
  before do
    allow(Lich).to receive(:log)
  end

  after do
    described_class.list.each { |name| described_class.remove(name) }
  end

  it 'delivers immutable input and timing metadata inline' do
    received = nil
    described_class.add('capture', lambda { |raw, event| received = [raw, event] })

    described_class.run('line', received_at: Time.at(10), monotonic_received_at: 20.0)
    raw, event = received

    expect(raw).to eq('line')
    expect(raw).to be_frozen
    expect(event.received_at).to eq(Time.at(10))
    expect(event.monotonic_received_at).to eq(20.0)
    expect(event).to be_frozen
  end

  it 'completes each hook before returning to the socket reader' do
    calls = []
    described_class.add('first') { calls << :first }
    described_class.add('second') { calls << :second }

    described_class.run('line')
    calls << :reader_continues

    expect(calls).to eq(%i[first second reader_continues])
  end

  it 'removes a hook that raises and continues with later hooks' do
    calls = []
    described_class.add('broken') { raise 'bad hook' }
    described_class.add('healthy') { calls << :healthy }

    described_class.run('line')

    expect(described_class.list).to eq(['healthy'])
    expect(calls).to eq([:healthy])
    expect(Lich).to have_received(:log).with(/SocketReadHook broken: RuntimeError/)
  end
end
