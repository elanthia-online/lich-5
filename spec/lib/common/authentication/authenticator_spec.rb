# frozen_string_literal: true

require 'rspec'
require 'tmpdir'

# Define DATA_DIR before requiring eaccess.rb
# Use Dir.tmpdir which always exists on all platforms
DATA_DIR = Dir.tmpdir unless defined?(DATA_DIR)

# Mock Lich module before requiring the actual code
module Lich
  def self.log(_message)
    # no-op for tests
  end
end unless defined?(Lich)

# Note: EAccess module is loaded via authenticator.rb -> eaccess.rb
# Tests use RSpec stubs (allow/expect) to mock EAccess.auth behavior
# We only need to ensure AuthenticationError is available for tests
module Lich
  module Common
    module Authentication
      module EAccess
        class AuthenticationError < StandardError
          attr_reader :error_code

          def initialize(error_code)
            @error_code = error_code
            super("Error(#{error_code})")
          end
        end unless defined?(Lich::Common::Authentication::EAccess::AuthenticationError)
      end
    end
  end
end unless defined?(Lich::Common::Authentication::EAccess)

# Require the actual authenticator code
require_relative '../../../../lib/common/authentication/authenticator'

RSpec.describe Lich::Common::Authentication do
  describe '.authenticate' do
    let(:auth_result) { { 'key' => 'abc123', 'gamecode' => 'GS3' } }

    before do
      # Stub the EAccess.auth method to return our test data
      allow(Lich::Common::Authentication::EAccess).to receive(:auth).and_return(auth_result)
      allow(Lich).to receive(:log)
    end

    it 'calls EAccess.auth with character and game_code' do
      expect(Lich::Common::Authentication::EAccess).to receive(:auth).with(
        account: 'testuser',
        password: 'testpass',
        character: 'TestChar',
        game_code: 'GS3'
      ).and_return(auth_result)

      result = described_class.authenticate(
        account: 'testuser',
        password: 'testpass',
        character: 'TestChar',
        game_code: 'GS3'
      )

      expect(result).to eq(auth_result)
    end

    it 'calls EAccess.auth with legacy flag when specified' do
      expect(Lich::Common::Authentication::EAccess).to receive(:auth).with(
        account: 'testuser',
        password: 'testpass',
        legacy: true
      ).and_return([])

      described_class.authenticate(
        account: 'testuser',
        password: 'testpass',
        legacy: true
      )
    end

    it 'calls EAccess.auth with just account and password when no character/game' do
      expect(Lich::Common::Authentication::EAccess).to receive(:auth).with(
        account: 'testuser',
        password: 'testpass'
      ).and_return(auth_result)

      described_class.authenticate(
        account: 'testuser',
        password: 'testpass'
      )
    end
  end

  describe '.with_retry' do
    before do
      allow(Lich).to receive(:log)
      allow(described_class).to receive(:sleep) # Don't actually sleep in tests
    end

    it 'returns the result on success' do
      result = described_class.with_retry { 'success' }
      expect(result).to eq('success')
    end

    it 'retries on transient errors' do
      attempts = 0
      result = described_class.with_retry do
        attempts += 1
        raise StandardError, 'Transient error' if attempts < 2

        'success'
      end

      expect(result).to eq('success')
      expect(attempts).to eq(2)
    end

    it 'raises FatalAuthError on fatal error codes' do
      error = Lich::Common::Authentication::EAccess::AuthenticationError.new('REJECT')

      expect {
        described_class.with_retry { raise error }
      }.to raise_error(Lich::Common::Authentication::FatalAuthError, /REJECT/)
    end

    it 'raises FatalAuthError on NORECORD error' do
      error = Lich::Common::Authentication::EAccess::AuthenticationError.new('NORECORD')

      expect {
        described_class.with_retry { raise error }
      }.to raise_error(Lich::Common::Authentication::FatalAuthError, /NORECORD/)
    end

    it 'raises FatalAuthError on INVALID error' do
      error = Lich::Common::Authentication::EAccess::AuthenticationError.new('INVALID')

      expect {
        described_class.with_retry { raise error }
      }.to raise_error(Lich::Common::Authentication::FatalAuthError, /INVALID/)
    end

    it 'raises FatalAuthError on PASSWORD error' do
      error = Lich::Common::Authentication::EAccess::AuthenticationError.new('PASSWORD')

      expect {
        described_class.with_retry { raise error }
      }.to raise_error(Lich::Common::Authentication::FatalAuthError, /PASSWORD/)
    end

    it 'raises FatalAuthError on CHARACTER_NOT_FOUND error' do
      error = Lich::Common::Authentication::EAccess::AuthenticationError.new('CHARACTER_NOT_FOUND')

      expect {
        described_class.with_retry { raise error }
      }.to raise_error(Lich::Common::Authentication::FatalAuthError, /CHARACTER_NOT_FOUND/)
    end

    it 're-raises after max retries exhausted' do
      expect {
        described_class.with_retry { raise StandardError, 'Persistent error' }
      }.to raise_error(StandardError, /Persistent error/)
    end

    it 'logs retry attempts' do
      expect(Lich).to receive(:log).with(/attempt 1\/3 failed/).at_least(:once)

      expect {
        described_class.with_retry { raise StandardError, 'Test error' }
      }.to raise_error(StandardError)
    end
  end

  describe 'constants' do
    it 'defines MAX_AUTH_RETRIES' do
      expect(Lich::Common::Authentication::MAX_AUTH_RETRIES).to eq(3)
    end

    it 'defines AUTH_RETRY_BASE_DELAY' do
      expect(Lich::Common::Authentication::AUTH_RETRY_BASE_DELAY).to eq(5)
    end

    it 'defines FATAL_ERROR_CODES' do
      expect(Lich::Common::Authentication::FATAL_ERROR_CODES).to include(
        'REJECT', 'NORECORD', 'INVALID', 'PASSWORD', 'CHARACTER_NOT_FOUND'
      )
    end
  end
end
