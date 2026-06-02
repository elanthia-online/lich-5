# frozen_string_literal: true

# NOTE: This spec intentionally does NOT require spec_helper.
# It tests EAccess authentication in isolation with minimal mocks to verify
# the SGE protocol handling works standalone without network dependencies.

require 'rspec'
require 'tmpdir'

# Mock dependencies before requiring the code
# Use Dir.tmpdir which always exists on all platforms
DATA_DIR = Dir.tmpdir unless defined?(DATA_DIR)

# Define Lich.log separately
module Lich
  def self.log(_message)
    # no-op for tests
  end
end unless defined?(Lich)

# Account module must be defined with separate guard
module Lich
  module Common
    module Account
      class << self
        attr_accessor :name, :game_code, :character, :subscription, :members
      end
    end
  end
end unless defined?(Lich::Common::Account)

require_relative '../../../../lib/common/authentication/eaccess'

RSpec.describe Lich::Common::Authentication::EAccess do
  describe 'AuthenticationError' do
    it 'stores the error code' do
      error = described_class::AuthenticationError.new('REJECT')
      expect(error.error_code).to eq('REJECT')
    end

    it 'formats message with error code' do
      error = described_class::AuthenticationError.new('NORECORD')
      expect(error.message).to eq('Error(NORECORD)')
    end

    it 'is a StandardError subclass' do
      expect(described_class::AuthenticationError.superclass).to eq(StandardError)
    end
  end

  describe 'PACKET_SIZE' do
    it 'is defined as 8192' do
      expect(described_class::PACKET_SIZE).to eq(8192)
    end
  end

  describe '.pem' do
    it 'returns path to simu.pem in DATA_DIR' do
      expect(described_class.pem).to eq(File.join(DATA_DIR, 'simu.pem'))
    end
  end

  describe '.pem_exist?' do
    context 'when pem file exists' do
      before do
        allow(File).to receive(:exist?).with(described_class.pem).and_return(true)
      end

      it 'returns true' do
        expect(described_class.pem_exist?).to be true
      end
    end

    context 'when pem file does not exist' do
      before do
        allow(File).to receive(:exist?).with(described_class.pem).and_return(false)
      end

      it 'returns false' do
        expect(described_class.pem_exist?).to be false
      end
    end
  end

  describe '.auth' do
    # Note: The auth method involves complex network operations (SSL sockets, protocol exchange)
    # and is better tested via integration tests. Unit testing it requires extensive mocking
    # that becomes fragile when multiple specs share the same process.
    #
    # The key behaviors tested elsewhere:
    # - AuthenticationError is tested above
    # - authenticate wrapper is tested in authenticator_spec.rb
    # - Account state setting happens at the start of auth before any network ops

    it 'requires password and account parameters' do
      expect(described_class.method(:auth).parameters).to include([:keyreq, :password])
      expect(described_class.method(:auth).parameters).to include([:keyreq, :account])
    end

    it 'has optional character and game_code parameters' do
      params = described_class.method(:auth).parameters
      expect(params).to include([:key, :character])
      expect(params).to include([:key, :game_code])
    end

    it 'has optional legacy parameter' do
      params = described_class.method(:auth).parameters
      expect(params).to include([:key, :legacy])
    end
  end

  describe 'NEW_CHARACTER_CODE' do
    it 'equals "0"' do
      expect(described_class::NEW_CHARACTER_CODE).to eq('0')
    end
  end

  describe 'NEW_CHARACTER_PATTERN' do
    it 'matches "new" case-insensitively' do
      pattern = described_class::NEW_CHARACTER_PATTERN
      expect('new').to match(pattern)
      expect('NEW').to match(pattern)
      expect('New').to match(pattern)
      expect('nEw').to match(pattern)
    end

    it 'does not match substrings containing "new"' do
      pattern = described_class::NEW_CHARACTER_PATTERN
      expect('newchar').not_to match(pattern)
      expect('anew').not_to match(pattern)
      expect('renew').not_to match(pattern)
    end
  end

  describe '.resolve_char_code' do
    let(:c_response) { "C\t2\t16\t1\t1\tW_ACCT_W002\tGrimaldo\tW_ACCT_W003\tIdavoll" }

    context 'when character is "NEW" (case-insensitive)' do
      it 'returns NEW_CHARACTER_CODE for "NEW"' do
        result = described_class.resolve_char_code(c_response, 'NEW')
        expect(result).to eq('0')
      end

      it 'returns NEW_CHARACTER_CODE for "new"' do
        result = described_class.resolve_char_code(c_response, 'new')
        expect(result).to eq('0')
      end

      it 'returns NEW_CHARACTER_CODE for "New"' do
        result = described_class.resolve_char_code(c_response, 'New')
        expect(result).to eq('0')
      end

      it 'skips character lookup entirely' do
        empty_response = "C\t0\t16\t0\t1"
        result = described_class.resolve_char_code(empty_response, 'NEW')
        expect(result).to eq('0')
      end
    end

    context 'when character is a normal name' do
      it 'returns the matching character code' do
        result = described_class.resolve_char_code(c_response, 'Grimaldo')
        expect(result).to eq('W_ACCT_W002')
      end

      it 'returns the correct code for the second character' do
        result = described_class.resolve_char_code(c_response, 'Idavoll')
        expect(result).to eq('W_ACCT_W003')
      end
    end

    context 'when character is not found' do
      it 'raises AuthenticationError with CHARACTER_NOT_FOUND' do
        expect {
          described_class.resolve_char_code(c_response, 'NonExistent')
        }.to raise_error(described_class::AuthenticationError, /CHARACTER_NOT_FOUND/)
      end
    end

    context 'when character is nil' do
      it 'raises AuthenticationError with CHARACTER_NOT_FOUND' do
        expect {
          described_class.resolve_char_code(c_response, nil)
        }.to raise_error(described_class::AuthenticationError, /CHARACTER_NOT_FOUND/)
      end
    end
  end
end
