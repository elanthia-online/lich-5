# frozen_string_literal: true

# NOTE: This spec intentionally does NOT require spec_helper.
# It tests Authentication in isolation with minimal mocks to verify
# the module works standalone without the full Lich infrastructure.

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

# Account state -- same accessor shape EAccess.auth sets internally (see
# eaccess.rb); Authenticator.authenticate now sets the same state at a
# provider-neutral boundary so WebLogin gets it too (see "Account state"
# specs below).
module Lich
  module Common
    module Account
      class << self
        attr_accessor :name, :game_code, :character, :subscription, :members
      end
    end
  end
end unless defined?(Lich::Common::Account)

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
        game_code: 'GS3',
        generator: false
      ).and_return(auth_result)

      result = described_class.authenticate(
        account: 'testuser',
        password: 'testpass',
        character: 'TestChar',
        game_code: 'GS3'
      )

      expect(result).to eq(auth_result)
    end

    it 'forwards the generator flag to EAccess.auth' do
      expect(Lich::Common::Authentication::EAccess).to receive(:auth).with(
        account: 'testuser',
        password: 'testpass',
        character: 'NEW',
        game_code: 'GS3',
        generator: true
      ).and_return(auth_result)

      described_class.authenticate(
        account: 'testuser',
        password: 'testpass',
        character: 'NEW',
        game_code: 'GS3',
        generator: true
      )
    end

    it 'routes to EAccess.auth on generator intent without a character' do
      expect(Lich::Common::Authentication::EAccess).to receive(:auth).with(
        account: 'testuser',
        password: 'testpass',
        character: nil,
        game_code: 'GS3',
        generator: true
      ).and_return(auth_result)

      described_class.authenticate(
        account: 'testuser',
        password: 'testpass',
        game_code: 'GS3',
        generator: true
      )
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

  describe '.authenticate web fallback' do
    let(:auth_result) { { 'key' => 'abc123', 'gamehost' => 'h', 'gameport' => 'p' } }

    before do
      allow(Lich).to receive(:log)
      allow(described_class).to receive(:sleep) # no real backoff delay in tests
      # Account uses persistent class-level attributes (not reset between
      # examples by default) -- without this, a real regression in
      # Authenticator's Account-state-setting could go undetected, since a
      # later example's assertion could pass on a value a prior example
      # already left behind rather than one this example's call actually set.
      Lich::Common::Account.name = nil
      Lich::Common::Account.game_code = nil
      Lich::Common::Account.character = nil
    end

    it 'forces WebLogin directly when auth_provider: :web, without touching EAccess' do
      expect(Lich::Common::Authentication::EAccess).not_to receive(:auth)
      expect(Lich::Common::Authentication::WebLogin).to receive(:auth_with_timeout).with(
        account: 'testuser', password: 'testpass', character: 'TestChar', game_code: 'GS3'
      ).and_return(auth_result)

      result = described_class.authenticate(
        account: 'testuser', password: 'testpass', character: 'TestChar', game_code: 'GS3', auth_provider: :web
      )
      expect(result).to eq(auth_result)
      expect(Lich).to have_received(:log).with(/authenticated via web login \(forced by auth_provider: :web\)/)
    end

    it 'logs which provider succeeded on a plain EAccess login' do
      allow(Lich::Common::Authentication::EAccess).to receive(:auth).and_return(auth_result)

      described_class.authenticate(account: 'testuser', password: 'testpass', character: 'TestChar', game_code: 'GS3')

      expect(Lich).to have_received(:log).with('info: authenticated via eaccess')
    end

    it 'falls back to WebLogin when EAccess raises a non-fatal (transport) error' do
      allow(Lich::Common::Authentication::EAccess).to receive(:auth).and_raise(SocketError, 'getaddrinfo failed')
      allow(Lich::Common::Authentication::WebLogin).to receive(:auth_with_timeout).and_return(auth_result)

      result = described_class.authenticate(
        account: 'testuser', password: 'testpass', character: 'TestChar', game_code: 'GS3'
      )
      expect(result).to eq(auth_result)
      expect(Lich::Common::Authentication::WebLogin).to have_received(:auth_with_timeout).with(
        account: 'testuser', password: 'testpass', character: 'TestChar', game_code: 'GS3'
      )
      expect(Lich).to have_received(:log).with(/authenticated via web login \(fallback from eaccess\)/)
    end

    it 'does NOT fall back to WebLogin when EAccess rejects credentials (fatal)' do
      error = Lich::Common::Authentication::EAccess::AuthenticationError.new('PASSWORD')
      allow(Lich::Common::Authentication::EAccess).to receive(:auth).and_raise(error)
      expect(Lich::Common::Authentication::WebLogin).not_to receive(:auth_with_timeout)

      expect {
        described_class.authenticate(account: 'testuser', password: 'wrong', character: 'TestChar', game_code: 'GS3')
      }.to raise_error(Lich::Common::Authentication::FatalAuthError, /PASSWORD/)
    end

    it 'does not fall back for legacy (no WebLogin equivalent)' do
      allow(Lich::Common::Authentication::EAccess).to receive(:auth).and_raise(SocketError, 'unreachable')
      expect(Lich::Common::Authentication::WebLogin).not_to receive(:auth_with_timeout)

      expect {
        described_class.authenticate(account: 'testuser', password: 'testpass', legacy: true)
      }.to raise_error(SocketError)
    end

    it 'does not fall back for generator entry (no WebLogin equivalent)' do
      allow(Lich::Common::Authentication::EAccess).to receive(:auth).and_raise(SocketError, 'unreachable')
      expect(Lich::Common::Authentication::WebLogin).not_to receive(:auth_with_timeout)

      expect {
        described_class.authenticate(account: 'testuser', password: 'testpass', game_code: 'GS3', generator: true)
      }.to raise_error(SocketError)
    end

    it 'treats a WebLogin credential rejection as fatal too (LOGIN_FAILED), without exhausting retries first' do
      allow(Lich::Common::Authentication::EAccess).to receive(:auth).and_raise(SocketError, 'unreachable')
      web_error = Lich::Common::Authentication::WebLogin::AuthenticationError.new('LOGIN_FAILED')
      allow(Lich::Common::Authentication::WebLogin).to receive(:auth_with_timeout).and_raise(web_error)

      expect {
        described_class.authenticate(account: 'testuser', password: 'wrong', character: 'TestChar', game_code: 'GS3')
      }.to raise_error(Lich::Common::Authentication::FatalAuthError, /LOGIN_FAILED/)
      expect(Lich::Common::Authentication::WebLogin).to have_received(:auth_with_timeout).once # not retried
    end

    it 'treats WebLogin NO_SUBSCRIPTION as fatal too, without exhausting retries first' do
      allow(Lich::Common::Authentication::EAccess).to receive(:auth).and_raise(SocketError, 'unreachable')
      web_error = Lich::Common::Authentication::WebLogin::AuthenticationError.new('NO_SUBSCRIPTION')
      allow(Lich::Common::Authentication::WebLogin).to receive(:auth_with_timeout).and_raise(web_error)

      expect {
        described_class.authenticate(account: 'testuser', password: 'testpass', character: 'TestChar', game_code: 'DR')
      }.to raise_error(Lich::Common::Authentication::FatalAuthError, /NO_SUBSCRIPTION/)
      expect(Lich::Common::Authentication::WebLogin).to have_received(:auth_with_timeout).once # not retried
    end

    it 'sets Account.name/game_code/character for auth_provider: :web (WebLogin.auth does not set it itself)' do
      allow(Lich::Common::Authentication::WebLogin).to receive(:auth_with_timeout).and_return(auth_result)

      described_class.authenticate(
        account: 'testuser', password: 'testpass', character: 'TestChar', game_code: 'GS3', auth_provider: :web
      )

      expect(Lich::Common::Account.name).to eq('testuser')
      expect(Lich::Common::Account.game_code).to eq('GS3')
      expect(Lich::Common::Account.character).to eq('TestChar')
    end

    it 'sets Account.name/game_code/character on fallback to WebLogin too' do
      allow(Lich::Common::Authentication::EAccess).to receive(:auth).and_raise(SocketError, 'unreachable')
      allow(Lich::Common::Authentication::WebLogin).to receive(:auth_with_timeout).and_return(auth_result)

      described_class.authenticate(account: 'testuser', password: 'testpass', character: 'TestChar', game_code: 'GS3')

      expect(Lich::Common::Account.character).to eq('TestChar')
    end

    it 'does not retry a SocketError 3 times before falling back -- fails fast on an unreachable endpoint' do
      allow(Lich::Common::Authentication::EAccess).to receive(:auth).and_raise(SocketError, 'getaddrinfo failed')
      allow(Lich::Common::Authentication::WebLogin).to receive(:auth_with_timeout).and_return(auth_result)

      described_class.authenticate(account: 'testuser', password: 'testpass', character: 'TestChar', game_code: 'GS3')

      expect(Lich::Common::Authentication::EAccess).to have_received(:auth).once
      expect(described_class).not_to have_received(:sleep)
    end

    it 'logs the actual number of attempts made, not always MAX_AUTH_RETRIES, when fast-failing early' do
      allow(Lich::Common::Authentication::EAccess).to receive(:auth).and_raise(SocketError, 'getaddrinfo failed')
      allow(Lich::Common::Authentication::WebLogin).to receive(:auth_with_timeout).and_return(auth_result)

      described_class.authenticate(account: 'testuser', password: 'testpass', character: 'TestChar', game_code: 'GS3')

      expect(Lich).to have_received(:log).with(/Authentication failed after 1 attempt:/)
    end

    it 'still retries a transient reachable-endpoint error (not fast-failed) 3 times when no fallback is available' do
      # legacy: true has no WebLogin fallback (web_fallback_supported? is
      # false), so this also confirms the retry loop doesn't reach for a
      # fallback that isn't there -- EAccess.auth is the only thing stubbed.
      allow(Lich::Common::Authentication::EAccess).to receive(:auth).and_raise(StandardError, 'weird protocol response')

      expect {
        described_class.authenticate(account: 'testuser', password: 'testpass', legacy: true)
      }.to raise_error(StandardError, /weird protocol response/)
      expect(Lich::Common::Authentication::EAccess).to have_received(:auth).exactly(3).times
      expect(Lich).to have_received(:log).with(/Authentication failed after 3 attempts:/)
    end

    it 'does NOT fast-fail an unreachable-classified error on a legacy call -- there is no alternate provider to hand off to' do
      expect(Lich::Common::Authentication::WebLogin).not_to receive(:auth_with_timeout)
      attempts = 0
      allow(Lich::Common::Authentication::EAccess).to receive(:auth) do
        attempts += 1
        raise Errno::ECONNRESET if attempts == 1

        []
      end

      result = described_class.authenticate(account: 'testuser', password: 'testpass', legacy: true)

      expect(result).to eq([])
      expect(attempts).to eq(2) # retried, not fast-failed, and recovered on the 2nd attempt
    end

    it 'does NOT fast-fail an unreachable-classified error on generator entry -- there is no alternate provider to hand off to' do
      attempts = 0
      allow(Lich::Common::Authentication::EAccess).to receive(:auth) do
        attempts += 1
        raise Errno::ECONNRESET if attempts == 1

        auth_result
      end

      result = described_class.authenticate(account: 'testuser', password: 'testpass', game_code: 'GS3', generator: true)

      expect(result).to eq(auth_result)
      expect(attempts).to eq(2)
    end

    it 'does NOT fast-fail an unreachable-classified error on a forced-web call -- there is no alternate provider to hand off to' do
      attempts = 0
      allow(Lich::Common::Authentication::WebLogin).to receive(:auth_with_timeout) do
        attempts += 1
        raise Errno::ECONNRESET if attempts == 1

        auth_result
      end

      result = described_class.authenticate(
        account: 'testuser', password: 'testpass', character: 'TestChar', game_code: 'GS3', auth_provider: :web
      )

      expect(result).to eq(auth_result)
      expect(attempts).to eq(2)
    end

    it 'does NOT fast-fail an unreachable-classified error on the fallback-to-web attempt itself -- no third provider' do
      allow(Lich::Common::Authentication::EAccess).to receive(:auth).and_raise(SocketError, 'unreachable')
      attempts = 0
      allow(Lich::Common::Authentication::WebLogin).to receive(:auth_with_timeout) do
        attempts += 1
        raise Errno::ECONNRESET if attempts == 1

        auth_result
      end

      result = described_class.authenticate(account: 'testuser', password: 'testpass', character: 'TestChar', game_code: 'GS3')

      expect(result).to eq(auth_result)
      expect(attempts).to eq(2)
    end
  end

  describe '.unreachable_error?' do
    it 'is true for connection-level errors' do
      [
        SocketError.new, Errno::ECONNREFUSED.new, Errno::ECONNRESET.new, Errno::ETIMEDOUT.new,
        Errno::EHOSTUNREACH.new, Errno::ENETUNREACH.new, OpenSSL::SSL::SSLError.new
      ].each do |error|
        expect(described_class.unreachable_error?(error)).to be(true), "expected #{error.class} to be unreachable"
      end
    end

    it 'is true for the auth_with_timeout watchdog timeout (a black-holed connection times out rather than refusing)' do
      error = RuntimeError.new('error: timed out authenticating with EAccess after 30s')
      expect(described_class.unreachable_error?(error)).to be true
    end

    it 'is false for a protocol-level error on a reachable endpoint' do
      expect(described_class.unreachable_error?(StandardError.new('weird response'))).to be false
    end

    it 'is false for an unrelated RuntimeError that is not the timeout watchdog' do
      expect(described_class.unreachable_error?(RuntimeError.new('some other runtime error'))).to be false
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
