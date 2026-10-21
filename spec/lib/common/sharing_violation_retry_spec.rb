# frozen_string_literal: true

require_relative '../../../lib/common/sharing_violation_retry'
require_relative '../../../lib/common/frontend_settings'
require_relative '../../../lib/internal_api/active_sessions'

RSpec.describe Lich::Common::SharingViolationRetry do
  let(:host) { Module.new { extend Lich::Common::SharingViolationRetry } }
  let(:delays) { described_class::DELAYS }

  before { allow(host).to receive(:sleep) }

  def run(&block)
    host.send(:retry_sharing_violation, &block)
  end

  it 'returns the block result without sleeping when the first attempt succeeds' do
    expect(run { :done }).to eq(:done)
    expect(host).not_to have_received(:sleep)
  end

  it 'retries EACCES through the extending module sleep and returns the later result' do
    attempts = 0
    result = run do
      attempts += 1
      raise Errno::EACCES, 'held open' if attempts < 3

      :published
    end

    expect(result).to eq(:published)
    expect(attempts).to eq(3)
    expect(host).to have_received(:sleep).with(delays[0]).ordered
    expect(host).to have_received(:sleep).with(delays[1]).ordered
    expect(host).to have_received(:sleep).twice
  end

  it 're-raises EACCES after one attempt per delay plus the first' do
    attempts = 0
    expect { run { attempts += 1; raise Errno::EACCES, 'held open' } }.to raise_error(Errno::EACCES)
    expect(attempts).to eq(delays.length + 1)
    expect(host).to have_received(:sleep).exactly(delays.length).times
  end

  it 'raises any other error on the first attempt' do
    attempts = 0
    expect { run { attempts += 1; raise Errno::EXDEV, 'cross device' } }.to raise_error(Errno::EXDEV)
    expect(attempts).to eq(1)
    expect(host).not_to have_received(:sleep)
  end

  it 'keeps the helper private on the extending module' do
    expect(host).not_to respond_to(:retry_sharing_violation)
    expect(Lich::Common::FrontendSettings).not_to respond_to(:retry_sharing_violation)
    expect(Lich::InternalAPI::ActiveSessions).not_to respond_to(:retry_sharing_violation)
  end

  it 'is the one schedule FrontendSettings and ActiveSessions both use' do
    expect(delays.sum).to be_within(1e-9).of(0.31)
    expect(Lich::Common::FrontendSettings::SHARING_VIOLATION_RETRY_DELAYS).to equal(delays)
    expect(Lich::InternalAPI::ActiveSessions::DISCOVERY_FILESYSTEM_RETRY_DELAYS).to equal(delays)
  end
end
