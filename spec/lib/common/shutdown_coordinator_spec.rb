# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/common/shutdown_coordinator'

RSpec.describe Lich::Common::ShutdownCoordinator do
  before do
    described_class.reset!
    allow(Lich).to receive(:log)
  end

  after do
    described_class.reset!
  end

  it 'records the first shutdown request' do
    request = described_class.request(reason: :user_exit, source: :primary_frontend)

    expect(request.reason).to eq(:user_exit)
    expect(request.source).to eq('primary_frontend')
    expect(request).to be_frozen
    expect(described_class.current).to be_frozen
    expect(described_class.reason).to eq(:user_exit)
    expect(described_class).to be_requested
  end

  it 'keeps the first reason when a later request arrives' do
    first = described_class.request(reason: :user_exit, source: :primary_frontend)
    second = described_class.request(reason: :game_eof, source: :game_reader)

    expect(second).to equal(first)
    expect(described_class.reason).to eq(:user_exit)
    expect(described_class.current.source).to eq('primary_frontend')
  end

  it 'classifies explicit user exit as orderly' do
    described_class.request(reason: :user_exit, source: :primary_frontend)

    expect(described_class).to be_orderly_user_exit
    expect(described_class).not_to be_connection_loss
  end

  it 'classifies connection loss reasons' do
    described_class.request(reason: :connection_reset, source: :game_reader)

    expect(described_class).to be_connection_loss
    expect(described_class).not_to be_orderly_user_exit
  end

  it 'logs the first shutdown request with reason and source' do
    described_class.request(reason: :game_timeout, source: :game_reader, detail: Errno::ETIMEDOUT)

    expect(Lich).to have_received(:log).with(
      'info: shutdown requested reason=game_timeout source=game_reader detail=Errno::ETIMEDOUT'
    )
  end

  it 'rejects invalid reasons' do
    expect {
      described_class.request(reason: :unknown, source: :game_reader)
    }.to raise_error(ArgumentError, 'invalid shutdown reason: :unknown')
  end

  it 'rejects missing sources' do
    expect {
      described_class.request(reason: :game_eof, source: '')
    }.to raise_error(ArgumentError, 'shutdown source must be present')
  end
end
