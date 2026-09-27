# frozen_string_literal: true

require 'rspec'

require_relative '../../../lib/main/detachable_session_poller'

RSpec.describe Lich::Main::DetachableSessionPoller do
  before { allow(described_class).to receive(:sleep) }

  def source(*values)
    enum = values.each
    -> { enum.next }
  end

  describe '.wait_for_name' do
    it 'returns the name immediately when already available' do
      result = described_class.wait_for_name(
        name_source: source('Mahtra'),
        shutdown_requested: -> { false }
      )
      expect(result).to eq('Mahtra')
    end

    it 'strips surrounding whitespace' do
      result = described_class.wait_for_name(
        name_source: source('  Mahtra  '),
        shutdown_requested: -> { false }
      )
      expect(result).to eq('Mahtra')
    end

    it 'keeps polling past blank and whitespace-only candidates' do
      result = described_class.wait_for_name(
        name_source: source(nil, '', '   ', 'Mahtra'),
        shutdown_requested: -> { false }
      )
      expect(result).to eq('Mahtra')
    end

    it 'never gives up on its own -- only shutdown or a name stop it' do
      many_blanks = Array.new(10_000, '')
      result = described_class.wait_for_name(
        name_source: source(*many_blanks, 'Mahtra'),
        shutdown_requested: -> { false }
      )
      expect(result).to eq('Mahtra')
    end

    it 'returns nil once shutdown is requested, without waiting for a name' do
      result = described_class.wait_for_name(
        name_source: -> { raise 'should not be called' },
        shutdown_requested: -> { true }
      )
      expect(result).to be_nil
    end

    it 'stops mid-poll once shutdown becomes requested' do
      calls = 0
      shutdown_after = 3
      result = described_class.wait_for_name(
        name_source: -> { '' },
        shutdown_requested: -> { (calls += 1) > shutdown_after }
      )
      expect(result).to be_nil
      expect(calls).to eq(shutdown_after + 1)
    end
  end
end
